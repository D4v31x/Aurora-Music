import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LocalCachingArtistService {
  // Singleton pattern - ensures all widgets share the same cache
  static final LocalCachingArtistService _instance =
      LocalCachingArtistService._internal();
  factory LocalCachingArtistService() => _instance;
  LocalCachingArtistService._internal();

  final http.Client _client = http.Client();
  late Directory cacheDir;
  String? _accessToken;
  final String? _clientId = dotenv.env['SPOTIFY_CLIENT_ID'];
  final String? _clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'];
  final Map<String, String?> _imageCache = {};
  bool _isInitialized = false;
  bool _spotifyEnabled = false;

  // Track pending requests to avoid duplicate API calls
  final Set<String> _pendingRequests = {};
  final Map<String, Completer<String?>> _pendingCompleters = {};

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      _spotifyEnabled = _clientId != null &&
          _clientSecret != null &&
          _clientId.isNotEmpty &&
          _clientSecret.isNotEmpty;

      await _createCacheDirectory();
      if (_spotifyEnabled) {
        await _loadCachedData();
      }
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    cacheDir = Directory('${appDir.path}/artist_images');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  Future<void> _loadCachedData() async {
    await _getSpotifyAccessToken();
  }

  Future<void> _getSpotifyAccessToken() async {
    if (!_spotifyEnabled || _clientId == null || _clientSecret == null) {
      return;
    }

    final authString = base64.encode(utf8.encode('$_clientId:$_clientSecret'));
    final response = await _client.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $authString',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Failed to get Spotify access token');
    }
  }

  /// Check if artist name is unknown/empty - skip fetching for these
  bool _isUnknownArtist(String artistName) {
    final lowerName = artistName.toLowerCase().trim();
    return lowerName.isEmpty ||
        lowerName == 'unknown' ||
        lowerName == 'unknown artist' ||
        lowerName == '<unknown>' ||
        lowerName == 'unknown_artist';
  }

  Future<String?> fetchArtistImage(String artistName) async {
    // Completely skip fetching for unknown artists
    if (_isUnknownArtist(artistName)) {
      return null;
    }

    // Check memory cache FIRST to avoid any I/O or network calls
    if (_imageCache.containsKey(artistName)) {
      return _imageCache[artistName];
    }

    // If a request is already pending for this artist, wait for it
    if (_pendingRequests.contains(artistName)) {
      final completer = _pendingCompleters[artistName];
      if (completer != null) {
        return completer.future;
      }
      // Fallback: wait a bit and check cache
      await Future.delayed(const Duration(milliseconds: 100));
      if (_imageCache.containsKey(artistName)) {
        return _imageCache[artistName];
      }
    }

    // Mark this artist as having a pending request
    _pendingRequests.add(artistName);
    final completer = Completer<String?>();
    _pendingCompleters[artistName] = completer;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      // If Spotify is not enabled, return null early
      if (!_spotifyEnabled) {
        _imageCache[artistName] = null;
        completer.complete(null);
        return null;
      }

      final cacheFile =
          File('${cacheDir.path}/${artistName.replaceAll(' ', '_')}.jpg');

      // Check file cache
      if (await cacheFile.exists()) {
        _imageCache[artistName] = cacheFile.path;
        completer.complete(cacheFile.path);
        return cacheFile.path;
      }

      final String? imageUrl = await _getArtistImageFromSpotify(artistName);

      if (imageUrl != null) {
        final imagePath = await _downloadAndCacheImage(imageUrl, cacheFile);
        _imageCache[artistName] = imagePath;
        completer.complete(imagePath);
        return imagePath;
      }

      _imageCache[artistName] = null;
      completer.complete(null);
      return null;
    } catch (e) {
      _imageCache[artistName] = null;
      completer.complete(null);
      return null;
    } finally {
      _pendingRequests.remove(artistName);
      _pendingCompleters.remove(artistName);
    }
  }

  Future<String?> _getArtistImageFromSpotify(String artistName) async {
    if (!_spotifyEnabled) {
      return null;
    }

    if (_accessToken == null) {
      await _getSpotifyAccessToken();
    }

    final String primaryArtist = artistName
        .split(RegExp(
            r'[,/]|\s+&\s+|\s+feat\.?\s+|\s+ft\.?\s+|\s+featuring\s+|\s+with\s+|\s+x\s+|\s+X\s+'))
        .first
        .trim();

    final encodedArtist = Uri.encodeComponent(primaryArtist);
    final url =
        'https://api.spotify.com/v1/search?q=$encodedArtist&type=artist&limit=1';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artists = data['artists']['items'];
        if (artists.isNotEmpty) {
          final artist = artists[0];
          final images = artist['images'];
          if (images.isNotEmpty) {
            return images[0]['url'];
          }
        }
      } else if (response.statusCode == 401) {
        await _getSpotifyAccessToken();
        return _getArtistImageFromSpotify(artistName);
      }
    } catch (e) {}
    return null;
  }

  Future<String?> _downloadAndCacheImage(
      String imageUrl, File cacheFile) async {
    try {
      final imageResponse = await _client.get(Uri.parse(imageUrl));

      if (imageResponse.statusCode == 200) {
        await cacheFile.writeAsBytes(imageResponse.bodyBytes);
        return cacheFile.path;
      }
    } catch (e) {}
    return null;
  }
}

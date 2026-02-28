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

  // Spotify ToS compliance: cached images must be re-fetched every 30 days.
  static const Duration _cacheTtl = Duration(days: 30);

  // Metadata file that tracks the download timestamp of each cached image.
  // Format: { "Artist_Name.jpg": "2026-01-01T00:00:00.000Z", ... }
  static const String _metadataFileName = 'cache_metadata.json';
  Map<String, DateTime> _cacheTimestamps = {};

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
      await _loadCacheMetadata();
      await _expireStaleImages();

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

  // ──────────────────────────────────────────────────────────────
  // Cache metadata – tracks download timestamps per image file
  // ──────────────────────────────────────────────────────────────

  File get _metadataFile => File('${cacheDir.path}/$_metadataFileName');

  /// Load the timestamp index from disk.
  Future<void> _loadCacheMetadata() async {
    try {
      final file = _metadataFile;
      if (!await file.exists()) {
        _cacheTimestamps = {};
        return;
      }
      final raw = await file.readAsString();
      final Map<String, dynamic> decoded =
          json.decode(raw) as Map<String, dynamic>;
      _cacheTimestamps = decoded.map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)),
      );
    } catch (_) {
      _cacheTimestamps = {};
    }
  }

  /// Persist the timestamp index to disk.
  Future<void> _saveCacheMetadata() async {
    try {
      final encoded = json.encode(
        _cacheTimestamps
            .map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
      );
      await _metadataFile.writeAsString(encoded);
    } catch (_) {}
  }

  /// Returns the filename key used in the metadata map for a given artist name.
  String _fileNameFor(String artistName) =>
      '${artistName.replaceAll(' ', '_')}.jpg';

  /// Returns true when a cached file has exceeded the 30-day TTL.
  bool _isStale(String fileName) {
    final ts = _cacheTimestamps[fileName];
    if (ts == null) return true; // no record → treat as stale
    return DateTime.now().difference(ts) >= _cacheTtl;
  }

  /// Delete all cached images whose timestamp is older than [_cacheTtl].
  /// Runs once on startup to enforce the Spotify ToS retention limit.
  Future<void> _expireStaleImages() async {
    final staleKeys = _cacheTimestamps.entries
        .where((e) => DateTime.now().difference(e.value) >= _cacheTtl)
        .map((e) => e.key)
        .toList();

    for (final fileName in staleKeys) {
      final file = File('${cacheDir.path}/$fileName');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _cacheTimestamps.remove(fileName);

      // Derive the artist name back from the file name to clear memory cache.
      final artistName = fileName.replaceAll('_', ' ').replaceAll('.jpg', '');
      _imageCache.remove(artistName);
    }

    // Also delete any .jpg on disk that has no metadata entry at all.
    try {
      final files = await cacheDir.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          final fileName = entity.path.split('/').last;
          if (!_cacheTimestamps.containsKey(fileName)) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}

    if (staleKeys.isNotEmpty) {
      await _saveCacheMetadata();
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

      final fileName = _fileNameFor(artistName);
      final cacheFile = File('${cacheDir.path}/$fileName');

      // Check file cache – serve it only when it is within the 30-day TTL.
      if (await cacheFile.exists() && !_isStale(fileName)) {
        _imageCache[artistName] = cacheFile.path;
        completer.complete(cacheFile.path);
        return cacheFile.path;
      }

      // File is either missing or stale – delete the old copy before re-fetching.
      if (await cacheFile.exists()) {
        try {
          await cacheFile.delete();
        } catch (_) {}
        _cacheTimestamps.remove(fileName);
      }

      final String? imageUrl = await _getArtistImageFromSpotify(artistName);

      if (imageUrl != null) {
        final imagePath =
            await _downloadAndCacheImage(imageUrl, cacheFile, fileName);
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
      String imageUrl, File cacheFile, String fileName) async {
    try {
      final imageResponse = await _client.get(Uri.parse(imageUrl));

      if (imageResponse.statusCode == 200) {
        await cacheFile.writeAsBytes(imageResponse.bodyBytes);
        // Record the download timestamp so we can expire it after 30 days.
        _cacheTimestamps[fileName] = DateTime.now().toUtc();
        await _saveCacheMetadata();
        return cacheFile.path;
      }
    } catch (e) {}
    return null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LocalCachingArtistService {
  final http.Client _client = http.Client();
  late Directory cacheDir;
  String? _accessToken;
  final String _clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;
  final String _clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET']!;
  final Map<String, String?> _imageCache = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      await _createCacheDirectory();
      await _loadCachedData();
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

  Future<String?> fetchArtistImage(String artistName) async {
    if (!_isInitialized) {
      await initialize();
    }

    final cacheFile =
        File('${cacheDir.path}/${artistName.replaceAll(' ', '_')}.jpg');

    if (await cacheFile.exists()) {
      _imageCache[artistName] = cacheFile.path;
      return cacheFile.path;
    }

    if (_imageCache.containsKey(artistName)) {
      return _imageCache[artistName];
    }

    String? imageUrl = await _getArtistImageFromSpotify(artistName);

    if (imageUrl != null) {
      final imagePath = await _downloadAndCacheImage(imageUrl, cacheFile);
      _imageCache[artistName] = imagePath;
      return imagePath;
    }

    _imageCache[artistName] = null;
    return null;
  }

  Future<String?> _getArtistImageFromSpotify(String artistName) async {
    if (_accessToken == null) {
      await _getSpotifyAccessToken();
    }

    String primaryArtist = artistName
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

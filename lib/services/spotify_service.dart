import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class SpotifyService {
  final String clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;
  final String clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET']!;
  final String redirectUri = dotenv.env['SPOTIFY_REDIRECT_URI']!;
  String? accessToken;

  Future<bool> authenticate() async {
    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': 'user-library-read user-top-read user-read-recently-played playist-read-private',
    });

    try {
      final result = await FlutterWebAuth.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'auroramusic',
      );
      print('Authentication result: $result');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        print('Received code: $code');
        return await getAccessToken(code);
      } else {
        print('No code received in the callback');
      }
    } catch (e) {
      print('Authentication error: $e');
    }
    return false;
  }

  Future<bool> getAccessToken(String code) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      accessToken = data['access_token'];
      print('Access token obtained: $accessToken');
      return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getRecentlyPlayedTracks() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/recently-played?limit=20'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      print('Recently played tracks response status: ${response.statusCode}');
      print('Recently played tracks response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['items'] as List).map((item) => item['track'] as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load recently played tracks: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting recently played tracks: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSpotifyCreatedPlaylists() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/browse/featured-playlists?limit=10'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      print('Spotify playlists response status: ${response.statusCode}');
      print('Spotify playlists response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['playlists']['items'] as List).cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load Spotify playlists: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting Spotify playlists: $e');
      return [];
    }
  }


  Future<Map<String, dynamic>> getTrackDetails(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/tracks/$trackId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      print('Track details response status: ${response.statusCode}');
      print('Track details response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load track details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting track details: $e');
      return {};
    }
  }
  Future<String?> downloadSpotifySong(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/tracks/$trackId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final previewUrl = data['preview_url'];

        if (previewUrl != null) {
          final songResponse = await http.get(Uri.parse(previewUrl));
          if (songResponse.statusCode == 200) {
            final directory = await getApplicationDocumentsDirectory();
            final filePath = '${directory.path}/$trackId.mp3';
            final file = File(filePath);
            await file.writeAsBytes(songResponse.bodyBytes);
            return filePath;
          }
        }
      }
    } catch (e) {
      print('Error downloading Spotify song: $e');
    }
    return null;
  }
}
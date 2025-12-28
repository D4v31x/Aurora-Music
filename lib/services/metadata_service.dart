import 'dart:convert';
import 'package:http/http.dart' as http;

class MetadataService {
  static const String _deezerBaseUrl = 'https://api.deezer.com';
  static const String _itunesBaseUrl = 'https://itunes.apple.com';

  Future<List<Map<String, dynamic>>> searchMetadata(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Properly encode the query parameter using Uri class
      final uri = Uri.parse('$_deezerBaseUrl/search').replace(
        queryParameters: {'q': query},
      );
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['data'];
        if (tracks is List) {
          return tracks.map((track) => track as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      print('Error searching Deezer: $e');
    }
    return [];
  }

  Future<String?> fetchCoverArt(String query) async {
    if (query.trim().isEmpty) return null;
    
    try {
      // Properly encode the query parameters using Uri class
      final uri = Uri.parse('$_itunesBaseUrl/search').replace(
        queryParameters: {
          'term': query,
          'entity': 'album',
          'limit': '1',
        },
      );
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] != null && data['resultCount'] > 0) {
          final results = data['results'];
          if (results is List && results.isNotEmpty) {
            final result = results[0];
            // Get high res image
            final artworkUrl = result['artworkUrl100'];
            if (artworkUrl != null) {
              return artworkUrl.toString().replaceAll('100x100', '600x600');
            }
          }
        }
      }
    } catch (e) {
      print('Error searching iTunes: $e');
    }
    return null;
  }

  Future<List<int>?> downloadImage(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
    return null;
  }
}

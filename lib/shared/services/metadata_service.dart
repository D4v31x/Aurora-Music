import 'dart:convert';
import 'package:http/http.dart' as http;

class MetadataService {
  static const String _deezerBaseUrl = 'https://api.deezer.com';
  static const String _itunesBaseUrl = 'https://itunes.apple.com';

  /// Force English results from any locale-aware upstream API.
  static const Map<String, String> _englishHeaders = {
    'Accept-Language': 'en-US,en;q=0.9',
  };

  Future<List<Map<String, dynamic>>> searchMetadata(String query) async {
    if (query.trim().isEmpty) return [];

    // Try progressively simplified query variants until we get results.
    for (final q in _buildQueryVariants(query)) {
      final results = await _searchDeezer(q);
      if (results.isNotEmpty) return results;
    }
    return [];
  }

  /// Returns a deduped list of query strings to try, from most specific to
  /// least specific. Stops as soon as one variant produces results.
  List<String> _buildQueryVariants(String query) {
    final variants = <String>[];

    // 1. Original query (trimmed).
    final original = query.trim();
    variants.add(original);

    // 2. Cleaned variant – strip file-name noise.
    final cleaned = _cleanQuery(original);
    if (cleaned != original && cleaned.isNotEmpty) variants.add(cleaned);

    // 3. First 3 words of the cleaned query (cuts extra metadata tokens).
    final words =
        cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length > 3) {
      variants.add(words.take(3).join(' '));
    }

    // 4. Single first word (last-resort broad search).
    if (words.isNotEmpty && words.first.length > 2) {
      final first = words.first;
      if (!variants.contains(first)) variants.add(first);
    }

    return variants;
  }

  /// Normalises a query by removing common file-name artefacts.
  String _cleanQuery(String query) {
    var s = query;
    // Leading track numbers: "01 -", "1.", "02 - " etc.
    s = s.replaceFirst(RegExp(r'^\d+[\s\-\.]+'), '');
    // Parenthetical / bracket annotations: (feat. X), [Official Video] …
    s = s.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '');
    // Trailing feat/ft: "Title feat. Artist"
    s = s.replaceAll(
        RegExp(r'\s+(?:feat\.?|ft\.?)\s+.+$', caseSensitive: false), '');
    // Underscores → spaces, collapse whitespace.
    s = s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Future<List<Map<String, dynamic>>> _searchDeezer(String query) async {
    try {
      final uri = Uri.parse('$_deezerBaseUrl/search').replace(
        queryParameters: {'q': query},
      );
      final response = await http
          .get(uri, headers: _englishHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['data'];
        if (tracks is List) {
          return tracks
              .map((track) => track as Map<String, dynamic>)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetches the full track details from Deezer (`/track/{id}`) and enriches
  /// the map with year, trackPosition, and genre from the album endpoint.
  Future<Map<String, dynamic>> fetchFullTrackDetails(
      Map<String, dynamic> basicTrack) async {
    final trackId = basicTrack['id'];
    final albumId = (basicTrack['album'] as Map?)?['id'];
    if (trackId == null) return basicTrack;

    final enriched = Map<String, dynamic>.from(basicTrack);

    try {
      final futures = [
        http
            .get(Uri.parse('$_deezerBaseUrl/track/$trackId'),
                headers: _englishHeaders)
            .timeout(const Duration(seconds: 8)),
        if (albumId != null)
          http
              .get(Uri.parse('$_deezerBaseUrl/album/$albumId'),
                  headers: _englishHeaders)
              .timeout(const Duration(seconds: 8)),
      ];

      final responses = await Future.wait(futures);

      // Track response
      if (responses[0].statusCode == 200) {
        final t = json.decode(responses[0].body) as Map<String, dynamic>;
        enriched['_release_date'] = t['release_date'] as String? ?? '';
        enriched['_track_position'] = t['track_position'];
        enriched['_disk_number'] = t['disk_number'];
        // Override contributor data if present
        final contributors = t['contributors'];
        if (contributors is List && contributors.isNotEmpty) {
          enriched['_contributors'] = contributors;
        }
      }

      // Album response
      if (responses.length > 1 && responses[1].statusCode == 200) {
        final a = json.decode(responses[1].body) as Map<String, dynamic>;
        final genres = a['genres']?['data'] as List?;
        if (genres != null && genres.isNotEmpty) {
          enriched['_genre'] = (genres.first as Map)['name'] as String? ?? '';
        }
        // Fall back album release date if track didn't have one
        if ((enriched['_release_date'] as String? ?? '').isEmpty) {
          enriched['_release_date'] = a['release_date'] as String? ?? '';
        }
      }
    } catch (_) {}

    return enriched;
  }

  Future<String?> fetchCoverArt(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      // Properly encode the query parameters using Uri class.
      // Force the US storefront + English language so results are in English
      // regardless of the device locale.
      final uri = Uri.parse('$_itunesBaseUrl/search').replace(
        queryParameters: {
          'term': query,
          'entity': 'album',
          'limit': '1',
          'country': 'US',
          'lang': 'en_us',
        },
      );

      final response = await http
          .get(uri, headers: _englishHeaders)
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
    } catch (_) {}
    return null;
  }

  Future<List<int>?> downloadImage(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}

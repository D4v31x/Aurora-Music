import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

class LyricsService {
  static String _geniusToken = dotenv.env['GENIUS_API_KEY'] ?? '';

  // Method to fetch lyrics
  static Future<String?> fetchLyrics(String artist, String title) async {
    if (_geniusToken.isEmpty) {
      print('Genius API key is missing. Please check your .env file.');
      return 'API key missing';
    }

    final searchUrl = 'https://api.genius.com/search?q=${Uri.encodeComponent("$title $artist")}';
    print('Sending request to Genius API: $searchUrl for Song: $title, Artist: $artist');

    final response = await http.get(
      Uri.parse(searchUrl),
      headers: {
        'Authorization': 'Bearer $_geniusToken',
      },
    );

    print('Genius API search response code: ${response.statusCode}');
    print('Genius API search response body: ${response.body}');

    if (response.statusCode != 200) {
      print('Failed to search for song on Genius. Response code: ${response.statusCode}');
      return 'Error fetching song from Genius API';
    }

    final Map<String, dynamic> jsonResponse = json.decode(response.body);
    if (jsonResponse['response']['hits'].isEmpty) {
      print('No hits found for the song on Genius.');
      return 'No lyrics found for this song.';
    }

    // Find the best match based on the song title and artist name
    final hits = jsonResponse['response']['hits'];
    for (var hit in hits) {
      final geniusTitle = hit['result']['title'].toLowerCase();
      final geniusArtist = hit['result']['primary_artist']['name'].toLowerCase();

      if (geniusTitle.contains(title.toLowerCase()) && geniusArtist.contains(artist.toLowerCase())) {
        final songPath = hit['result']['path'];
        print('Matched song found: $geniusTitle by $geniusArtist. Fetching lyrics...');
        return _fetchLyricsFromPath(songPath);
      }
    }

    print('No matching song found in Genius API for $artist - $title.');
    return 'No matching song found.';
  }

  // Fetch lyrics from Genius path
  static Future<String?> _fetchLyricsFromPath(String songPath) async {
    final songUrl = 'https://genius.com$songPath';
    print('Fetching lyrics from: $songUrl');

    final response = await http.get(Uri.parse(songUrl));

    if (response.statusCode != 200) {
      print('Failed to load lyrics page from Genius. Response code: ${response.statusCode}');
      return 'Error loading lyrics page';
    }

    final lyrics = _extractLyricsFromHtml(response.body);
    if (lyrics != null) {
      print('Lyrics successfully extracted.');
      return lyrics;
    } else {
      print('Failed to extract lyrics from the HTML.');
      return 'No lyrics found for this song.';
    }
  }

  // Extract lyrics from the HTML response using a more modern Genius page structure
  static String? _extractLyricsFromHtml(String htmlContent) {
    print('Extracting lyrics from HTML...');

    // Parsing the HTML
    final document = parse(htmlContent);

    // Find all divs that have 'data-lyrics-container' attribute
    final lyricsContainers = document.querySelectorAll('div[data-lyrics-container=true]');

    if (lyricsContainers.isEmpty) {
      print('No lyrics containers found in the HTML.');
      return null;
    }

    // Extract text from all matching divs and join them
    final lyrics = lyricsContainers.map((element) => element.text.trim()).join('\n');

    if (lyrics.isNotEmpty) {
      print('Lyrics successfully extracted.');
      return lyrics;
    } else {
      print('No lyrics found in the extracted divs.');
      return null;
    }
  }
}

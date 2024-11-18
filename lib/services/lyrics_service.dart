import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/timed_lyrics.dart';
import 'package:crypto/crypto.dart';
import 'dart:math' show min, max;

class TimedLyricsService {
  static const String apiBaseUrl = 'https://lrclib.net/api';

  Future<List<TimedLyric>?> fetchTimedLyrics(String artist, String title, {Duration? songDuration}) async {
    print('⭐ Fetching lyrics for: "$artist" - "$title" (Duration: ${songDuration?.inSeconds}s)');
    
    try {
      // First try loading from local storage
      final localLyrics = await loadLyricsFromFile(artist, title);
      if (localLyrics != null) {
        if (_isLyricsDurationValid(localLyrics, songDuration)) {
          print('📂 Found valid cached lyrics with ${localLyrics.length} lines');
          return localLyrics;
        } else {
          print('⚠️ Cached lyrics duration mismatch, fetching new lyrics');
        }
      }
      print('💫 No cached lyrics found, fetching from API...');

      // Clean and prepare the search parameters
      String cleanArtist = artist.trim()
          .split('/')[0]  // Take only the first artist if multiple
          .replaceAll(RegExp(r'\(.*?\)'), '') // Remove content in parentheses
          .trim();
      
      String cleanTitle = title.trim()
          .replaceAll(RegExp(r'\(.*?\)'), '') // Remove content in parentheses
          .replaceAll(RegExp(r'\[.*?\]'), '') // Remove content in brackets
          .trim();

      print('🔍 Cleaned search terms - Artist: "$cleanArtist", Title: "$cleanTitle"');

      // Try direct search using /api/get
      final directUrl = Uri.parse('$apiBaseUrl/get').replace(queryParameters: {
        'artist_name': cleanArtist,
        'track_name': cleanTitle,
      });
      
      print('🌐 Trying direct API request to: $directUrl');
      
      final directResponse = await http.get(
        directUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85'
        },
      );

      print('📥 Direct API response status: ${directResponse.statusCode}');
      if (directResponse.body.isNotEmpty) {
        print('📥 Direct API response body: ${directResponse.body.substring(0, min(100, directResponse.body.length))}...');
      }

      if (directResponse.statusCode == 200 && directResponse.body.isNotEmpty) {
        final directData = json.decode(utf8.decode(directResponse.bodyBytes));
        if (directData != null && directData['syncedLyrics'] != null) {
          final lrcContent = directData['syncedLyrics'] as String;
          final normalizedContent = utf8.decode(
            utf8.encode(lrcContent),
            allowMalformed: true
          ).replaceAll(RegExp(r'[\uFFFD]'), '');
          
          print('✅ Found lyrics in direct response! First 100 chars: ${normalizedContent.substring(0, min(100, normalizedContent.length))}...');
          await _saveLyricsToFile(artist, title, normalizedContent);
          final lyrics = _parseLrc(normalizedContent);
          print('📝 Parsed ${lyrics.length} lyrics lines');
          return lyrics;
        }
      }

      // If direct search fails, try search API with more flexible search
      print('🔄 Direct search failed, trying search API...');
      
      // For search, try even more simplified terms
      cleanTitle = cleanTitle.split('-')[0].trim(); // Remove anything after a dash
      
      final searchUrl = Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
        'artist_name': cleanArtist,
        'track_name': cleanTitle,
      });
      
      print('🌐 Search API request to: $searchUrl');
      
      final searchResponse = await http.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85'
        },
      );

      print('📥 Search API response status: ${searchResponse.statusCode}');
      if (searchResponse.body.isNotEmpty) {
        print('📥 Search API response body: ${searchResponse.body.substring(0, min(100, searchResponse.body.length))}...');
      }

      if (searchResponse.statusCode == 200) {
        final List searchResults = json.decode(utf8.decode(searchResponse.bodyBytes));
        print('🔍 Found ${searchResults.length} search results');
        
        if (searchResults.isNotEmpty) {
          // Sort results by duration match if song duration is provided
          if (songDuration != null) {
            searchResults.sort((a, b) {
              final aDuration = _parseApproximateDuration(a['syncedLyrics'] as String?);
              final bDuration = _parseApproximateDuration(b['syncedLyrics'] as String?);
              
              final aDiff = (aDuration - songDuration).abs();
              final bDiff = (bDuration - songDuration).abs();
              
              return aDiff.compareTo(bDiff);
            });
            
            print('📊 Sorted ${searchResults.length} results by duration match');
          }

          // Try to find the best matching result
          for (final result in searchResults) {
            if (result['syncedLyrics'] != null) {
              final lrcContent = result['syncedLyrics'] as String;
              final lyrics = _parseLrc(lrcContent);
              
              if (_isLyricsDurationValid(lyrics, songDuration)) {
                print('✅ Found matching lyrics! Duration difference: ${_getLyricsDurationDifference(lyrics, songDuration).inSeconds}s');
                await _saveLyricsToFile(artist, title, lrcContent);
                return lyrics;
              } else {
                print('⚠️ Skipping result due to duration mismatch');
              }
            }
          }
        }
      }

      // Try one last time with just the title if both previous attempts failed
      if (cleanTitle != title.trim()) {
        print('🔄 Trying one last search with just the title...');
        final lastSearchUrl = Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
          'track_name': cleanTitle,
        });
        
        print('🌐 Final search attempt to: $lastSearchUrl');
        
        final lastResponse = await http.get(
          lastSearchUrl,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AuroraMusic v0.0.85'
          },
        );

        if (lastResponse.statusCode == 200) {
          final List searchResults = json.decode(lastResponse.body);
          print('🔍 Found ${searchResults.length} results in final search');
          
          if (searchResults.isNotEmpty) {
            final firstResult = searchResults[0];
            if (firstResult['syncedLyrics'] != null) {
              final lrcContent = firstResult['syncedLyrics'] as String;
              print('✅ Found lyrics in final search! First 100 chars: ${lrcContent.substring(0, min(100, lrcContent.length))}...');
              await _saveLyricsToFile(artist, title, lrcContent);
              final lyrics = _parseLrc(lrcContent);
              print('📝 Parsed ${lyrics.length} lyrics lines');
              return lyrics;
            }
          }
        }
      }

      print('❌ No lyrics found in any source');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error fetching lyrics: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  List<TimedLyric> _parseLrc(String lrcContent) {
    print('🎯 Starting LRC parsing');
    final List<TimedLyric> timedLyrics = [];
    
    // Properly decode and normalize the content
    final normalizedContent = utf8.decode(
      utf8.encode(lrcContent),
      allowMalformed: true
    ).replaceAll(RegExp(r'[\uFFFD]'), '');
    
    final lines = normalizedContent.split('\n');
    print('📄 Total lines to parse: ${lines.length}');
    
    // Basic LRC format regex
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:]\d{2,3}\]');
    
    for (var i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];
        
        // Skip empty lines and metadata
        if (line.trim().isEmpty || line.startsWith('[ti:') || 
            line.startsWith('[ar:') || line.startsWith('[al:')) {
          print('⏭️ Skipping metadata/empty line: $line');
          continue;
        }

        final timeMatches = timeRegex.allMatches(line);
        if (timeMatches.isEmpty) {
          print('⚠️ No time tags found in line $i: $line');
          continue;
        }

        // Get the text content after the last time tag
        var text = line.substring(line.lastIndexOf(']') + 1).trim();
        
        // Additional UTF-8 normalization for the text content
        text = utf8.decode(
          utf8.encode(text),
          allowMalformed: true
        ).replaceAll(RegExp(r'[\uFFFD]'), '');
        
        if (text.isEmpty) {
          print('⚠️ Empty text content in line $i: $line');
          continue;
        }

        print('✍️ Processing line $i: "$text" with ${timeMatches.length} time tags');

        // Process each time tag in the line
        for (var match in timeMatches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          
          final time = Duration(
            minutes: minutes,
            seconds: seconds,
          );
          
          timedLyrics.add(TimedLyric(time: time, text: text));
        }
      } catch (e) {
        print('❌ Error parsing line $i: $e');
        continue;
      }
    }

    timedLyrics.sort((a, b) => a.time.compareTo(b.time));
    print('✅ Successfully parsed ${timedLyrics.length} timed lyrics');
    return timedLyrics;
  }

  Future<void> _saveLyricsToFile(String artist, String title, String content) async {
    print('💾 Saving lyrics for: "$artist" - "$title"');
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      final fileName = md5.convert(utf8.encode('$artist-$title')).toString();
      print('📄 Generated filename: $fileName');
      
      final lyricsDir = Directory('${directory.path}/lyrics');
      if (!await lyricsDir.exists()) {
        print('📁 Creating lyrics directory');
        await lyricsDir.create();
      }
      
      final filePath = '${lyricsDir.path}/$fileName.lrc';
      print('📂 Saving to path: $filePath');
      
      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);
      print('✅ Successfully saved lyrics file');
    } catch (e) {
      print('❌ Error saving lyrics: $e');
    }
  }

  Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title) async {
    print('🔍 Attempting to load cached lyrics for: "$artist" - "$title"');
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      final fileName = md5.convert(utf8.encode('$artist-$title')).toString();
      final filePath = '${directory.path}/lyrics/$fileName.lrc';
      
      print(' Looking for file: $filePath');
      
      final file = File(filePath);
      if (await file.exists()) {
        print('✅ Found cached file');
        final content = await file.readAsString(encoding: utf8);
        print('📄 File content length: ${content.length}');
        return _parseLrc(content);
      }
      print('❌ No cached file found');
      return null;
    } catch (e) {
      print('❌ Error loading lyrics: $e');
      return null;
    }
  }

  bool _isLyricsDurationValid(List<TimedLyric> lyrics, Duration? songDuration) {
    if (songDuration == null || lyrics.isEmpty) return true;
    
    final lyricsDuration = _getLyricsDuration(lyrics);
    final difference = (lyricsDuration - songDuration).abs();
    
    // Allow 10% duration difference or 10 seconds, whichever is greater
    final maxAllowedDifference = max(
      songDuration.inMilliseconds * 0.1,
      10000, // 10 seconds in milliseconds
    );
    
    return difference.inMilliseconds <= maxAllowedDifference;
  }

  Duration _getLyricsDuration(List<TimedLyric> lyrics) {
    if (lyrics.isEmpty) return Duration.zero;
    return lyrics.last.time;
  }

  Duration _getLyricsDurationDifference(List<TimedLyric> lyrics, Duration? songDuration) {
    if (songDuration == null || lyrics.isEmpty) return Duration.zero;
    return (lyrics.last.time - songDuration).abs();
  }

  Duration _parseApproximateDuration(String? lrcContent) {
    if (lrcContent == null || lrcContent.isEmpty) return Duration.zero;
    
    // Find the last timestamp in the lyrics
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:]\d{2,3}\]');
    final matches = timeRegex.allMatches(lrcContent);
    
    if (matches.isEmpty) return Duration.zero;
    
    final lastMatch = matches.last;
    final minutes = int.parse(lastMatch.group(1)!);
    final seconds = int.parse(lastMatch.group(2)!);
    
    return Duration(minutes: minutes, seconds: seconds);
  }
}

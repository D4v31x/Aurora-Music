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
    
    
    try {
      // First try loading from local storage
      final localLyrics = await loadLyricsFromFile(artist, title);
      if (localLyrics != null) {
        if (_isLyricsDurationValid(localLyrics, songDuration)) {
          
          return localLyrics;
        } else {
          
        }
      }
      

      // Clean and prepare the search parameters
      String cleanArtist = artist.trim()
          .split('/')[0]  // Take only the first artist if multiple
          .replaceAll(RegExp(r'\(.*?\)'), '') // Remove content in parentheses
          .trim();
      
      String cleanTitle = title.trim()
          .replaceAll(RegExp(r'\(.*?\)'), '') // Remove content in parentheses
          .replaceAll(RegExp(r'\[.*?\]'), '') // Remove content in brackets
          .trim();

      

      // Try direct search using /api/get
      final directUrl = Uri.parse('$apiBaseUrl/get').replace(queryParameters: {
        'artist_name': cleanArtist,
        'track_name': cleanTitle,
      });
      
      
      
      final directResponse = await http.get(
        directUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85'
        },
      );

      
      if (directResponse.body.isNotEmpty) {
        
      }

      if (directResponse.statusCode == 200 && directResponse.body.isNotEmpty) {
        final directData = json.decode(utf8.decode(directResponse.bodyBytes));
        if (directData != null && directData['syncedLyrics'] != null) {
          final lrcContent = directData['syncedLyrics'] as String;
          final normalizedContent = utf8.decode(
            utf8.encode(lrcContent),
            allowMalformed: true
          ).replaceAll(RegExp(r'[\uFFFD]'), '');
          
          
          await _saveLyricsToFile(artist, title, normalizedContent);
          final lyrics = _parseLrc(normalizedContent);
          
          return lyrics;
        }
      }

      // If direct search fails, try search API with more flexible search
      
      
      // For search, try even more simplified terms
      cleanTitle = cleanTitle.split('-')[0].trim(); // Remove anything after a dash
      
      final searchUrl = Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
        'artist_name': cleanArtist,
        'track_name': cleanTitle,
      });
      
      
      
      final searchResponse = await http.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'AuroraMusic v0.0.85'
        },
      );

      
      if (searchResponse.body.isNotEmpty) {
        
      }

      if (searchResponse.statusCode == 200) {
        final List searchResults = json.decode(utf8.decode(searchResponse.bodyBytes));
        
        
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
            
            
          }

          // Try to find the best matching result
          for (final result in searchResults) {
            if (result['syncedLyrics'] != null) {
              final lrcContent = result['syncedLyrics'] as String;
              final lyrics = _parseLrc(lrcContent);
              
              if (_isLyricsDurationValid(lyrics, songDuration)) {
                
                await _saveLyricsToFile(artist, title, lrcContent);
                return lyrics;
              } else {
                
              }
            }
          }
        }
      }

      // Try one last time with just the title if both previous attempts failed
      if (cleanTitle != title.trim()) {
        
        final lastSearchUrl = Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
          'track_name': cleanTitle,
        });
        
        
        
        final lastResponse = await http.get(
          lastSearchUrl,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AuroraMusic v0.0.85'
          },
        );

        if (lastResponse.statusCode == 200) {
          final List searchResults = json.decode(lastResponse.body);
          
          
          if (searchResults.isNotEmpty) {
            final firstResult = searchResults[0];
            if (firstResult['syncedLyrics'] != null) {
              final lrcContent = firstResult['syncedLyrics'] as String;
              
              await _saveLyricsToFile(artist, title, lrcContent);
              final lyrics = _parseLrc(lrcContent);
              
              return lyrics;
            }
          }
        }
      }

      
      return null;
    } catch (e) {
      
      
      return null;
    }
  }

  List<TimedLyric> _parseLrc(String lrcContent) {
    
    final List<TimedLyric> timedLyrics = [];
    
    // Properly decode and normalize the content
    final normalizedContent = utf8.decode(
      utf8.encode(lrcContent),
      allowMalformed: true
    ).replaceAll(RegExp(r'[\uFFFD]'), '');
    
    final lines = normalizedContent.split('\n');
    
    
    // Basic LRC format regex
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:]\d{2,3}\]');
    
    for (var i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];
        
        // Skip empty lines and metadata
        if (line.trim().isEmpty || line.startsWith('[ti:') || 
            line.startsWith('[ar:') || line.startsWith('[al:')) {
          
          continue;
        }

        final timeMatches = timeRegex.allMatches(line);
        if (timeMatches.isEmpty) {
          
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
          
          continue;
        }

        

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
        
        continue;
      }
    }

    timedLyrics.sort((a, b) => a.time.compareTo(b.time));
    
    return timedLyrics;
  }

  Future<void> _saveLyricsToFile(String artist, String title, String content) async {
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      final fileName = md5.convert(utf8.encode('$artist-$title')).toString();
      
      
      final lyricsDir = Directory('${directory.path}/lyrics');
      if (!await lyricsDir.exists()) {
        
        await lyricsDir.create();
      }
      
      final filePath = '${lyricsDir.path}/$fileName.lrc';
      
      
      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8);
      
    } catch (e) {
      
    }
  }

  Future<List<TimedLyric>?> loadLyricsFromFile(String artist, String title) async {
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      final fileName = md5.convert(utf8.encode('$artist-$title')).toString();
      final filePath = '${directory.path}/lyrics/$fileName.lrc';
      
      
      
      final file = File(filePath);
      if (await file.exists()) {
        
        final content = await file.readAsString(encoding: utf8);
        
        return _parseLrc(content);
      }
      
      return null;
    } catch (e) {
      
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

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/timed_lyrics.dart';
import 'package:crypto/crypto.dart';
import 'dart:math' show min, max;
import 'package:flutter/foundation.dart';

class TimedLyricsService {
  static const String apiBaseUrl = 'https://lrclib.net/api';
  static const Duration _apiTimeout = Duration(seconds: 5);

  void Function(String)? _onLog;

  // In-memory cache for instant access
  final Map<String, List<TimedLyric>> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;

  void _log(String message) {
    final fullMessage = '🎵 [LYRICS] $message';
    debugPrint(fullMessage);
    _onLog?.call(fullMessage);
  }

  /// Get lyrics synchronously from memory cache if available
  List<TimedLyric>? getCachedLyrics(String artist, String title) {
    final cacheKey = md5.convert(utf8.encode('$artist-$title')).toString();
    return _memoryCache[cacheKey];
  }

  /// Preload lyrics into memory cache for instant access
  Future<void> preloadLyricsToMemory(String artist, String title) async {
    final cacheKey = md5.convert(utf8.encode('$artist-$title')).toString();
    if (_memoryCache.containsKey(cacheKey)) return;

    final lyrics = await loadLyricsFromFile(artist, title);
    if (lyrics != null) {
      _addToMemoryCache(cacheKey, lyrics);
    }
  }

  void _addToMemoryCache(String key, List<TimedLyric> lyrics) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry (first key)
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = lyrics;
  }

  Future<List<TimedLyric>?> fetchTimedLyrics(
    String artist,
    String title, {
    Duration? songDuration,
    void Function(String)? onLog,
    Future<Map<String, dynamic>?> Function(List<Map<String, dynamic>>)?
        onMultipleResults,
  }) async {
    _onLog = onLog;
    _log('=' * 60);
    _log('SEARCH STARTED');
    _log('Original Artist: "$artist"');
    _log('Original Title: "$title"');
    if (songDuration != null) {
      _log(
          'Song Duration: ${songDuration.inMinutes}:${(songDuration.inSeconds % 60).toString().padLeft(2, '0')}');
    }

    try {
      // First try loading from local storage
      _log('Checking local cache...');
      final localLyrics = await loadLyricsFromFile(artist, title);
      if (localLyrics != null) {
        _log('✓ Found cached lyrics (${localLyrics.length} lines)');
        if (_isLyricsDurationValid(localLyrics, songDuration)) {
          _log('✓ Cached lyrics duration is valid - using cached version');
          _log('=' * 60);
          return localLyrics;
        } else {
          final lyricsDur = _getLyricsDuration(localLyrics);
          _log(
              '✗ Cached lyrics duration mismatch: ${lyricsDur.inMinutes}:${(lyricsDur.inSeconds % 60).toString().padLeft(2, '0')} vs song ${songDuration?.inMinutes}:${((songDuration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}');
          _log('Fetching fresh lyrics from API...');
        }
      } else {
        _log('✗ No cached lyrics found');
      }

      // Use exact names without cleaning
      final searchArtist = artist.trim();
      final searchTitle = title.trim();

      _log('Searching with EXACT names (no cleaning)');
      _log('─' * 60);
      _log('METHOD 1 & 2: Parallel API Search (Direct + Search)');
      _log('Search Artist: "$searchArtist"');
      _log('Search Title: "$searchTitle"');

      final directUrl = Uri.parse('$apiBaseUrl/get').replace(queryParameters: {
        'artist_name': searchArtist,
        'track_name': searchTitle,
      });

      final searchUrl =
          Uri.parse('$apiBaseUrl/search').replace(queryParameters: {
        'artist_name': searchArtist,
        'track_name': searchTitle,
      });

      _log('Direct URL: $directUrl');
      _log('Search URL: $searchUrl');

      // Run both API calls in parallel for faster results
      final results = await Future.wait([
        http.get(
          directUrl,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AuroraMusic v0.0.85'
          },
        ).timeout(_apiTimeout, onTimeout: () => http.Response('', 408)),
        http.get(
          searchUrl,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AuroraMusic v0.0.85'
          },
        ).timeout(_apiTimeout, onTimeout: () => http.Response('', 408)),
      ]);

      final directResponse = results[0];
      final searchResponse = results[1];

      // Try direct response first
      _log('Direct Response Status: ${directResponse.statusCode}');
      if (directResponse.statusCode == 200 && directResponse.body.isNotEmpty) {
        final directData = json.decode(utf8.decode(directResponse.bodyBytes));
        if (directData != null && directData['syncedLyrics'] != null) {
          final foundTrack = directData['trackName'] ?? 'Unknown';
          final foundArtist = directData['artistName'] ?? 'Unknown';

          _log('✓ FOUND synced lyrics in direct match!');
          _log('📍 Searched: "$searchTitle" by "$searchArtist"');
          _log('📍 Got: "$foundTrack" by "$foundArtist"');
          _log('Album: ${directData['albumName'] ?? 'N/A'}');

          final lrcContent = directData['syncedLyrics'] as String;
          final normalizedContent = utf8
              .decode(utf8.encode(lrcContent), allowMalformed: true)
              .replaceAll(RegExp(r'[\uFFFD]'), '');

          final lyrics = _parseLrc(normalizedContent);
          _log('✓ Parsed ${lyrics.length} lyric lines');

          await _saveLyricsToFile(artist, title, normalizedContent);
          _log('✓ USING direct match result');
          _log('=' * 60);
          return lyrics;
        }
      }

      // Process search response
      _log('Search Response Status: ${searchResponse.statusCode}');

      if (searchResponse.statusCode == 200 && searchResponse.body.isNotEmpty) {
        final List searchResults =
            json.decode(utf8.decode(searchResponse.bodyBytes));

        _log('Found ${searchResults.length} search results');

        if (searchResults.isNotEmpty) {
          // Log all results before sorting
          _log('📍 Searched: "$searchTitle" by "$searchArtist"');
          for (var i = 0; i < searchResults.length; i++) {
            final r = searchResults[i];
            final hasSynced = r['syncedLyrics'] != null;
            final dur = hasSynced
                ? _parseApproximateDuration(r['syncedLyrics'])
                : Duration.zero;
            _log(
                '  Result ${i + 1}: "${r['trackName']}" by "${r['artistName']}" - Synced: $hasSynced - Duration: ${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}');
          }

          // Filter results to only those with synced lyrics
          final syncedResults =
              searchResults.where((r) => r['syncedLyrics'] != null).toList();

          if (syncedResults.isEmpty) {
            _log('✗ No results with synced lyrics');
          } else {
            _log('Found ${syncedResults.length} results with synced lyrics');

            // Sort results by relevance: exact artist match, then duration match, then similarity
            syncedResults.sort((a, b) {
              // Score based on artist match
              final aArtistMatch =
                  _artistSimilarity(searchArtist, a['artistName'] ?? '');
              final bArtistMatch =
                  _artistSimilarity(searchArtist, b['artistName'] ?? '');

              if (aArtistMatch != bArtistMatch) {
                return bArtistMatch
                    .compareTo(aArtistMatch); // Higher score first
              }

              // If artist scores are equal, sort by duration match
              if (songDuration != null) {
                final aDuration =
                    _parseApproximateDuration(a['syncedLyrics'] as String?);
                final bDuration =
                    _parseApproximateDuration(b['syncedLyrics'] as String?);
                final aDiff = (aDuration - songDuration).abs();
                final bDiff = (bDuration - songDuration).abs();
                return aDiff.compareTo(bDiff);
              }

              return 0;
            });

            _log('After sorting by relevance:');
            for (var i = 0; i < min(5, syncedResults.length); i++) {
              final r = syncedResults[i];
              final dur = _parseApproximateDuration(r['syncedLyrics']);
              final artistScore =
                  _artistSimilarity(searchArtist, r['artistName'] ?? '');
              _log(
                  '  #${i + 1}: "${r['trackName']}" by "${r['artistName']}" - Artist match: ${artistScore.toStringAsFixed(2)} - Duration: ${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}');
            }

            // If we have multiple good results and a callback, let user choose
            if (syncedResults.length > 1 && onMultipleResults != null) {
              _log('Multiple results found - asking user to choose...');
              final userChoice = await onMultipleResults(
                  syncedResults.cast<Map<String, dynamic>>());

              if (userChoice != null) {
                final lrcContent = userChoice['syncedLyrics'] as String;
                final lyrics = _parseLrc(lrcContent);
                final foundTrack = userChoice['trackName'] ?? 'Unknown';
                final foundArtist = userChoice['artistName'] ?? 'Unknown';

                _log('✓ User selected: "$foundTrack" by "$foundArtist"');
                _log('✓ Parsed ${lyrics.length} lyric lines');
                await _saveLyricsToFile(artist, title, lrcContent);
                _log('=' * 60);
                return lyrics;
              } else {
                _log('✗ User cancelled selection');
                _log('=' * 60);
                return null;
              }
            }
          }

          // Auto-select if only one result or if top result is valid
          if (syncedResults.isNotEmpty) {
            _log('Evaluating top results for duration validity...');
            for (var i = 0; i < min(3, syncedResults.length); i++) {
              final result = syncedResults[i];
              final lrcContent = result['syncedLyrics'] as String;
              final lyrics = _parseLrc(lrcContent);

              if (_isLyricsDurationValid(lyrics, songDuration)) {
                final foundTrack = result['trackName'] ?? 'Unknown';
                final foundArtist = result['artistName'] ?? 'Unknown';

                _log('✓ Result #${i + 1} VALID (auto-selected)');
                _log('📍 Got: "$foundTrack" by "$foundArtist"');
                _log('✓ Parsed ${lyrics.length} lyric lines');
                _log('✓ USING search result #${i + 1}');
                await _saveLyricsToFile(artist, title, lrcContent);
                _log('=' * 60);
                return lyrics;
              } else {
                final lyricsDur = _getLyricsDuration(lyrics);
                final diff = _getLyricsDurationDifference(lyrics, songDuration);
                _log(
                    '✗ Result #${i + 1} duration mismatch: ${diff.inSeconds}s (lyrics: ${lyricsDur.inMinutes}:${(lyricsDur.inSeconds % 60).toString().padLeft(2, '0')}, song: ${songDuration?.inMinutes}:${((songDuration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')})');
              }
            }

            // If no exact match but we have results, use the best one
            if (syncedResults.isNotEmpty) {
              final bestResult = syncedResults[0];
              final lrcContent = bestResult['syncedLyrics'] as String;
              final lyrics = _parseLrc(lrcContent);
              final foundTrack = bestResult['trackName'] ?? 'Unknown';
              final foundArtist = bestResult['artistName'] ?? 'Unknown';

              _log('⚠️ No exact duration match - using best result');
              _log('📍 Got: "$foundTrack" by "$foundArtist"');
              _log('✓ Parsed ${lyrics.length} lyric lines');
              await _saveLyricsToFile(artist, title, lrcContent);
              _log('=' * 60);
              return lyrics;
            }
          }
        }
      }

      _log('✗ No lyrics found with artist+title search');
      _log('=' * 60);
      return null;
    } catch (e) {
      _log('✗ ERROR during lyrics fetch: $e');
      _log('=' * 60);
      return null;
    }
  }

  /// Public method to parse LRC content
  List<TimedLyric> parseLrcContent(String lrcContent) {
    return _parseLrc(lrcContent);
  }

  /// Public method to save lyrics to cache
  Future<void> saveLyricsToCache(
      String artist, String title, String content) async {
    await _saveLyricsToFile(artist, title, content);
  }

  List<TimedLyric> _parseLrc(String lrcContent) {
    _log('  Parsing LRC content...');
    final List<TimedLyric> timedLyrics = [];

    // Properly decode and normalize the content
    final normalizedContent = utf8
        .decode(utf8.encode(lrcContent), allowMalformed: true)
        .replaceAll(RegExp(r'[\uFFFD]'), '');

    final lines = normalizedContent.split('\n');
    _log('  Processing ${lines.length} lines from LRC file');

    // Basic LRC format regex
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:]\d{2,3}\]');

    for (var i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];

        // Skip empty lines and metadata
        if (line.trim().isEmpty ||
            line.startsWith('[ti:') ||
            line.startsWith('[ar:') ||
            line.startsWith('[al:')) {
          continue;
        }

        final timeMatches = timeRegex.allMatches(line);
        if (timeMatches.isEmpty) {
          continue;
        }

        // Get the text content after the last time tag
        var text = line.substring(line.lastIndexOf(']') + 1).trim();

        // Additional UTF-8 normalization for the text content
        text = utf8
            .decode(utf8.encode(text), allowMalformed: true)
            .replaceAll(RegExp(r'[\uFFFD]'), '');

        if (text.isEmpty) {
          continue;
        }

        // Process each time tag in the line
        for (final match in timeMatches) {
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

  Future<void> _saveLyricsToFile(
      String artist, String title, String content) async {
    _log('  Saving lyrics to cache...');
    try {
      final directory = await getApplicationDocumentsDirectory();

      final fileName = md5.convert(utf8.encode('$artist-$title')).toString();
      _log('  Cache filename: $fileName.lrc');

      final lyricsDir = Directory('${directory.path}/lyrics');
      if (!await lyricsDir.exists()) {
        _log('  Creating lyrics directory...');
        await lyricsDir.create();
      }

      final filePath = '${lyricsDir.path}/$fileName.lrc';
      _log('  Cache path: $filePath');

      final file = File(filePath);
      await file.writeAsString(content);
      _log('  ✓ Lyrics saved to cache');

      // Also add to memory cache for instant access
      final lyrics = _parseLrc(content);
      _addToMemoryCache(fileName, lyrics);
    } catch (e) {
      _log('  ✗ Error saving lyrics: $e');
    }
  }

  Future<List<TimedLyric>?> loadLyricsFromFile(
      String artist, String title) async {
    final cacheKey = md5.convert(utf8.encode('$artist-$title')).toString();

    // Check memory cache first for instant access
    if (_memoryCache.containsKey(cacheKey)) {
      _log('  ✓ Found in memory cache (instant)');
      return _memoryCache[cacheKey];
    }

    _log('  Loading from file cache...');
    try {
      final directory = await getApplicationDocumentsDirectory();

      final fileName = cacheKey;
      final filePath = '${directory.path}/lyrics/$fileName.lrc';

      _log('  Cache filename: $fileName.lrc');
      _log('  Cache path: $filePath');

      final file = File(filePath);
      if (await file.exists()) {
        _log('  ✓ Cache file exists, loading...');
        final content = await file.readAsString();
        final lyrics = _parseLrc(content);
        _log('  ✓ Loaded ${lyrics.length} lines from file cache');

        // Add to memory cache for next time
        _addToMemoryCache(cacheKey, lyrics);

        return lyrics;
      }
      _log('  ✗ Cache file does not exist');
      return null;
    } catch (e) {
      _log('  ✗ Error loading from cache: $e');
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

  Duration _getLyricsDurationDifference(
      List<TimedLyric> lyrics, Duration? songDuration) {
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

  /// Calculate similarity score between two artist names (0.0 to 1.0)
  /// Higher score means better match
  double _artistSimilarity(String searchArtist, String resultArtist) {
    final searchLower = searchArtist.toLowerCase().trim();
    final resultLower = resultArtist.toLowerCase().trim();

    // Exact match gets highest score
    if (searchLower == resultLower) {
      return 1.0;
    }

    // Check if one contains the other (for featuring artists, remixes, etc.)
    if (resultLower.contains(searchLower) ||
        searchLower.contains(resultLower)) {
      return 0.9;
    }

    // Check if search artist is mentioned anywhere in result artist
    // (e.g., "Artist feat. SearchArtist" or "SearchArtist & Other")
    final searchWords = searchLower.split(RegExp(r'\W+'));
    final resultWords = resultLower.split(RegExp(r'\W+'));

    var matchingWords = 0;
    for (final searchWord in searchWords) {
      if (searchWord.length < 3) continue; // Skip very short words
      for (final resultWord in resultWords) {
        if (resultWord.contains(searchWord) ||
            searchWord.contains(resultWord)) {
          matchingWords++;
          break;
        }
      }
    }

    if (matchingWords > 0) {
      return 0.5 +
          (matchingWords / max(searchWords.length, resultWords.length)) * 0.4;
    }

    // Calculate Levenshtein distance for fuzzy matching
    final distance = _levenshteinDistance(searchLower, resultLower);
    final maxLength = max(searchLower.length, resultLower.length);

    if (maxLength == 0) return 0.0;

    // Convert distance to similarity score (0.0 to 0.5 for non-matching artists)
    return max(0.0, 0.5 - (distance / maxLength) * 0.5);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[s1.length][s2.length];
  }
}

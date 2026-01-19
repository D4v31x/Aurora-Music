import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/timed_lyrics.dart';

/// Isolate helper for parsing lyrics to avoid UI thread blocking
class LyricsIsolate {
  /// Parse LRC content in an isolate for better performance
  static Future<List<TimedLyric>> parseLrcInIsolate(String lrcContent) async {
    // On web, we can't use isolates, so parse directly
    if (kIsWeb) {
      return _parseLrc(lrcContent);
    }

    // Use compute for better performance on native platforms
    return compute(_parseLrc, lrcContent);
  }

  /// Parse LRC content - can be run in isolate or main thread
  static List<TimedLyric> _parseLrc(String lrcContent) {
    final List<TimedLyric> timedLyrics = [];

    // Properly decode and normalize the content
    final normalizedContent = utf8
        .decode(utf8.encode(lrcContent), allowMalformed: true)
        .replaceAll(RegExp(r'[\uFFFD]'), '');

    final lines = normalizedContent.split('\n');

    // Basic LRC format regex
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})[\.:]\d{2,3}\]');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final matches = timeRegex.allMatches(line);
      if (matches.isEmpty) continue;

      // Extract text after the timestamp
      final textMatch = RegExp(r'\](.*)$').firstMatch(line);
      if (textMatch == null) continue;

      String text = textMatch.group(1)?.trim() ?? '';
      if (text.isEmpty) continue;

      // Parse all timestamps for this line (some lines have multiple timestamps)
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final milliseconds = minutes * 60000 + seconds * 1000;

        timedLyrics.add(TimedLyric(
          time: Duration(milliseconds: milliseconds),
          text: text,
        ));
      }
    }

    // Sort by timestamp
    timedLyrics.sort((a, b) => a.time.compareTo(b.time));

    return timedLyrics;
  }

  /// Generate suggestions for song metadata in isolate
  static Future<Map<String, dynamic>> generateSuggestionsInIsolate(
    Map<String, dynamic> data,
  ) async {
    if (kIsWeb) {
      return _generateSuggestions(data);
    }

    return compute(_generateSuggestions, data);
  }

  static Map<String, dynamic> _generateSuggestions(Map<String, dynamic> data) {
    // Placeholder for smart suggestions computation
    // This would contain the expensive computation logic
    // that should not run on the UI thread
    return {
      'suggestions': [],
      'computedAt': DateTime.now().toIso8601String(),
    };
  }
}

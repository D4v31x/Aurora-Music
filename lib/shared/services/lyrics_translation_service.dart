import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LyricsTranslationService {
  static const String _baseUrl =
      'https://api.mymemory.translated.net/get';
  static const int _maxCharsPerRequest = 450;
  static const int _contextWindowSize = 5;
  static final Map<String, List<String?>> _cache = {};
  static Future<List<String?>> translateLines({
    required List<String> texts,
    required String targetLang,
    String cacheKey = '',
  }) async {
    if (texts.isEmpty) return [];

    final key = '$cacheKey|$targetLang';
    if (_cache.containsKey(key)) return List.from(_cache[key]!);

    final result = List<String?>.filled(texts.length, null);

    // Build batches whose core text stays within the char limit.
    int i = 0;
    while (i < texts.length) {
      // 1. Build the core batch
      var coreJoined = '';
      int j = i;
      while (j < texts.length) {
        final candidate =
            coreJoined.isEmpty ? texts[j] : '$coreJoined\n${texts[j]}';
        if (candidate.length > _maxCharsPerRequest && coreJoined.isNotEmpty) {
          break;
        }
        coreJoined = candidate;
        j++;
      }
      final batchLineCount = j - i;

      // 2. Fill remaining char budget with surrounding context lines
      final spare = _maxCharsPerRequest - coreJoined.length;
      final contextBeforeLines = <String>[];
      final contextAfterLines = <String>[];

      if (spare > 20) {
        int beforeBudget = spare ~/ 2;
        int afterBudget = spare - beforeBudget;

        for (int k = i - 1;
            k >= 0 && contextBeforeLines.length < _contextWindowSize;
            k--) {
          final cost = texts[k].length + 1; // +1 for the joining newline
          if (cost > beforeBudget) break;
          contextBeforeLines.insert(0, texts[k]);
          beforeBudget -= cost;
        }

        for (int k = j;
            k < texts.length && contextAfterLines.length < _contextWindowSize;
            k++) {
          final cost = texts[k].length + 1;
          if (cost > afterBudget) break;
          contextAfterLines.add(texts[k]);
          afterBudget -= cost;
        }
      }

      // 3. Assemble the full request text
      final allLines = [
        ...contextBeforeLines,
        ...texts.sublist(i, j),
        ...contextAfterLines,
      ];
      final requestText = allLines.join('\n');

      try {
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'q': requestText,
          'langpair': 'autodetect|$targetLang',
          'de': const String.fromEnvironment('MYMEMORY_EMAIL'),
        });

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data =
              jsonDecode(response.body) as Map<String, dynamic>;
          final translated =
              (data['responseData']?['translatedText'] as String?) ?? '';

          // Skip the translated context-before lines; extract only the batch.
          final lines = translated.split('\n');
          final skip = contextBeforeLines.length;
          for (int k = 0; k < batchLineCount; k++) {
            final idx = skip + k;
            if (idx < lines.length) {
              final t = lines[idx].trim();
              result[i + k] = t.isEmpty ? null : t;
            }
          }
        }
      } catch (e) {
        debugPrint(
            '[LyricsTranslation] Batch $i–${j - 1} failed: $e');
      }

      i = j;
    }

    // Evict the oldest single entry when the cache is full (LRU-style).
    if (_cache.length >= 30) _cache.remove(_cache.keys.first);
    _cache[key] = List.from(result);
    return result;
  }

  /// Clears the in-memory translation cache.
  static void clearCache() => _cache.clear();
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Translates song lyrics via the MyMemory free translation API.
///
/// MyMemory anonymous tier: 5 000 chars/day.
/// With the `de` (email) parameter: 50 000 chars/day — no account required.
///
/// API format:
///   GET https://api.mymemory.translated.net/get
///     ?q=TEXT
///     &langpair=autodetect|TARGET  ← autodetect source language
///     &de=EMAIL              ← increases daily quota
///
/// Context-aware batching: each request includes surrounding lines from the
/// rest of the song (within the char budget) so the API can resolve ambiguous
/// words, metaphors, and pronouns in the right thematic context. Only the
/// translated lines for the core batch are retained from the response.
///
/// Caching: in-memory map keyed by "$cacheKey|$targetLang".
/// The cache is capped at 30 entries (LRU-free, just clears when full).

/// Thrown when the detected source language of the lyrics matches the
/// requested target language — i.e. translation would be a no-op.
class SameLanguageException implements Exception {
  final String detectedLanguage;
  const SameLanguageException(this.detectedLanguage);

  @override
  String toString() =>
      'SameLanguageException: lyrics already in "$detectedLanguage"';
}

class LyricsTranslationService {
  static const String _baseUrl =
      'https://api.mymemory.translated.net/get';

  // MyMemory enforces a ~500 character limit per request.
  static const int _maxCharsPerRequest = 450;

  // Maximum number of surrounding lines to include as context per batch.
  static const int _contextWindowSize = 5;

  // In-memory cache: key = "$cacheKey|$targetLang"
  static final Map<String, List<String?>> _cache = {};

  /// Translate [texts] into [targetLang] (BCP-47 code, e.g. "fr", "de", "ja").
  ///
  /// Texts are batched into newline-joined chunks ≤ [_maxCharsPerRequest] chars.
  /// Any spare character budget after filling the core batch is used to prepend
  /// and append surrounding lines from the full lyrics as context, so that each
  /// batch is translated with awareness of the song's broader narrative.
  ///
  /// Returns a list parallel to [texts]; null entries indicate lines that could
  /// not be translated.
  ///
  /// [cacheKey] should uniquely identify the song (e.g. "artist|title") so
  /// the same translation is not re-fetched during the same session.
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
      // --- 1. Build the core batch (same logic as before) ---
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

      // --- 2. Fill remaining char budget with surrounding context lines ---
      // ~half the spare budget goes to lines before, half to lines after.
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

      // --- 3. Assemble the full request text ---
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

          // On the first batch, detect the source language from the matches
          // array (e.g. "en-GB" → "en"). If it equals the target language,
          // abort immediately so we don't waste quota translating a no-op.
          if (i == 0) {
            final matches = data['matches'] as List<dynamic>?;
            if (matches != null && matches.isNotEmpty) {
              final firstMatch = matches[0] as Map<String, dynamic>?;
              final detectedFull =
                  (firstMatch?['source'] as String?) ?? '';
              if (detectedFull.isNotEmpty) {
                final detected =
                    detectedFull.split('-')[0].toLowerCase();
                final target = targetLang.split('-')[0].toLowerCase();
                if (detected == target) {
                  throw SameLanguageException(detected);
                }
              }
            }
          }

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

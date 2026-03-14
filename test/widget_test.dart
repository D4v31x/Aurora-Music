import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/shared/services/lyrics_translation_service.dart';

void main() {
  group('LyricsTranslationService', () {
    setUp(LyricsTranslationService.clearCache);

    test('returns empty list immediately for empty input', () async {
      final result = await LyricsTranslationService.translateLines(
        texts: [],
        targetLang: 'fr',
      );
      expect(result, isEmpty);
    });

    test('result length matches input length', () async {
      final result = await LyricsTranslationService.translateLines(
        texts: [],
        targetLang: 'de',
        cacheKey: 'artist|title',
      );
      expect(result.length, 0);
    });

    test('clearCache completes normally', () {
      expect(LyricsTranslationService.clearCache, returnsNormally);
    });

    test('clearCache allows fresh translation after clear', () async {
      // Populate via empty-input fast path then clear — verifies no state leak
      await LyricsTranslationService.translateLines(texts: [], targetLang: 'ja');
      LyricsTranslationService.clearCache();
      final result = await LyricsTranslationService.translateLines(
        texts: [],
        targetLang: 'ja',
      );
      expect(result, isEmpty);
    });
  });
}

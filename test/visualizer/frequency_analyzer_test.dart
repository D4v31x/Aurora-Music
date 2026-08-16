import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/engine/audio_feature_frame.dart';
import 'package:aurora_music_v01/features/visualizer/engine/frequency_analyzer.dart';

/// Builds a synthetic 0x01-prefixed FFT complex-pair packet with a strong
/// signal concentrated in one bin range (and near-silence elsewhere), to
/// verify range extraction actually reads the right bins.
Uint8List _syntheticFftPacket({required int loudBinStart, required int loudBinEnd}) {
  const totalBins = 256;
  final bytes = Uint8List(1 + totalBins * 2);
  bytes[0] = 1; // FFT type prefix
  for (int b = 1; b <= totalBins; b++) {
    final idx = 1 + (b - 1) * 2;
    final loud = b >= loudBinStart && b < loudBinEnd;
    // int8 real/imag pair — loud bins get a large magnitude, others ~0.
    bytes[idx] = loud ? 100 : 1;
    bytes[idx + 1] = loud ? 100 : 1;
  }
  return bytes;
}

void main() {
  group('FrequencyAnalyzer', () {
    test('malformed/too-short packet returns empty result, never throws', () {
      final analyzer = FrequencyAnalyzer();
      final result = analyzer.analyzeFftPacket(Uint8List.fromList([1]));
      expect(result.spectrum, isEmpty);
      expect(result.frequencyEnergies, isEmpty);
      expect(result.overallEnergy, 0.0);
    });

    test('produces a configured number of spectrum bins', () {
      const config = FrequencyAnalyzerConfig(spectrumResolution: 16);
      final analyzer = FrequencyAnalyzer(config);
      final packet = _syntheticFftPacket(loudBinStart: 1, loudBinEnd: 256);
      final result = analyzer.analyzeFftPacket(packet);
      expect(result.spectrum.length, 16);
    });

    test('exposes every configured named frequency range', () {
      final analyzer = FrequencyAnalyzer();
      final packet = _syntheticFftPacket(loudBinStart: 1, loudBinEnd: 256);
      final result = analyzer.analyzeFftPacket(packet);
      for (final range in FrequencyRange.defaults) {
        expect(result.frequencyEnergies.containsKey(range.name), isTrue);
      }
    });

    test('a bin range with energy reads higher than a silent one', () {
      final analyzer = FrequencyAnalyzer();
      // Concentrate energy in only the very first few bins (sub-bass).
      final packet = _syntheticFftPacket(loudBinStart: 1, loudBinEnd: 3);
      final result = analyzer.analyzeFftPacket(packet);
      final subBass = result.frequencyEnergies['20-60'] ?? 0.0;
      final treble = result.frequencyEnergies['8000-16000'] ?? 0.0;
      expect(subBass, greaterThan(treble));
    });

    test('supports custom (non-default) frequency ranges', () {
      const config = FrequencyAnalyzerConfig(
        frequencyRanges: [FrequencyRange('custom', 100, 300)],
      );
      final analyzer = FrequencyAnalyzer(config);
      final packet = _syntheticFftPacket(loudBinStart: 1, loudBinEnd: 256);
      final result = analyzer.analyzeFftPacket(packet);
      expect(result.frequencyEnergies.containsKey('custom'), isTrue);
    });
  });
}

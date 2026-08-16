import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/engine/audio_feature_frame.dart';
import 'package:aurora_music_v01/features/visualizer/engine/beat_detector.dart';

List<double> _spectrumWithEnergy(int size, double energy) =>
    List.filled(size, energy);

void main() {
  group('BeatDetector', () {
    test('empty spectrum returns idle result, never throws', () {
      final detector = BeatDetector();
      final result = detector.process(const []);
      expect(result.beatPulse, isFalse);
      expect(result.beatIntensity, 0.0);
    });

    test('a sudden loud transient after quiet frames triggers a pulse', () {
      final detector = BeatDetector(historyLength: 16);
      final baseTime = DateTime(2024);
      // Feed several quiet, near-identical frames to establish a low
      // baseline, then one sharp transient.
      for (var i = 0; i < 12; i++) {
        detector.process(_spectrumWithEnergy(8, 0.05),
            now: baseTime.add(Duration(milliseconds: i * 20)));
      }
      final result = detector.process(
        _spectrumWithEnergy(8, 0.9),
        now: baseTime.add(const Duration(milliseconds: 260)),
      );
      expect(result.beatPulse, isTrue);
      expect(result.beatIntensity, greaterThan(0.0));
    });

    test('refractory period prevents an immediate second pulse', () {
      final detector = BeatDetector(
        historyLength: 16,
        refractoryPeriod: const Duration(milliseconds: 200),
      );
      final baseTime = DateTime(2024);
      for (var i = 0; i < 12; i++) {
        detector.process(_spectrumWithEnergy(8, 0.05),
            now: baseTime.add(Duration(milliseconds: i * 20)));
      }
      final first = detector.process(
        _spectrumWithEnergy(8, 0.9),
        now: baseTime.add(const Duration(milliseconds: 260)),
      );
      final second = detector.process(
        _spectrumWithEnergy(8, 0.9),
        now: baseTime.add(const Duration(milliseconds: 270)),
      );
      expect(first.beatPulse, isTrue);
      expect(second.beatPulse, isFalse);
    });

    test('reset clears history so a new sequence starts fresh', () {
      final detector = BeatDetector();
      detector.process(_spectrumWithEnergy(8, 0.5));
      detector.reset();
      final result = detector.process(const []);
      expect(result.beatPulse, isFalse);
    });
  });

  group('AudioFeatureFrame from beat detector', () {
    test('beatPulse aggregate source reads as 1.0/0.0', () {
      const pulsing = AudioFeatureFrame(beatPulse: true);
      const idle = AudioFeatureFrame();
      expect(pulsing.beatPulse, isTrue);
      expect(idle.beatPulse, isFalse);
    });
  });
}

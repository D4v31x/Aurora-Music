import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/engine/audio_feature_frame.dart';
import 'package:aurora_music_v01/features/visualizer/engine/drop_detector.dart';

void main() {
  group('DropDetector', () {
    test('first call never fires (needs a baseline first)', () {
      final detector = DropDetector();
      final result = detector.process(0.9, now: DateTime(2024));
      expect(result.dropPulse, isFalse);
    });

    test('a sudden surge after a sustained quiet buildup fires a drop', () {
      final detector = DropDetector();
      final baseTime = DateTime(2024);
      // Sustained quiet section (breakdown) for several seconds.
      for (var i = 0; i < 40; i++) {
        detector.process(0.1, now: baseTime.add(Duration(milliseconds: i * 100)));
      }
      // Sudden full-energy hit.
      final result = detector.process(
        0.95,
        now: baseTime.add(const Duration(milliseconds: 4100)),
      );
      expect(result.dropPulse, isTrue);
      expect(result.dropIntensity, greaterThan(0.0));
    });

    test('a loud passage getting louder (no quiet buildup) never counts as a drop', () {
      final detector = DropDetector();
      final baseTime = DateTime(2024);
      // Already loud the whole time — never dips below the quiet threshold.
      for (var i = 0; i < 40; i++) {
        detector.process(0.6, now: baseTime.add(Duration(milliseconds: i * 100)));
      }
      final result = detector.process(
        0.95,
        now: baseTime.add(const Duration(milliseconds: 4100)),
      );
      expect(result.dropPulse, isFalse);
    });

    test('refractory period prevents an immediate second drop pulse', () {
      final detector = DropDetector(
        refractoryPeriod: const Duration(seconds: 2),
      );
      final baseTime = DateTime(2024);
      for (var i = 0; i < 40; i++) {
        detector.process(0.1, now: baseTime.add(Duration(milliseconds: i * 100)));
      }
      final first = detector.process(
        0.95,
        now: baseTime.add(const Duration(milliseconds: 4100)),
      );
      final second = detector.process(
        0.95,
        now: baseTime.add(const Duration(milliseconds: 4200)),
      );
      expect(first.dropPulse, isTrue);
      expect(second.dropPulse, isFalse);
    });

    test('reset clears state so a new sequence starts fresh', () {
      final detector = DropDetector();
      detector.process(0.9, now: DateTime(2024));
      detector.reset();
      final result = detector.process(0.1, now: DateTime(2024));
      expect(result.dropPulse, isFalse);
    });
  });

  group('AudioFeatureFrame from drop detector', () {
    test('dropPulse aggregate source reads as 1.0/0.0', () {
      const pulsing = AudioFeatureFrame(dropPulse: true);
      const idle = AudioFeatureFrame();
      expect(pulsing.dropPulse, isTrue);
      expect(idle.dropPulse, isFalse);
    });
  });
}

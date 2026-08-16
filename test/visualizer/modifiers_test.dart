import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/model/modifiers.dart';

void main() {
  group('NormalizeModifier', () {
    test('maps an arbitrary range to 0.0-1.0', () {
      final state = ModifierState();
      const modifier = NormalizeModifier(min: -1);
      expect(modifier.apply(0.0, state, 0.016), closeTo(0.5, 0.001));
      expect(modifier.apply(-1.0, state, 0.016), closeTo(0.0, 0.001));
      expect(modifier.apply(1.0, state, 0.016), closeTo(1.0, 0.001));
    });

    test('degenerate range (max<=min) returns 0 rather than throwing', () {
      final state = ModifierState();
      const modifier = NormalizeModifier(min: 5, max: 5);
      expect(modifier.apply(5.0, state, 0.016), 0.0);
    });
  });

  group('ClampModifier', () {
    test('clamps outside the range', () {
      final state = ModifierState();
      const modifier = ClampModifier(0.0, 1.0);
      expect(modifier.apply(1.5, state, 0.016), 1.0);
      expect(modifier.apply(-0.5, state, 0.016), 0.0);
      expect(modifier.apply(0.5, state, 0.016), 0.5);
    });
  });

  group('RemapModifier', () {
    test('remaps a value proportionally between output bounds', () {
      final state = ModifierState();
      const modifier =
          RemapModifier(inMin: 0, inMax: 1, outMin: 10, outMax: 20);
      expect(modifier.apply(0.5, state, 0.016), closeTo(15, 0.001));
      expect(modifier.apply(0.0, state, 0.016), closeTo(10, 0.001));
      expect(modifier.apply(1.0, state, 0.016), closeTo(20, 0.001));
    });
  });

  group('SmoothModifier', () {
    test('first call passes input through unchanged (no jump from 0)', () {
      final state = ModifierState();
      const modifier = SmoothModifier(0.8);
      expect(modifier.apply(1.0, state, 0.016), 1.0);
    });

    test('approaches but does not immediately reach a step input', () {
      final state = ModifierState();
      const modifier = SmoothModifier(0.9);
      modifier.apply(0.0, state, 0.016); // seed at 0
      final result = modifier.apply(1.0, state, 0.016);
      expect(result, greaterThan(0.0));
      expect(result, lessThan(1.0));
    });

    test('smoothing 0.0 tracks input immediately', () {
      final state = ModifierState();
      const modifier = SmoothModifier(0.0);
      modifier.apply(0.0, state, 0.016);
      expect(modifier.apply(1.0, state, 0.016), closeTo(1.0, 0.01));
    });
  });

  group('AttackDecayModifier', () {
    test('rises faster with a short attack than it falls with a long decay', () {
      final riseState = ModifierState();
      final fallState = ModifierState();
      const modifier =
          AttackDecayModifier(attackSeconds: 0.05, decaySeconds: 2.0);

      modifier.apply(0.0, riseState, 0.016);
      final risen = modifier.apply(1.0, riseState, 0.05);

      modifier.apply(1.0, fallState, 0.016);
      final fallen = modifier.apply(0.0, fallState, 0.05);

      // After the same dt, the fast-attack rise should have moved further
      // toward its target than the slow-decay fall moved toward its target.
      expect(risen, greaterThan(1 - fallen));
    });
  });

  group('PowerModifier', () {
    test('applies exponent while preserving sign', () {
      final state = ModifierState();
      const modifier = PowerModifier(2.0);
      expect(modifier.apply(0.5, state, 0.016), closeTo(0.25, 0.001));
      expect(modifier.apply(-0.5, state, 0.016), closeTo(-0.25, 0.001));
    });
  });

  group('AbsModifier / InvertModifier', () {
    test('abs removes sign', () {
      final state = ModifierState();
      expect(const AbsModifier().apply(-0.7, state, 0.016), closeTo(0.7, 0.001));
    });

    test('invert flips a normalized 0-1 value', () {
      final state = ModifierState();
      expect(const InvertModifier().apply(0.3, state, 0.016), closeTo(0.7, 0.001));
    });
  });

  group('PulseModifier', () {
    test('jumps up instantly on a rising trigger, decays gradually', () {
      final state = ModifierState();
      const modifier = PulseModifier(1.0);
      expect(modifier.apply(1.0, state, 0.016), 1.0);
      final decayed = modifier.apply(0.0, state, 0.5);
      expect(decayed, closeTo(0.5, 0.05));
    });
  });

  group('RotationModifier', () {
    test('accumulates rotation proportional to input over time', () {
      final state = ModifierState();
      const modifier = RotationModifier(1.0);
      modifier.apply(1.0, state, 1.0);
      final second = modifier.apply(1.0, state, 1.0);
      expect(second, closeTo(2.0, 0.001));
    });
  });

  group('Modifier JSON round-trip', () {
    test('every modifier type survives toJson/fromJson', () {
      final modifiers = <Modifier>[
        const NormalizeModifier(max: 2),
        const ClampModifier(0, 1),
        const MultiplyModifier(2.0),
        const AddModifier(1.0),
        const SubtractModifier(0.5),
        const SensitivityModifier(1.5),
        const RemapModifier(inMin: 0, inMax: 1, outMin: 0, outMax: 10),
        const SmoothModifier(0.5),
        const AttackDecayModifier(attackSeconds: 0.1, decaySeconds: 0.5),
        const PowerModifier(1.5),
        const EaseModifier(EaseCurve.easeInOut),
        const AbsModifier(),
        const InvertModifier(),
        const OscillateModifier(frequencyHz: 1.0, amplitude: 0.1),
        const NoiseModifier(amplitude: 0.2, speed: 1.0),
        const RandomModifier(changeIntervalSeconds: 2.0),
        const PulseModifier(1.0),
        const RotationModifier(0.5),
      ];

      for (final modifier in modifiers) {
        final restored = Modifier.fromJson(modifier.toJson());
        expect(restored.toJson(), modifier.toJson());
      }
    });
  });
}

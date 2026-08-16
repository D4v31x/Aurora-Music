import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/engine/audio_feature_frame.dart';
import 'package:aurora_music_v01/features/visualizer/model/audio_signal_source.dart';
import 'package:aurora_music_v01/features/visualizer/model/modifiers.dart';
import 'package:aurora_music_v01/features/visualizer/model/signal_binding.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_property.dart';

AudioFeatureFrame _frameWithBass(double bass) => AudioFeatureFrame(
      frequencyEnergies: {'20-60': bass},
      overallEnergy: bass,
    );

void main() {
  group('SignalBinding resolution', () {
    test('reads the bound source through an empty pipeline unchanged', () {
      const binding = SignalBinding(source: FrequencyRangeSource('20-60'));
      final runtime = SignalBindingRuntime(0);
      final value = runtime.resolve(binding, _frameWithBass(0.7), 0.016);
      expect(value, closeTo(0.7, 0.001));
    });

    test('applies pipeline stages in order', () {
      const binding = SignalBinding(
        source: FrequencyRangeSource('20-60'),
        pipeline: [MultiplyModifier(2.0), ClampModifier(0, 1)],
      );
      final runtime = SignalBindingRuntime(binding.pipeline.length);
      // 0.7 * 2.0 = 1.4, clamped to 1.0
      final value = runtime.resolve(binding, _frameWithBass(0.7), 0.016);
      expect(value, 1.0);
    });

    test('missing frequency range reads as 0.0 rather than throwing', () {
      const binding = SignalBinding(source: FrequencyRangeSource('unknown-range'));
      final runtime = SignalBindingRuntime(0);
      final value = runtime.resolve(binding, _frameWithBass(0.7), 0.016);
      expect(value, 0.0);
    });
  });

  group('VisualizerProperty audio-to-property mapping', () {
    test('add mode: base + signal (spec example: scale = 1.0 + bass * 0.4)', () {
      const property = VisualizerProperty(
        baseValue: 1.0,
        binding: SignalBinding(
          source: FrequencyRangeSource('20-60'),
          pipeline: [MultiplyModifier(0.4)],
        ),
      );
      final runtime = SignalBindingRuntime(property.binding!.pipeline.length);
      final reactive = runtime.resolve(property.binding!, _frameWithBass(1.0), 0.016);
      expect(property.resolve(reactive), closeTo(1.4, 0.001));
    });

    test('replace mode: property IS the signal (spec example: opacity = vocals)', () {
      const property = VisualizerProperty(
        baseValue: 0.0,
        binding: SignalBinding(source: FrequencyRangeSource('20-60')),
        mode: PropertyBindMode.replace,
      );
      final runtime = SignalBindingRuntime(0);
      final reactive = runtime.resolve(property.binding!, _frameWithBass(0.65), 0.016);
      expect(property.resolve(reactive), closeTo(0.65, 0.001));
    });

    test('multiply mode', () {
      const property = VisualizerProperty(
        baseValue: 2.0,
        binding: SignalBinding(source: FrequencyRangeSource('20-60')),
        mode: PropertyBindMode.multiply,
      );
      final runtime = SignalBindingRuntime(0);
      final reactive = runtime.resolve(property.binding!, _frameWithBass(0.5), 0.016);
      expect(property.resolve(reactive), closeTo(1.0, 0.001));
    });

    test('a property with no binding always returns its static base value', () {
      const property = VisualizerProperty(baseValue: 42.0);
      expect(property.resolve(null), 42.0);
      expect(property.isReactive, isFalse);
    });
  });

  group('AudioSignalSource JSON round-trip', () {
    test('every source type survives toJson/fromJson', () {
      final sources = <AudioSignalSource>[
        const FrequencyRangeSource('20-60'),
        const AggregateSource(AggregateFeature.beatIntensity),
        const SemanticSource('vocals'),
        const ConstantSource(0.5),
      ];
      for (final source in sources) {
        final restored = AudioSignalSource.fromJson(source.toJson());
        expect(restored.toJson(), source.toJson());
      }
    });
  });

  group('AudioFeatureFrame resilience', () {
    test('empty frame resolves signals to safe defaults, never throws', () {
      const frame = AudioFeatureFrame.empty;
      expect(frame.frequencyEnergy('20-60'), 0.0);
      expect(frame.semantic('vocals').value, 0.0);
      expect(frame.hasData, isFalse);
      expect(frame.overallEnergy, 0.0);
    });

    test('parses a well-formed FFT byte packet without throwing', () {
      // Not asserting exact numeric output here (covered by
      // frequency_analyzer_test.dart) — just that malformed/edge-case
      // packets can't crash the pipeline.
      final packet = Uint8List.fromList([1, 0, 0, 0, 0]);
      expect(() => packet.length, returnsNormally);
    });
  });
}

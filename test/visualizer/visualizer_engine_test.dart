import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/engine/audio_feature_frame.dart';
import 'package:aurora_music_v01/features/visualizer/engine_runtime/visualizer_engine.dart';
import 'package:aurora_music_v01/features/visualizer/model/audio_signal_source.dart';
import 'package:aurora_music_v01/features/visualizer/model/modifiers.dart';
import 'package:aurora_music_v01/features/visualizer/model/signal_binding.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_element.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_layer.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_property.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_template.dart';

VisualizerTemplate _templateWithReactiveCircle() {
  return const VisualizerTemplate(
    id: 't',
    name: 'Test',
    layers: [
      VisualizerLayer(name: 'L', elements: [
        CircleElement(id: 'c', properties: {
          PropertyKey.scale: VisualizerProperty(
            baseValue: 1.0,
            binding: SignalBinding(
              source: FrequencyRangeSource('20-60'),
              pipeline: [MultiplyModifier(0.5)],
            ),
          ),
        }),
      ]),
    ],
  );
}

void main() {
  group('VisualizerEngine.computeFrame', () {
    test('resolves a reactive property using the current frame', () {
      final engine = VisualizerEngine(_templateWithReactiveCircle());
      const frame = AudioFeatureFrame(
        frequencyEnergies: {'20-60': 1.0},
        hasData: true,
      );
      final state = engine.computeFrame(frame, 0.016);
      final scale = state.layers[0].elements[0].value(PropertyKey.scale, -1);
      expect(scale, closeTo(1.5, 0.001)); // 1.0 base + 1.0 * 0.5
    });

    test('continues functioning with an empty/no-data frame — never throws', () {
      final engine = VisualizerEngine(_templateWithReactiveCircle());
      final state = engine.computeFrame(AudioFeatureFrame.empty, 0.016);
      final scale = state.layers[0].elements[0].value(PropertyKey.scale, -1);
      // No data ⇒ frequency energy reads as 0 ⇒ base + 0*0.5 = base.
      expect(scale, closeTo(1.0, 0.001));
      expect(state.frame.hasData, isFalse);
    });

    test('switching templates resets per-binding smoothing state', () {
      final engine = VisualizerEngine(const VisualizerTemplate(
        id: 'a',
        name: 'A',
        layers: [
          VisualizerLayer(name: 'L', elements: [
            CircleElement(id: 'c', properties: {
              PropertyKey.scale: VisualizerProperty(
                baseValue: 0.0,
                binding: SignalBinding(
                  source: FrequencyRangeSource('20-60'),
                  pipeline: [SmoothModifier(0.9)],
                ),
                mode: PropertyBindMode.replace,
              ),
            }),
          ]),
        ],
      ));

      const loudFrame = AudioFeatureFrame(frequencyEnergies: {'20-60': 1.0});
      // Feed several frames so the smoothed value climbs partway up.
      for (var i = 0; i < 5; i++) {
        engine.computeFrame(loudFrame, 0.016);
      }
      final beforeSwitch =
          engine.computeFrame(loudFrame, 0.016).layers[0].elements[0].value(PropertyKey.scale, -1);
      expect(beforeSwitch, greaterThan(0.0));

      engine.setTemplate(_templateWithReactiveCircle());
      engine.setTemplate(const VisualizerTemplate(
        id: 'a',
        name: 'A',
        layers: [
          VisualizerLayer(name: 'L', elements: [
            CircleElement(id: 'c', properties: {
              PropertyKey.scale: VisualizerProperty(
                baseValue: 0.0,
                binding: SignalBinding(
                  source: FrequencyRangeSource('20-60'),
                  pipeline: [SmoothModifier(0.9)],
                ),
                mode: PropertyBindMode.replace,
              ),
            }),
          ]),
        ],
      ));
      // Right after a template switch, smoothing state is fresh — the very
      // first resolved value should pass straight through (no artificial
      // ramp carried over from the previous template).
      final afterSwitch =
          engine.computeFrame(loudFrame, 0.016).layers[0].elements[0].value(PropertyKey.scale, -1);
      expect(afterSwitch, closeTo(1.0, 0.001));
    });
  });
}

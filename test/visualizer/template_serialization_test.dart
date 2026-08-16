import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_music_v01/features/visualizer/model/audio_signal_source.dart';
import 'package:aurora_music_v01/features/visualizer/model/modifiers.dart';
import 'package:aurora_music_v01/features/visualizer/model/signal_binding.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_element.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_layer.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_property.dart';
import 'package:aurora_music_v01/features/visualizer/model/visualizer_template.dart';
import 'package:aurora_music_v01/features/visualizer/templates/builtin_templates.dart';

VisualizerTemplate _sampleTemplate() {
  return VisualizerTemplate(
    id: 'sample',
    name: 'Sample',
    description: 'A test template',
    layers: [
      VisualizerLayer(name: 'Background', elements: [
        RectangleElement(id: 'bg', properties: {
          PropertyKey.width: VisualizerProperty.static(400),
          PropertyKey.height: VisualizerProperty.static(800),
        }),
      ]),
      const VisualizerLayer(name: 'Reactive', elements: [
        CircleElement(id: 'circle', properties: {
          PropertyKey.scale: VisualizerProperty(
            baseValue: 1.0,
            binding: SignalBinding(
              source: FrequencyRangeSource('20-60'),
              pipeline: [SmoothModifier(0.5), MultiplyModifier(0.4)],
            ),
          ),
        }),
      ]),
    ],
  );
}

void main() {
  group('VisualizerTemplate serialization', () {
    test('round-trips through JSON preserving structure', () {
      final template = _sampleTemplate();
      final restored = VisualizerTemplate.fromJson(template.toJson());

      expect(restored.id, template.id);
      expect(restored.name, template.name);
      expect(restored.layers.length, template.layers.length);
      expect(restored.layers[0].elements[0].id, 'bg');
      expect(restored.layers[1].elements[0].id, 'circle');
    });

    test('reactive bindings and their modifier pipeline survive round-trip', () {
      final template = _sampleTemplate();
      final restored = VisualizerTemplate.fromJson(template.toJson());
      final circle = restored.layers[1].elements[0];
      final scaleProp = circle.properties[PropertyKey.scale]!;
      expect(scaleProp.isReactive, isTrue);
      expect(scaleProp.binding!.pipeline.length, 2);
      expect(scaleProp.binding!.pipeline[0], isA<SmoothModifier>());
      expect(scaleProp.binding!.pipeline[1], isA<MultiplyModifier>());
    });

    test('has a version field and defaults to the current version', () {
      final template = _sampleTemplate();
      expect(template.version, kVisualizerTemplateVersion);
      final json = template.toJson();
      expect(json['version'], kVisualizerTemplateVersion);
    });

    test('missing version in JSON is treated as current version rather than throwing', () {
      final json = _sampleTemplate().toJson();
      json.remove('version');
      final restored = VisualizerTemplate.fromJson(json);
      expect(restored.version, kVisualizerTemplateVersion);
    });

    test('template JSON never contains runtime state, only static config', () {
      final json = _sampleTemplate().toJson();
      // Sanity check: nothing like a "currentValue"/"phase"/"lastFired" key
      // should ever appear anywhere in a serialized template.
      final encoded = json.toString();
      expect(encoded.contains('phase'), isFalse);
      expect(encoded.contains('currentValue'), isFalse);
    });
  });

  group('Layer ordering', () {
    test('layers preserve authoring order through serialization', () {
      final template = _sampleTemplate();
      final restored = VisualizerTemplate.fromJson(template.toJson());
      expect(restored.layers[0].name, 'Background');
      expect(restored.layers[1].name, 'Reactive');
    });

    test('layer visibility/opacity/blendMode round-trip', () {
      const layer = VisualizerLayer(
        name: 'Test',
        visible: false,
        opacity: 0.5,
      );
      final restored = VisualizerLayer.fromJson(layer.toJson());
      expect(restored.visible, isFalse);
      expect(restored.opacity, 0.5);
    });
  });

  group('Built-in templates', () {
    test('all 7 required built-in templates exist and are distinct, plus '
        'the Impact Drop extra', () {
      final templates = BuiltinTemplates.all;
      expect(templates.length, 8);
      expect(templates.map((t) => t.id).toSet().length, 8);
    });

    test('every built-in template round-trips through JSON', () {
      for (final template in BuiltinTemplates.all) {
        final restored = VisualizerTemplate.fromJson(template.toJson());
        expect(restored.layers.length, template.layers.length);
      }
    });

    test('built-in templates demonstrate different element types (not all spectrum bars)', () {
      final allTypes = BuiltinTemplates.all
          .expand((t) => t.layers)
          .expand((l) => l.elements)
          .map((e) => e.type)
          .toSet();
      expect(allTypes.length, greaterThan(3));
    });
  });
}

/// A named, ordered group of [VisualizerElement]s (spec section 10).
library;

import 'dart:ui' show BlendMode;

import 'visualizer_element.dart';

class VisualizerLayer {
  final String name;
  final bool visible;
  final double opacity;
  final BlendMode blendMode;
  final List<VisualizerElement> elements;

  const VisualizerLayer({
    required this.name,
    this.visible = true,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.elements = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'visible': visible,
        'opacity': opacity,
        'blendMode': blendMode.name,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory VisualizerLayer.fromJson(Map<String, dynamic> json) {
    return VisualizerLayer(
      name: json['name'] as String? ?? 'Layer',
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: BlendMode.values.firstWhere(
        (m) => m.name == json['blendMode'],
        orElse: () => BlendMode.srcOver,
      ),
      elements: ((json['elements'] as List?) ?? const [])
          .map((e) => VisualizerElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

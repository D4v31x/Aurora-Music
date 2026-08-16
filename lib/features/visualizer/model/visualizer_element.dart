/// Generic visualizer element abstraction (spec section 7/8). Every element
/// shares the same [PropertyKey]-keyed reactive/static property map plus a
/// static base color — type-specific extra fields (text string, particle
/// behavior, path points, ...) live on the concrete subclass. The renderer
/// dispatches purely on [type]; adding a new element type later means one
/// new subclass + one new painter branch, nothing else changes.
library;

import 'dart:ui' show Color;

import 'visualizer_property.dart';

enum VisualizerElementType {
  rectangle,
  circle,
  line,
  polygon,
  path,
  waveform,
  spectrumBars,
  radialSpectrum,
  particles,
  text,
  image,
}

/// Where an [ImageElement] gets its pixels from.
sealed class ImageSource {
  const ImageSource();
  Map<String, dynamic> toJson();
  static ImageSource fromJson(Map<String, dynamic> json) {
    return json['kind'] == 'currentArtwork'
        ? const CurrentArtworkSource()
        : AssetImageSource(json['path'] as String? ?? '');
  }
}

class AssetImageSource extends ImageSource {
  final String path;
  const AssetImageSource(this.path);
  @override
  Map<String, dynamic> toJson() => {'kind': 'asset', 'path': path};
}

/// Uses the currently-playing song's album artwork — see spec section 13.
class CurrentArtworkSource extends ImageSource {
  const CurrentArtworkSource();
  @override
  Map<String, dynamic> toJson() => {'kind': 'currentArtwork'};
}

sealed class VisualizerElement {
  final String id;
  final VisualizerElementType type;
  final Map<PropertyKey, VisualizerProperty> properties;
  final Color color;
  final bool visible;

  const VisualizerElement({
    required this.id,
    required this.type,
    required this.properties,
    this.color = const Color(0xFFFFFFFF),
    this.visible = true,
  });

  VisualizerProperty prop(PropertyKey key, double defaultValue) =>
      properties[key] ?? VisualizerProperty.static(defaultValue);

  Map<String, dynamic> toJson();

  static VisualizerElement fromJson(Map<String, dynamic> json) {
    final type = VisualizerElementType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => VisualizerElementType.rectangle,
    );
    final id = json['id'] as String;
    final properties = _propertiesFromJson(json['properties']);
    final color = Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF);
    final visible = json['visible'] as bool? ?? true;

    switch (type) {
      case VisualizerElementType.rectangle:
        return RectangleElement(
            id: id, properties: properties, color: color, visible: visible);
      case VisualizerElementType.circle:
        return CircleElement(
            id: id, properties: properties, color: color, visible: visible);
      case VisualizerElementType.line:
        return LineElement(id: id, properties: properties, color: color, visible: visible);
      case VisualizerElementType.polygon:
        return PolygonElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          sides: (json['sides'] as num?)?.toInt() ?? 6,
        );
      case VisualizerElementType.path:
        return PathElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          points: ((json['points'] as List?) ?? const [])
              .map((p) => (
                    (p as Map)['x'] as num,
                    p['y'] as num,
                  ))
              .map((p) => (p.$1.toDouble(), p.$2.toDouble()))
              .toList(),
        );
      case VisualizerElementType.waveform:
        return WaveformElement(
            id: id, properties: properties, color: color, visible: visible);
      case VisualizerElementType.spectrumBars:
        return SpectrumBarsElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          barCount: (json['barCount'] as num?)?.toInt() ?? 32,
        );
      case VisualizerElementType.radialSpectrum:
        return RadialSpectrumElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          barCount: (json['barCount'] as num?)?.toInt() ?? 48,
        );
      case VisualizerElementType.particles:
        return ParticlesElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          maxParticles: (json['maxParticles'] as num?)?.toInt() ?? 64,
        );
      case VisualizerElementType.text:
        return TextElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          text: json['text'] as String? ?? '',
        );
      case VisualizerElementType.image:
        return ImageElement(
          id: id,
          properties: properties,
          color: color,
          visible: visible,
          source: ImageSource.fromJson(
              json['source'] as Map<String, dynamic>? ?? const {'kind': 'currentArtwork'}),
        );
    }
  }

  Map<String, dynamic> _baseJson() => {
        'id': id,
        'type': type.name,
        'properties': {
          for (final e in properties.entries) e.key.name: e.value.toJson(),
        },
        'color': color.toARGB32(),
        'visible': visible,
      };

  static Map<PropertyKey, VisualizerProperty> _propertiesFromJson(dynamic json) {
    if (json is! Map) return const {};
    final result = <PropertyKey, VisualizerProperty>{};
    for (final entry in json.entries) {
      final key = PropertyKey.values.firstWhere(
        (k) => k.name == entry.key,
        orElse: () => PropertyKey.opacity,
      );
      result[key] =
          VisualizerProperty.fromJson(entry.value as Map<String, dynamic>);
    }
    return result;
  }
}

class RectangleElement extends VisualizerElement {
  const RectangleElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
  }) : super(type: VisualizerElementType.rectangle);
  @override
  Map<String, dynamic> toJson() => _baseJson();
}

class CircleElement extends VisualizerElement {
  const CircleElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
  }) : super(type: VisualizerElementType.circle);
  @override
  Map<String, dynamic> toJson() => _baseJson();
}

class LineElement extends VisualizerElement {
  const LineElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
  }) : super(type: VisualizerElementType.line);
  @override
  Map<String, dynamic> toJson() => _baseJson();
}

class PolygonElement extends VisualizerElement {
  final int sides;
  const PolygonElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.sides = 6,
  }) : super(type: VisualizerElementType.polygon);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'sides': sides};
}

/// Static (x, y) control points, normalized 0.0-1.0 within the element's
/// bounding box — full path editing is left to a future editor.
class PathElement extends VisualizerElement {
  final List<(double, double)> points;
  const PathElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.points = const [],
  }) : super(type: VisualizerElementType.path);
  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'points': points.map((p) => {'x': p.$1, 'y': p.$2}).toList(),
      };
}

class WaveformElement extends VisualizerElement {
  const WaveformElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
  }) : super(type: VisualizerElementType.waveform);
  @override
  Map<String, dynamic> toJson() => _baseJson();
}

class SpectrumBarsElement extends VisualizerElement {
  final int barCount;
  const SpectrumBarsElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.barCount = 32,
  }) : super(type: VisualizerElementType.spectrumBars);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'barCount': barCount};
}

class RadialSpectrumElement extends VisualizerElement {
  final int barCount;
  const RadialSpectrumElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.barCount = 48,
  }) : super(type: VisualizerElementType.radialSpectrum);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'barCount': barCount};
}

class ParticlesElement extends VisualizerElement {
  final int maxParticles;
  const ParticlesElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.maxParticles = 64,
  }) : super(type: VisualizerElementType.particles);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'maxParticles': maxParticles};
}

class TextElement extends VisualizerElement {
  final String text;
  const TextElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.text = '',
  }) : super(type: VisualizerElementType.text);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'text': text};
}

class ImageElement extends VisualizerElement {
  final ImageSource source;
  const ImageElement({
    required super.id,
    required super.properties,
    super.color,
    super.visible,
    this.source = const CurrentArtworkSource(),
  }) : super(type: VisualizerElementType.image);
  @override
  Map<String, dynamic> toJson() => {..._baseJson(), 'source': source.toJson()};
}

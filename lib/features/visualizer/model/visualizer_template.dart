/// Serializable, versioned visualizer template — the top-level "recipe" a
/// [VisualizerEngine] renders. Contains only static configuration, never
/// runtime state (spec section 11): re-loading the same template always
/// starts from the same definition, though live signal smoothing state is
/// naturally per-session (see [SignalBindingRuntime]).
library;

import 'dart:ui' show Color;

import 'visualizer_layer.dart';

/// Bumped whenever the template schema changes in a way that needs
/// migration. See [VisualizerTemplate.fromJson] for the migration hook.
const int kVisualizerTemplateVersion = 1;

class VisualizerCanvasConfig {
  /// Logical reference size the template was authored against; elements'
  /// position/size properties are expressed relative to this and scaled to
  /// fit the actual render surface.
  final double referenceWidth;
  final double referenceHeight;

  const VisualizerCanvasConfig({
    this.referenceWidth = 400,
    this.referenceHeight = 800,
  });

  Map<String, dynamic> toJson() =>
      {'referenceWidth': referenceWidth, 'referenceHeight': referenceHeight};

  factory VisualizerCanvasConfig.fromJson(Map<String, dynamic> json) {
    return VisualizerCanvasConfig(
      referenceWidth: (json['referenceWidth'] as num?)?.toDouble() ?? 400,
      referenceHeight: (json['referenceHeight'] as num?)?.toDouble() ?? 800,
    );
  }
}

class VisualizerTemplate {
  final int version;
  final String id;
  final String name;
  final String description;
  final VisualizerCanvasConfig canvas;

  /// Solid background color shown beneath all layers. A blurred-artwork
  /// background is achieved via an [ImageElement] using
  /// `CurrentArtworkSource` in a background layer instead of a dedicated
  /// field, keeping "background" just an ordinary (bottom) layer.
  final Color backgroundColor;

  final List<VisualizerLayer> layers;

  const VisualizerTemplate({
    this.version = kVisualizerTemplateVersion,
    required this.id,
    required this.name,
    this.description = '',
    this.canvas = const VisualizerCanvasConfig(),
    this.backgroundColor = const Color(0xFF000000),
    this.layers = const [],
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'id': id,
        'name': name,
        'description': description,
        'canvas': canvas.toJson(),
        'backgroundColor': backgroundColor.toARGB32(),
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  /// Deserializes a template, migrating older versions forward first. Never
  /// throws on a recognized-but-outdated version — see [_migrate].
  factory VisualizerTemplate.fromJson(Map<String, dynamic> json) {
    final migrated = _migrate(Map<String, dynamic>.from(json));
    return VisualizerTemplate(
      version: migrated['version'] as int? ?? kVisualizerTemplateVersion,
      id: migrated['id'] as String? ?? 'unknown',
      name: migrated['name'] as String? ?? 'Untitled',
      description: migrated['description'] as String? ?? '',
      canvas: migrated['canvas'] != null
          ? VisualizerCanvasConfig.fromJson(
              migrated['canvas'] as Map<String, dynamic>)
          : const VisualizerCanvasConfig(),
      backgroundColor:
          Color((migrated['backgroundColor'] as num?)?.toInt() ?? 0xFF000000),
      layers: ((migrated['layers'] as List?) ?? const [])
          .map((l) => VisualizerLayer.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Forward-migrates a raw JSON map to the current [kVisualizerTemplateVersion].
  /// No prior versions exist yet — this is the hook future migrations plug
  /// into, one `if ((json['version'] as int) == N) { ...; json['version'] =
  /// N + 1; }` step at a time.
  static Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    json['version'] ??= kVisualizerTemplateVersion;
    return json;
  }
}

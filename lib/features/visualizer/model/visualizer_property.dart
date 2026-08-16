/// A property on a [VisualizerElement] — either a fixed static value or one
/// driven by a [SignalBinding] combined with the static [baseValue] via
/// [mode]. Every animatable numeric property in the engine (scale,
/// rotation, opacity, size, ...) uses this same type; there is no separate
/// "reactive widget" per property.
library;

import 'signal_binding.dart';

/// How a resolved signal combines with [VisualizerProperty.baseValue].
enum PropertyBindMode {
  /// `base + signal` — e.g. `scale = 1.0 + bass * 0.4`.
  add,

  /// `base * signal`.
  multiply,

  /// The signal fully replaces the base value — e.g. `opacity = vocals`.
  replace,
}

/// Canonical set of properties [VisualizerElement]s expose — kept as a
/// closed enum (rather than free-form strings) so the engine/painter can
/// exhaustively switch over them, while still allowing any property to be
/// bound to any [AudioSignalSource].
enum PropertyKey {
  positionX,
  positionY,
  scale,
  rotation,
  width,
  height,
  opacity,
  strokeWidth,
  cornerRadius,
  particleCount,
  particleSize,
  blurAmount,
  waveformAmplitude,
  spectrumSensitivity,
  hueShift,
}

class VisualizerProperty {
  final double baseValue;
  final SignalBinding? binding;
  final PropertyBindMode mode;

  const VisualizerProperty({
    required this.baseValue,
    this.binding,
    this.mode = PropertyBindMode.add,
  });

  factory VisualizerProperty.static(double value) =>
      VisualizerProperty(baseValue: value);

  bool get isReactive => binding != null;

  double resolve(double? reactiveValue) {
    if (binding == null || reactiveValue == null) return baseValue;
    switch (mode) {
      case PropertyBindMode.add:
        return baseValue + reactiveValue;
      case PropertyBindMode.multiply:
        return baseValue * reactiveValue;
      case PropertyBindMode.replace:
        return reactiveValue;
    }
  }

  Map<String, dynamic> toJson() => {
        'base': baseValue,
        if (binding != null) 'binding': binding!.toJson(),
        'mode': mode.name,
      };

  factory VisualizerProperty.fromJson(Map<String, dynamic> json) {
    return VisualizerProperty(
      baseValue: (json['base'] as num).toDouble(),
      binding: json['binding'] != null
          ? SignalBinding.fromJson(json['binding'] as Map<String, dynamic>)
          : null,
      mode: PropertyBindMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => PropertyBindMode.add,
      ),
    );
  }
}

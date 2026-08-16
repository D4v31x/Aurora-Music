/// Resolves a [VisualizerTemplate] against the latest [AudioFeatureFrame]
/// into a plain, already-computed [VisualizerRenderState] the painter can
/// draw with zero further audio/binding logic — keeping the render path
/// itself trivially cheap per frame.
library;

import '../engine/audio_feature_frame.dart';
import '../model/signal_binding.dart';
import '../model/visualizer_element.dart';
import '../model/visualizer_layer.dart';
import '../model/visualizer_property.dart';
import '../model/visualizer_template.dart';
import 'particle_system_runtime.dart';

class ResolvedElement {
  final VisualizerElement element;
  final Map<PropertyKey, double> resolvedProperties;
  final List<ParticleSnapshot>? particles;
  const ResolvedElement(this.element, this.resolvedProperties, {this.particles});

  double value(PropertyKey key, double fallback) =>
      resolvedProperties[key] ?? fallback;
}

class ResolvedLayer {
  final VisualizerLayer layer;
  final List<ResolvedElement> elements;
  const ResolvedLayer(this.layer, this.elements);
}

class VisualizerRenderState {
  final VisualizerTemplate template;
  final List<ResolvedLayer> layers;
  final AudioFeatureFrame frame;

  const VisualizerRenderState({
    required this.template,
    required this.layers,
    required this.frame,
  });

  static const empty = VisualizerRenderState(
    template: VisualizerTemplate(id: 'empty', name: 'Empty'),
    layers: [],
    frame: AudioFeatureFrame.empty,
  );
}

class VisualizerEngine {
  VisualizerTemplate template;

  /// One [SignalBindingRuntime] per (element id, property) binding site,
  /// so stateful modifiers (smoothing, pulse, oscillation, ...) persist
  /// correctly frame-to-frame. Cleared whenever the template changes.
  final Map<String, SignalBindingRuntime> _runtimeByKey = {};

  /// One [ParticleSystemRuntime] per [ParticlesElement] id.
  final Map<String, ParticleSystemRuntime> _particleRuntimes = {};

  VisualizerEngine(this.template);

  void setTemplate(VisualizerTemplate newTemplate) {
    template = newTemplate;
    _runtimeByKey.clear();
    _particleRuntimes.clear();
  }

  /// Computes render state for [frame] at time-step [dtSeconds] since the
  /// previous call. Pure with respect to its inputs aside from the
  /// per-binding smoothing state described above — safe to call every
  /// frame, allocates only the (small) resolved-value structures needed to
  /// paint this frame.
  VisualizerRenderState computeFrame(AudioFeatureFrame frame, double dtSeconds) {
    final layers = <ResolvedLayer>[];
    for (final layer in template.layers) {
      final elements = <ResolvedElement>[];
      for (final element in layer.elements) {
        final resolved = <PropertyKey, double>{};
        for (final entry in element.properties.entries) {
          final binding = entry.value.binding;
          double? reactiveValue;
          if (binding != null) {
            final runtimeKey = '${element.id}#${entry.key.name}';
            final runtime = _runtimeByKey.putIfAbsent(
              runtimeKey,
              () => SignalBindingRuntime(binding.pipeline.length),
            );
            reactiveValue = runtime.resolve(binding, frame, dtSeconds);
          }
          resolved[entry.key] = entry.value.resolve(reactiveValue);
        }

        List<ParticleSnapshot>? particles;
        if (element is ParticlesElement) {
          final runtime = _particleRuntimes.putIfAbsent(
              element.id, () => ParticleSystemRuntime());
          final targetCount = resolved[PropertyKey.particleCount]
                  ?.round()
                  .clamp(0, element.maxParticles) ??
              element.maxParticles;
          final particleSize = resolved[PropertyKey.particleSize] ?? 4.0;
          final spawnBoost =
              frame.beatPulse ? 1.0 : frame.spectralFlux.clamp(0.0, 1.0) * 0.3;
          particles = runtime.tick(
            dtSeconds: dtSeconds,
            originX: resolved[PropertyKey.positionX] ??
                template.canvas.referenceWidth / 2,
            originY: resolved[PropertyKey.positionY] ??
                template.canvas.referenceHeight / 2,
            targetCount: targetCount,
            particleSize: particleSize,
            spawnBoost: spawnBoost,
          );
        }

        elements.add(ResolvedElement(element, resolved, particles: particles));
      }
      layers.add(ResolvedLayer(layer, elements));
    }
    return VisualizerRenderState(template: template, layers: layers, frame: frame);
  }
}

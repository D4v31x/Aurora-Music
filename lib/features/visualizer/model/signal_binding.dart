/// A [SignalBinding] is a source plus an ordered pipeline of [Modifier]s —
/// the generic "Audio Signal → Normalization → Smoothing → Sensitivity →
/// Response curve → Visualizer property" mapping described by the spec.
/// Binding definitions are pure data (serializable); evaluation state lives
/// in [SignalBindingRuntime], owned by the engine.
library;

import '../engine/audio_feature_frame.dart';
import 'audio_signal_source.dart';
import 'modifiers.dart';

class SignalBinding {
  final AudioSignalSource source;
  final List<Modifier> pipeline;

  const SignalBinding({required this.source, this.pipeline = const []});

  Map<String, dynamic> toJson() => {
        'source': source.toJson(),
        'pipeline': pipeline.map((m) => m.toJson()).toList(),
      };

  factory SignalBinding.fromJson(Map<String, dynamic> json) {
    return SignalBinding(
      source: AudioSignalSource.fromJson(
          json['source'] as Map<String, dynamic>),
      pipeline: (json['pipeline'] as List? ?? const [])
          .map((m) => Modifier.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Per-instance runtime state for one [SignalBinding] evaluation site (one
/// per bound element property) — one [ModifierState] slot per pipeline
/// stage, persisted across frames so stateful modifiers (smooth, pulse,
/// oscillate, ...) work correctly.
class SignalBindingRuntime {
  final List<ModifierState> _stageStates;

  SignalBindingRuntime(int pipelineLength)
      : _stageStates = List.generate(pipelineLength, (_) => ModifierState());

  double resolve(SignalBinding binding, AudioFeatureFrame frame, double dtSeconds) {
    var value = binding.source.read(frame);
    for (var i = 0; i < binding.pipeline.length && i < _stageStates.length; i++) {
      value = binding.pipeline[i].apply(value, _stageStates[i], dtSeconds);
    }
    return value;
  }
}

/// The named sources a [SignalBinding] can read from — the "Audio Signal
/// Bus" as seen by the model layer. Deliberately generic: visualizer
/// elements bind to a source name string, never a hard-coded bass/mid/high
/// property.
library;

import '../engine/audio_feature_frame.dart';

enum AggregateFeature {
  overallEnergy,
  rms,
  spectralFlux,
  beatIntensity,
  beatPulse,
  dropIntensity,
  dropPulse,
  positionSeconds,
}

sealed class AudioSignalSource {
  const AudioSignalSource();

  double read(AudioFeatureFrame frame);

  Map<String, dynamic> toJson();

  static AudioSignalSource fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'frequencyRange':
        return FrequencyRangeSource(json['range'] as String);
      case 'aggregate':
        return AggregateSource(AggregateFeature.values
            .firstWhere((f) => f.name == json['feature']));
      case 'semantic':
        return SemanticSource(json['name'] as String);
      case 'constant':
        return ConstantSource((json['value'] as num).toDouble());
      default:
        return const ConstantSource(0.0);
    }
  }
}

/// Reads a configurable named frequency range's energy (see
/// [FrequencyRange]) — not limited to predefined bass/mid/treble buckets.
class FrequencyRangeSource extends AudioSignalSource {
  final String rangeName;
  const FrequencyRangeSource(this.rangeName);
  @override
  double read(AudioFeatureFrame frame) => frame.frequencyEnergy(rangeName);
  @override
  Map<String, dynamic> toJson() => {'type': 'frequencyRange', 'range': rangeName};
}

/// Reads one of the whole-signal aggregate features (overall energy, RMS,
/// spectral flux, beat intensity/pulse, drop (structural impact)
/// intensity/pulse, or playback position in seconds — the last enabling
/// position-synced, non-audio-reactive time effects).
class AggregateSource extends AudioSignalSource {
  final AggregateFeature feature;
  const AggregateSource(this.feature);
  @override
  double read(AudioFeatureFrame frame) {
    switch (feature) {
      case AggregateFeature.overallEnergy:
        return frame.overallEnergy;
      case AggregateFeature.rms:
        return frame.rms;
      case AggregateFeature.spectralFlux:
        return frame.spectralFlux;
      case AggregateFeature.beatIntensity:
        return frame.beatIntensity;
      case AggregateFeature.beatPulse:
        return frame.beatPulse ? 1.0 : 0.0;
      case AggregateFeature.dropIntensity:
        return frame.dropIntensity;
      case AggregateFeature.dropPulse:
        return frame.dropPulse ? 1.0 : 0.0;
      case AggregateFeature.positionSeconds:
        return frame.position.inMilliseconds / 1000.0;
    }
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'aggregate', 'feature': feature.name};
}

/// Reads a higher-level semantic feature (vocals/drums/bass/melody/...).
/// The visualizer doesn't care whether the value is a real analysis or an
/// explicit fallback proxy — see [SemanticSignal.isFallback].
class SemanticSource extends AudioSignalSource {
  final String name;
  const SemanticSource(this.name);
  @override
  double read(AudioFeatureFrame frame) => frame.semantic(name).value;
  @override
  Map<String, dynamic> toJson() => {'type': 'semantic', 'name': name};
}

/// A fixed value — useful for testing modifier pipelines or elements that
/// want e.g. constant slow rotation unaffected by audio.
class ConstantSource extends AudioSignalSource {
  final double value;
  const ConstantSource(this.value);
  @override
  double read(AudioFeatureFrame frame) => value;
  @override
  Map<String, dynamic> toJson() => {'type': 'constant', 'value': value};
}

/// Higher-level ("semantic") audio feature architecture.
///
/// Only a frequency-proxy fallback is implemented here — genuine on-device
/// neural source separation (vocals/drums/melody) is a substantial follow-up
/// (model size/licensing/latency all need real validation) intentionally
/// **not** bundled in this pass. Every value produced below is explicitly
/// marked `isFallback: true` so the engine/renderer never mistakes a
/// frequency-band proxy for real semantic analysis (spec: "must not be
/// faked"). Swapping in a real provider later requires no changes to the
/// visualizer/signal system — it consumes [SemanticSignal]s the same way
/// regardless of source.
library;

import 'audio_feature_frame.dart';

abstract class SemanticSignalProvider {
  Map<String, SemanticSignal> compute({
    required Map<String, double> frequencyEnergies,
    required double beatIntensity,
    required double overallEnergy,
  });
}

/// Proxies semantic features from ordinary frequency-band energies and the
/// onset detector. Deliberately crude — e.g. "vocals" is really just
/// mid/high-frequency presence, not a detected voice — hence
/// `isFallback: true` everywhere.
class FallbackSemanticProvider implements SemanticSignalProvider {
  const FallbackSemanticProvider();

  static const _source = 'frequency-band-proxy';

  @override
  Map<String, SemanticSignal> compute({
    required Map<String, double> frequencyEnergies,
    required double beatIntensity,
    required double overallEnergy,
  }) {
    double energyOf(List<String> ranges) {
      if (ranges.isEmpty) return 0.0;
      double sum = 0.0;
      var count = 0;
      for (final r in ranges) {
        final v = frequencyEnergies[r];
        if (v != null) {
          sum += v;
          count++;
        }
      }
      return count == 0 ? 0.0 : sum / count;
    }

    final bass = energyOf(const ['20-60', '60-120', '120-250']);
    final vocalsProxy = energyOf(const ['500-1000', '1000-2000', '2000-4000']);
    final melodyProxy = energyOf(const ['250-500', '500-1000', '1000-2000']);

    return {
      'vocals': SemanticSignal(
          value: vocalsProxy.clamp(0.0, 1.0), isFallback: true, source: _source),
      'drums': SemanticSignal(
          value: beatIntensity.clamp(0.0, 1.0), isFallback: true, source: _source),
      'bass': SemanticSignal(
          value: bass.clamp(0.0, 1.0), isFallback: true, source: _source),
      'melody': SemanticSignal(
          value: melodyProxy.clamp(0.0, 1.0), isFallback: true, source: _source),
    };
  }
}

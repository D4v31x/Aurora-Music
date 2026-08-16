/// Real-time, causal onset/beat detector for the visualizer.
///
/// This is intentionally much simpler/cheaper than the offline BPM detector
/// used by AutoMix (see lib/shared/services/automix/bpm_detector.dart) — it
/// only needs to say "something percussive just happened, how strongly",
/// not estimate a precise tempo. It never claims every pulse is a musical
/// downbeat (see spec: "do not assume every onset is a musical downbeat").
library;

import 'dart:collection';
import 'dart:math' as math;

class BeatDetectorResult {
  final double flux;
  final double beatIntensity;
  final bool beatPulse;

  const BeatDetectorResult({
    required this.flux,
    required this.beatIntensity,
    required this.beatPulse,
  });

  static const idle = BeatDetectorResult(flux: 0, beatIntensity: 0, beatPulse: false);
}

class BeatDetector {
  /// How many recent flux samples to use for the adaptive threshold.
  final int historyLength;

  /// How many standard deviations above the rolling mean counts as onset.
  final double sensitivityStdDevs;

  /// Minimum time between pulses so one transient can't fire twice.
  final Duration refractoryPeriod;

  final Queue<double> _history = Queue<double>();
  List<double>? _previousSpectrum;
  DateTime? _lastPulseAt;
  double _smoothedIntensity = 0.0;

  BeatDetector({
    this.historyLength = 64,
    this.sensitivityStdDevs = 1.4,
    this.refractoryPeriod = const Duration(milliseconds: 120),
  });

  /// Feeds one frame's spectrum in and returns the current onset state.
  /// [now] defaults to DateTime.now() but can be supplied for deterministic
  /// tests.
  BeatDetectorResult process(List<double> spectrum, {DateTime? now}) {
    if (spectrum.isEmpty) return BeatDetectorResult.idle;

    final previous = _previousSpectrum;
    double flux = 0.0;
    if (previous != null) {
      final n = math.min(previous.length, spectrum.length);
      for (int i = 0; i < n; i++) {
        final diff = spectrum[i] - previous[i];
        if (diff > 0) flux += diff;
      }
    }
    _previousSpectrum = List<double>.from(spectrum);

    _history.addLast(flux);
    while (_history.length > historyLength) {
      _history.removeFirst();
    }

    if (_history.length < 8) {
      return BeatDetectorResult(flux: flux, beatIntensity: 0, beatPulse: false);
    }

    final mean = _history.reduce((a, b) => a + b) / _history.length;
    double variance = 0.0;
    for (final v in _history) {
      variance += (v - mean) * (v - mean);
    }
    final stdDev = math.sqrt(variance / _history.length);
    final threshold = mean + stdDev * sensitivityStdDevs;

    final timestamp = now ?? DateTime.now();
    final withinRefractory = _lastPulseAt != null &&
        timestamp.difference(_lastPulseAt!) < refractoryPeriod;

    final isOnset = stdDev > 0 && flux > threshold && !withinRefractory;
    if (isOnset) _lastPulseAt = timestamp;

    final normalized =
        stdDev <= 0 ? 0.0 : ((flux - mean) / (stdDev * 3)).clamp(0.0, 1.0);
    // Smooth the continuous intensity so it decays rather than snapping to 0
    // the instant a single frame drops below threshold.
    _smoothedIntensity = normalized > _smoothedIntensity
        ? normalized
        : _smoothedIntensity * 0.85;

    return BeatDetectorResult(
      flux: flux,
      beatIntensity: _smoothedIntensity,
      beatPulse: isOnset,
    );
  }

  void reset() {
    _history.clear();
    _previousSpectrum = null;
    _lastPulseAt = null;
    _smoothedIntensity = 0.0;
  }
}

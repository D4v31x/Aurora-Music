/// Real-time, causal detector for musical "drop"/"impact" moments — the
/// kind of big structural hit (quiet breakdown → sudden full-energy hit)
/// that a drum-and-bass or EDM track uses for its chorus/drop, distinct
/// from an ordinary beat. [BeatDetector] already answers "did a percussive
/// transient just happen"; this answers the much rarer "did the track just
/// structurally *drop*" — requiring a sustained quiet buildup beforehand,
/// not just any loud onset, so it doesn't fire on every kick drum.
///
/// Like [BeatDetector], this is a lightweight causal heuristic operating on
/// live overall-energy readings, not an offline structural analyzer — it
/// can only ever say "energy just surged after a quiet patch", not "this is
/// the chorus" in a musicological sense.
library;

class DropDetectorResult {
  /// Continuous 0.0-1.0 envelope — rises instantly on a drop and decays
  /// slowly afterward, for a lingering "impact" visual response.
  final double dropIntensity;

  /// True only on the frame where a drop was detected.
  final bool dropPulse;

  const DropDetectorResult({required this.dropIntensity, required this.dropPulse});

  static const idle = DropDetectorResult(dropIntensity: 0, dropPulse: false);
}

class DropDetector {
  /// How long a previously-tracked quiet minimum stays "valid" before being
  /// refreshed to the current baseline — keeps the detector responsive to
  /// the track's current section rather than remembering a quiet moment
  /// from minutes ago forever.
  final Duration quietWindow;

  /// The rolling baseline must have dipped to at or below this (0.0-1.0)
  /// energy at some point in [quietWindow] for a subsequent surge to count
  /// as a "drop" rather than just a loud passage getting louder.
  final double quietEnergyThreshold;

  /// Current energy must be at least this many times the tracked quiet
  /// minimum to count as a surge.
  final double surgeRatio;

  /// Absolute floor so near-silence noise can never itself register as a
  /// surge just because the "quiet minimum" it's compared against is tiny.
  final double minSurgeEnergy;

  /// Minimum time between drop pulses — these are meant to be rare,
  /// dramatic moments, not one per bar.
  final Duration refractoryPeriod;

  double _slowAvg = 0.0;
  double _recentQuietMin = 1.0;
  DateTime? _quietMinAt;
  DateTime? _lastPulseAt;
  double _smoothedIntensity = 0.0;
  bool _initialized = false;

  DropDetector({
    this.quietWindow = const Duration(seconds: 6),
    this.quietEnergyThreshold = 0.35,
    this.surgeRatio = 2.2,
    this.minSurgeEnergy = 0.4,
    this.refractoryPeriod = const Duration(milliseconds: 2500),
  });

  /// Feeds one frame's overall energy (0.0-1.0) in and returns the current
  /// drop state. [now] defaults to DateTime.now() but can be supplied for
  /// deterministic tests.
  DropDetectorResult process(double overallEnergy, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();

    if (!_initialized) {
      _slowAvg = overallEnergy;
      _recentQuietMin = overallEnergy;
      _quietMinAt = timestamp;
      _initialized = true;
      return DropDetectorResult.idle;
    }

    // Slow-moving baseline — represents "what energy regime is the track
    // in right now", reacting over several calls rather than instantly.
    const slowAlpha = 0.05;
    _slowAvg += (overallEnergy - _slowAvg) * slowAlpha;

    if (_slowAvg < _recentQuietMin ||
        timestamp.difference(_quietMinAt!) > quietWindow) {
      _recentQuietMin = _slowAvg;
      _quietMinAt = timestamp;
    }

    final withinRefractory =
        _lastPulseAt != null && timestamp.difference(_lastPulseAt!) < refractoryPeriod;
    final hadQuietBuildup = _recentQuietMin <= quietEnergyThreshold;
    final isSurge = overallEnergy >= minSurgeEnergy &&
        overallEnergy >= _recentQuietMin * surgeRatio;
    final isDrop = hadQuietBuildup && isSurge && !withinRefractory;

    // Compute the intensity against the pre-drop baseline before resetting
    // it below — otherwise the very frame that triggers the drop would
    // read back a bogus near-zero intensity.
    final denom = _recentQuietMin * surgeRatio;
    final normalized =
        denom <= 0 ? 0.0 : ((overallEnergy - _recentQuietMin) / denom).clamp(0.0, 1.0);
    _smoothedIntensity =
        normalized > _smoothedIntensity ? normalized : _smoothedIntensity * 0.9;

    if (isDrop) {
      _lastPulseAt = timestamp;
      // Require a fresh quiet buildup before the next drop can fire.
      _recentQuietMin = overallEnergy;
      _quietMinAt = timestamp;
    }

    return DropDetectorResult(dropIntensity: _smoothedIntensity, dropPulse: isDrop);
  }

  void reset() {
    _slowAvg = 0.0;
    _recentQuietMin = 1.0;
    _quietMinAt = null;
    _lastPulseAt = null;
    _smoothedIntensity = 0.0;
    _initialized = false;
  }
}

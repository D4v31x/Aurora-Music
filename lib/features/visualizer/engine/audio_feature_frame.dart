/// The "Audio Feature Bus" — a single immutable snapshot of everything the
/// Visualizer Engine needs to know about the currently playing audio at one
/// instant. Produced by the Audio Analysis Engine (see
/// `visualizer_audio_source.dart`), consumed by [VisualizerEngine].
///
/// Visualizer elements never read audio data directly — they only ever see
/// resolved numeric properties computed from a frame like this one.
library;

/// A single named frequency-energy reading, e.g. "bass" for 20-250Hz.
/// Ranges are configurable — not a fixed bass/mid/treble enum.
class FrequencyRange {
  final String name;
  final double minHz;
  final double maxHz;

  const FrequencyRange(this.name, this.minHz, this.maxHz);

  /// A reasonable general-purpose default set spanning the audible range in
  /// roughly musically-even steps, per the spec's example ranges.
  static const List<FrequencyRange> defaults = [
    FrequencyRange('20-60', 20, 60),
    FrequencyRange('60-120', 60, 120),
    FrequencyRange('120-250', 120, 250),
    FrequencyRange('250-500', 250, 500),
    FrequencyRange('500-1000', 500, 1000),
    FrequencyRange('1000-2000', 1000, 2000),
    FrequencyRange('2000-4000', 2000, 4000),
    FrequencyRange('4000-8000', 4000, 8000),
    FrequencyRange('8000-16000', 8000, 16000),
  ];
}

/// A higher-level ("semantic") audio feature such as vocal or drum activity.
/// [isFallback] is true when this value is a frequency-band/energy proxy
/// rather than genuine source-separated analysis (see semantic_signals.dart)
/// — the visualizer never pretends a proxy is the real thing.
class SemanticSignal {
  final double value; // 0.0-1.0
  final bool isFallback;
  final String source;

  const SemanticSignal({
    required this.value,
    required this.isFallback,
    required this.source,
  });

  static const unavailable =
      SemanticSignal(value: 0.0, isFallback: true, source: 'unavailable');
}

class AudioFeatureFrame {
  /// Raw magnitude spectrum for this frame (arbitrary units, roughly 0-1
  /// after normalization), lowest frequency first. Empty if unavailable.
  final List<double> spectrum;

  /// Raw waveform samples for this frame, roughly -1.0..1.0. Empty if the
  /// platform/session doesn't provide waveform capture.
  final List<double> waveform;

  /// Named frequency-range energies (0.0-1.0), keyed by [FrequencyRange.name].
  final Map<String, double> frequencyEnergies;

  /// Overall loudness/intensity across the whole spectrum, 0.0-1.0.
  final double overallEnergy;

  /// Amplitude/RMS-style estimate derived from the spectrum, 0.0-1.0.
  final double rms;

  /// Frame-to-frame spectral change — high during onsets/transients.
  final double spectralFlux;

  /// Continuous 0.0-1.0 "how strong was the most recent onset" signal.
  final double beatIntensity;

  /// True only on the frame where a new onset/beat was detected.
  final bool beatPulse;

  /// Continuous 0.0-1.0 "how strong was the most recent structural drop/
  /// impact moment" signal — a much rarer, bigger event than [beatPulse]
  /// (see drop_detector.dart), for chorus/drop-style visual hits.
  final double dropIntensity;

  /// True only on the frame where a structural drop was detected.
  final bool dropPulse;

  /// Higher-level features — see [SemanticSignal]. Always present (falls
  /// back to a frequency-proxy rather than being omitted).
  final Map<String, SemanticSignal> semanticSignals;

  /// True if this frame carries real analyzed data. False means "no audio
  /// data available right now" (e.g. permission denied, no active session)
  /// — the engine/renderer must keep functioning, just with idle output.
  final bool hasData;

  /// Playback position this frame corresponds to — the source of truth for
  /// time-based visual state, never raw frame/tick count.
  final Duration position;

  const AudioFeatureFrame({
    this.spectrum = const [],
    this.waveform = const [],
    this.frequencyEnergies = const {},
    this.overallEnergy = 0.0,
    this.rms = 0.0,
    this.spectralFlux = 0.0,
    this.beatIntensity = 0.0,
    this.beatPulse = false,
    this.dropIntensity = 0.0,
    this.dropPulse = false,
    this.semanticSignals = const {},
    this.hasData = false,
    this.position = Duration.zero,
  });

  static const empty = AudioFeatureFrame();

  double frequencyEnergy(String name) => frequencyEnergies[name] ?? 0.0;

  SemanticSignal semantic(String name) =>
      semanticSignals[name] ?? SemanticSignal.unavailable;
}

/// The "Audio Analysis Engine" box from the architecture diagram — bridges
/// the native Android Visualizer EventChannel (FFT + waveform capture) to a
/// continuously-updated [AudioFeatureFrame], attaching current playback
/// position from [AudioPlayerService] as the timing source of truth.
///
/// Visualizer elements never touch this class directly — only
/// [VisualizerEngine] reads [frameNotifier].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../shared/services/audio_player_service.dart';
import 'audio_feature_frame.dart';
import 'beat_detector.dart';
import 'drop_detector.dart';
import 'frequency_analyzer.dart';
import 'semantic_signals.dart';
import 'waveform_analyzer.dart';

class VisualizerAudioSource {
  final AudioPlayerService audioService;
  final FrequencyAnalyzer _frequencyAnalyzer;
  final BeatDetector _beatDetector;
  final DropDetector _dropDetector;
  final SemanticSignalProvider _semanticProvider;

  static const EventChannel _kChannel = EventChannel('aurora/visualizer');
  static const int _kFftPrefix = 0x01;
  static const int _kWaveformPrefix = 0x02;

  StreamSubscription<dynamic>? _sessionIdSub;
  StreamSubscription<dynamic>? _dataSub;
  List<double> _lastWaveform = const [];
  bool _attached = false;

  final ValueNotifier<AudioFeatureFrame> frameNotifier =
      ValueNotifier(AudioFeatureFrame.empty);

  VisualizerAudioSource(
    this.audioService, {
    FrequencyAnalyzerConfig config = const FrequencyAnalyzerConfig(),
    BeatDetector? beatDetector,
    DropDetector? dropDetector,
    SemanticSignalProvider semanticProvider = const FallbackSemanticProvider(),
  })  : _frequencyAnalyzer = FrequencyAnalyzer(config),
        _beatDetector = beatDetector ?? BeatDetector(),
        _dropDetector = dropDetector ?? DropDetector(),
        _semanticProvider = semanticProvider;

  /// Starts listening for the current Android audio session and attaching
  /// the native Visualizer once one is available. Safe to call multiple
  /// times. Does not itself request any permissions — that's a UI concern.
  void start() {
    if (_attached) return;
    _attached = true;
    _sessionIdSub =
        audioService.audioPlayer.androidAudioSessionIdStream.listen(
      (sessionId) {
        if (sessionId != null && sessionId > 0) _attachSession(sessionId);
      },
      onError: (_) {},
    );
  }

  void _attachSession(int sessionId) {
    _dataSub?.cancel();
    _dataSub = _kChannel.receiveBroadcastStream(sessionId).listen(
      _onData,
      onError: (_) {
        // No data available (e.g. permission denied, unsupported device) —
        // fall back to an empty/idle frame rather than throwing.
        frameNotifier.value = AudioFeatureFrame.empty;
      },
    );
  }

  void _onData(dynamic data) {
    if (data is! Uint8List || data.isEmpty) return;
    final position = audioService.audioPlayer.position;

    if (data[0] == _kFftPrefix) {
      final result = _frequencyAnalyzer.analyzeFftPacket(data);
      final beat = _beatDetector.process(result.spectrum);
      final drop = _dropDetector.process(result.overallEnergy, now: DateTime.now());
      final semantics = _semanticProvider.compute(
        frequencyEnergies: result.frequencyEnergies,
        beatIntensity: beat.beatIntensity,
        overallEnergy: result.overallEnergy,
      );
      frameNotifier.value = AudioFeatureFrame(
        spectrum: result.spectrum,
        waveform: _lastWaveform,
        frequencyEnergies: result.frequencyEnergies,
        overallEnergy: result.overallEnergy,
        rms: result.rms,
        spectralFlux: beat.flux,
        beatIntensity: beat.beatIntensity,
        beatPulse: beat.beatPulse,
        dropIntensity: drop.dropIntensity,
        dropPulse: drop.dropPulse,
        semanticSignals: semantics,
        hasData: true,
        position: position,
      );
    } else if (data[0] == _kWaveformPrefix) {
      _lastWaveform = parseWaveformPacket(data);
      final current = frameNotifier.value;
      frameNotifier.value = AudioFeatureFrame(
        spectrum: current.spectrum,
        waveform: _lastWaveform,
        frequencyEnergies: current.frequencyEnergies,
        overallEnergy: current.overallEnergy,
        rms: current.rms,
        spectralFlux: current.spectralFlux,
        beatIntensity: current.beatIntensity,
        dropIntensity: current.dropIntensity,
        semanticSignals: current.semanticSignals,
        hasData: current.hasData,
        position: position,
      );
    }
  }

  void stop() {
    _attached = false;
    _dataSub?.cancel();
    _dataSub = null;
    _sessionIdSub?.cancel();
    _sessionIdSub = null;
    _beatDetector.reset();
    _dropDetector.reset();
    frameNotifier.value = AudioFeatureFrame.empty;
  }

  void dispose() {
    stop();
    frameNotifier.dispose();
  }
}

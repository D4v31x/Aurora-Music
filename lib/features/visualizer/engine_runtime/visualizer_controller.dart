/// Glue layer: `Flutter UI → VisualizerController → VisualizerEngine →
/// Renderer` (spec section 15). Owns the audio source + engine, drives a
/// [Ticker] independent of the rest of the app's widget rebuilds, and
/// exposes only a [ValueNotifier] of already-resolved [VisualizerRenderState]
/// for the painter to consume — the renderer never touches audio data or
/// bindings directly.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/services/audio_player_service.dart';
import '../engine/audio_feature_frame.dart';
import '../engine/visualizer_audio_source.dart';
import '../model/visualizer_element.dart';
import '../model/visualizer_template.dart';
import '../render/image_element_resolver.dart';
import 'visualizer_engine.dart';

class VisualizerController {
  final AudioPlayerService audioService;
  final TickerProvider vsync;
  final VisualizerAudioSource audioSource;
  final VisualizerEngine engine;
  final ImageElementResolver imageResolver;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  final ValueNotifier<VisualizerRenderState> renderStateNotifier =
      ValueNotifier(VisualizerRenderState.empty);

  VisualizerController({
    required this.audioService,
    required this.vsync,
    required VisualizerTemplate initialTemplate,
  })  : audioSource = VisualizerAudioSource(audioService),
        engine = VisualizerEngine(initialTemplate),
        imageResolver = ImageElementResolver(audioService) {
    _resolveImages(initialTemplate);
  }

  VisualizerTemplate get template => engine.template;

  void setTemplate(VisualizerTemplate newTemplate) {
    engine.setTemplate(newTemplate);
    _resolveImages(newTemplate);
  }

  void _resolveImages(VisualizerTemplate t) {
    final images = <ImageElement>[
      for (final layer in t.layers)
        for (final element in layer.elements)
          if (element is ImageElement) element,
    ];
    imageResolver.resolveAll(images);
  }

  void start() {
    audioSource.start();
    _lastElapsed = Duration.zero;
    (_ticker ??= vsync.createTicker(_onTick)).start();
  }

  void stop() {
    _ticker?.stop();
  }

  void _onTick(Duration elapsed) {
    final dtSeconds =
        ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(0.0, 0.1);
    _lastElapsed = elapsed;

    // Playback position — not frame count — is the timing source of truth
    // (spec section 16). Refresh it every tick even if no new FFT packet
    // has arrived since the last one.
    final latest = audioSource.frameNotifier.value;
    final position = audioService.audioPlayer.position;
    final frame = latest.position == position
        ? latest
        : AudioFeatureFrame(
            spectrum: latest.spectrum,
            waveform: latest.waveform,
            frequencyEnergies: latest.frequencyEnergies,
            overallEnergy: latest.overallEnergy,
            rms: latest.rms,
            spectralFlux: latest.spectralFlux,
            beatIntensity: latest.beatIntensity,
            dropIntensity: latest.dropIntensity,
            // A pulse is a one-frame event tied to real new data — don't
            // let it "repeat" across extra ticks with no new packet.
            semanticSignals: latest.semanticSignals,
            hasData: latest.hasData,
            position: position,
          );

    renderStateNotifier.value = engine.computeFrame(frame, dtSeconds);
  }

  void dispose() {
    _ticker?.dispose();
    audioSource.dispose();
    imageResolver.dispose();
    renderStateNotifier.dispose();
  }
}

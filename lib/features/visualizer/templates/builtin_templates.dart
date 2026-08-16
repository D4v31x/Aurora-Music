/// The 7 built-in templates required by spec section 12 — each deliberately
/// demonstrates a *different* audio signal/element combination rather than
/// all behaving like plain spectrum bars — plus one additional template
/// ('Impact Drop') built on top of the drop/beat pulse signals for a
/// dramatic, UKF-style hit-driven experience. These are Aurora's own
/// designs, not a reproduction of any third-party visualizer's presets.
library;

import 'dart:ui' show Color;

import '../model/audio_signal_source.dart';
import '../model/modifiers.dart';
import '../model/signal_binding.dart';
import '../model/visualizer_element.dart';
import '../model/visualizer_layer.dart';
import '../model/visualizer_property.dart';
import '../model/visualizer_template.dart';

SignalBinding _bind(AudioSignalSource source, List<Modifier> pipeline) =>
    SignalBinding(source: source, pipeline: pipeline);

VisualizerProperty _reactive(
  double base,
  AudioSignalSource source, {
  List<Modifier> pipeline = const [],
  PropertyBindMode mode = PropertyBindMode.add,
}) =>
    VisualizerProperty(
      baseValue: base,
      binding: _bind(source, pipeline),
      mode: mode,
    );

const _bass = FrequencyRangeSource('20-60');
const _overall = AggregateSource(AggregateFeature.overallEnergy);
const _flux = AggregateSource(AggregateFeature.spectralFlux);
const _beat = AggregateSource(AggregateFeature.beatIntensity);
const _beatPulse = AggregateSource(AggregateFeature.beatPulse);
const _dropIntensity = AggregateSource(AggregateFeature.dropIntensity);
const _dropPulse = AggregateSource(AggregateFeature.dropPulse);

class BuiltinTemplates {
  BuiltinTemplates._();

  static List<VisualizerTemplate> get all => [
        classicSpectrum,
        radialSpectrum,
        waveform,
        particleField,
        albumArtReactive,
        bassReactive,
        cinematic,
        impactDrop,
      ];

  /// 1. Classic spectrum — plain vertical bars, sensitivity gently boosted
  /// by overall energy so louder passages read a bit taller across the board.
  static VisualizerTemplate get classicSpectrum => VisualizerTemplate(
        id: 'classic_spectrum',
        name: 'Classic Spectrum',
        description: 'Vertical spectrum bars across the bottom.',
        layers: [
          VisualizerLayer(name: 'Spectrum', elements: [
            SpectrumBarsElement(
              id: 'bars',
              barCount: 40,
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(650),
                PropertyKey.width: VisualizerProperty.static(360),
                PropertyKey.height: VisualizerProperty.static(260),
                PropertyKey.spectrumSensitivity: _reactive(
                  1.0,
                  _overall,
                  pipeline: const [SmoothModifier(0.4), MultiplyModifier(0.6)],
                ),
              },
            ),
          ]),
        ],
      );

  /// 2. Circular/radial spectrum — bars radiate from a slowly-rotating ring.
  static VisualizerTemplate get radialSpectrum => VisualizerTemplate(
        id: 'radial_spectrum',
        name: 'Radial Spectrum',
        description: 'Spectrum bars radiating from a rotating ring.',
        layers: [
          VisualizerLayer(name: 'Radial', elements: [
            RadialSpectrumElement(
              id: 'radial',
              barCount: 56,
              color: const Color(0xFF7FE7FF),
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(140),
                PropertyKey.height: VisualizerProperty.static(120),
                PropertyKey.strokeWidth: VisualizerProperty.static(3),
                PropertyKey.rotation: _reactive(
                  0.0,
                  const ConstantSource(1.0),
                  pipeline: const [RotationModifier(0.03)],
                  mode: PropertyBindMode.replace,
                ),
                PropertyKey.spectrumSensitivity: VisualizerProperty.static(1.1),
              },
            ),
          ]),
        ],
      );

  /// 3. Waveform — the raw playback waveform trace, thickened by loudness.
  static VisualizerTemplate get waveform => VisualizerTemplate(
        id: 'waveform',
        name: 'Waveform',
        description: 'Live waveform trace across the middle of the screen.',
        layers: [
          VisualizerLayer(name: 'Waveform', elements: [
            WaveformElement(
              id: 'wave',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(360),
                PropertyKey.height: VisualizerProperty.static(200),
                PropertyKey.strokeWidth: VisualizerProperty.static(2.5),
                PropertyKey.waveformAmplitude: _reactive(
                  1.0,
                  _overall,
                  pipeline: const [SmoothModifier(0.3), MultiplyModifier(0.5)],
                ),
              },
            ),
          ]),
        ],
      );

  /// 4. Particle field — particle count/size driven by spectral flux and
  /// beat intensity rather than a fixed spectrum bucket.
  static VisualizerTemplate get particleField => VisualizerTemplate(
        id: 'particle_field',
        name: 'Particle Field',
        description: 'A field of particles that bursts on transients.',
        layers: [
          VisualizerLayer(name: 'Particles', elements: [
            ParticlesElement(
              id: 'particles',
              maxParticles: 120,
              color: const Color(0xFFFF8FD9),
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.particleCount: _reactive(
                  20,
                  _flux,
                  pipeline: const [ClampModifier(0, 1), MultiplyModifier(90)],
                ),
                PropertyKey.particleSize: _reactive(
                  4,
                  _beat,
                  pipeline: const [MultiplyModifier(8)],
                ),
              },
            ),
          ]),
        ],
      );

  /// 5. Album-art reactive — the currently-playing artwork gently pulses
  /// with bass and rotates slowly, faster during beats.
  static VisualizerTemplate get albumArtReactive => VisualizerTemplate(
        id: 'album_art_reactive',
        name: 'Album Art',
        description: 'Current album art pulses with the beat.',
        layers: [
          VisualizerLayer(name: 'Glow', elements: [
            CircleElement(
              id: 'glow',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: _reactive(
                  260,
                  _overall,
                  pipeline: const [SmoothModifier(0.6), MultiplyModifier(60)],
                ),
                PropertyKey.opacity: VisualizerProperty.static(0.18),
                PropertyKey.blurAmount: VisualizerProperty.static(40),
              },
            ),
          ]),
          VisualizerLayer(name: 'Artwork', elements: [
            ImageElement(
              id: 'artwork',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(220),
                PropertyKey.height: VisualizerProperty.static(220),
                PropertyKey.cornerRadius: VisualizerProperty.static(24),
                PropertyKey.scale: _reactive(
                  1.0,
                  _bass,
                  pipeline: const [SmoothModifier(0.35), MultiplyModifier(0.15)],
                ),
                PropertyKey.rotation: _reactive(
                  0.0,
                  _beat,
                  pipeline: const [RotationModifier(0.02)],
                  mode: PropertyBindMode.replace,
                ),
              },
            ),
          ]),
        ],
      );

  /// 6. Bass-reactive — a single large pulsing glow, purely bass-driven.
  static VisualizerTemplate get bassReactive => VisualizerTemplate(
        id: 'bass_reactive',
        name: 'Bass Pulse',
        description: 'A single glow that pulses purely with bass.',
        layers: [
          VisualizerLayer(name: 'Pulse', elements: [
            CircleElement(
              id: 'pulse',
              color: const Color(0xFFB388FF),
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(220),
                PropertyKey.scale: _reactive(
                  1.0,
                  _bass,
                  pipeline: const [
                    SmoothModifier(0.25),
                    PowerModifier(1.4),
                    MultiplyModifier(0.5),
                  ],
                ),
                PropertyKey.opacity: _reactive(
                  0.55,
                  _bass,
                  pipeline: const [SmoothModifier(0.25), MultiplyModifier(0.4)],
                ),
                PropertyKey.blurAmount: VisualizerProperty.static(30),
              },
            ),
          ]),
        ],
      );

  /// 7. Multi-layer cinematic — combines blurred background art, a glow,
  /// radial spectrum, particles and a foreground label to demonstrate real
  /// layering (spec section 10's own example layer stack).
  static VisualizerTemplate get cinematic => VisualizerTemplate(
        id: 'cinematic',
        name: 'Cinematic',
        description: 'Layered background art, glow, spectrum and particles.',
        layers: [
          VisualizerLayer(name: 'Background', elements: [
            ImageElement(
              id: 'bg_artwork',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(500),
                PropertyKey.height: VisualizerProperty.static(900),
                PropertyKey.blurAmount: VisualizerProperty.static(50),
                PropertyKey.opacity: VisualizerProperty.static(0.55),
              },
            ),
          ]),
          VisualizerLayer(name: 'Glow', elements: [
            CircleElement(
              id: 'cine_glow',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: _reactive(
                  200,
                  _overall,
                  pipeline: const [SmoothModifier(0.5), MultiplyModifier(120)],
                ),
                PropertyKey.opacity: VisualizerProperty.static(0.15),
                PropertyKey.blurAmount: VisualizerProperty.static(60),
              },
            ),
          ]),
          VisualizerLayer(name: 'Spectrum', elements: [
            RadialSpectrumElement(
              id: 'cine_radial',
              barCount: 64,
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(240),
                PropertyKey.height: VisualizerProperty.static(90),
                PropertyKey.strokeWidth: VisualizerProperty.static(2),
                PropertyKey.opacity: VisualizerProperty.static(0.8),
              },
            ),
          ]),
          VisualizerLayer(name: 'Particles', elements: [
            ParticlesElement(
              id: 'cine_particles',
              maxParticles: 60,
              color: const Color(0xFFFFE082),
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.particleCount: _reactive(
                  10,
                  _flux,
                  pipeline: const [ClampModifier(0, 1), MultiplyModifier(40)],
                ),
                PropertyKey.particleSize: VisualizerProperty.static(3),
                PropertyKey.opacity: VisualizerProperty.static(0.7),
              },
            ),
          ]),
          VisualizerLayer(name: 'Foreground', elements: [
            TextElement(
              id: 'label',
              text: 'AURORA MUSIC',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(750),
                PropertyKey.height: VisualizerProperty.static(16),
                PropertyKey.opacity: _reactive(
                  0.5,
                  _overall,
                  pipeline: const [SmoothModifier(0.6), MultiplyModifier(0.4)],
                ),
              },
            ),
          ]),
        ],
      );

  /// 8. Impact Drop — reacts hard to *exact* moments: a particle burst and
  /// artwork punch on every drum hit ([AggregateFeature.beatPulse]), plus a
  /// full-screen flash and expanding shockwave ring specifically on
  /// detected structural drops ([AggregateFeature.dropPulse]/
  /// [AggregateFeature.dropIntensity]) — the "chorus/drop hits hard" look.
  static VisualizerTemplate get impactDrop => VisualizerTemplate(
        id: 'impact_drop',
        name: 'Impact Drop',
        description: 'Punches on every beat, flashes hard on the drop.',
        layers: [
          VisualizerLayer(name: 'Background', elements: [
            ImageElement(
              id: 'impact_bg',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(500),
                PropertyKey.height: VisualizerProperty.static(900),
                PropertyKey.blurAmount: VisualizerProperty.static(45),
                PropertyKey.opacity: VisualizerProperty.static(0.5),
                PropertyKey.scale: _reactive(
                  1.0,
                  _bass,
                  pipeline: const [SmoothModifier(0.4), MultiplyModifier(0.08)],
                ),
              },
            ),
          ]),
          // Expands outward and fades on every detected drop — a
          // shockwave ring rather than a continuous pulse.
          VisualizerLayer(name: 'Shockwave', elements: [
            CircleElement(
              id: 'impact_shockwave',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: _reactive(
                  120,
                  _dropIntensity,
                  pipeline: const [PulseModifier(1.6), MultiplyModifier(260)],
                ),
                PropertyKey.strokeWidth: VisualizerProperty.static(4),
                PropertyKey.opacity: _reactive(
                  0.0,
                  _dropIntensity,
                  pipeline: const [PulseModifier(1.6), MultiplyModifier(0.8)],
                ),
              },
            ),
          ]),
          // Artwork punches (scale) on every beat, on top of the shockwave.
          VisualizerLayer(name: 'Artwork', elements: [
            ImageElement(
              id: 'impact_artwork',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(220),
                PropertyKey.height: VisualizerProperty.static(220),
                PropertyKey.cornerRadius: VisualizerProperty.static(24),
                PropertyKey.scale: _reactive(
                  1.0,
                  _beat,
                  pipeline: const [PulseModifier(0.25), MultiplyModifier(0.18)],
                ),
              },
            ),
          ]),
          // Bursts of particles on every drum hit, not just drops.
          VisualizerLayer(name: 'Particles', elements: [
            ParticlesElement(
              id: 'impact_particles',
              maxParticles: 140,
              color: const Color(0xFFFFD54F),
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.particleCount: _reactive(
                  10,
                  _beatPulse,
                  pipeline: const [PulseModifier(0.5), MultiplyModifier(110)],
                ),
                PropertyKey.particleSize: _reactive(
                  4,
                  _beat,
                  pipeline: const [MultiplyModifier(6)],
                ),
              },
            ),
          ]),
          // A full-screen flash exactly on the drop, nothing else.
          VisualizerLayer(name: 'Flash', elements: [
            RectangleElement(
              id: 'impact_flash',
              properties: {
                PropertyKey.positionX: VisualizerProperty.static(200),
                PropertyKey.positionY: VisualizerProperty.static(400),
                PropertyKey.width: VisualizerProperty.static(500),
                PropertyKey.height: VisualizerProperty.static(900),
                PropertyKey.opacity: _reactive(
                  0.0,
                  _dropPulse,
                  pipeline: const [PulseModifier(0.6), MultiplyModifier(0.65)],
                ),
              },
            ),
          ]),
        ],
      );
}

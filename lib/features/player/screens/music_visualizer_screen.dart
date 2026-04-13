/// Full-screen music visualiser with real-time FFT reactivity.
///
/// On Android, taps the ExoPlayer audio session via the
/// [android.media.audiofx.Visualizer] API (native EventChannel
/// "aurora/visualizer") to drive bars and particles with actual frequency data.
/// Falls back to multi-sine simulation when the native Visualizer is
/// unavailable.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/background_manager_service.dart';
import '../../../shared/services/artist_separator_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Particle model ────────────────────────────────────────────────────────────

class _Particle {
  double angle;
  double radius;
  final double speed;
  final double size;
  double alpha;
  final double alphaDecay;
  final Color  color; // tinted from artwork palette

  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.alpha,
    required this.alphaDecay,
    required this.color,
  });

  /// Spawns a new particle.
  ///
  /// [paletteColors] is the full artwork palette (dominant, vibrant …).
  /// The spawn color is randomly picked from the palette and blended with
  /// white so it stays luminous against the dark background.
  factory _Particle.spawn(
    Random rng,
    double birthRadius,
    List<Color> paletteColors,
  ) {
    final List<Color> pool =
        paletteColors.isNotEmpty ? paletteColors : [Colors.white];
    final Color base = pool[rng.nextInt(pool.length)];
    // Blend toward white (0.3–0.6) so dim palette colours stay visible
    final Color tinted =
        Color.lerp(base, Colors.white, 0.30 + rng.nextDouble() * 0.30)!;

    return _Particle(
      angle:      rng.nextDouble() * 2 * pi,
      radius:     birthRadius,
      speed:      0.5 + rng.nextDouble() * 1.5,
      size:       1.5 + rng.nextDouble() * 3.0,
      alpha:      0.6 + rng.nextDouble() * 0.4,
      alphaDecay: 0.005 + rng.nextDouble() * 0.007,
      color:      tinted,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-screen animated music visualiser.
///
/// Visual elements:
/// - Ambient radial gradient tinted by dominant artwork colour (pulses with bass).
/// - 90 radial bars driven by real FFT data (or sine waves as fallback).
/// - Slowly rotating circular artwork disc; glow expands on bass transients.
/// - Two expanding / fading pulse rings that throb with low frequencies.
/// - ~55 particles drifting outward; speed and spawn-radius scale with energy.
/// - Song title + artist name at the bottom.
class MusicVisualizerScreen extends StatefulWidget {
  const MusicVisualizerScreen({super.key});

  @override
  State<MusicVisualizerScreen> createState() => _MusicVisualizerScreenState();
}

class _MusicVisualizerScreenState extends State<MusicVisualizerScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int    _kNumBars         = 90;
  /// Maximum number of particles alive at once.
  static const int    _kMaxParticles    = 80;
  /// Minimum active particles even during silence.
  static const int    _kMinParticles    = 15;
  static const double _kArtworkR        = 105.0;

  // Fallback sine-wave parameters (used when real FFT is unavailable)
  static const _kFreqs = [0.55, 0.90, 1.40, 2.10, 3.00];
  static const _kAmps  = [0.30, 0.25, 0.20, 0.15, 0.10];

  // Native EventChannel that streams Android Visualizer FFT bytes
  static const _kFftChannel = EventChannel('aurora/visualizer');

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _mainCtrl;    // ~60fps tick for bars/particles
  late final AnimationController _pulseCtrl;   // 1800ms breathe for rings + bg
  late final AnimationController _spinCtrl;    // 24s artwork disc rotation

  // ── FFT / energy state ─────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _sessionIdSub;
  StreamSubscription<dynamic>? _fftSub;

  late final List<double> _barHeights;   // smoothed amplitudes [0..1] per bar
  late final List<int>    _barBinStart;  // first FFT bin for each bar
  late final List<int>    _barBinEnd;    // exclusive last bin for each bar

  double _bassEnergy    = 0.0;  // low-frequency energy [0..1]
  double _overallEnergy = 0.0;  // total energy [0..1]
  bool   _hasRealData   = false;

  // ── Simulation state (fallback) ────────────────────────────────────────────
  final _rng = Random();
  late final List<_Particle> _particles; // always _kMaxParticles slots
  late final List<double>    _barPhases;
  int _activeParticles = _kMinParticles; // how many slots are actually updated

  double _time          = 0.0;
  double _lastCtrlValue = 0.0;

  // ── Audio / artwork ────────────────────────────────────────────────────────
  late final AudioPlayerService _audio;
  ImageProvider? _artwork;
  List<Color> _paletteColors = [];
  int _lastSongId = -1;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioPlayerService>();

    // Fallback simulation setup
    _barPhases = List.generate(_kNumBars, (_) => _rng.nextDouble() * 2 * pi);
    // Pre-allocate all slots; only _activeParticles are updated each frame.
    _particles = List.generate(_kMaxParticles, (i) {
      final p = _Particle.spawn(_rng, _kArtworkR + 12, []);
      if (i < _kMinParticles) {
        p.radius += _rng.nextDouble() * 140; // stagger initial positions
        p.alpha   = _rng.nextDouble();
      } else {
        p.alpha = 0; // dormant until energy wakes them
      }
      return p;
    });

    // FFT setup
    _initFftBinRanges();
    _barHeights = List.filled(_kNumBars, 0.0);
    _subscribeToSessionId();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _mainCtrl.addListener(_onTick);
    _loadArtwork();
  }

  /// Precompute logarithmic FFT bin ranges for [_kNumBars] bars.
  ///
  /// Covers bins 1–256 ≈ 43 Hz–11 kHz at 44100/1024 Hz resolution.
  void _initFftBinRanges() {
    const int firstBin = 1;
    const int lastBin  = 256;
    _barBinStart = List.filled(_kNumBars, 0);
    _barBinEnd   = List.filled(_kNumBars, 1);
    for (int i = 0; i < _kNumBars; i++) {
      final double t0 = i / _kNumBars;
      final double t1 = (i + 1) / _kNumBars;
      final int s = (firstBin * pow(lastBin / firstBin, t0)).round()
          .clamp(firstBin, lastBin);
      final int e = (firstBin * pow(lastBin / firstBin, t1)).round()
          .clamp(s + 1, lastBin + 1);
      _barBinStart[i] = s;
      _barBinEnd[i]   = e;
    }
  }

  /// Listen on the just_audio session ID stream and re-attach the native
  /// Visualizer whenever the session changes.
  ///
  /// Requests [Permission.microphone] first — Android's Visualizer API
  /// requires RECORD_AUDIO even for your own audio session.
  Future<void> _subscribeToSessionId() async {
    try {
      await Permission.microphone.request();
    } catch (_) {}

    _sessionIdSub = _audio.audioPlayer.androidAudioSessionIdStream.listen(
      (sessionId) {
        if (sessionId != null && sessionId > 0) {
          _attachVisualizer(sessionId);
        }
      },
      onError: (_) { /* not Android or unsupported — sine fallback */ },
    );
  }

  /// Subscribe to the native FFT event stream for [sessionId].
  void _attachVisualizer(int sessionId) {
    _fftSub?.cancel();
    _fftSub = _kFftChannel.receiveBroadcastStream(sessionId).listen(
      (data) {
        if (data is Uint8List) _processFft(data);
      },
      onError: (_) { _hasRealData = false; },
    );
  }

  /// Decode one FFT frame and update [_barHeights], [_bassEnergy],
  /// [_overallEnergy].
  void _processFft(Uint8List fft) {
    if (!mounted) return;
    final ByteData bd     = fft.buffer.asByteData();
    final int      maxBin = (fft.length ~/ 2) - 1;
    double totalEnergy = 0.0;

    for (int i = 0; i < _kNumBars; i++) {
      final int binStart = _barBinStart[i].clamp(1, maxBin);
      final int binEnd   = _barBinEnd[i].clamp(binStart + 1, maxBin + 1);

      double sum = 0.0;
      int count = 0;
      for (int b = binStart; b < binEnd; b++) {
        final int idx = b * 2;
        if (idx + 1 >= fft.length) break;
        final double real = bd.getInt8(idx).toDouble();
        final double imag = bd.getInt8(idx + 1).toDouble();
        sum += sqrt(real * real + imag * imag);
        count++;
      }

      // Normalise to ~0..1 (max FFT magnitude ≈ 90 for signed bytes)
      final double raw = count > 0 ? (sum / count) / 90.0 : 0.0;
      // Asymmetric smoothing: fast attack on transients, slow decay
      final double alpha = raw > _barHeights[i] ? 0.5 : 0.18;
      _barHeights[i] = (_barHeights[i] * (1 - alpha) +
              raw.clamp(0.0, 1.5) * alpha)
          .clamp(0.0, 1.0);
      totalEnergy += _barHeights[i];
    }

    // Bass = average of first four bars — fast attack for punchy drum hits
    final double bassRaw =
        (_barHeights[0] + _barHeights[1] + _barHeights[2] + _barHeights[3]) / 4.0;
    _bassEnergy    = (_bassEnergy * 0.40 + bassRaw * 0.60).clamp(0.0, 1.0);
    _overallEnergy = (_overallEnergy * 0.70 +
            (totalEnergy / _kNumBars) * 0.30)
        .clamp(0.0, 1.0);
    _hasRealData = true;
  }

  // Runs ~60 fps. Advances simulation time and updates particles.
  void _onTick() {
    if (!mounted) return;

    double delta = _mainCtrl.value - _lastCtrlValue;
    if (delta < -0.5) delta += 1.0; // handle 1→0 loop wrap
    _lastCtrlValue = _mainCtrl.value;

    if (_audio.isPlaying) _time += delta;

    // ── Fallback sine-wave bar heights ──────────────────────────────────────
    if (!_hasRealData && _audio.isPlaying) {
      for (int i = 0; i < _kNumBars; i++) {
        double h = 0.0;
        for (int j = 0; j < _kFreqs.length; j++) {
          h += _kAmps[j] *
              sin(_time * _kFreqs[j] * 2 * pi + _barPhases[i] + j * 0.7);
        }
        h = (h + 1.0) / 2.0;
        _barHeights[i] = h * h; // power curve for contrast
      }
      _bassEnergy    = (_barHeights[0] + _barHeights[1]) / 2.0;
      _overallEnergy = 0.4;
    }

    // ── Particle update ─────────────────────────────────────────────────────
    // Active count scales linearly with energy: quiet → few, loud → many.
    _activeParticles = (_kMinParticles +
            (_overallEnergy * (_kMaxParticles - _kMinParticles)).round())
        .clamp(_kMinParticles, _kMaxParticles);

    // Speed multiplier: 1× at silence, up to 4× at peak energy.
    final double speedMult = 1.0 + _overallEnergy * 3.0;
    // Alpha decay faster at high energy (particles live shorter, more pop).
    final double decayMult = 1.0 + _overallEnergy * 1.2;
    // Spawn ring widens on bass hits.
    final double birthR    = _kArtworkR + 12 + _bassEnergy * 28;
    final double maxR      = MediaQuery.sizeOf(context).shortestSide * 0.72;

    for (int i = 0; i < _activeParticles; i++) {
      final p = _particles[i];
      if (_audio.isPlaying) {
        p.radius += p.speed * speedMult;
        p.alpha  -= p.alphaDecay * decayMult;
      }
      if (p.alpha <= 0 || p.radius > maxR) {
        _particles[i] = _Particle.spawn(_rng, birthR, _paletteColors);
      }
    }
    // Dormant slots: keep alpha at 0 so they're invisible
    for (int i = _activeParticles; i < _kMaxParticles; i++) {
      _particles[i].alpha = 0;
    }
  }

  Future<void> _loadArtwork() async {
    final song = _audio.currentSong;
    if (song == null) return;
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;
    try {
      final p = await ArtworkCacheService()
          .getCachedImageProvider(song.id, highQuality: true);
      if (mounted) setState(() => _artwork = p);
    } catch (_) {}
    // Palette colours come from BackgroundManagerService (already computed)
    // so no extra work needed here — _paletteColors is refreshed in build().
  }

  @override
  void dispose() {
    _mainCtrl
      ..removeListener(_onTick)
      ..dispose();
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    _fftSub?.cancel();
    _sessionIdSub?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg       = context.watch<BackgroundManagerService>();
    final colors   = bg.currentColors;
    final dominant = colors.isNotEmpty  ? colors[0] : const Color(0xFF6200EE);
    final vibrant  = colors.length > 1  ? colors[1] : dominant;    // Keep the palette cache up to date for particle spawning.
    _paletteColors = colors.isNotEmpty ? colors : [dominant, vibrant];    final song     = _audio.currentSong;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Ambient background gradient — pulses with bass ───────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final glow = _pulseCtrl.value * 0.14 + _bassEnergy * 0.14;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.3,
                    colors: [
                      dominant.withValues(
                          alpha: (0.10 + glow).clamp(0.0, 0.42)),
                      Colors.black,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // ── Spectrum bars + particles ────────────────────────────────────
          AnimatedBuilder(
            animation: _mainCtrl,
            builder: (_, __) => CustomPaint(
              painter: _VisualizerPainter(
                barHeights:    _barHeights,
                dominant:      dominant,
                vibrant:       vibrant,
                numBars:       _kNumBars,
                artworkRadius: _kArtworkR,
                particles:     _particles,
                activeCount:   _activeParticles,
                overallEnergy: _overallEnergy,
              ),
              size: Size.infinite,
            ),
          ),

          // ── Pulse rings — throb with bass ────────────────────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              painter: _PulseRingPainter(
                dominant:      dominant,
                artworkRadius: _kArtworkR,
                pulse:         _pulseCtrl.value,
                bassEnergy:    _bassEnergy,
              ),
              size: Size.infinite,
            ),
          ),

          // ── Rotating artwork disc — glow expands with bass ───────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseCtrl, _spinCtrl]),
              builder: (_, __) {
                final scale      = 1.0 + _pulseCtrl.value * 0.022 + _bassEnergy * 0.04;
                final glowBlur   = 44.0 + _bassEnergy * 22.0;
                final glowSpread = 6.0  + _bassEnergy *  8.0;
                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width:  _kArtworkR * 2,
                    height: _kArtworkR * 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow halo
                        Container(
                          width:  _kArtworkR * 2,
                          height: _kArtworkR * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dominant.withValues(
                                    alpha: (0.62 + _bassEnergy * 0.28)
                                        .clamp(0.0, 0.9)),
                                blurRadius:   glowBlur,
                                spreadRadius: glowSpread,
                              ),
                            ],
                          ),
                        ),
                        // Rotating artwork
                        Transform.rotate(
                          angle: _spinCtrl.value * 2 * pi,
                          child: ClipOval(
                            child: SizedBox(
                              width:  _kArtworkR * 2,
                              height: _kArtworkR * 2,
                              child: _artwork != null
                                  ? Image(
                                      image:           _artwork!,
                                      fit:             BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : ColoredBox(
                                      color: dominant.withValues(alpha: 0.4),
                                    ),
                            ),
                          ),
                        ),
                        // Vinyl ring border
                        Container(
                          width:  _kArtworkR * 2,
                          height: _kArtworkR * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Spindle dot
                        Container(
                          width:  10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.65),
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.white.withValues(alpha: 0.40),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Song info ────────────────────────────────────────────────────
          if (song != null)
            Positioned(
              bottom: bottomPad + 52,
              left:   32,
              right:  32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color:        Colors.white,
                      fontSize:     20,
                      fontWeight:   FontWeight.w700,
                      fontFamily:   FontConstants.fontFamily,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ArtistSeparatorService()
                        .splitArtists(song.artist ?? '')
                        .join(', '),
                    style: TextStyle(
                      color:      Colors.white.withValues(alpha: 0.55),
                      fontSize:   15,
                      fontFamily: FontConstants.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // ── Close button ─────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: IconButton(
                  icon: const Iconoir.NavArrowDown(
                    color:  Colors.white,
                    width:  28,
                    height: 28,
                  ),
                  onPressed:  () => Navigator.of(context).pop(),
                  tooltip:    'Close visualiser',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spectrum-bars + particles painter ────────────────────────────────────────

class _VisualizerPainter extends CustomPainter {
  final List<double>    barHeights;
  final Color           dominant;
  final Color           vibrant;
  final int             numBars;
  final double          artworkRadius;
  final List<_Particle> particles;
  final int             activeCount;   // how many particles to actually draw
  final double          overallEnergy; // [0..1] boosts particle size slightly

  _VisualizerPainter({
    required this.barHeights,
    required this.dominant,
    required this.vibrant,
    required this.numBars,
    required this.artworkRadius,
    required this.particles,
    required this.activeCount,
    required this.overallEnergy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerR = artworkRadius + 14.0;
    final twoPi  = 2 * pi;
    final barW   = (size.width / 420).clamp(1.5, 3.0);

    // ── Radial spectrum bars ───────────────────────────────────────────────
    for (int i = 0; i < numBars; i++) {
      final double angle  = (twoPi * i / numBars) - pi / 2;
      final double h      = barHeights[i];
      final double barLen = 6.0 + h * 58.0;
      final double alpha  = 0.45 + h * 0.55;

      final color = Color.lerp(
        dominant.withValues(alpha: alpha),
        vibrant.withValues(alpha: alpha),
        h,
      )!;

      final cosA = cos(angle);
      final sinA = sin(angle);
      canvas.drawLine(
        Offset(center.dx + cosA * innerR,            center.dy + sinA * innerR),
        Offset(center.dx + cosA * (innerR + barLen), center.dy + sinA * (innerR + barLen)),
        Paint()
          ..color       = color
          ..strokeWidth = barW
          ..strokeCap   = StrokeCap.round,
      );
    }

    // ── Particles ─────────────────────────────────────────────────────────
    // Particle size grows slightly with overall energy for extra punch.
    final double sizeBoost = 1.0 + overallEnergy * 0.6;
    final pPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < activeCount; i++) {
      final p = particles[i];
      final double a = p.alpha.clamp(0.0, 1.0);
      if (a <= 0) continue;
      final double x = center.dx + cos(p.angle) * p.radius;
      final double y = center.dy + sin(p.angle) * p.radius;
      if (x < -10 || x > size.width + 10 || y < -10 || y > size.height + 10) continue;
      pPaint.color = p.color.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), p.size * sizeBoost, pPaint);
    }
  }

  @override
  bool shouldRepaint(_VisualizerPainter _) => true;
}

// ── Pulse-ring painter ────────────────────────────────────────────────────────

class _PulseRingPainter extends CustomPainter {
  final Color  dominant;
  final double artworkRadius;
  final double pulse;       // 0..1 from AnimationController
  final double bassEnergy;  // 0..1 adds extra ring expansion on kick/bass

  const _PulseRingPainter({
    required this.dominant,
    required this.artworkRadius,
    required this.pulse,
    required this.bassEnergy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base   = artworkRadius + 8.0;

    // Ring 1: breathes with AnimationController, swells further on bass
    final double r1 = base + pulse * 22 + bassEnergy * 20;
    final double a1 = (0.55 - pulse * 0.45 + bassEnergy * 0.28).clamp(0.0, 0.85);
    canvas.drawCircle(
      center, r1,
      Paint()
        ..color       = dominant.withValues(alpha: a1)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5 + bassEnergy * 1.5,
    );

    // Ring 2: inverse phase so the two rings alternate
    final double inv = 1.0 - pulse;
    final double r2  = base + inv * 38 + bassEnergy * 14;
    final double a2  = (0.28 - inv * 0.22 + bassEnergy * 0.18).clamp(0.0, 0.55);
    canvas.drawCircle(
      center, r2,
      Paint()
        ..color       = dominant.withValues(alpha: a2)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0 + bassEnergy * 1.0,
    );
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.pulse != pulse || old.bassEnergy != bassEnergy;
}

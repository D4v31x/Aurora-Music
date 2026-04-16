/// Full-screen music visualiser with six switchable modes and real-time FFT.
///
/// Modes: Bar Spectrum, Waveform, Circular Bars, Particle Field, Mirror Bars,
/// Frequency Line. The active mode is persisted via SharedPreferences.
/// On Android the native Visualizer EventChannel ("aurora/visualizer") drives
/// FFT. Falls back to procedural sine animation when unavailable.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/background_manager_service.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/services/artwork_cache_service.dart';

// ── Visualiser modes ──────────────────────────────────────────────────────────

enum VisualizerMode {
  barSpectrum,
  waveform,
  circularBars,
  particleField,
  mirrorBars,
  frequencyLine;

  String get label => switch (this) {
    VisualizerMode.barSpectrum   => 'Bar Spectrum',
    VisualizerMode.waveform      => 'Waveform',
    VisualizerMode.circularBars  => 'Circular Bars',
    VisualizerMode.particleField => 'Particle Field',
    VisualizerMode.mirrorBars    => 'Mirror Bars',
    VisualizerMode.frequencyLine => 'Frequency Line',
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MusicVisualizerScreen extends StatefulWidget {
  const MusicVisualizerScreen({super.key});

  @override
  State<MusicVisualizerScreen> createState() => _MusicVisualizerScreenState();
}

class _MusicVisualizerScreenState extends State<MusicVisualizerScreen>
    with SingleTickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int    _kNumBars        = 48;
  static const String _kPrefKey        = 'visualizer_mode';

  static const _kFreqs = [0.55, 0.90, 1.40, 2.10, 3.00];
  static const _kAmps  = [0.30, 0.25, 0.20, 0.15, 0.10];

  static const _kFftChannel = EventChannel('aurora/visualizer');
  static final  _artworkService = ArtworkCacheService();

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _mainCtrl;

  // ── FFT / energy state ─────────────────────────────────────────────────────
  StreamSubscription<dynamic>? _sessionIdSub;
  StreamSubscription<dynamic>? _fftSub;

  late final List<double> _barHeights;
  late final List<int>    _barBinStart;
  late final List<int>    _barBinEnd;
  // Raw waveform bytes for waveform mode (same FFT callback, re-used)
  final List<double> _waveform = List.filled(_kNumBars * 4, 0.0);

  double _bassEnergy    = 0.0;
  double _overallEnergy = 0.0;
  bool   _hasRealData   = false;

  // ── Simulation fallback ────────────────────────────────────────────────────
  final _rng = Random();
  late final List<double> _barPhases;
  double _time          = 0.0;
  double _lastCtrlValue = 0.0;

  // ── Particle state ─────────────────────────────────────────────────────────
  late final List<_Particle> _particles;

  // ── Mode / UI ──────────────────────────────────────────────────────────────
  VisualizerMode _mode  = VisualizerMode.barSpectrum;
  bool           _micGranted     = false;
  ImageProvider? _artworkProvider;

  late final AudioPlayerService _audio;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioPlayerService>();

    _barPhases = List.generate(_kNumBars, (_) => _rng.nextDouble() * 2 * pi);
    _initFftBinRanges();
    _barHeights = List.filled(_kNumBars, 0.0);
    _particles  = List.generate(120, (_) => _Particle.random(_rng));

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _mainCtrl.addListener(_onTick);

    _loadMode();
    _checkAndRequestPermission();
    _loadArtwork();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKey);
    if (saved != null && mounted) {
      final idx = VisualizerMode.values.indexWhere((m) => m.name == saved);
      if (idx != -1) setState(() => _mode = VisualizerMode.values[idx]);
    }
  }

  Future<void> _saveMode(VisualizerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, mode.name);
  }

  void _switchMode(int delta) {
    final next = VisualizerMode
        .values[(_mode.index + delta) % VisualizerMode.values.length];
    setState(() => _mode = next);
    unawaited(_saveMode(next));
  }

  Future<void> _loadArtwork() async {
    final song = _audio.currentSong;
    if (song == null) return;
    try {
      final provider = await _artworkService.getCachedImageProvider(song.id);
      if (mounted) setState(() => _artworkProvider = provider);
    } catch (_) {}
  }

  Future<void> _checkAndRequestPermission() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    final granted = status.isGranted;
    setState(() => _micGranted = granted);
    if (granted) unawaited(_subscribeToSessionId());
  }

  void _initFftBinRanges() {
    const int firstBin = 1;
    const int lastBin  = 256;
    _barBinStart = List.filled(_kNumBars, 0);
    _barBinEnd   = List.filled(_kNumBars, 1);
    for (int i = 0; i < _kNumBars; i++) {
      final double t0 = i / _kNumBars;
      final double t1 = (i + 1) / _kNumBars;
      final int s = (firstBin * pow(lastBin / firstBin, t0))
          .round().clamp(firstBin, lastBin);
      final int e = (firstBin * pow(lastBin / firstBin, t1))
          .round().clamp(s + 1, lastBin + 1);
      _barBinStart[i] = s;
      _barBinEnd[i]   = e;
    }
  }

  Future<void> _subscribeToSessionId() async {
    _sessionIdSub = _audio.audioPlayer.androidAudioSessionIdStream.listen(
      (sessionId) {
        if (sessionId != null && sessionId > 0) _attachVisualizer(sessionId);
      },
      onError: (_) {},
    );
  }

  void _attachVisualizer(int sessionId) {
    _fftSub?.cancel();
    _fftSub = _kFftChannel.receiveBroadcastStream(sessionId).listen(
      (data) { if (data is Uint8List) _processFft(data); },
      onError: (_) { _hasRealData = false; },
    );
  }

  void _processFft(Uint8List fft) {
    if (!mounted) return;
    final bd     = fft.buffer.asByteData();
    final maxBin = (fft.length ~/ 2) - 1;
    double totalEnergy = 0.0;

    // Waveform: sample evenly across the raw byte array
    final wStep = fft.length / _waveform.length;
    for (int i = 0; i < _waveform.length; i++) {
      final idx = (i * wStep).floor().clamp(0, fft.length - 1);
      _waveform[i] = (bd.getInt8(idx) / 128.0).clamp(-1.0, 1.0);
    }

    for (int i = 0; i < _kNumBars; i++) {
      final binStart = _barBinStart[i].clamp(1, maxBin);
      final binEnd   = _barBinEnd[i].clamp(binStart + 1, maxBin + 1);

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

      final double raw   = count > 0 ? (sum / count) / 200.0 : 0.0;
      final double alpha = raw > _barHeights[i] ? 0.30 : 0.10;
      _barHeights[i] = (_barHeights[i] * (1 - alpha) +
              raw.clamp(0.0, 1.0) * alpha)
          .clamp(0.0, 1.0);
      totalEnergy += _barHeights[i];
    }

    final bassRaw  = (_barHeights[0] + _barHeights[1] +
                      _barHeights[2] + _barHeights[3]) / 4.0;
    _bassEnergy    = (_bassEnergy * 0.40 + bassRaw * 0.60).clamp(0.0, 1.0);
    _overallEnergy = (_overallEnergy * 0.70 +
                     (totalEnergy / _kNumBars) * 0.30).clamp(0.0, 1.0);
    _hasRealData   = true;
  }

  void _onTick() {
    if (!mounted) return;

    double delta = _mainCtrl.value - _lastCtrlValue;
    if (delta < -0.5) delta += 1.0;
    _lastCtrlValue = _mainCtrl.value;

    if (_audio.isPlaying) _time += delta;

    if (!_hasRealData && _audio.isPlaying) {
      // Procedural sine fallback
      for (int i = 0; i < _kNumBars; i++) {
        double h = 0.0;
        for (int j = 0; j < _kFreqs.length; j++) {
          h += _kAmps[j] * sin(_time * _kFreqs[j] * 2 * pi + _barPhases[i] + j * 0.7);
        }
        _barHeights[i] = ((h + 1.0) / 2.0);
        _barHeights[i] = _barHeights[i] * _barHeights[i];
      }
      _bassEnergy    = (_barHeights[0] + _barHeights[1]) / 2.0;
      _overallEnergy = 0.4;

      // Waveform fallback: smooth sine
      for (int i = 0; i < _waveform.length; i++) {
        _waveform[i] = sin(_time * 3.0 + i * 2 * pi / _waveform.length);
      }
    }

    // Animate particles
    if (_audio.isPlaying) {
      for (final p in _particles) {
        p.update(delta, _bassEnergy, _overallEnergy, _rng);
      }
    }
  }

  @override
  void dispose() {
    _mainCtrl
      ..removeListener(_onTick)
      ..dispose();
    _fftSub?.cancel();
    _sessionIdSub?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg        = context.watch<BackgroundManagerService>();
    final colors    = bg.currentColors;
    final dominant  = colors.isNotEmpty ? colors[0] : const Color(0xFF6200EE);
    final vibrant   = colors.length > 1 ? colors[1] : dominant;
    final barColor  = colors.length > 2 ? colors[2]
                    : colors.length > 1 ? colors[1]
                    : dominant;
    final song      = _audio.currentSong;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final topPad    = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred album art background ────────────────────────────────
          if (_artworkProvider != null) ...[
            Image(
              image: _artworkProvider!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            ),
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.60)),
            ),
          ] else
            const ColoredBox(color: Colors.black),

          // ── Visualiser canvas or permission prompt ──────────────────────
          if (!_micGranted)
            _buildPermissionPrompt(context, barColor)
          else
            AnimatedBuilder(
              animation: _mainCtrl,
              builder: (_, __) => CustomPaint(
                painter: _buildPainter(barColor, bottomPad),
                size: Size.infinite,
              ),
            ),

          // ── Song info ──────────────────────────────────────────────────
          if (song != null)
            Positioned(
              bottom: bottomPad + 36,
              left:   32,
              right:  32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      22,
                      fontWeight:    FontWeight.w700,
                      fontFamily:    FontConstants.fontFamily,
                      letterSpacing: 0.2,
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
                      color:         vibrant.withValues(alpha: 0.85),
                      fontSize:      14,
                      fontFamily:    FontConstants.fontFamily,
                      fontWeight:    FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // ── Top chrome: close + mode switcher ─────────────────────────
          Positioned(
            top: topPad,
            left: 0,
            right: 0,
            child: Row(
              children: [
                // Close button
                IconButton(
                  icon: const Iconoir.NavArrowDown(
                    color: Colors.white, width: 28, height: 28),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close visualiser',
                ),
                // Mode switcher centred in remaining space
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Iconoir.NavArrowLeft(
                            color: Colors.white, width: 22, height: 22),
                        onPressed: () => _switchMode(-1),
                        tooltip: 'Previous mode',
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _mode.label,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   15,
                          fontWeight: FontWeight.w600,
                          fontFamily: FontConstants.fontFamily,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Iconoir.NavArrowRight(
                            color: Colors.white, width: 22, height: 22),
                        onPressed: () => _switchMode(1),
                        tooltip: 'Next mode',
                      ),
                    ],
                  ),
                ),
                // Spacer matching close button width so title stays centred
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _buildPainter(Color barColor, double bottomInset) {
    return switch (_mode) {
      VisualizerMode.barSpectrum   => _BarSpectrumPainter(
          barHeights: _barHeights, barColor: barColor, bottomInset: bottomInset),
      VisualizerMode.waveform      => _WaveformPainter(
          waveform: _waveform, color: barColor, bottomInset: bottomInset),
      VisualizerMode.circularBars  => _CircularBarsPainter(
          barHeights: _barHeights, barColor: barColor,
          bassEnergy: _bassEnergy),
      VisualizerMode.particleField => _ParticleFieldPainter(
          particles: _particles, accentColor: barColor,
          bassEnergy: _bassEnergy, overallEnergy: _overallEnergy),
      VisualizerMode.mirrorBars    => _MirrorBarsPainter(
          barHeights: _barHeights, barColor: barColor, bottomInset: bottomInset),
      VisualizerMode.frequencyLine => _FrequencyLinePainter(
          barHeights: _barHeights, color: barColor, bottomInset: bottomInset),
    };
  }

  Widget _buildPermissionPrompt(BuildContext context, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Microphone access needed',
              style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
                fontFamily: FontConstants.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Aurora needs microphone access to tap your device\'s audio session '
              'for the live visualizer. No audio is ever recorded or stored.',
              style: TextStyle(
                fontSize: 14, fontFamily: FontConstants.fontFamily,
                color: Color(0xA6FFFFFF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: () async {
                final status = await Permission.microphone.request();
                if (!mounted) return;
                final granted = status.isGranted;
                setState(() => _micGranted = granted);
                if (granted) {
                  unawaited(_subscribeToSessionId());
                } else if (status.isPermanentlyDenied) {
                  await openAppSettings();
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Particle helper ───────────────────────────────────────────────────────────

class _Particle {
  double x, y;      // normalised [0..1]
  double vx, vy;
  double radius;
  double opacity;
  double life;       // [0..1]
  double speed;

  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.radius, required this.opacity,
    required this.life, required this.speed,
  });

  factory _Particle.random(Random rng) => _Particle(
    x: rng.nextDouble(), y: rng.nextDouble(),
    vx: (rng.nextDouble() - 0.5) * 0.003,
    vy: (rng.nextDouble() - 0.5) * 0.003,
    radius: 2 + rng.nextDouble() * 4,
    opacity: 0.3 + rng.nextDouble() * 0.5,
    life: rng.nextDouble(),
    speed: 0.5 + rng.nextDouble(),
  );

  void update(double dt, double bass, double energy, Random rng) {
    final boost = 1.0 + bass * 6.0 + energy * 2.0;
    x += vx * boost;
    y += vy * boost;
    life += dt * speed * 0.4;

    // Orbit-drift — slight pull toward center and tangential nudge
    final cx = x - 0.5;
    final cy = y - 0.5;
    vx += (-cx * 0.0002 + cy * 0.0003) * boost;
    vy += (-cy * 0.0002 - cx * 0.0003) * boost;

    // Dampen velocity slightly so particles don't fly away
    vx *= 0.998;
    vy *= 0.998;

    if (life > 1.0 || x < -0.05 || x > 1.05 || y < -0.05 || y > 1.05) {
      // Respawn near center with random radial offset
      final angle = rng.nextDouble() * 2 * pi;
      final r     = 0.05 + rng.nextDouble() * 0.15;
      x = 0.5 + cos(angle) * r;
      y = 0.5 + sin(angle) * r;
      vx = (rng.nextDouble() - 0.5) * 0.003;
      vy = (rng.nextDouble() - 0.5) * 0.003;
      life = 0.0;
      opacity = 0.3 + rng.nextDouble() * 0.5;
      radius  = 2 + rng.nextDouble() * 4;
    }
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// 1 · Bar Spectrum — vertical rounded bars from the bottom.
class _BarSpectrumPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bottomInset;

  const _BarSpectrumPainter({
    required this.barHeights,
    required this.barColor,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int    kBars      = 48;
    const double hPad       = 20.0;
    const double gapFactor  = 0.4;
    const double topReserve = 110.0;

    final available = size.width - hPad * 2;
    final barWidth  = available / (kBars + (kBars - 1) * gapFactor);
    final gap       = barWidth * gapFactor;
    final bottomY   = size.height - 200.0 - bottomInset;
    final maxH      = (bottomY - topReserve).clamp(50.0, double.infinity);

    final solidPaint = Paint()
      ..color = barColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color      = barColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..style      = PaintingStyle.fill;

    for (int i = 0; i < kBars; i++) {
      final h    = (barHeights[i] * maxH).clamp(2.0, maxH);
      final x    = hPad + i * (barWidth + gap);
      final topY = bottomY - h;
      final r    = Radius.circular(barWidth / 2);
      final rr   = RRect.fromLTRBAndCorners(
          x, topY, x + barWidth, bottomY, topLeft: r, topRight: r);
      canvas.drawRRect(rr, glowPaint);
      canvas.drawRRect(rr, solidPaint);
    }
  }

  @override
  bool shouldRepaint(_BarSpectrumPainter _) => true;
}

/// 2 · Waveform — oscilloscope-style horizontal line.
class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color        color;
  final double       bottomInset;

  const _WaveformPainter({
    required this.waveform,
    required this.color,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final cy    = size.height * 0.45;
    final amp   = size.height * 0.20;
    final xStep = size.width / (waveform.length - 1);

    final linePaint = Paint()
      ..color       = color.withValues(alpha: 0.90)
      ..strokeWidth = 2.5
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color       = color.withValues(alpha: 0.25)
      ..strokeWidth = 8.0
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style       = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < waveform.length; i++) {
      final x = i * xStep;
      final y = cy + waveform[i] * amp;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter _) => true;
}

/// 3 · Circular Bars — bars radiating outward in a ring around the center.
class _CircularBarsPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bassEnergy;

  const _CircularBarsPainter({
    required this.barHeights,
    required this.barColor,
    required this.bassEnergy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int kBars    = 48;
    final     center   = size.center(Offset.zero);
    final     baseR    = min(size.width, size.height) * 0.18 + bassEnergy * 20;
    final     maxLen   = min(size.width, size.height) * 0.28;
    const     angleStep = 2 * pi / kBars;

    final solidPaint = Paint()
      ..color       = barColor.withValues(alpha: 0.90)
      ..strokeWidth = 4.0
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color       = barColor.withValues(alpha: 0.30)
      ..strokeWidth = 10.0
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style       = PaintingStyle.stroke;

    for (int i = 0; i < kBars; i++) {
      final angle  = i * angleStep - pi / 2;
      final barLen = (barHeights[i] * maxLen).clamp(4.0, maxLen);
      final x0 = center.dx + cos(angle) * baseR;
      final y0 = center.dy + sin(angle) * baseR;
      final x1 = center.dx + cos(angle) * (baseR + barLen);
      final y1 = center.dy + sin(angle) * (baseR + barLen);
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), glowPaint);
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), solidPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularBarsPainter _) => true;
}

/// 4 · Particle Field — glowing orbiting dots that react to the beat,
///     with a central pulsing ball (NCS-style).
class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color           accentColor;
  final double          bassEnergy;
  final double          overallEnergy;

  const _ParticleFieldPainter({
    required this.particles,
    required this.accentColor,
    required this.bassEnergy,
    required this.overallEnergy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center  = size.center(Offset.zero);
    final ballR   = min(size.width, size.height) * (0.12 + bassEnergy * 0.06);

    // Central glowing ball
    final ballGlow = Paint()
      ..color      = accentColor.withValues(alpha: 0.18 + bassEnergy * 0.20)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + bassEnergy * 30);
    canvas.drawCircle(center, ballR * 1.6, ballGlow);

    final ballCore = Paint()
      ..shader = ui.Gradient.radial(
        center, ballR,
        [
          accentColor.withValues(alpha: 0.95),
          accentColor.withValues(alpha: 0.60),
          accentColor.withValues(alpha: 0.0),
        ],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(center, ballR, ballCore);

    // Particles
    for (final p in particles) {
      final fade = sin(p.life * pi).clamp(0.0, 1.0);
      final paint = Paint()
        ..color      = accentColor.withValues(
            alpha: (p.opacity * fade * (0.6 + overallEnergy * 0.4)).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 0.8);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius * (1.0 + bassEnergy * 1.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticleFieldPainter _) => true;
}

/// 5 · Mirror Bars — bars that grow both up and down from the center line.
class _MirrorBarsPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bottomInset;

  const _MirrorBarsPainter({
    required this.barHeights,
    required this.barColor,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int    kBars     = 48;
    const double hPad      = 20.0;
    const double gapFactor = 0.4;

    final available = size.width - hPad * 2;
    final barWidth  = available / (kBars + (kBars - 1) * gapFactor);
    final gap       = barWidth * gapFactor;
    final cy        = size.height * 0.46;
    final maxH      = (cy - 90.0).clamp(40.0, double.infinity);

    final solidPaint = Paint()
      ..color = barColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color      = barColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..style      = PaintingStyle.fill;

    for (int i = 0; i < kBars; i++) {
      final h   = (barHeights[i] * maxH).clamp(2.0, maxH);
      final x   = hPad + i * (barWidth + gap);
      final r   = Radius.circular(barWidth / 2);

      // Upper half
      final upRR = RRect.fromLTRBAndCorners(
          x, cy - h, x + barWidth, cy, topLeft: r, topRight: r);
      // Lower half
      final downRR = RRect.fromLTRBAndCorners(
          x, cy, x + barWidth, cy + h,
          bottomLeft: r, bottomRight: r);

      canvas.drawRRect(upRR,   glowPaint);
      canvas.drawRRect(upRR,   solidPaint);
      canvas.drawRRect(downRR, glowPaint);
      canvas.drawRRect(downRR, solidPaint);
    }
  }

  @override
  bool shouldRepaint(_MirrorBarsPainter _) => true;
}

/// 6 · Frequency Line — smooth filled curve connecting all FFT bins.
class _FrequencyLinePainter extends CustomPainter {
  final List<double> barHeights;
  final Color        color;
  final double       bottomInset;

  const _FrequencyLinePainter({
    required this.barHeights,
    required this.color,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (barHeights.isEmpty) return;

    const double topReserve = 110.0;
    final double bottomY    = size.height - 200.0 - bottomInset;
    final double maxH       = (bottomY - topReserve).clamp(40.0, double.infinity);
    final double xStep      = size.width / (barHeights.length - 1);

    // Build a smooth cubic path
    final path = Path();
    for (int i = 0; i < barHeights.length; i++) {
      final x = i * xStep;
      final y = bottomY - barHeights[i] * maxH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * xStep;
        final prevY = bottomY - barHeights[i - 1] * maxH;
        final cpX   = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    // Close fill down to the baseline
    path.lineTo(size.width, bottomY);
    path.lineTo(0, bottomY);
    path.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topReserve),
        Offset(0, bottomY),
        [
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.05),
        ],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Stroke the top line
    final strokePath = Path();
    for (int i = 0; i < barHeights.length; i++) {
      final x = i * xStep;
      final y = bottomY - barHeights[i] * maxH;
      if (i == 0) {
        strokePath.moveTo(x, y);
      } else {
        final prevX = (i - 1) * xStep;
        final prevY = bottomY - barHeights[i - 1] * maxH;
        final cpX   = (prevX + x) / 2;
        strokePath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    final linePaint = Paint()
      ..color       = color.withValues(alpha: 0.90)
      ..strokeWidth = 2.5
      ..style       = PaintingStyle.stroke
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(strokePath, linePaint);
  }

  @override
  bool shouldRepaint(_FrequencyLinePainter _) => true;
}


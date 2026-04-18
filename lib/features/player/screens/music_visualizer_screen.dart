/// Full-screen music visualiser with switchable modes and real-time FFT.
///
/// Modes: Bar Spectrum, Circular Bars, Mirror Bars, Frequency Line. The active mode is persisted via SharedPreferences.
/// On Android the native Visualizer EventChannel ("aurora/visualizer") drives
/// FFT. Falls back to procedural sine animation when unavailable.
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/background_manager_service.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/services/artwork_cache_service.dart';

// ── Visualiser modes ──────────────────────────────────────────────────────────

enum VisualizerMode {
  barSpectrum,
  circularBars,
  mirrorBars,
  frequencyLine;

  String get label => switch (this) {
    VisualizerMode.barSpectrum   => 'Bar Spectrum',
    VisualizerMode.circularBars  => 'Circular Bars',
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
  double _bassEnergy    = 0.0;
  double _overallEnergy = 0.0;
  bool   _hasRealData   = false;
  Uint8List? _pendingFftData;
  // Incremented whenever bar heights or energy change so painters can skip
  // redundant GPU draws via shouldRepaint when nothing changed.
  int _paintGeneration = 0;

  // ── Simulation fallback ────────────────────────────────────────────────────
  final _rng = Random();
  late final List<double> _barPhases;
  double _time          = 0.0;
  double _lastCtrlValue = 0.0;

  // ── Mode / UI ──────────────────────────────────────────────────────────────
  VisualizerMode _mode  = VisualizerMode.barSpectrum;
  bool           _micGranted     = false;
  ImageProvider? _artworkProvider;
  int?           _loadedSongId;

  late final AudioPlayerService _audio;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioPlayerService>();

    _barPhases = List.generate(_kNumBars, (_) => _rng.nextDouble() * 2 * pi);
    _initFftBinRanges();
    _barHeights = List.filled(_kNumBars, 0.0);

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _mainCtrl.addListener(_onTick);

    _loadMode();
    _checkAndRequestPermission();
    _loadArtwork();
    _audio.currentSongNotifier.addListener(_onSongChanged);
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

  void _onSongChanged() {
    final song = _audio.currentSong;
    final newId = song?.id;
    if (newId == _loadedSongId) return;
    // Clear stale artwork immediately so the old song's art doesn't flash.
    if (mounted) setState(() => _artworkProvider = null);
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    final song = _audio.currentSong;
    if (song == null) {
      _loadedSongId = null;
      return;
    }
    final targetId = song.id;
    try {
      final provider = await _artworkService.getCachedImageProvider(song.id);
      if (mounted && _audio.currentSong?.id == targetId) {
        setState(() {
          _artworkProvider = provider;
          _loadedSongId = targetId;
        });
      }
    } catch (_) {
      if (mounted && _audio.currentSong?.id == targetId) {
        setState(() {
          _artworkProvider = null;
          _loadedSongId = targetId;
        });
      }
    }
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
      (data) { if (data is Uint8List) _processVisualizerData(data); },
      onError: (_) { _hasRealData = false; },
    );
  }

  /// Stores incoming visualizer packets for processing on the next animation
  /// frame, throttling FFT math to at most once per frame (~60 Hz).
  void _processVisualizerData(Uint8List data) {
    if (data.isEmpty || !mounted) return;
    _pendingFftData = data;
  }

  /// Processes FFT complex-pair data (prefixed with 0x01) into bar heights
  /// and energy values used by all visualizer modes.
  void _processFft(Uint8List data) {
    if (!mounted || data.length < 2) return;
    // data[0] = type prefix; FFT pairs start at offset 1
    final bd     = data.buffer.asByteData();
    final fftLen = data.length - 1;
    final maxBin = (fftLen ~/ 2) - 1;
    double totalEnergy = 0.0;

    for (int i = 0; i < _kNumBars; i++) {
      final binStart = _barBinStart[i].clamp(1, maxBin);
      final binEnd   = _barBinEnd[i].clamp(binStart + 1, maxBin + 1);

      double sum = 0.0;
      int count = 0;
      for (int b = binStart; b < binEnd; b++) {
        final int idx = 1 + b * 2; // +1 to skip prefix byte
        if (idx + 1 >= data.length) break;
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

    // Drain the latest FFT packet (at most one per animation frame).
    final pending = _pendingFftData;
    if (pending != null) {
      _pendingFftData = null;
      _processFft(pending);
      _paintGeneration++;
    }

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
      _paintGeneration++;
    }

  }

  @override
  void dispose() {
    _audio.currentSongNotifier.removeListener(_onSongChanged);
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
    final bg         = context.watch<BackgroundManagerService>();
    final colors     = bg.currentColors;
    final hasArtwork = _artworkProvider != null;
    final dominant   = colors.isNotEmpty ? colors[0] : const Color(0xFF6200EE);
    // When there is no artwork show white bars and text on a solid black bg.
    final vibrant    = hasArtwork
        ? (colors.length > 1 ? colors[1] : dominant)
        : Colors.white;
    final barColor   = hasArtwork
        ? (colors.length > 2 ? colors[2]
           : colors.length > 1 ? colors[1]
           : dominant)
        : Colors.white;
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
                  icon: const iconoir.NavArrowDown(
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
                        icon: const iconoir.NavArrowLeft(
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
                        icon: const iconoir.NavArrowRight(
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
          barHeights: _barHeights, barColor: barColor, bottomInset: bottomInset,
          paintGeneration: _paintGeneration),
      VisualizerMode.circularBars  => _CircularBarsPainter(
          barHeights: _barHeights, barColor: barColor,
          bassEnergy: _bassEnergy, paintGeneration: _paintGeneration),
      VisualizerMode.mirrorBars    => _MirrorBarsPainter(
          barHeights: _barHeights, barColor: barColor, bottomInset: bottomInset,
          paintGeneration: _paintGeneration),
      VisualizerMode.frequencyLine => _FrequencyLinePainter(
          barHeights: _barHeights, color: barColor, bottomInset: bottomInset,
          paintGeneration: _paintGeneration),
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
            Text(
              AppLocalizations.of(context).microphoneAccessNeeded,
              style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
                fontFamily: FontConstants.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).microphoneAccessDesc,
              style: const TextStyle(
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
              child: Text(AppLocalizations.of(context).grantPermission),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// 1 · Bar Spectrum — vertical rounded bars from the bottom.
class _BarSpectrumPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bottomInset;
  final int          paintGeneration;

  const _BarSpectrumPainter({
    required this.barHeights,
    required this.barColor,
    required this.bottomInset,
    required this.paintGeneration,
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
  bool shouldRepaint(_BarSpectrumPainter old) =>
      old.paintGeneration != paintGeneration || old.barColor != barColor;
}

/// 2 · Circular Bars — bars radiating outward in a ring around the center.
class _CircularBarsPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bassEnergy;
  final int          paintGeneration;

  const _CircularBarsPainter({
    required this.barHeights,
    required this.barColor,
    required this.bassEnergy,
    required this.paintGeneration,
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
  bool shouldRepaint(_CircularBarsPainter old) =>
      old.paintGeneration != paintGeneration || old.barColor != barColor;
}

/// 4 · Mirror Bars — bars that grow both up and down from the center line.
class _MirrorBarsPainter extends CustomPainter {
  final List<double> barHeights;
  final Color        barColor;
  final double       bottomInset;
  final int          paintGeneration;

  const _MirrorBarsPainter({
    required this.barHeights,
    required this.barColor,
    required this.bottomInset,
    required this.paintGeneration,
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
  bool shouldRepaint(_MirrorBarsPainter old) =>
      old.paintGeneration != paintGeneration || old.barColor != barColor;
}

/// 6 · Frequency Line — smooth filled curve connecting all FFT bins.
class _FrequencyLinePainter extends CustomPainter {
  final List<double> barHeights;
  final Color        color;
  final double       bottomInset;
  final int          paintGeneration;

  const _FrequencyLinePainter({
    required this.barHeights,
    required this.color,
    required this.bottomInset,
    required this.paintGeneration,
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
        const Offset(0, topReserve),
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
      ..color       = color.withValues(alpha: 0.92)
      ..strokeWidth = 2.0
      ..style       = PaintingStyle.stroke;
    canvas.drawPath(strokePath, linePaint);
  }

  @override
  bool shouldRepaint(_FrequencyLinePainter old) =>
      old.paintGeneration != paintGeneration || old.color != color;
}


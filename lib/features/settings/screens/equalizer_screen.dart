import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/font_constants.dart';
import '../../../main.dart' show equalizer;
import '../../../shared/services/equalizer_service.dart';
import '../../../shared/widgets/expanding_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInit());
  }

  Future<void> _maybeInit() async {
    if (!mounted) return;
    final svc = context.read<EqualizerService>();
    if (!svc.initialized) await svc.init(equalizer);
  }

  Future<void> _showSaveDialog(EqualizerService svc) async {
    final controller = TextEditingController();
    String? errorMsg;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void validate() {
            final name = controller.text.trim();
            if (name.isEmpty) {
              setState(() => errorMsg = 'Name cannot be empty.');
              return;
            }
            final isBuiltIn = EqualizerService.builtInPresets
                .any((p) => p.name.toLowerCase() == name.toLowerCase());
            if (isBuiltIn) {
              setState(() => errorMsg = '"$name" is a built-in preset name.');
              return;
            }
            svc.saveCurrentAsPreset(name);
            Navigator.pop(ctx);
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Save Preset',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: FontConstants.fontFamily,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. My Bass Boost',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => errorMsg = null),
                  onSubmitted: (_) => validate(),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ),
              TextButton(
                onPressed: validate,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: iconoir.NavArrowLeft(
            color: isDark ? Colors.white : Colors.black,
            width: 28,
            height: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Equalizer',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Consumer<EqualizerService>(
            builder: (_, svc, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: svc.enabled ? cs.primary : Colors.grey,
                      fontSize: 13,
                      fontFamily: FontConstants.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                    child: Text(svc.enabled ? 'On' : 'Off'),
                  ),
                  Switch(
                    value: svc.enabled,
                    onChanged: svc.initialized
                        ? (v) => svc.setEnabled(equalizer, v)
                        : null,
                    activeColor: cs.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Consumer<EqualizerService>(
        builder: (context, svc, _) {
          if (!svc.initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          final params = svc.params;
          if (params == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Equalizer not available on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }

          final gains = params.bands.map((b) => b.gain).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              // ── Interactive EQ curve ─────────────────────────────────────
              _InteractiveCurve(
                params: params,
                gains: gains,
                enabled: svc.enabled,
                onBandChanged: (i, v) => svc.setBandGain(i, v),
              ),
              const SizedBox(height: 12),
              // ── Band sliders ─────────────────────────────────────────────
              _BandSliders(
                params: params,
                gains: gains,
                enabled: svc.enabled,
                onChanged: (i, v) => svc.setBandGain(i, v),
              ),
              const SizedBox(height: 16),
              // ── Presets ──────────────────────────────────────────────────
              _PresetsSection(
                svc: svc,
                onSavePressed: () => _showSaveDialog(svc),
              ),
              // ── Bottom padding ───────────────────────────────────────────
              Builder(builder: (context) {
                final miniH =
                    ExpandingPlayer.getMiniPlayerPaddingHeight(context);
                return SizedBox(
                  height: miniH > 0
                      ? miniH
                      : MediaQuery.of(context).padding.bottom + 16,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive EQ curve
// ─────────────────────────────────────────────────────────────────────────────

class _InteractiveCurve extends StatefulWidget {
  final AndroidEqualizerParameters params;
  final List<double> gains;
  final bool enabled;
  final void Function(int bandIndex, double gainDb) onBandChanged;

  const _InteractiveCurve({
    required this.params,
    required this.gains,
    required this.enabled,
    required this.onBandChanged,
  });

  @override
  State<_InteractiveCurve> createState() => _InteractiveCurveState();
}

class _InteractiveCurveState extends State<_InteractiveCurve> {
  int? _activeBand;

  static const double _kH       = 220.0;
  static const double _kTopPad  = 20.0;
  static const double _kBotPad  = 28.0; // frequency label space
  static const double _kLeftPad = 40.0; // dB label space
  static const double _kRightPad = 8.0;

  double _freqToX(double hz, double w) {
    final bands = widget.params.bands;
    if (bands.length < 2) return (w - _kLeftPad - _kRightPad) / 2 + _kLeftPad;
    final minHz = bands.first.centerFrequency.toDouble();
    final maxHz = bands.last.centerFrequency.toDouble();
    if (minHz == maxHz) return (w - _kLeftPad - _kRightPad) / 2 + _kLeftPad;
    final t = (math.log(hz) - math.log(minHz)) /
        (math.log(maxHz) - math.log(minHz));
    return _kLeftPad + t * (w - _kLeftPad - _kRightPad);
  }

  double _gainToY(double db) {
    final minDb = widget.params.minDecibels.toDouble();
    final maxDb = widget.params.maxDecibels.toDouble();
    final range = maxDb - minDb;
    if (range == 0) return _kH / 2;
    final drawH = _kH - _kTopPad - _kBotPad;
    return _kTopPad + drawH * (1.0 - (db - minDb) / range);
  }

  double _yToGain(double y) {
    final minDb = widget.params.minDecibels.toDouble();
    final maxDb = widget.params.maxDecibels.toDouble();
    final range = maxDb - minDb;
    if (range == 0) return 0;
    final drawH = _kH - _kTopPad - _kBotPad;
    final t = 1.0 - ((y - _kTopPad) / drawH);
    return (minDb + t * range).clamp(minDb, maxDb);
  }

  int? _nearestBand(Offset pos, double w) {
    final bands = widget.params.bands;
    int? nearest;
    double nearestDist = double.infinity;
    for (int i = 0; i < bands.length; i++) {
      final bx = _freqToX(bands[i].centerFrequency.toDouble(), w);
      final by = _gainToY(
          i < widget.gains.length ? widget.gains[i] : 0.0);
      final dist = (pos - Offset(bx, by)).distance;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = i;
      }
    }
    // Accept touch within 48 logical pixels of a band point
    return nearestDist < 48 ? nearest : null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (d) => setState(
                    () => _activeBand = _nearestBand(d.localPosition, w))
                : null,
            onTapUp: (_) => setState(() => _activeBand = null),
            onTapCancel: () => setState(() => _activeBand = null),
            onPanStart: widget.enabled
                ? (d) => setState(() {
                      _activeBand ??= _nearestBand(d.localPosition, w);
                    })
                : null,
            onPanUpdate: widget.enabled
                ? (d) {
                    final band = _activeBand;
                    if (band == null) return;
                    widget.onBandChanged(band, _yToGain(d.localPosition.dy));
                  }
                : null,
            onPanEnd: (_) => setState(() => _activeBand = null),
            child: CustomPaint(
              size: Size(w, _kH),
              painter: _CurvePainter(
                bands: widget.params.bands,
                gains: widget.gains,
                minDb: widget.params.minDecibels.toDouble(),
                maxDb: widget.params.maxDecibels.toDouble(),
                color: cs.primary,
                enabled: widget.enabled,
                activeBand: _activeBand,
                width: w,
                freqToX: _freqToX,
                gainToY: _gainToY,
                topPad: _kTopPad,
                botPad: _kBotPad,
                leftPad: _kLeftPad,
                rightPad: _kRightPad,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Curve painter
// ─────────────────────────────────────────────────────────────────────────────

class _CurvePainter extends CustomPainter {
  final List<AndroidEqualizerBand> bands;
  final List<double> gains;
  final double minDb;
  final double maxDb;
  final Color color;
  final bool enabled;
  final int? activeBand;
  final double width;
  final double Function(double hz, double w) freqToX;
  final double Function(double db) gainToY;
  final double topPad;
  final double botPad;
  final double leftPad;
  final double rightPad;

  _CurvePainter({
    required this.bands,
    required this.gains,
    required this.minDb,
    required this.maxDb,
    required this.color,
    required this.enabled,
    required this.activeBand,
    required this.width,
    required this.freqToX,
    required this.gainToY,
    required this.topPad,
    required this.botPad,
    required this.leftPad,
    required this.rightPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;
    final h = size.height;
    final w = size.width;
    final ec = enabled ? color : color.withValues(alpha: 0.3);
    final drawRect = Rect.fromLTWH(
        leftPad, topPad, w - leftPad - rightPad, h - topPad - botPad);

    // ── dB grid lines + labels ────────────────────────────────────────────────
    final range = maxDb - minDb;
    final step = range > 20 ? 6.0 : 3.0;
    var db = ((minDb / step).ceil() * step).toDouble();
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    while (db <= maxDb + 0.01) {
      final y = gainToY(db);
      final isZero = db.abs() < 0.1;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(w - rightPad, y),
        isZero
            ? (Paint()
              ..color = Colors.white.withValues(alpha: 0.2)
              ..strokeWidth = 1.0)
            : gridPaint,
      );
      final label =
          isZero ? '0' : (db > 0 ? '+${db.toInt()}' : '${db.toInt()}');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isZero ? 0.5 : 0.28),
            fontSize: 9,
            fontWeight: isZero ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 5, y - tp.height / 2));
      db += step;
    }

    // ── Frequency labels at band positions ──────────────────────────────────
    for (int i = 0; i < bands.length; i++) {
      final hz = bands[i].centerFrequency.toDouble();
      final x = freqToX(hz, w);
      final isActive = activeBand == i;
      final label = hz >= 1000
          ? (hz % 1000 == 0
              ? '${(hz / 1000).toInt()}k'
              : '${(hz / 1000).toStringAsFixed(1)}k')
          : '${hz.toInt()}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isActive ? 0.75 : 0.38),
            fontSize: 9.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, h - botPad + 7));
    }

    // ── EQ curve ────────────────────────────────────────────────────────────
    final pts = List.generate(
      bands.length,
      (i) => Offset(
        freqToX(bands[i].centerFrequency.toDouble(), w),
        gainToY(i < gains.length ? gains[i] : 0.0),
      ),
    );
    if (pts.isEmpty) return;

    canvas.save();
    canvas.clipRect(drawRect.inflate(2));

    if (pts.length == 1) {
      canvas.drawCircle(pts.first, 6, Paint()..color = ec);
      canvas.restore();
      return;
    }

    // Smooth cubic bezier
    final curvePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp = (pts[i].dx + pts[i + 1].dx) / 2;
      curvePath.cubicTo(
          cp, pts[i].dy, cp, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    // Gradient fill between curve and 0 dB line
    final zeroY = gainToY(0).clamp(drawRect.top, drawRect.bottom);
    final fillPath = Path.from(curvePath)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ec.withValues(alpha: 0.28),
            ec.withValues(alpha: 0.03),
          ],
        ).createShader(drawRect),
    );

    // Curve stroke
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = ec
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // ── Band control points ─────────────────────────────────────────────────
    for (int i = 0; i < pts.length; i++) {
      final pt = pts[i];
      final isActive = activeBand == i;
      if (isActive) {
        canvas.drawCircle(
            pt, 22, Paint()..color = ec.withValues(alpha: 0.08));
        canvas.drawCircle(
            pt, 14, Paint()..color = ec.withValues(alpha: 0.2));
      }
      canvas.drawCircle(pt, isActive ? 7.5 : 5.5, Paint()..color = ec);
      canvas.drawCircle(
        pt,
        isActive ? 7.5 : 5.5,
        Paint()
          ..color = Colors.white.withValues(alpha: isActive ? 1.0 : 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 2.0 : 1.5,
      );

      // dB tooltip shown while the band is being dragged
      if (isActive) {
        final db = i < gains.length ? gains[i] : 0.0;
        final label = db > 0
            ? '+${db.toStringAsFixed(1)} dB'
            : '${db.toStringAsFixed(1)} dB';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: ec,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelY = pt.dy > topPad + 30 ? pt.dy - 30 : pt.dy + 20;
        final bgRect = Rect.fromLTWH(
          pt.dx - tp.width / 2 - 7,
          labelY - 5,
          tp.width + 14,
          tp.height + 10,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
          Paint()..color = Colors.black.withValues(alpha: 0.75),
        );
        tp.paint(canvas, Offset(pt.dx - tp.width / 2, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) {
    if (old.enabled != enabled) return true;
    if (old.activeBand != activeBand) return true;
    if (old.color != color) return true;
    if (old.width != width) return true;
    if (old.gains.length != gains.length) return true;
    for (int i = 0; i < gains.length; i++) {
      if ((old.gains[i] - gains[i]).abs() > 0.005) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Band sliders row
// ─────────────────────────────────────────────────────────────────────────────

class _BandSliders extends StatelessWidget {
  final AndroidEqualizerParameters params;
  final List<double> gains;
  final bool enabled;
  final void Function(int index, double gain) onChanged;

  const _BandSliders({
    required this.params,
    required this.gains,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bandCount = params.bands.length;
    Widget row;
    if (bandCount > 7) {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < bandCount; i++)
              SizedBox(
                width: 56,
                child: _BandFader(
                  band: params.bands[i],
                  gain: gains[i],
                  minDb: params.minDecibels.toDouble(),
                  maxDb: params.maxDecibels.toDouble(),
                  enabled: enabled,
                  bandIndex: i,
                  totalBands: bandCount,
                  onChanged: (v) => onChanged(i, v),
                ),
              ),
          ],
        ),
      );
    } else {
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < bandCount; i++)
            Expanded(
              child: _BandFader(
                band: params.bands[i],
                gain: gains[i],
                minDb: params.minDecibels.toDouble(),
                maxDb: params.maxDecibels.toDouble(),
                enabled: enabled,
                bandIndex: i,
                totalBands: bandCount,
                onChanged: (v) => onChanged(i, v),
              ),
            ),
        ],
      );
    }
    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: row,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single band fader  (warm bass → primary mid → cool treble gradient)
// ─────────────────────────────────────────────────────────────────────────────

class _BandFader extends StatelessWidget {
  final AndroidEqualizerBand band;
  final double gain;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final int bandIndex;
  final int totalBands;
  final ValueChanged<double> onChanged;

  const _BandFader({
    required this.band,
    required this.gain,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.bandIndex,
    required this.totalBands,
    required this.onChanged,
  });

  Color _bandColor(BuildContext context) {
    final t = totalBands > 1 ? bandIndex / (totalBands - 1) : 0.5;
    final primary = Theme.of(context).colorScheme.primary;
    if (t <= 0.5) {
      return Color.lerp(const Color(0xFFFF8C42), primary, t * 2)!;
    }
    return Color.lerp(primary, const Color(0xFF8B9EFF), (t - 0.5) * 2)!;
  }

  String _fmtDb(double db) {
    if (db.abs() < 0.05) return '0';
    return db > 0 ? '+${db.toStringAsFixed(1)}' : db.toStringAsFixed(1);
  }

  String _fmtFreq(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble()
          ? '${k.round()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return hz.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bc = _bandColor(context);
    final textColor = isDark ? Colors.white70 : Colors.black54;
    final active = gain.abs() > 0.05;

    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          _fmtDb(gain),
          style: TextStyle(
            fontSize: 11,
            fontFamily: FontConstants.fontFamily,
            color: enabled
                ? (active ? bc : textColor)
                : textColor.withValues(alpha: 0.4),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor:
                    enabled ? bc : bc.withValues(alpha: 0.35),
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                thumbColor: enabled ? bc : bc.withValues(alpha: 0.4),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  disabledThumbRadius: 6,
                ),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 18),
                overlayColor: bc.withValues(alpha: 0.2),
              ),
              child: Slider(
                min: minDb,
                max: maxDb,
                value: gain.clamp(minDb, maxDb),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _fmtFreq(band.centerFrequency.toDouble()),
          style: TextStyle(
            fontSize: 10,
            fontFamily: FontConstants.fontFamily,
            color: textColor.withValues(alpha: enabled ? 1.0 : 0.4),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Presets section  (built-in + user-created)
// ─────────────────────────────────────────────────────────────────────────────

class _PresetsSection extends StatelessWidget {
  final EqualizerService svc;
  final VoidCallback onSavePressed;

  const _PresetsSection({required this.svc, required this.onSavePressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Built-in ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'BUILT-IN',
            style: TextStyle(
              fontSize: 11,
              fontFamily: FontConstants.fontFamily,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: EqualizerService.builtInPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = EqualizerService.builtInPresets[i];
              final selected = svc.preset == p.name;
              return _PresetChip(
                label: p.name,
                selected: selected,
                enabled: svc.enabled,
                onTap: svc.enabled ? () => svc.applyPreset(p) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Your Presets ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
          child: Row(
            children: [
              Text(
                'YOUR PRESETS',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: FontConstants.fontFamily,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: svc.enabled ? onSavePressed : null,
                icon: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: svc.enabled ? cs.primary : Colors.grey,
                ),
                label: Text(
                  'Save current',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.w600,
                    color: svc.enabled ? cs.primary : Colors.grey,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        if (svc.customPresets.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Dial in your sound, then tap "Save current".',
              style: TextStyle(
                fontSize: 13,
                fontFamily: FontConstants.fontFamily,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          )
        else
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: svc.customPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = svc.customPresets[i];
                final selected = svc.preset == p.name;
                return _PresetChip(
                  label: p.name,
                  selected: selected,
                  enabled: svc.enabled,
                  isCustom: true,
                  onTap: svc.enabled ? () => svc.applyPreset(p) : null,
                  onDelete: () => svc.deleteCustomPreset(p.name),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preset chip  (built-in and custom variants)
// ─────────────────────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool isCustom;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.enabled,
    this.isCustom = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          left: 14,
          right: isCustom ? 4 : 14,
          top: 0,
          bottom: 0,
        ),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: enabled ? 1.0 : 0.5)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? (enabled
                        ? cs.onPrimary
                        : cs.onPrimary.withValues(alpha: 0.7))
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            if (isCustom) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: selected
                        ? cs.onPrimary.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../main.dart' show equalizer;
import '../../../shared/services/equalizer_service.dart';
import '../../../shared/widgets/app_background.dart';
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
  bool _curveDragging = false;

  @override
  void initState() {
    super.initState();
    // Fallback init in case the app-level eager init hasn't run yet.
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
          final l10n = AppLocalizations.of(ctx);
          void validate() {
            final name = controller.text.trim();
            if (name.isEmpty) {
              setState(() => errorMsg = l10n.eqPresetNameEmpty);
              return;
            }
            final isBuiltIn = EqualizerService.builtInPresets
                .any((p) => p.name.toLowerCase() == name.toLowerCase());
            if (isBuiltIn) {
              setState(() => errorMsg = l10n.eqPresetNameBuiltIn(name));
              return;
            }
            svc.saveCurrentAsPreset(name);
            Navigator.pop(ctx);
          }

          return Dialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.eqSavePreset,
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.eqPresetNameHint,
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
                          color: Theme.of(ctx).colorScheme.primary,
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          l10n.cancel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: validate,
                        child: Text(
                          l10n.save,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.primary,
                            fontFamily: FontConstants.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    // Do NOT call controller.dispose() here. showDialog's future resolves
    // when Navigator.pop() is called, but the dialog's closing animation
    // continues running after that. The TextField still has focus during
    // the animation and fires clearComposing() on focus-loss — which
    // crashes if the controller was already disposed. TextEditingController
    // holds no OS resources, so letting the GC reclaim it is safe.
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return AppBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
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
          AppLocalizations.of(context).eqTitle,
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Consumer<EqualizerService>(
            builder: (_, svc, __) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: svc.initialized
                    ? () => svc.setEnabled(equalizer, !svc.enabled)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: svc.enabled
                        ? cs.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    svc.enabled ? AppLocalizations.of(context).eqOn : AppLocalizations.of(context).eqOff,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: svc.enabled
                          ? cs.onPrimary
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).eqNotAvailable,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: FontConstants.fontFamily,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => svc.openSystemEqualizer(),
                      child: Text(
                        AppLocalizations.of(context).eqOpenSystem,
                        style: TextStyle(fontFamily: FontConstants.fontFamily),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final gains = params.bands.map((b) => b.gain).toList();
          return ListView(
            padding: EdgeInsets.zero,
            // Lock scroll while the user is dragging a band on the EQ curve.
            // Without this, the ListView's VerticalDragRecognizer wins the
            // gesture arena and the page scrolls instead of the band moving.
            physics: _curveDragging
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            children: [
              const SizedBox(height: 8),
              // ── Interactive EQ curve ─────────────────────────────────────
              _InteractiveCurve(
                params: params,
                gains: gains,
                enabled: svc.enabled,
                onBandChanged: (i, v) => svc.setBandGain(i, v),
                onDragActiveChanged: (active) {
                  setState(() => _curveDragging = active);
                },
              ),
              const SizedBox(height: 10),
              // ── Band value read-out ───────────────────────────────────────
              _BandValueRow(
                params: params,
                gains: gains,
                enabled: svc.enabled,
                onResetBand: (i) => svc.setBandGain(i, 0.0),
                onResetAll: () {
                  for (int i = 0; i < params.bands.length; i++) {
                    svc.setBandGain(i, 0.0);
                  }
                },
              ),
              const SizedBox(height: 20),
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
  final void Function(bool active) onDragActiveChanged;

  const _InteractiveCurve({
    required this.params,
    required this.gains,
    required this.enabled,
    required this.onBandChanged,
    required this.onDragActiveChanged,
  });

  @override
  State<_InteractiveCurve> createState() => _InteractiveCurveState();
}

class _InteractiveCurveState extends State<_InteractiveCurve> {
  int? _activeBand;

  static const double _kH       = 260.0;
  static const double _kTopPad  = 20.0;
  static const double _kBotPad  = 28.0; // frequency label space
  static const double _kLeftPad = 40.0; // dB label space
  static const double _kRightPad = 16.0;
  static const double _kBandInset = 20.0; // extra inset for outermost dots

  double _freqToX(double hz, double w) {
    final bands = widget.params.bands;
    final usableLeft = _kLeftPad + _kBandInset;
    final usableRight = _kRightPad + _kBandInset;
    if (bands.length < 2) return (w - usableLeft - usableRight) / 2 + usableLeft;
    final minHz = bands.first.centerFrequency.toDouble();
    final maxHz = bands.last.centerFrequency.toDouble();
    if (minHz == maxHz) return (w - usableLeft - usableRight) / 2 + usableLeft;
    final t = (math.log(hz) - math.log(minHz)) /
        (math.log(maxHz) - math.log(minHz));
    return usableLeft + t * (w - usableLeft - usableRight);
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.enabled
                ? (event) {
                    final band = _nearestBand(event.localPosition, w);
                    if (band != null) {
                      setState(() => _activeBand = band);
                      widget.onDragActiveChanged(true);
                    }
                  }
                : null,
            onPointerMove: (event) {
              final band = _activeBand;
              if (band == null) return;
              widget.onBandChanged(band, _yToGain(event.localPosition.dy));
            },
            onPointerUp: (event) {
              if (_activeBand != null) {
                setState(() => _activeBand = null);
                widget.onDragActiveChanged(false);
              }
            },
            onPointerCancel: (event) {
              if (_activeBand != null) {
                setState(() => _activeBand = null);
                widget.onDragActiveChanged(false);
              }
            },
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
// Band value read-out row  (shows current dB per band; double-tap to reset)
// ─────────────────────────────────────────────────────────────────────────────

class _BandValueRow extends StatelessWidget {
  final AndroidEqualizerParameters params;
  final List<double> gains;
  final bool enabled;
  final void Function(int bandIndex) onResetBand;
  final VoidCallback onResetAll;

  const _BandValueRow({
    required this.params,
    required this.gains,
    required this.enabled,
    required this.onResetBand,
    required this.onResetAll,
  });

  String _fmtDb(double db) {
    if (db.abs() < 0.05) return '0.0';
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

  bool get _isFlat => gains.every((g) => g.abs() < 0.05);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bands = params.bands;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Band value chips
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
              child: Row(
                children: [
                  for (int i = 0; i < bands.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onDoubleTap: enabled ? () => onResetBand(i) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  fontSize: 12,
                                  fontWeight: gains[i].abs() > 0.05
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: enabled
                                      ? (gains[i].abs() > 0.05
                                          ? cs.primary
                                          : dimColor)
                                      : dimColor.withValues(alpha: 0.4),
                                ),
                                child: Text(
                                  _fmtDb(gains[i]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fmtFreq(
                                    bands[i].centerFrequency.toDouble()),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white.withValues(
                                          alpha: enabled ? 0.35 : 0.15)
                                      : Colors.black.withValues(
                                          alpha: enabled ? 0.38 : 0.18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Reset all divider + button
            if (!_isFlat) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              TextButton(
                onPressed: enabled ? onResetAll : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 38),
                  padding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).eqResetAllBands,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? cs.primary.withValues(alpha: 0.75)
                        : dimColor.withValues(alpha: 0.4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Presets section  (built-in + user-created)
// ─────────────────────────────────────────────────────────────────────────────

class _PresetsSection extends StatelessWidget {
  final EqualizerService svc;
  final VoidCallback onSavePressed;

  const _PresetsSection({required this.svc, required this.onSavePressed});

  TextStyle _labelStyle(bool isDark) => TextStyle(
        fontSize: 11,
        fontFamily: FontConstants.fontFamily,
        fontWeight: FontWeight.w700,
        color: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.4),
        letterSpacing: 1.2,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Built-in presets ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(AppLocalizations.of(context).eqPresetsLabel, style: _labelStyle(isDark)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: EqualizerService.builtInPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = EqualizerService.builtInPresets[i];
              final selected = svc.preset == p.name;
              return _PresetChip(
                label: p.name,
                selected: selected,
                eqEnabled: svc.enabled,
                onTap: () {
                  if (!svc.enabled) svc.setEnabled(equalizer, true);
                  svc.applyPreset(p);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Your Presets ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(
            children: [
              Text(AppLocalizations.of(context).eqYourPresetsLabel, style: _labelStyle(isDark)),
              const Spacer(),
              TextButton.icon(
                onPressed: onSavePressed,
                icon: Icon(Icons.add_rounded, size: 16, color: cs.primary),
                label: Text(
                  AppLocalizations.of(context).eqSaveCurrent,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              AppLocalizations.of(context).eqEmptyPresets,
              style: TextStyle(
                fontSize: 13,
                fontFamily: FontConstants.fontFamily,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.28),
              ),
            ),
          )
        else
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              itemCount: svc.customPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = svc.customPresets[i];
                final selected = svc.preset == p.name;
                return _PresetChip(
                  label: p.name,
                  selected: selected,
                  eqEnabled: svc.enabled,
                  isCustom: true,
                  onTap: () {
                    if (!svc.enabled) svc.setEnabled(equalizer, true);
                    svc.applyPreset(p);
                  },
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
  final bool eqEnabled;
  final bool isCustom;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.eqEnabled,
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
              ? cs.primary.withValues(alpha: eqEnabled ? 1.0 : 0.6)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
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
                    ? cs.onPrimary
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
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.35)),
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

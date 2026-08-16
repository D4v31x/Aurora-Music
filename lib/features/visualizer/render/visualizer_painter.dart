/// The sole renderer for all visualizer elements — a single [CustomPainter]
/// that dispatches per element type using plain `Canvas` calls (matching
/// this codebase's existing convention; no shaders anywhere else in the
/// app, see spec section 14/15). Consumes an already-resolved
/// [VisualizerRenderState] — no audio/binding logic happens here.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine_runtime/visualizer_engine.dart';
import '../model/visualizer_element.dart';
import '../model/visualizer_property.dart';
import '../model/visualizer_template.dart';
import 'image_element_resolver.dart';

class VisualizerPainter extends CustomPainter {
  final VisualizerRenderState state;
  final ImageElementResolver imageResolver;

  VisualizerPainter({required this.state, required this.imageResolver});

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.template.canvas;
    final scaleX = size.width / cfg.referenceWidth;
    final scaleY = size.height / cfg.referenceHeight;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = state.template.backgroundColor,
    );

    for (final resolvedLayer in state.layers) {
      final layer = resolvedLayer.layer;
      if (!layer.visible || layer.opacity <= 0) continue;

      final needsLayer = layer.opacity < 1.0 || layer.blendMode != BlendMode.srcOver;
      if (needsLayer) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()
            ..blendMode = layer.blendMode
            ..color = Color.fromRGBO(0, 0, 0, layer.opacity),
        );
      }

      for (final resolvedElement in resolvedLayer.elements) {
        if (!resolvedElement.element.visible) continue;
        _paintElement(canvas, resolvedElement, cfg, scaleX, scaleY);
      }

      if (needsLayer) canvas.restore();
    }
  }

  void _paintElement(
    Canvas canvas,
    ResolvedElement el,
    VisualizerCanvasConfig cfg,
    double scaleX,
    double scaleY,
  ) {
    switch (el.element.type) {
      case VisualizerElementType.rectangle:
        _paintRectangle(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.circle:
        _paintCircle(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.line:
        _paintLine(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.polygon:
        _paintPolygon(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.path:
        _paintPath(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.waveform:
        _paintWaveform(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.spectrumBars:
        _paintSpectrumBars(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.radialSpectrum:
        _paintRadialSpectrum(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.particles:
        _paintParticles(canvas, el, scaleX, scaleY);
      case VisualizerElementType.text:
        _paintText(canvas, el, cfg, scaleX, scaleY);
      case VisualizerElementType.image:
        _paintImage(canvas, el, cfg, scaleX, scaleY);
    }
  }

  // ── Shared property helpers ─────────────────────────────────────────────

  Color _colorFor(Color base, double hueShiftDeg, double opacity) {
    var color = base;
    if (hueShiftDeg != 0) {
      final hsv = HSVColor.fromColor(color);
      color = hsv.withHue((hsv.hue + hueShiftDeg) % 360).toColor();
    }
    return color.withValues(alpha: (color.a * opacity).clamp(0.0, 1.0));
  }

  (double cx, double cy, double scale, double rotationTurns, double opacity, double hue)
      _commonTransform(ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final cx = el.value(PropertyKey.positionX, cfg.referenceWidth / 2) * sx;
    final cy = el.value(PropertyKey.positionY, cfg.referenceHeight / 2) * sy;
    final scale = el.value(PropertyKey.scale, 1.0);
    final rotationTurns = el.value(PropertyKey.rotation, 0.0);
    final opacity = el.value(PropertyKey.opacity, 1.0).clamp(0.0, 1.0);
    final hue = el.value(PropertyKey.hueShift, 0.0);
    return (cx, cy, scale, rotationTurns, opacity, hue);
  }

  double _uniformScale(double sx, double sy) => (sx + sy) / 2;

  // ── Shape painters ──────────────────────────────────────────────────────

  void _paintRectangle(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final (cx, cy, scale, rotationTurns, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final w = el.value(PropertyKey.width, 100) * sx * scale;
    final h = el.value(PropertyKey.height, 100) * sy * scale;
    final cornerRadius = el.value(PropertyKey.cornerRadius, 0.0) * _uniformScale(sx, sy);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationTurns * 2 * math.pi);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final paint = Paint()..color = _colorFor(el.element.color, hue, opacity);
    final blur = el.value(PropertyKey.blurAmount, 0.0);
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)), paint);
    canvas.restore();
  }

  void _paintCircle(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final (cx, cy, scale, _, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final diameter = el.value(PropertyKey.width, 100) * scale * _uniformScale(sx, sy);
    final paint = Paint()..color = _colorFor(el.element.color, hue, opacity);
    final blur = el.value(PropertyKey.blurAmount, 0.0);
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(Offset(cx, cy), diameter / 2, paint);
  }

  void _paintLine(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final (cx, cy, scale, rotationTurns, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final length = el.value(PropertyKey.width, 100) * scale * _uniformScale(sx, sy);
    final strokeWidth =
        el.value(PropertyKey.strokeWidth, 2.0) * _uniformScale(sx, sy);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationTurns * 2 * math.pi);
    final paint = Paint()
      ..color = _colorFor(el.element.color, hue, opacity)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-length / 2, 0), Offset(length / 2, 0), paint);
    canvas.restore();
  }

  void _paintPolygon(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final polygon = el.element as PolygonElement;
    final (cx, cy, scale, rotationTurns, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final radius = el.value(PropertyKey.width, 100) / 2 * scale * _uniformScale(sx, sy);
    final sides = polygon.sides.clamp(3, 32);

    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotationTurns * 2 * math.pi + i / sides * 2 * math.pi;
      final point = Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _colorFor(el.element.color, hue, opacity));
  }

  void _paintPath(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final pathElement = el.element as PathElement;
    if (pathElement.points.length < 2) return;
    final (cx, cy, scale, _, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final w = el.value(PropertyKey.width, 100) * scale * sx;
    final h = el.value(PropertyKey.height, 100) * scale * sy;
    final strokeWidth =
        el.value(PropertyKey.strokeWidth, 2.0) * _uniformScale(sx, sy);

    final path = Path();
    for (var i = 0; i < pathElement.points.length; i++) {
      final (px, py) = pathElement.points[i];
      final point = Offset(cx - w / 2 + px * w, cy - h / 2 + py * h);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _colorFor(el.element.color, hue, opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _paintWaveform(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    // Renders nothing (not a crash) when waveform data isn't available yet
    // — matches "must continue functioning with no data".
    final waveform = state.frame.waveform;
    if (waveform.isEmpty) return;

    final (cx, cy, scale, _, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final w = el.value(PropertyKey.width, cfg.referenceWidth * 0.8) * scale * sx;
    final h = el.value(PropertyKey.height, 150) * scale * sy;
    final amplitude = el.value(PropertyKey.waveformAmplitude, 1.0);
    final strokeWidth = el.value(PropertyKey.strokeWidth, 2.0) * _uniformScale(sx, sy);

    final path = Path();
    for (var i = 0; i < waveform.length; i++) {
      final x = cx - w / 2 + w * i / (waveform.length - 1);
      final y = cy - waveform[i] * (h / 2) * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _colorFor(el.element.color, hue, opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _paintSpectrumBars(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final barsElement = el.element as SpectrumBarsElement;
    final spectrum = state.frame.spectrum;
    if (spectrum.isEmpty) return;

    final (cx, cy, scale, _, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final w = el.value(PropertyKey.width, cfg.referenceWidth * 0.9) * scale * sx;
    final h = el.value(PropertyKey.height, 200) * scale * sy;
    final sensitivity = el.value(PropertyKey.spectrumSensitivity, 1.0);
    final barCount = barsElement.barCount.clamp(1, 256);
    final barWidth = w / barCount;
    final paint = Paint()..color = _colorFor(el.element.color, hue, opacity);

    for (var i = 0; i < barCount; i++) {
      final specIndex = (i * spectrum.length / barCount).floor().clamp(0, spectrum.length - 1);
      final magnitude = (spectrum[specIndex] * sensitivity).clamp(0.0, 1.0);
      final barHeight = magnitude * h;
      final x = cx - w / 2 + i * barWidth;
      final rect = Rect.fromLTWH(x, cy + h / 2 - barHeight, barWidth * 0.8, barHeight);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(barWidth * 0.2)), paint);
    }
  }

  void _paintRadialSpectrum(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final radialElement = el.element as RadialSpectrumElement;
    final spectrum = state.frame.spectrum;
    if (spectrum.isEmpty) return;

    final (cx, cy, scale, rotationTurns, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final baseRadius = el.value(PropertyKey.width, 100) / 2 * scale * _uniformScale(sx, sy);
    final maxExtra = el.value(PropertyKey.height, 100) * scale * _uniformScale(sx, sy);
    final sensitivity = el.value(PropertyKey.spectrumSensitivity, 1.0);
    final strokeWidth = el.value(PropertyKey.strokeWidth, 3.0) * _uniformScale(sx, sy);
    final barCount = radialElement.barCount.clamp(1, 256);
    final paint = Paint()
      ..color = _colorFor(el.element.color, hue, opacity)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final specIndex = (i * spectrum.length / barCount).floor().clamp(0, spectrum.length - 1);
      final magnitude = (spectrum[specIndex] * sensitivity).clamp(0.0, 1.0);
      final angle = rotationTurns * 2 * math.pi + i / barCount * 2 * math.pi;
      final inner = Offset(cx + baseRadius * math.cos(angle), cy + baseRadius * math.sin(angle));
      final outer = Offset(
        cx + (baseRadius + magnitude * maxExtra) * math.cos(angle),
        cy + (baseRadius + magnitude * maxExtra) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintParticles(Canvas canvas, ResolvedElement el, double sx, double sy) {
    final particles = el.particles;
    if (particles == null || particles.isEmpty) return;
    final opacity = el.value(PropertyKey.opacity, 1.0).clamp(0.0, 1.0);
    final hue = el.value(PropertyKey.hueShift, 0.0);
    final scale = _uniformScale(sx, sy);

    for (final p in particles) {
      final paint = Paint()
        ..color = _colorFor(el.element.color, hue, opacity * p.alpha);
      canvas.drawCircle(Offset(p.x * sx, p.y * sy), (p.size / 2) * scale, paint);
    }
  }

  void _paintText(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final textElement = el.element as TextElement;
    if (textElement.text.isEmpty) return;
    final (cx, cy, scale, rotationTurns, opacity, hue) = _commonTransform(el, cfg, sx, sy);
    final fontSize = el.value(PropertyKey.height, 24) * scale * _uniformScale(sx, sy);

    final painter = TextPainter(
      text: TextSpan(
        text: textElement.text,
        style: TextStyle(
          color: _colorFor(el.element.color, hue, opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationTurns * 2 * math.pi);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintImage(
      Canvas canvas, ResolvedElement el, VisualizerCanvasConfig cfg, double sx, double sy) {
    final image = imageResolver.imageFor(el.element.id);
    if (image == null) return; // no artwork yet — draw nothing, not a crash

    final (cx, cy, scale, rotationTurns, opacity, _) = _commonTransform(el, cfg, sx, sy);
    final w = el.value(PropertyKey.width, cfg.referenceWidth * 0.7) * scale * sx;
    final h = el.value(PropertyKey.height, cfg.referenceWidth * 0.7) * scale * sy;
    final blur = el.value(PropertyKey.blurAmount, 0.0);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationTurns * 2 * math.pi);
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    if (blur > 0) {
      paint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    }
    final destRect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, destRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) => true;
}

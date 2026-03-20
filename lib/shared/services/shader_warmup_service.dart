import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;

/// Service responsible for optimizing shader performance
/// Precaches commonly used shaders for better application performance
class ShaderWarmupService {
  /// Precaches commonly used shaders to reduce initial render times
  /// This prevents jank when first rendering UI elements that use these shaders
  static Future<void> warmupShaders() async {
    final shaderWarmUpTask = Future(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const warmupRect = Rect.fromLTWH(0, 0, 100, 100);

      // Common UI shaders
      final shaders = [
        // Fade out gradient (used in lists, text overflow)
        painting.LinearGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
          stops: const [0.8, 1.0],
        ).createShader(warmupRect),

        // Bottom to top fade (used in backgrounds)
        painting.LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(warmupRect),

        // Glassmorphic overlay gradient
        painting.LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(warmupRect),

        // Radial gradient for artwork backgrounds
        painting.RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.3, 1.0],
        ).createShader(warmupRect),

        // Vertical gradient for app bars
        painting.LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ).createShader(warmupRect),

        // Sweep gradient for loading indicators
        painting.SweepGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.0),
            Colors.blue,
          ],
        ).createShader(warmupRect),
      ];

      // Draw with each shader to compile them
      for (final shader in shaders) {
        final paint = Paint()..shader = shader;
        canvas.drawRect(warmupRect, paint);
      }

      // Also warm up common paint operations
      _warmupPaintOperations(canvas);

      final picture = recorder.endRecording();
      await picture.toImage(100, 100);
    });

    await shaderWarmUpTask;
  }

  /// Warm up common paint operations to pre-compile their shaders
  static void _warmupPaintOperations(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 50, 50);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Solid color paints
    final solidPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, solidPaint);
    canvas.drawRRect(rrect, solidPaint);
    canvas.drawCircle(const Offset(25, 25), 20, solidPaint);

    // Stroke paints
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, strokePaint);
    canvas.drawRRect(rrect, strokePaint);
    canvas.drawCircle(const Offset(25, 25), 20, strokePaint);

    // Shadow paint
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect, shadowPaint);
  }
}

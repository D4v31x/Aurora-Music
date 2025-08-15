import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;

/// Service responsible for optimizing shader performance
/// Precaches commonly used shaders for better application performance
class ShaderWarmupService {
  /// Precaches commonly used shaders to reduce initial render times
  static Future<void> warmupShaders() async {
    final shaderWarmUpTask = Future(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final shaders = [
        // Common gradient for UI elements
        painting.LinearGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
          stops: const [0.8, 1.0],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),

        // Common gradient for backgrounds
        painting.LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
      ];

      for (final shader in shaders) {
        final paint = Paint()..shader = shader;
        canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
      }

      final picture = recorder.endRecording();
      await picture.toImage(100, 100);
    });

    await shaderWarmUpTask;
  }
}
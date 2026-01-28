import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mesh/mesh.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/performance_mode_provider.dart';

class GrainyGradientBackground extends HookWidget {
  final Widget child;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double noiseOpacity;

  /// If true, forces simple mode regardless of device performance
  final bool forceSimple;

  const GrainyGradientBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF0F1419), // Dark gray
      Color(0xFF1A2332), // Dark blue-gray
      Color(0xFF0D1B2A), // Deep blue
    ],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.noiseOpacity = 0.05,
    this.forceSimple = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check performance mode - use simple background for low-end devices
    final performanceProvider = context.watch<PerformanceModeProvider>();
    final useSimpleBackground = forceSimple ||
        performanceProvider.isLowEndDevice ||
        !performanceProvider.shouldEnableAnimatedGradients;

    if (useSimpleBackground) {
      return _buildSimpleBackground(context);
    }

    final controller = useAnimationController(
      duration: const Duration(seconds: 12),
    )..repeat();

    final t = useAnimation(controller);

    return Stack(
      children: [
        // Animated mesh gradient background
        Positioned.fill(
          child: _buildMeshGradient(t),
        ),
        // Content
        child,
      ],
    );
  }

  /// Simple solid background for low-end devices
  /// Uses a solid Material You surface color for better performance
  Widget _buildSimpleBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: child,
    );
  }

  Widget _buildMeshGradient(double t) {
    final sin1 = math.sin(t * 2 * math.pi);
    final cos1 = math.cos(t * 2 * math.pi);
    final sin2 = math.sin(t * 2 * math.pi + math.pi / 2);
    final cos2 = math.cos(t * 2 * math.pi + math.pi / 2);
    final sin3 = math.sin(t * 2 * math.pi + math.pi);
    final cos3 = math.cos(t * 2 * math.pi + math.pi);

    // Smooth color interpolation using the same colors
    // This creates a seamless loop without discrete color shifts
    final List<Color> rotatedColors =
        colors.length >= 3 ? [colors[0], colors[1], colors[2]] : colors;

    return OMeshGradient(
      tessellation: 20,
      size: Size.infinite,
      mesh: OMeshRect(
        width: 5,
        height: 5,
        colorSpace: OMeshColorSpace.lab,
        fallbackColor: colors.first,
        vertices: [
          // Row 1 - Top edge with slight movement
          (0.0, 0.0).v,
          (0.25 + sin1 * 0.03, 0.0).v,
          (0.5 + cos1 * 0.03, 0.0).v,
          (0.75 + sin2 * 0.03, 0.0).v,
          (1.0, 0.0).v,
          // Row 2 - More movement
          (0.0, 0.25 + sin1 * 0.02).v,
          (0.25 + sin1 * 0.08, 0.25 + cos1 * 0.08).v,
          (0.5 + cos2 * 0.08, 0.25 + sin2 * 0.08).v,
          (0.75 + sin3 * 0.08, 0.25 + cos3 * 0.08).v,
          (1.0, 0.25 + cos1 * 0.02).v,
          // Row 3 - Maximum movement
          (0.0, 0.5 + cos1 * 0.02).v,
          (0.25 + cos1 * 0.1, 0.5 + sin1 * 0.1).v,
          (0.5 + sin2 * 0.1, 0.5 + cos2 * 0.1).v,
          (0.75 + cos3 * 0.1, 0.5 + sin3 * 0.1).v,
          (1.0, 0.5 + sin1 * 0.02).v,
          // Row 4 - More movement
          (0.0, 0.75 + sin2 * 0.02).v,
          (0.25 + sin2 * 0.08, 0.75 + cos2 * 0.08).v,
          (0.5 + cos3 * 0.08, 0.75 + sin3 * 0.08).v,
          (0.75 + sin1 * 0.08, 0.75 + cos1 * 0.08).v,
          (1.0, 0.75 + cos2 * 0.02).v,
          // Row 5 - Bottom edge with slight movement
          (0.0, 1.0).v,
          (0.25 + cos2 * 0.03, 1.0).v,
          (0.5 + sin3 * 0.03, 1.0).v,
          (0.75 + cos3 * 0.03, 1.0).v,
          (1.0, 1.0).v,
        ],
        colors: [
          // Row 1
          rotatedColors[0],
          rotatedColors[1],
          rotatedColors[2],
          rotatedColors[0],
          rotatedColors[1],
          // Row 2
          rotatedColors[2],
          rotatedColors[0],
          rotatedColors[1],
          rotatedColors[2],
          rotatedColors[0],
          // Row 3
          rotatedColors[1],
          rotatedColors[2],
          rotatedColors[0],
          rotatedColors[1],
          rotatedColors[2],
          // Row 4
          rotatedColors[0],
          rotatedColors[1],
          rotatedColors[2],
          rotatedColors[0],
          rotatedColors[1],
          // Row 5
          rotatedColors[2],
          rotatedColors[0],
          rotatedColors[1],
          rotatedColors[2],
          rotatedColors[0],
        ],
      ),
    );
  }
}

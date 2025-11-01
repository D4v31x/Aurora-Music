import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';
import 'dart:math' as math;

class GrainyGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double noiseOpacity;

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
  });

  @override
  State<GrainyGradientBackground> createState() =>
      _GrainyGradientBackgroundState();
}

class _GrainyGradientBackgroundState extends State<GrainyGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated mesh gradient background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final sin1 = math.sin(t * 2 * math.pi);
              final cos1 = math.cos(t * 2 * math.pi);
              final sin2 = math.sin(t * 2 * math.pi + math.pi / 2);
              final cos2 = math.cos(t * 2 * math.pi + math.pi / 2);
              final sin3 = math.sin(t * 2 * math.pi + math.pi);
              final cos3 = math.cos(t * 2 * math.pi + math.pi);

              // Smooth color interpolation using the same colors
              // This creates a seamless loop without discrete color shifts
              final List<Color> rotatedColors = widget.colors.length >= 3
                  ? [widget.colors[0], widget.colors[1], widget.colors[2]]
                  : widget.colors;

              return OMeshGradient(
                tessellation: 20,
                size: Size.infinite,
                mesh: OMeshRect(
                  width: 5,
                  height: 5,
                  colorSpace: OMeshColorSpace.lab,
                  fallbackColor: widget.colors.first,
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
            },
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}

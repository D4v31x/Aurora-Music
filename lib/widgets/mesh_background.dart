import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mesh/mesh.dart';

/// Mesh gradient background that uses the mesh package
/// Colors are derived from artwork or use default colors when no artwork is available
class MeshBackground extends HookWidget {
  final List<Color> colors;
  final bool animated;
  final Duration animationDuration;
  final double animationSpeed;

  const MeshBackground({
    super.key,
    required this.colors,
    this.animated = true,
    this.animationDuration =
        const Duration(seconds: 3), // Much faster animation (was 5)
    this.animationSpeed = 2.5, // Much faster speed (was 1.2)
  });

  // Initial vertex positions for animation reference - flowing organic pattern
  static final List<OVertex> _baseVertices = [
    // Top row with slight curve
    (-0.15, -0.2).v, (0.25, -0.15).v, (0.75, -0.18).v, (1.15, -0.12).v,
    // Upper middle row with wave pattern
    (-0.18, 0.3).v, (0.35, 0.28).v, (0.65, 0.35).v, (1.22, 0.25).v,
    // Lower middle row with flowing curves
    (-0.12, 0.7).v, (0.28, 0.72).v, (0.78, 0.68).v, (1.18, 0.75).v,
    // Bottom row with gentle waves
    (-0.2, 1.15).v, (0.22, 1.18).v, (0.82, 1.12).v, (1.25, 1.2).v,
  ];

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
      duration: animationDuration,
    );

    // Handle animation state
    useEffect(() {
      if (animated) {
        animationController.repeat();
      } else {
        animationController.stop();
      }
      return null;
    }, [animated]);

    final animationValue = useAnimation(
      Tween<double>(begin: 0.0, end: 2 * pi).animate(animationController),
    );

    // Ensure we have at least 3 colors for a rich mesh gradient
    final gradientColors = _ensureColors(colors);

    if (!animated) {
      return RepaintBoundary(
        child: OMeshGradient(
          mesh: OMeshRect(
            width: 4,
            height: 4,
            fallbackColor: gradientColors.first,
            colorSpace: OMeshColorSpace.lab,
            vertices: _baseVertices,
            colors: _getColorsList(gradientColors),
          ),
        ),
      );
    }

    final animatedVertices = _animateVertices(animationValue, animationSpeed);

    return RepaintBoundary(
      child: OMeshGradient(
        mesh: OMeshRect(
          width: 4,
          height: 4,
          fallbackColor: gradientColors.first,
          colorSpace: OMeshColorSpace.lab,
          vertices: animatedVertices,
          colors: _getColorsList(gradientColors),
        ),
      ),
    );
  }

  // Generate animated vertices based on the animation value with flowing motion
  static List<OVertex> _animateVertices(
      double animationValue, double animationSpeed) {
    final List<OVertex> animatedVertices = [];
    final random = Random(42); // Fixed seed for deterministic movement

    // Apply flowing wave motion to each vertex
    for (int i = 0; i < _baseVertices.length; i++) {
      final baseVertex = _baseVertices[i];
      final rowIndex = i ~/ 4; // 0, 1, 2, 3 for each row (4x4 grid)
      final colIndex = i % 4; // 0, 1, 2, 3 for each column

      // Create flowing wave patterns with different frequencies for organic motion
      final baseFreqX = 0.4 + (rowIndex * 0.1) + random.nextDouble() * 0.2;
      final baseFreqY = 0.3 + (colIndex * 0.1) + random.nextDouble() * 0.2;

      // Phase offsets for wave motion
      final phaseX = (colIndex * 0.5) + (rowIndex * 0.3);
      final phaseY = (rowIndex * 0.7) + (colIndex * 0.4);

      // Create flowing motion with larger varying amplitudes for more dramatic movement
      final amplitudeX =
          0.15 + (sin(rowIndex + colIndex) * 0.08); // Doubled from 0.08 + 0.02
      final amplitudeY =
          0.12 + (cos(rowIndex - colIndex) * 0.06); // Doubled from 0.06 + 0.02

      // Apply flowing wave motion with increased speed
      final flowTime =
          animationValue * animationSpeed * 2.0; // Double the speed multiplier
      final xOffset = sin(flowTime * baseFreqX + phaseX) * amplitudeX;
      final yOffset = cos(flowTime * baseFreqY + phaseY) * amplitudeY;

      // Add secondary wave for more complex motion with larger amplitude
      final secondaryX = sin(flowTime * baseFreqX * 1.7 + phaseX + 1.5) *
          amplitudeX *
          0.6; // Increased from 0.3
      final secondaryY = cos(flowTime * baseFreqY * 1.3 + phaseY + 2.1) *
          amplitudeY *
          0.6; // Increased from 0.3

      final finalX = baseVertex.x + xOffset + secondaryX;
      final finalY = baseVertex.y + yOffset + secondaryY;

      // Create bezier control points for smoother curves with larger movement
      final bezierStrength =
          0.08 + random.nextDouble() * 0.04; // Doubled from 0.04 + 0.02
      final bezierPhase =
          flowTime * 0.8 + (i * 0.3); // Increased phase speed from 0.5

      final newVertex = OVertex(finalX, finalY);

      // Add bezier controls for flowing curves
      if (rowIndex > 0 && rowIndex < 3 && colIndex > 0 && colIndex < 3) {
        // Inner vertices get full bezier control
        final northCtrl = OVertex(
          finalX + sin(bezierPhase) * bezierStrength,
          finalY - bezierStrength * cos(bezierPhase + 0.5),
        );
        final eastCtrl = OVertex(
          finalX + bezierStrength * cos(bezierPhase + 1.0),
          finalY + sin(bezierPhase + 1.2) * bezierStrength,
        );
        final southCtrl = OVertex(
          finalX - sin(bezierPhase + 2.0) * bezierStrength,
          finalY + bezierStrength * cos(bezierPhase + 2.5),
        );
        final westCtrl = OVertex(
          finalX - bezierStrength * cos(bezierPhase + 3.0),
          finalY - sin(bezierPhase + 3.2) * bezierStrength,
        );

        animatedVertices.add(newVertex.bezier(
          north: northCtrl,
          east: eastCtrl,
          south: southCtrl,
          west: westCtrl,
        ));
      } else {
        // Edge vertices get simpler bezier controls
        final simpleCtrl = bezierStrength * 0.5;
        if (rowIndex == 0) {
          // Top edge
          animatedVertices.add(newVertex.bezier(
            south: OVertex(finalX, finalY + simpleCtrl),
          ));
        } else if (rowIndex == 3) {
          // Bottom edge
          animatedVertices.add(newVertex.bezier(
            north: OVertex(finalX, finalY - simpleCtrl),
          ));
        } else if (colIndex == 0) {
          // Left edge
          animatedVertices.add(newVertex.bezier(
            east: OVertex(finalX + simpleCtrl, finalY),
          ));
        } else if (colIndex == 3) {
          // Right edge
          animatedVertices.add(newVertex.bezier(
            west: OVertex(finalX - simpleCtrl, finalY),
          ));
        } else {
          animatedVertices.add(newVertex);
        }
      }
    }

    return animatedVertices;
  }

  // Helper method to create the colors list for 4x4 grid (16 colors)
  static List<Color?> _getColorsList(List<Color> gradientColors) {
    List<Color?> colors = [];

    // Generate 16 colors for 4x4 grid with flowing variations
    for (int i = 0; i < 16; i++) {
      final int rowIndex = i ~/ 4;
      final int colIndex = i % 4;

      // Calculate base color index with cycling
      final baseIndex = (i % gradientColors.length);
      final baseColor = gradientColors[baseIndex];

      // Create distance-based brightness variation
      final centerX = 1.5;
      final centerY = 1.5;
      final distance =
          sqrt(pow(rowIndex - centerX, 2) + pow(colIndex - centerY, 2));
      final normalizedDistance =
          distance / sqrt(4.5); // Max distance from center

      // Apply subtle variations
      final hsv = HSVColor.fromColor(baseColor);
      final brightness =
          (hsv.value * (0.7 + (0.3 * (1.0 - normalizedDistance))))
              .clamp(0.0, 1.0);
      final saturation =
          (hsv.saturation * (0.8 + (0.2 * (1.0 - normalizedDistance * 0.5))))
              .clamp(0.0, 1.0);

      // Subtle hue shift for variety
      final hueShift = (i * 5.0) % 15.0; // Small hue variations
      final adjustedHue = (hsv.hue + hueShift) % 360.0;

      final adjustedColor = HSVColor.fromAHSV(
        baseColor.opacity,
        adjustedHue,
        saturation,
        brightness,
      ).toColor();

      colors.add(adjustedColor);
    }

    return colors;
  }

  /// Ensure we have at least 3 colors for a rich gradient
  static List<Color> _ensureColors(List<Color> inputColors) {
    if (inputColors.isEmpty) {
      // Default colors - dark mode
      return [
        const Color(0xFF1A237E),
        const Color(0xFF311B92),
        const Color(0xFF512DA8),
        const Color(0xFF7B1FA2),
      ];
    }

    if (inputColors.length >= 3) {
      return inputColors.take(9).toList();
    }

    // Need to derive more colors
    final result = <Color>[];
    result.addAll(inputColors);

    if (inputColors.length == 1) {
      // Single color - create variations
      final baseColor = inputColors.first;
      final hsl = HSLColor.fromColor(baseColor);

      // Add a lighter version
      result.add(
          hsl.withLightness((hsl.lightness * 1.3).clamp(0.0, 1.0)).toColor());

      // Add a darker version
      result.add(
          hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor());

      // Add variations with different saturation
      result.add(
          hsl.withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0)).toColor());
      result.add(
          hsl.withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0)).toColor());
      result.add(
          hsl.withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0)).toColor());

      // Add variations with different hues
      result.add(hsl.withHue((hsl.hue + 10) % 360).toColor());
      result.add(hsl.withHue((hsl.hue + 20) % 360).toColor());
      result.add(hsl.withHue((hsl.hue + 30) % 360).toColor());
    } else if (inputColors.length == 2) {
      // Two colors - interpolate between them for more variations
      result.add(
          Color.lerp(inputColors[0], inputColors[1], 0.2) ?? inputColors[0]);
      result.add(
          Color.lerp(inputColors[0], inputColors[1], 0.4) ?? inputColors[0]);
      result.add(
          Color.lerp(inputColors[0], inputColors[1], 0.6) ?? inputColors[1]);
      result.add(
          Color.lerp(inputColors[0], inputColors[1], 0.8) ?? inputColors[1]);

      // Add some variations with different opacity
      result.add(inputColors[0].withOpacity(0.8));
      result.add(inputColors[1].withOpacity(0.8));
      result.add(inputColors[0].withOpacity(0.9));
    }

    // Take at most 9 colors (for a 3x3 mesh)
    return result.take(9).toList();
  }
}

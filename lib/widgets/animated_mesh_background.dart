import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';

/// Animated mesh gradient that transitions between color sets
/// Used for smooth transitions as songs change with continuous movement
class AnimatedMeshBackground extends StatefulWidget {
  final List<Color> colors;
  final Duration animationDuration;
  final Duration transitionDuration;
  final double animationSpeed;

  const AnimatedMeshBackground({
    super.key,
    required this.colors,
    this.animationDuration = const Duration(seconds: 3), // Much faster animation (was 5 seconds)
    this.transitionDuration = const Duration(milliseconds: 400), // Faster transitions (was 800ms)
    this.animationSpeed = 2.5, // Much faster movement speed (was 1.6)
  });

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground> 
    with SingleTickerProviderStateMixin {
  late List<Color> _currentColors;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Initial vertex positions for 4x4 grid with flowing pattern coverage
  final List<OVertex> _baseVertices = [
    // Row 0 (top)
    (-0.15, -0.15).v, (0.38, -0.12).v, (0.62, -0.12).v, (1.15, -0.15).v,
    // Row 1 
    (-0.12, 0.38).v, (0.35, 0.35).v, (0.65, 0.35).v, (1.12, 0.38).v,
    // Row 2
    (-0.12, 0.62).v, (0.35, 0.65).v, (0.65, 0.65).v, (1.12, 0.62).v,
    // Row 3 (bottom)
    (-0.15, 1.15).v, (0.38, 1.12).v, (0.62, 1.12).v, (1.15, 1.15).v,
  ];

  @override
  void initState() {
    super.initState();
    _currentColors = _ensureColors(widget.colors);
    
    // Create an animation controller for continuous movement
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    
    // Create a looping animation
    _animation = Tween<double>(
      begin: 0.0,
      end: 2 * pi, // Full rotation in radians
    ).animate(_animationController);
    
    // Start the animation in a loop
    _animationController.repeat();
  }

  @override
  void didUpdateWidget(AnimatedMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.colors != widget.colors) {
      setState(() {
        _currentColors = _ensureColors(widget.colors);
      });
    }
    
    // Update animation duration if it changed
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
      // Reset the animation with the new duration
      _animationController.reset();
      _animationController.repeat();
    }
    
    // Update animation speed if it changed
    if (oldWidget.animationSpeed != widget.animationSpeed) {
      _animationController.value = 0.0;
      _animationController.repeat();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Generate animated vertices based on the animation value
  List<OVertex> _animateVertices(double animationValue) {
    final List<OVertex> animatedVertices = [];
    final random = Random(42); // Fixed seed for deterministic movement
    
    // Apply different movement patterns to each vertex
    for (int i = 0; i < _baseVertices.length; i++) {
      final baseVertex = _baseVertices[i];
      final rowIndex = i ~/ 4; // 0, 1, 2, 3 for each row (4x4 grid)
      final colIndex = i % 4; // 0, 1, 2, 3 for each column
      
      // Create unique but consistent offsets for each vertex with moderate frequencies
      final xFrequency = 0.3 + random.nextDouble() * 0.3; // Moderate frequency for smoother movement
      final yFrequency = 0.3 + random.nextDouble() * 0.3; // Moderate frequency for smoother movement
      final xPhaseOffset = random.nextDouble() * pi * 2;
      final yPhaseOffset = random.nextDouble() * pi * 2;
      
      // Identify corner and edge vertices
      bool isCorner = (rowIndex == 0 && colIndex == 0) || // top-left
                      (rowIndex == 0 && colIndex == 2) || // top-right
                      (rowIndex == 2 && colIndex == 0) || // bottom-left
                      (rowIndex == 2 && colIndex == 2);   // bottom-right
      
      // Use smaller movement for edge and corner vertices but maintain coverage
      double edgeFactor = 1.0;
      if (isCorner) {
        edgeFactor = 0.3; // Minimal movement for corners but allow some movement for coverage
      } else if (colIndex == 0 || colIndex == 2 || rowIndex == 0 || rowIndex == 2) {
        edgeFactor = 0.5; // Reduced movement at edges but maintain coverage
      }
      
      // Slightly larger amplitude to ensure full coverage
      final amplitude = 0.06 * edgeFactor * widget.animationSpeed; // Increased amplitude for coverage
      
      // Apply smooth movement pattern with controlled speed
      final xOffset = sin(animationValue * xFrequency + xPhaseOffset) * amplitude;
      final yOffset = cos(animationValue * yFrequency + yPhaseOffset) * amplitude;
      
      // Create a new animated vertex with boundary constraints to ensure coverage
      final double newX = baseVertex.x + xOffset;
      final double newY = baseVertex.y + yOffset;
      
      // Allow slight overflow to ensure full coverage, no black edges
      final double boundedX = isCorner ? baseVertex.x : newX.clamp(-0.2, 1.2);
      final double boundedY = isCorner ? baseVertex.y : newY.clamp(-0.2, 1.2);
      
      final newVertex = OVertex(boundedX, boundedY);
      
      // Only add bezier control points for inner vertices, not edges or corners
      if (rowIndex == 1 && colIndex == 1) {
        // Center vertex can have more organic movement
        final bezierAmount = 0.05 + random.nextDouble() * 0.05; // Reduced bezier amount
        final northOffset = OVertex(newVertex.x, newVertex.y - bezierAmount);
        final eastOffset = OVertex(newVertex.x + bezierAmount, newVertex.y);
        
        // Only the center vertex gets bezier controls to keep edges smooth
        animatedVertices.add(newVertex.bezier(
          north: northOffset,
          east: eastOffset,
        ));
      } else if (!isCorner && (rowIndex == 1 || colIndex == 1)) {
        // Middle edge vertices get minimal bezier
        final bezierAmount = 0.03 + random.nextDouble() * 0.03; // Very small bezier
        
        if (colIndex == 1 && rowIndex == 0) { // Top middle
          final southOffset = OVertex(newVertex.x, newVertex.y + bezierAmount);
          animatedVertices.add(newVertex.bezier(south: southOffset));
        } else if (colIndex == 1 && rowIndex == 2) { // Bottom middle
          final northOffset = OVertex(newVertex.x, newVertex.y - bezierAmount);
          animatedVertices.add(newVertex.bezier(north: northOffset));
        } else if (rowIndex == 1 && colIndex == 0) { // Left middle
          final eastOffset = OVertex(newVertex.x + bezierAmount, newVertex.y);
          animatedVertices.add(newVertex.bezier(east: eastOffset));
        } else if (rowIndex == 1 && colIndex == 2) { // Right middle
          final westOffset = OVertex(newVertex.x - bezierAmount, newVertex.y);
          animatedVertices.add(newVertex.bezier(west: westOffset));
        } else {
          // Fallback case
          animatedVertices.add(newVertex);
        }
      } else {
        // For corners and other vertices, use no bezier to keep it smooth
        animatedVertices.add(newVertex);
      }
    }
    
    return animatedVertices;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final animatedVertices = _animateVertices(_animation.value);
          
          return AnimatedOMeshGradient(
            duration: widget.transitionDuration,
            size: Size.infinite,
            curve: Curves.easeInOut,
            mesh: OMeshRect(
              width: 4,
              height: 4,
              colorSpace: OMeshColorSpace.lab,
              fallbackColor: _currentColors.first,
              vertices: animatedVertices,
              colors: _getColorsList(_currentColors),
            ),
          );
        },
      ),
    );
  }
  
  /// Ensure we have at least 3 colors for a rich gradient
  List<Color> _ensureColors(List<Color> inputColors) {
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
      result.add(hsl.withLightness((hsl.lightness * 1.3).clamp(0.0, 1.0)).toColor());
      
      // Add a darker version
      result.add(hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor());
      
      // Add variations with different saturation
      result.add(hsl.withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0)).toColor());
      result.add(hsl.withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0)).toColor());
      result.add(hsl.withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0)).toColor());
      
      // Add variations with different hues
      result.add(hsl.withHue((hsl.hue + 10) % 360).toColor());
      result.add(hsl.withHue((hsl.hue + 20) % 360).toColor());
      result.add(hsl.withHue((hsl.hue + 30) % 360).toColor());
      
    } else if (inputColors.length == 2) {
      // Two colors - interpolate between them for more variations
      result.add(Color.lerp(inputColors[0], inputColors[1], 0.2) ?? inputColors[0]);
      result.add(Color.lerp(inputColors[0], inputColors[1], 0.4) ?? inputColors[0]);
      result.add(Color.lerp(inputColors[0], inputColors[1], 0.6) ?? inputColors[1]);
      result.add(Color.lerp(inputColors[0], inputColors[1], 0.8) ?? inputColors[1]);
      
      // Add some variations with different opacity
      result.add(inputColors[0].withOpacity(0.8));
      result.add(inputColors[1].withOpacity(0.8));
      result.add(inputColors[0].withOpacity(0.9));
    }
    
    // Take at most 16 colors (for a 4x4 mesh)
    return result.take(16).toList();
  }

  // Helper method to create the colors list for 4x4 grid (16 colors)
  List<Color?> _getColorsList(List<Color> gradientColors) {
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
      final distance = sqrt(pow(rowIndex - centerX, 2) + pow(colIndex - centerY, 2));
      final normalizedDistance = distance / sqrt(4.5); // Max distance from center
      
      // Apply subtle variations
      final hsv = HSVColor.fromColor(baseColor);
      final brightness = (hsv.value * (0.7 + (0.3 * (1.0 - normalizedDistance)))).clamp(0.0, 1.0);
      final saturation = (hsv.saturation * (0.8 + (0.2 * (1.0 - normalizedDistance * 0.5)))).clamp(0.0, 1.0);
      
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
}

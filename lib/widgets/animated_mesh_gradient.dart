import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import '../constants/animation_constants.dart';

/// Animated mesh gradient background that creates a dynamic gradient effect
/// Colors are derived from artwork or use default colors when no artwork is available
class AnimatedMeshGradient extends StatefulWidget {
  final List<Color> colors;
  final Duration animationDuration;
  final bool enableAnimation;
  final int? songId; // Add songId to track song changes

  const AnimatedMeshGradient({
    super.key,
    required this.colors,
    this.animationDuration = const Duration(seconds: 2), // Much faster animation for noticeable movement
    this.enableAnimation = true,
    this.songId,
  });

  @override
  State<AnimatedMeshGradient> createState() => _AnimatedMeshGradientState();
}

class _AnimatedMeshGradientState extends State<AnimatedMeshGradient>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _colorTransitionController;
  late Animation<double> _animation;
  late Animation<double> _colorTransition;

  List<Color> _currentColors = [];
  List<Color> _targetColors = [];
  bool _waveDirectionUp = true; // Track wave direction
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    
    _currentColors = widget.colors;
    _targetColors = widget.colors;

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _colorTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400), // Faster transitions (was 800ms)
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorTransition = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _colorTransitionController,
      curve: Curves.easeInOut,
    ));

    if (widget.enableAnimation) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedMeshGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.colors != widget.colors) {
      _updateColors(widget.colors);
    }
    
    // Toggle wave direction on song change
    if (widget.songId != null && widget.songId != _lastSongId) {
      _lastSongId = widget.songId;
      setState(() {
        _waveDirectionUp = !_waveDirectionUp; // Alternate direction for each song
      });
    }
    
    if (oldWidget.enableAnimation != widget.enableAnimation) {
      if (widget.enableAnimation) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  void _updateColors(List<Color> newColors) {
    _targetColors = newColors;
    _colorTransitionController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_animation, _colorTransition]),
        builder: (context, child) {
          // Interpolate between current and target colors
          final colors = List.generate(_currentColors.length, (index) {
            if (index >= _targetColors.length) {
              return _currentColors[index];
            }
            return Color.lerp(
              _currentColors[index],
              _targetColors[index],
              _colorTransition.value,
            ) ?? _currentColors[index];
          });

          // Update current colors when transition completes
          if (_colorTransition.value == 1.0 && _currentColors != _targetColors) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentColors = List.from(_targetColors);
                });
              }
            });
          }

          return Container(
            decoration: BoxDecoration(
              gradient: _createAnimatedGradient(colors, _animation.value),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _createAnimatedGradient(List<Color> colors, double animationValue) {
    if (colors.length < 2) {
      // Fallback to default gradient
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A237E),
          Color(0xFF311B92),
          Color(0xFF512DA8),
          Color(0xFF7B1FA2),
        ],
      );
    }

    // Create more dramatic diagonal wave movement with directional flow
    final wavePhase = animationValue * 2.0; // Double the wave speed
    final directionMultiplier = _waveDirectionUp ? 1.0 : -1.0; // Change direction based on song
    final diagonalWave = sin(wavePhase * pi * 2) * 0.8 * directionMultiplier; // Larger wave amplitude with direction
    final secondaryWave = cos(wavePhase * pi * 1.5 + pi/4) * 0.6 * directionMultiplier; // Secondary wave for complexity
    
    // Create flowing diagonal gradient positions with wave effects
    final begin = Alignment.lerp(
      Alignment(-1.0 + diagonalWave, -1.0 + secondaryWave * directionMultiplier),
      Alignment(1.0 + diagonalWave, -1.0 - secondaryWave * directionMultiplier),
      (sin(wavePhase * pi) * 0.5 + 0.5).clamp(0.0, 1.0),
    ) ?? Alignment.topLeft;

    final end = Alignment.lerp(
      Alignment(1.0 - diagonalWave, 1.0 - secondaryWave * directionMultiplier),
      Alignment(-1.0 - diagonalWave, 1.0 + secondaryWave * directionMultiplier),
      (cos(wavePhase * pi + pi/3) * 0.5 + 0.5).clamp(0.0, 1.0),
    ) ?? Alignment.bottomRight;

    // Ensure we have at least 4 colors for a rich gradient with dynamic variations
    List<Color> gradientColors;
    if (colors.length >= 4) {
      gradientColors = colors.take(4).toList();
    } else if (colors.length >= 2) {
      // Expand colors by creating vibrant variations
      final color1 = colors[0];
      final color2 = colors[1];
      gradientColors = [
        color1,
        Color.lerp(color1, color2, 0.3) ?? color1,
        Color.lerp(color1, color2, 0.7) ?? color2,
        color2,
      ];
    } else {
      // Single color - create dramatic variations with HSV manipulation
      final baseColor = colors[0];
      final hsvColor = HSVColor.fromColor(baseColor);
      gradientColors = [
        baseColor,
        hsvColor.withSaturation((hsvColor.saturation + 0.2).clamp(0.0, 1.0))
               .withValue((hsvColor.value + 0.1).clamp(0.0, 1.0)).toColor(),
        hsvColor.withHue((hsvColor.hue + 30) % 360)
               .withSaturation((hsvColor.saturation + 0.1).clamp(0.0, 1.0)).toColor(),
        hsvColor.withHue((hsvColor.hue + 60) % 360)
               .withValue((hsvColor.value - 0.1).clamp(0.0, 1.0)).toColor(),
      ];
    }

    // Add dynamic color shift based on animation for wave-like color flow
    final colorShiftPhase = wavePhase * 0.3; // Slower color phase for smoother transitions
    final shiftedColors = gradientColors.asMap().entries.map((entry) {
      final index = entry.key;
      final color = entry.value;
      final hsvColor = HSVColor.fromColor(color);
      final hueShift = sin(colorShiftPhase + index * pi / 2) * 20 * directionMultiplier; // Color wave effect with direction
      return hsvColor.withHue((hsvColor.hue + hueShift) % 360).toColor();
    }).toList();

    return LinearGradient(
      begin: begin,
      end: end,
      colors: shiftedColors,
      stops: [
        0.0,
        0.2 + sin(wavePhase) * 0.1,
        0.7 + cos(wavePhase + pi/2) * 0.1,
        1.0
      ], // Dynamic stops for wave effect
    );
  }
}

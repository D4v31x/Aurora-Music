import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/animation_constants.dart';

/// Animated mesh gradient background that creates a dynamic gradient effect
/// Colors are derived from artwork or use default colors when no artwork is available
class AnimatedMeshGradient extends StatefulWidget {
  final List<Color> colors;
  final Duration animationDuration;
  final bool enableAnimation;

  const AnimatedMeshGradient({
    super.key,
    required this.colors,
    this.animationDuration = const Duration(seconds: 8),
    this.enableAnimation = true,
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
      duration: const Duration(milliseconds: 800),
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

    // Create animated gradient positions
    final begin = Alignment.lerp(
      Alignment.topLeft,
      Alignment.topRight,
      (animationValue * 0.5).clamp(0.0, 1.0),
    ) ?? Alignment.topLeft;

    final end = Alignment.lerp(
      Alignment.bottomRight,
      Alignment.bottomLeft,
      (animationValue * 0.5).clamp(0.0, 1.0),
    ) ?? Alignment.bottomRight;

    // Ensure we have at least 4 colors for a rich gradient
    List<Color> gradientColors;
    if (colors.length >= 4) {
      gradientColors = colors.take(4).toList();
    } else if (colors.length >= 2) {
      // Expand colors by creating variations
      gradientColors = [
        colors[0],
        colors[0].withOpacity(0.8),
        colors[1].withOpacity(0.8),
        colors[1],
      ];
    } else {
      // Single color - create variations
      final baseColor = colors[0];
      gradientColors = [
        baseColor,
        baseColor.withOpacity(0.7),
        baseColor.withAlpha(150),
        baseColor.withOpacity(0.5),
      ];
    }

    return LinearGradient(
      begin: begin,
      end: end,
      colors: gradientColors,
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
  }
}

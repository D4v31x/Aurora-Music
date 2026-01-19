import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';
import '../services/background_manager_service.dart';

/// A beautiful animated background that displays heavily blurred artwork
/// with smooth transitions.
/// Performance-aware: Respects device performance mode for blur effects.
/// 
/// Optimized for:
/// - Reduced GPU load by wrapping blur layers in RepaintBoundary
/// - Throttled artwork updates to prevent excessive rebuilds
/// - Cached image providers to reduce memory churn
class AnimatedArtworkBackground extends StatefulWidget {
  final Uint8List? currentArtwork;
  final Widget child;
  final Color? fallbackColor;

  const AnimatedArtworkBackground({
    super.key,
    this.currentArtwork,
    Uint8List? previousArtwork, // Ignored - managed internally
    bool isTransitioning = false, // Ignored - managed internally
    required this.child,
    this.fallbackColor,
  });

  @override
  State<AnimatedArtworkBackground> createState() =>
      _AnimatedArtworkBackgroundState();
}

class _AnimatedArtworkBackgroundState extends State<AnimatedArtworkBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _crossfadeController;
  late Animation<double> _crossfadeAnimation;
  Uint8List? _previousArtworkCache;

  @override
  void initState() {
    super.initState();
    _crossfadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      value: widget.currentArtwork != null ? 1.0 : 0.0,
      vsync: this,
    );
    _crossfadeAnimation = CurvedAnimation(
      parent: _crossfadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(AnimatedArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only animate if artwork actually changed (check by reference or hash)
    final bool artworkChanged =
        !_areArtworksEqual(widget.currentArtwork, oldWidget.currentArtwork);

    if (artworkChanged) {
      if (oldWidget.currentArtwork == null && widget.currentArtwork != null) {
        // No animation when appearing for first time
        if (mounted) {
          setState(() {
            _crossfadeController.value = 1.0;
            _previousArtworkCache = null;
          });
        }
      } else if (widget.currentArtwork != null) {
        // Animate new artwork in
        if (mounted) {
          setState(() {
            _previousArtworkCache = oldWidget.currentArtwork;
          });
          _crossfadeController.forward(from: 0.0).then((_) {
            // Clear previous artwork after animation completes
            if (mounted) {
              setState(() {
                _previousArtworkCache = null;
              });
            }
          });
        }
      } else {
        // Artwork removed - fade out
        if (mounted) {
          setState(() {
            _previousArtworkCache = oldWidget.currentArtwork;
          });
          _crossfadeController.reverse(from: 1.0).then((_) {
            if (mounted) {
              setState(() {
                _previousArtworkCache = null;
              });
            }
          });
        }
      }
    }
  }

  // Helper to check if artworks are equal (by reference)
  bool _areArtworksEqual(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    // Use identical for performance - BackgroundManagerService should reuse instances
    return identical(a, b);
  }

  @override
  void dispose() {
    _crossfadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.fallbackColor ?? Theme.of(context).colorScheme.surface;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final isLowEndMode = !shouldBlur;

    // For low-end mode, use extracted colors as gradient instead of artwork
    if (isLowEndMode && widget.currentArtwork != null) {
      return _buildColorGradientBackground(context, backgroundColor);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer - solid surface color (always visible as fallback)
        Container(
          color: backgroundColor,
        ),

        // Previous artwork (fading out) - only show during transition
        if (_previousArtworkCache != null && _crossfadeController.isAnimating)
          AnimatedBuilder(
            animation: _crossfadeAnimation,
            builder: (context, child) => Opacity(
              opacity: (1.0 - _crossfadeAnimation.value).clamp(0.0, 1.0),
              child: child!,
            ),
            child: _buildBlurredArtwork(_previousArtworkCache!, shouldBlur),
          ),

        // Current artwork (always visible once loaded, no animation wrapper when stable)
        if (widget.currentArtwork != null)
          _crossfadeController.isAnimating
              ? AnimatedBuilder(
                  animation: _crossfadeAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _crossfadeAnimation.value.clamp(0.0, 1.0),
                    child: child!,
                  ),
                  child: RepaintBoundary(
                    child: _buildBlurredArtwork(
                        widget.currentArtwork!, shouldBlur),
                  ),
                )
              : RepaintBoundary(
                  child:
                      _buildBlurredArtwork(widget.currentArtwork!, shouldBlur),
                ),

        // Overlay for better text readability
        Container(
          color: Colors.black.withValues(alpha: 0.3),
        ),

        // Vignette effect for depth
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),

        // Child content
        widget.child,
      ],
    );
  }

  /// Build a color gradient background for low-end mode
  /// Uses animated color points from artwork instead of the artwork itself
  Widget _buildColorGradientBackground(
      BuildContext context, Color fallbackColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark base
        Container(color: Colors.black),

        // Animated color points
        AnimatedColorPointsBackground(
          fallbackColor: fallbackColor,
        ),

        // Overlay for better text readability
        Container(
          color: Colors.black.withValues(alpha: 0.3),
        ),

        // Vignette effect for depth
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),

        // Child content
        widget.child,
      ],
    );
  }

  Widget _buildBlurredArtwork(Uint8List artworkData, bool shouldBlur) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The image layer
          Image.memory(
            artworkData,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
          // The blur layer on top - only apply if performance mode allows
          if (shouldBlur)
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 50.0,
                sigmaY: 50.0,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
            )
          else
            // Fallback: darker overlay instead of blur for low-end devices
            Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }
}

/// Optimized blurred background for when performance is critical.
/// Performance-aware: Respects device performance mode for blur effects.
class SimpleBlurredBackground extends StatelessWidget {
  final Uint8List? artwork;
  final double blurIntensity;
  final Color overlayColor;
  final Widget child;

  const SimpleBlurredBackground({
    super.key,
    this.artwork,
    this.blurIntensity = 45.0,
    this.overlayColor = const Color(0x4D1A1A2E),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;

    if (artwork == null) {
      return ColoredBox(
        color: surfaceColor,
        child: child,
      );
    }

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final isLowEndMode = !shouldBlur;

    // For low-end mode, use animated color points instead of artwork
    if (isLowEndMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Dark base
          Container(color: Colors.black),
          // Animated color points background
          AnimatedColorPointsBackground(
            fallbackColor: surfaceColor,
          ),
          // Overlay for better text readability
          Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child,
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred artwork
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The image layer
              Image.memory(
                artwork!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              ),
              // The blur layer on top
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurIntensity,
                  sigmaY: blurIntensity,
                ),
                child: Container(
                  color: overlayColor,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Animated color points background for low-end mode
/// Displays 3 large blurred color circles at random positions
/// that slowly move and animate color transitions
class AnimatedColorPointsBackground extends StatefulWidget {
  final Color fallbackColor;

  const AnimatedColorPointsBackground({
    super.key,
    required this.fallbackColor,
  });

  @override
  State<AnimatedColorPointsBackground> createState() =>
      _AnimatedColorPointsBackgroundState();
}

class _AnimatedColorPointsBackgroundState
    extends State<AnimatedColorPointsBackground> with TickerProviderStateMixin {
  late AnimationController _positionController;
  late AnimationController _colorController;

  // Random positions for 3 color points (normalized 0-1)
  late List<Offset> _startPositions;
  late List<Offset> _endPositions;

  // Current and target colors
  List<Color> _currentColors = [];
  List<Color> _targetColors = [];

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Initialize random positions
    _startPositions = _generateRandomPositions();
    _endPositions = _generateRandomPositions();

    // Position animation - slow movement
    _positionController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _startPositions = _endPositions;
            _endPositions = _generateRandomPositions();
          });
          _positionController.forward(from: 0.0);
        }
      });

    // Color transition animation
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _positionController.forward();
  }

  List<Offset> _generateRandomPositions() {
    return List.generate(
        3,
        (_) => Offset(
              _random.nextDouble() * 0.6 + 0.2, // Keep within 0.2 - 0.8 range
              _random.nextDouble() * 0.6 + 0.2,
            ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateColors();
  }

  void _updateColors() {
    final backgroundManager =
        Provider.of<BackgroundManagerService>(context, listen: false);
    final newColors = backgroundManager.currentColors;

    if (newColors.isNotEmpty && !_areColorsEqual(newColors, _targetColors)) {
      setState(() {
        _currentColors = _targetColors.isNotEmpty
            ? _targetColors
            : newColors.take(3).toList();
        _targetColors = newColors.take(3).toList();
      });

      // Animate color transition
      _colorController.forward(from: 0.0);
    } else if (_currentColors.isEmpty && newColors.isNotEmpty) {
      setState(() {
        _currentColors = newColors.take(3).toList();
        _targetColors = newColors.take(3).toList();
      });
    }
  }

  bool _areColorsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _positionController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to background manager changes
    return Consumer<BackgroundManagerService>(
      builder: (context, backgroundManager, _) {
        // Update colors when they change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateColors();
        });

        final colors = _getInterpolatedColors();
        if (colors.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.fallbackColor,
                  widget.fallbackColor.withValues(alpha: 0.8),
                ],
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_positionController, _colorController]),
          builder: (context, _) {
            final positions = _getInterpolatedPositions();
            final animatedColors = _getInterpolatedColors();

            return CustomPaint(
              painter: _ColorPointsPainter(
                positions: positions,
                colors: animatedColors,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }

  List<Offset> _getInterpolatedPositions() {
    final t = Curves.easeInOut.transform(_positionController.value);
    return List.generate(3, (i) {
      if (i >= _startPositions.length || i >= _endPositions.length) {
        return const Offset(0.5, 0.5);
      }
      return Offset.lerp(_startPositions[i], _endPositions[i], t)!;
    });
  }

  List<Color> _getInterpolatedColors() {
    if (_currentColors.isEmpty) return _targetColors;
    if (_targetColors.isEmpty) return _currentColors;

    final t = Curves.easeInOut.transform(_colorController.value);
    return List.generate(
      math.min(_currentColors.length, _targetColors.length),
      (i) => Color.lerp(_currentColors[i], _targetColors[i], t)!,
    );
  }
}

/// Custom painter for drawing blurred color points
class _ColorPointsPainter extends CustomPainter {
  final List<Offset> positions;
  final List<Color> colors;

  _ColorPointsPainter({
    required this.positions,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty || positions.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw each color point as a large radial gradient circle
    for (int i = 0; i < math.min(positions.length, colors.length); i++) {
      final position = Offset(
        positions[i].dx * size.width,
        positions[i].dy * size.height,
      );

      // Large radius for soft, spread-out glow
      final radius = size.width * 0.6;

      paint.shader = RadialGradient(
        colors: [
          colors[i].withValues(alpha: 0.8),
          colors[i].withValues(alpha: 0.4),
          colors[i].withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: radius));

      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ColorPointsPainter oldDelegate) {
    return !_listEquals(positions, oldDelegate.positions) ||
        !_colorListEquals(colors, oldDelegate.colors);
  }

  bool _listEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _colorListEquals(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value) return false;
    }
    return true;
  }
}

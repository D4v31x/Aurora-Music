import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';
import '../providers/theme_provider.dart';
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

  // Cache decoded ImageProviders to avoid re-decoding Uint8List each frame
  MemoryImage? _currentImageProvider;
  MemoryImage? _previousImageProvider;
  Uint8List? _currentProviderSource;
  Uint8List? _previousProviderSource;

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
    _updateCurrentProvider(widget.currentArtwork);
  }

  /// Returns a cached MemoryImage for the given artwork, creating one only
  /// when the underlying bytes change.
  MemoryImage? _getOrCreateProvider(
      Uint8List? data, MemoryImage? cached, Uint8List? cachedSource) {
    if (data == null) return null;
    if (identical(data, cachedSource) && cached != null) return cached;
    return MemoryImage(data);
  }

  void _updateCurrentProvider(Uint8List? data) {
    _currentImageProvider =
        _getOrCreateProvider(data, _currentImageProvider, _currentProviderSource);
    _currentProviderSource = data;
  }

  void _updatePreviousProvider(Uint8List? data) {
    _previousImageProvider =
        _getOrCreateProvider(data, _previousImageProvider, _previousProviderSource);
    _previousProviderSource = data;
  }

  @override
  void didUpdateWidget(AnimatedArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only animate if artwork actually changed (check by reference or hash)
    final bool artworkChanged =
        !_areArtworksEqual(widget.currentArtwork, oldWidget.currentArtwork);

    if (artworkChanged) {
      _updateCurrentProvider(widget.currentArtwork);

      if (oldWidget.currentArtwork == null && widget.currentArtwork != null) {
        // No animation when appearing for first time
        _crossfadeController.value = 1.0;
        _previousArtworkCache = null;
        _previousImageProvider = null;
        _previousProviderSource = null;
      } else if (widget.currentArtwork != null) {
        // Animate new artwork in — cache the outgoing provider
        _previousArtworkCache = oldWidget.currentArtwork;
        _updatePreviousProvider(oldWidget.currentArtwork);
        _crossfadeController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _previousArtworkCache = null;
              _previousImageProvider = null;
              _previousProviderSource = null;
            });
          }
        });
      } else {
        // Artwork removed - fade out
        _previousArtworkCache = oldWidget.currentArtwork;
        _updatePreviousProvider(oldWidget.currentArtwork);
        _crossfadeController.reverse(from: 1.0).then((_) {
          if (mounted) {
            setState(() {
              _previousArtworkCache = null;
              _previousImageProvider = null;
              _previousProviderSource = null;
            });
          }
        });
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

    final themeProvider = Provider.of<ThemeProvider>(context);
    final blurIntensity = themeProvider.blurIntensity;
    final overlayOpacity = themeProvider.overlayOpacity;

    // High-end: if user chose solid background, skip blurred artwork
    if (shouldBlur &&
        themeProvider.highEndBackground == HighEndBackground.solid) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: backgroundColor),
          widget.child,
        ],
      );
    }

    // For low-end mode, use extracted colors as gradient instead of artwork
    if (isLowEndMode && widget.currentArtwork != null) {
      if (themeProvider.lowEndBackground == LowEndBackground.blobs) {
        return _buildColorGradientBackground(context, backgroundColor);
      } else {
        // Solid color preference — show plain surface color
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: backgroundColor),
            widget.child,
          ],
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer - solid surface color (always visible as fallback)
        Container(
          color: backgroundColor,
        ),

        // Previous artwork (fading out) - skip BackdropFilter during
        // crossfade to avoid two concurrent GPU blur passes.
        if (_previousArtworkCache != null &&
            _previousImageProvider != null &&
            _crossfadeController.isAnimating)
          AnimatedBuilder(
            animation: _crossfadeAnimation,
            builder: (context, child) => Opacity(
              opacity: (1.0 - _crossfadeAnimation.value).clamp(0.0, 1.0),
              child: child!,
            ),
            child: RepaintBoundary(
              child: _buildBlurredArtwork(
                  _previousImageProvider!, shouldBlur, blurIntensity),
            ),
          ),

        // Current artwork
        if (widget.currentArtwork != null && _currentImageProvider != null)
          _crossfadeController.isAnimating
              ? AnimatedBuilder(
                  animation: _crossfadeAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _crossfadeAnimation.value.clamp(0.0, 1.0),
                    child: child!,
                  ),
                  child: RepaintBoundary(
                    child: _buildBlurredArtwork(
                        _currentImageProvider!, shouldBlur, blurIntensity),
                  ),
                )
              : RepaintBoundary(
                  child: _buildBlurredArtwork(
                      _currentImageProvider!, shouldBlur, blurIntensity),
                ),

        // Overlay for better text readability
        Container(
          color: shouldBlur
              ? Colors.black.withValues(alpha: overlayOpacity)
              : Colors.black.withValues(alpha: (overlayOpacity + 0.3).clamp(0.0, 1.0)),
        ),

        // Vignette effect for depth - only apply in high-end mode
        if (shouldBlur)
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

        // Child content
        widget.child,
      ],
    );
  }

  Widget _buildBlurredArtwork(ImageProvider imageProvider, bool shouldBlur, double blurIntensity) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The image layer — cached ImageProvider avoids re-decoding each frame
          Image(
            image: imageProvider,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
          // The blur layer on top - only apply if performance mode allows
          if (shouldBlur)
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurIntensity,
                sigmaY: blurIntensity,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
            )
          else
            // Fallback: solid darker overlay instead of blur for low-end devices
            Container(
              color: Colors.black.withValues(alpha: 0.6),
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

    // High-end: if user chose solid background, show surface color
    if (shouldBlur) {
      final themeProvider =
          Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.highEndBackground == HighEndBackground.solid) {
        return ColoredBox(
          color: surfaceColor,
          child: child,
        );
      }
    }

    // For low-end mode, use animated color points instead of artwork
    if (isLowEndMode) {
      final themeProvider =
          Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.lowEndBackground == LowEndBackground.blobs) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            AnimatedColorPointsBackground(
              fallbackColor: surfaceColor,
            ),
            child,
          ],
        );
      } else {
        return ColoredBox(
          color: surfaceColor,
          child: child,
        );
      }
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
    extends State<AnimatedColorPointsBackground> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _positionController;
  late AnimationController _colorController;

  // Random positions for 5 color points (normalized 0-1)
  late List<Offset> _startPositions;
  late List<Offset> _endPositions;

  // Current and target colors
  List<Color> _currentColors = [];
  List<Color> _targetColors = [];

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize random positions
    _startPositions = _generateRandomPositions();
    _endPositions = _generateRandomPositions();

    // Position animation - slow drift to save energy
    _positionController = AnimationController(
      duration: const Duration(seconds: 12),
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

  // Normalized [xMin, xMax, yMin, yMax] region per blob — wider ranges
  // give each blob more room to roam while still covering the whole screen.
  static const List<List<double>> _blobRegions = [
    [0.0,  0.75, 0.0,  0.75], // top-left (large)
    [0.25, 1.0,  0.0,  0.75], // top-right (large)
    [0.0,  1.0,  0.0,  1.0],  // centre — free to roam anywhere
    [0.0,  0.75, 0.25, 1.0],  // bottom-left (large)
    [0.25, 1.0,  0.25, 1.0],  // bottom-right (large)
  ];

  List<Offset> _generateRandomPositions() {
    return List.generate(5, (i) {
      final r = _blobRegions[i];
      return Offset(
        _random.nextDouble() * (r[1] - r[0]) + r[0],
        _random.nextDouble() * (r[3] - r[2]) + r[2],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register dependency so this is called whenever BackgroundManagerService notifies
    _updateColorsFrom(Provider.of<BackgroundManagerService>(context).currentColors);
  }

  void _updateColorsFrom(List<Color> newColors) {
    // Build an expanded palette of up to 5 colors, deriving extras if needed
    final expanded = _expandColors(newColors, target: 5);
    if (expanded.isNotEmpty && !_areColorsEqual(expanded, _targetColors)) {
      setState(() {
        _currentColors = _targetColors.isNotEmpty
            ? _targetColors
            : expanded;
        _targetColors = expanded;
      });

      // Animate color transition
      _colorController.forward(from: 0.0);
    } else if (_currentColors.isEmpty && expanded.isNotEmpty) {
      setState(() {
        _currentColors = expanded;
        _targetColors = expanded;
      });
    }
  }

  /// Expands [colors] to [target] entries by blending adjacent pairs for extras.
  List<Color> _expandColors(List<Color> colors, {required int target}) {
    if (colors.isEmpty) return [];
    final result = List<Color>.from(colors);
    int src = 0;
    while (result.length < target) {
      final a = result[src % result.length];
      final b = result[(src + 1) % result.length];
      result.add(Color.lerp(a, b, 0.5)!);
      src++;
    }
    return result.take(target).toList();
  }

  bool _areColorsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _positionController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_positionController.isAnimating) {
        _positionController.forward();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
  }

  List<Offset> _getInterpolatedPositions() {
    final t = Curves.easeInOut.transform(_positionController.value);
    return List.generate(5, (i) {
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

      // Large radius — covers the full screen so no dark patches remain
      final radius = size.width * 0.8;

      paint.shader = RadialGradient(
        colors: [
          colors[i].withValues(alpha: 0.95),
          colors[i].withValues(alpha: 0.55),
          colors[i].withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
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
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }
}

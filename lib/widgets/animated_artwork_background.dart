import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A beautiful animated background that displays heavily blurred artwork
/// with smooth transitions
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
            child: _buildBlurredArtwork(_previousArtworkCache!),
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
                    child: _buildBlurredArtwork(widget.currentArtwork!),
                  ),
                )
              : RepaintBoundary(
                  child: _buildBlurredArtwork(widget.currentArtwork!),
                ),

        // Overlay for better text readability
        Container(
          color: Colors.black.withValues(alpha: 0.3),
        ),

        // Vignette effect for depth
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
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

  Widget _buildBlurredArtwork(Uint8List artworkData) {
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
          // The blur layer on top
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 50.0,
              sigmaY: 50.0,
            ),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized blurred background for when performance is critical
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
    if (artwork == null) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: child,
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

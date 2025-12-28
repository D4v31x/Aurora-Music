import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A beautiful animated background that displays heavily blurred artwork
/// with smooth transitions
class AnimatedArtworkBackground extends HookWidget {
  final Uint8List? currentArtwork;
  final Uint8List? previousArtwork;
  final bool isTransitioning;
  final Widget child;
  final Color? fallbackColor;

  const AnimatedArtworkBackground({
    super.key,
    this.currentArtwork,
    this.previousArtwork,
    this.isTransitioning = false,
    required this.child,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final crossfadeController = useAnimationController(
      duration: const Duration(milliseconds: 800),
      initialValue: currentArtwork != null ? 1.0 : 0.0,
    );

    final crossfadeAnimation = useAnimation(
      CurvedAnimation(
        parent: crossfadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Store previous artwork for comparison
    final prevArtworkRef = usePrevious(currentArtwork);

    // Handle artwork changes
    useEffect(() {
      if (currentArtwork != prevArtworkRef) {
        if (prevArtworkRef == null && currentArtwork != null) {
          crossfadeController.value = 1.0;
        } else if (currentArtwork != null) {
          crossfadeController.forward(from: 0.0);
        }
      }
      return null;
    }, [currentArtwork]);

    final backgroundColor =
        fallbackColor ?? Theme.of(context).colorScheme.surface;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer - solid surface color (always visible as fallback)
        Container(
          color: backgroundColor,
        ),

        // Previous artwork (fading out)
        if (previousArtwork != null)
          Opacity(
            opacity: (1.0 - crossfadeAnimation).clamp(0.0, 1.0),
            child: _buildBlurredArtwork(previousArtwork!),
          ),

        // Current artwork (fading in or fully visible)
        if (currentArtwork != null)
          crossfadeController.value >= 1.0
              ? _buildBlurredArtwork(currentArtwork!)
              : Opacity(
                  opacity: crossfadeAnimation.clamp(0.0, 1.0),
                  child: _buildBlurredArtwork(currentArtwork!),
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
        child,
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

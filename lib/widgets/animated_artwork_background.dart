import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/mood_detection_service.dart';

/// A beautiful animated background that displays heavily blurred artwork
/// with mood-based overlays and smooth transitions
class AnimatedArtworkBackground extends StatefulWidget {
  final Uint8List? currentArtwork;
  final Uint8List? previousArtwork;
  final bool isTransitioning;
  final MoodTheme moodTheme;
  final Widget child;
  final Color? fallbackColor;

  const AnimatedArtworkBackground({
    super.key,
    this.currentArtwork,
    this.previousArtwork,
    this.isTransitioning = false,
    required this.moodTheme,
    required this.child,
    this.fallbackColor,
  });

  @override
  State<AnimatedArtworkBackground> createState() => _AnimatedArtworkBackgroundState();
}

class _AnimatedArtworkBackgroundState extends State<AnimatedArtworkBackground>
    with TickerProviderStateMixin {
  late AnimationController _crossfadeController;
  late AnimationController _moodController;
  late Animation<double> _crossfadeAnimation;
  late Animation<double> _moodAnimation;
  
  MoodTheme? _previousMoodTheme;

  @override
  void initState() {
    super.initState();
    
    // Crossfade animation for artwork transitions
    _crossfadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _crossfadeAnimation = CurvedAnimation(
      parent: _crossfadeController,
      curve: Curves.easeInOut,
    );
    
    // If we already have artwork on init, start fully visible
    if (widget.currentArtwork != null) {
      _crossfadeController.value = 1.0;
    }
    
    // Mood transition animation
    _moodController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _moodAnimation = CurvedAnimation(
      parent: _moodController,
      curve: Curves.easeInOut,
    );
    
    _moodController.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Trigger crossfade when artwork changes
    if (widget.currentArtwork != oldWidget.currentArtwork) {
      // If going from no artwork to having artwork, show immediately
      if (oldWidget.currentArtwork == null && widget.currentArtwork != null) {
        _crossfadeController.value = 1.0;
        // Force rebuild to show artwork immediately
        if (mounted) setState(() {});
      } else if (widget.currentArtwork != null) {
        // Otherwise animate the transition
        _crossfadeController.forward(from: 0.0);
      }
    }
    
    // Trigger mood transition when mood changes
    if (widget.moodTheme != oldWidget.moodTheme) {
      _previousMoodTheme = oldWidget.moodTheme;
      _moodController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _crossfadeController.dispose();
    _moodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.fallbackColor ?? Theme.of(context).colorScheme.surface;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer - solid surface color (always visible as fallback)
        Container(
          color: backgroundColor,
        ),
        
        // Previous artwork (fading out)
        if (widget.previousArtwork != null)
          AnimatedBuilder(
            animation: _crossfadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: (1.0 - _crossfadeAnimation.value).clamp(0.0, 1.0),
                child: _buildBlurredArtwork(
                  widget.previousArtwork!,
                  _previousMoodTheme ?? widget.moodTheme,
                ),
              );
            },
          ),
        
        // Current artwork (fading in or fully visible)
        if (widget.currentArtwork != null)
          _crossfadeController.value >= 1.0
            ? _buildBlurredArtwork(widget.currentArtwork!, widget.moodTheme)
            : AnimatedBuilder(
                animation: _crossfadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _crossfadeAnimation.value.clamp(0.0, 1.0),
                    child: _buildBlurredArtwork(
                      widget.currentArtwork!,
                      widget.moodTheme,
                    ),
                  );
                },
              ),
        
        // Mood overlay with animation
        AnimatedBuilder(
          animation: _moodAnimation,
          builder: (context, child) {
            final currentOverlay = widget.moodTheme.overlayTint
                .withValues(alpha: widget.moodTheme.overlayOpacity);
            final previousOverlay = (_previousMoodTheme?.overlayTint ?? 
                widget.moodTheme.overlayTint)
                .withValues(alpha: _previousMoodTheme?.overlayOpacity ?? 
                    widget.moodTheme.overlayOpacity);
            
            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  previousOverlay,
                  currentOverlay,
                  _moodAnimation.value,
                ),
              ),
            );
          },
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

  Widget _buildBlurredArtwork(Uint8List artworkData, MoodTheme moodTheme) {
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
              sigmaX: moodTheme.blurIntensity,
              sigmaY: moodTheme.blurIntensity,
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

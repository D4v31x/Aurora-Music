import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/background_manager_service.dart';
import 'animated_artwork_background.dart';

/// Centralized app background widget that provides consistent background across the app
/// Shows blurred album artwork when a song with artwork is playing,
/// otherwise falls back to solid Material You surface color
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool enableAnimation;

  const AppBackground({
    super.key,
    required this.child,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    
    return Consumer<BackgroundManagerService>(
      builder: (context, backgroundManager, _) {
        // Always use AnimatedArtworkBackground - it handles null artwork internally
        // This keeps the widget tree stable and avoids remounting issues
        if (enableAnimation) {
          return AnimatedArtworkBackground(
            currentArtwork: backgroundManager.currentArtwork,
            previousArtwork: backgroundManager.previousArtwork,
            isTransitioning: backgroundManager.isTransitioning,
            moodTheme: backgroundManager.currentMoodTheme,
            fallbackColor: surfaceColor,
            child: child,
          );
        }

        // Simple blurred background for when animations are disabled
        if (backgroundManager.hasArtwork) {
          return SimpleBlurredBackground(
            artwork: backgroundManager.currentArtwork,
            blurIntensity: backgroundManager.currentMoodTheme.blurIntensity,
            overlayColor: backgroundManager.currentMoodTheme.overlayTint
                .withValues(alpha: backgroundManager.currentMoodTheme.overlayOpacity),
            child: child,
          );
        }

        // Fallback for non-animated mode without artwork
        return Container(
          color: surfaceColor,
          child: child,
        );
      },
    );
  }
}

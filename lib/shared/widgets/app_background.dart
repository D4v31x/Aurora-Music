import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

    return Selector<BackgroundManagerService, Uint8List?>(
      selector: (context, backgroundManager) =>
          backgroundManager.currentArtwork,
      shouldRebuild: (prev, next) {
        // Only rebuild if artwork reference changed
        final shouldRebuild = !identical(prev, next);
        if (kDebugMode && shouldRebuild) {
          debugPrint(
              '🎨 [APP_BG] Rebuild background (hasArtwork: ${next != null}, bytes: ${next?.length ?? 0}, animated: $enableAnimation)');
        }
        return shouldRebuild;
      },
      builder: (context, currentArtwork, _) {
        // Always use AnimatedArtworkBackground - it handles null artwork internally
        // This keeps the widget tree stable and avoids remounting issues
        if (enableAnimation) {
          return AnimatedArtworkBackground(
            currentArtwork: currentArtwork,
            fallbackColor: surfaceColor,
            child: child,
          );
        }

        // Simple blurred background for when animations are disabled
        if (currentArtwork != null) {
          return SimpleBlurredBackground(
            artwork: currentArtwork,
            blurIntensity: 25.0,
            overlayColor: Colors.black.withValues(alpha: 0.3),
            child: child,
          );
        }

        // Fallback for non-animated mode without artwork
        return ColoredBox(
          color: surfaceColor,
          child: child,
        );
      },
    );
  }
}

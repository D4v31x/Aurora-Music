/// Album artwork widget for the Now Playing screen.
///
/// Displays the album art with hero animations, shadows, and optional
/// tap-to-expand functionality.
library;

import 'package:flutter/material.dart';
import '../../services/artwork_cache_service.dart';

// MARK: - Constants

const _kDefaultBorderRadius = 16.0;
const _kPhoneBorderRadius = 27.0;
const _kShadowBlur = 15.0;
const _kShadowOffset = 8.0;
const _kShadowOpacity = 0.2;
const _kFallbackArtworkPath = 'assets/images/UI/defaultAlbumArt.png';

// MARK: - Now Playing Artwork Widget

/// A widget that displays the album artwork for the current song.
///
/// Features:
/// - Cached artwork loading for performance
/// - Hero animations for smooth screen transitions
/// - Configurable size and border radius
/// - Shadow effects
/// - Optional tap handler
///
/// Usage:
/// ```dart
/// NowPlayingArtwork(
///   songId: currentSong.id,
///   size: 280,
///   onTap: () => openFullscreenArtwork(),
/// )
/// ```
class NowPlayingArtwork extends StatelessWidget {
  /// The song ID to load artwork for.
  final int? songId;

  /// The size of the artwork (width and height).
  final double size;

  /// The border radius of the artwork.
  final double borderRadius;

  /// Optional callback when the artwork is tapped.
  final VoidCallback? onTap;

  /// The cached artwork image provider.
  final ImageProvider<Object>? artworkProvider;

  /// Whether to show shadow effect.
  final bool showShadow;

  /// Hero tag for animations.
  final String heroTag;

  const NowPlayingArtwork({
    super.key,
    this.songId,
    required this.size,
    this.borderRadius = _kDefaultBorderRadius,
    this.onTap,
    this.artworkProvider,
    this.showShadow = true,
    this.heroTag = 'songArtwork',
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      createRectTween: (begin, end) {
        return MaterialRectCenterArcTween(begin: begin, end: end);
      },
      flightShuttleBuilder: _artworkFlightShuttleBuilder,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          child: _buildArtworkContainer(),
        ),
      ),
    );
  }

  /// Builds the artwork container with shadow and image.
  Widget _buildArtworkContainer() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(_kShadowOpacity),
                  blurRadius: _kShadowBlur,
                  offset: const Offset(0, _kShadowOffset),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildArtworkImage(),
      ),
    );
  }

  /// Builds the artwork image with fallback.
  Widget _buildArtworkImage() {
    if (artworkProvider != null) {
      return Image(
        image: artworkProvider!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => _buildFallbackArtwork(),
      );
    }

    // Use cached artwork service if no provider is specified
    if (songId != null) {
      return FutureBuilder<ImageProvider?>(
        future: _loadArtwork(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image(
              image: snapshot.data!,
              fit: BoxFit.cover,
              width: size,
              height: size,
            );
          }
          return _buildFallbackArtwork();
        },
      );
    }

    return _buildFallbackArtwork();
  }

  /// Loads artwork from cache.
  Future<ImageProvider?> _loadArtwork() async {
    if (songId == null) return null;
    final artworkService = ArtworkCacheService();
    final bytes = await artworkService.getArtwork(songId!);
    if (bytes != null && bytes.isNotEmpty) {
      return MemoryImage(bytes);
    }
    return null;
  }

  /// Builds the fallback artwork placeholder.
  Widget _buildFallbackArtwork() {
    return Image.asset(
      _kFallbackArtworkPath,
      fit: BoxFit.cover,
      width: size,
      height: size,
    );
  }

  /// Flight shuttle builder for hero animation.
  Widget _artworkFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final Hero toHero = toHeroContext.widget as Hero;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final curvedValue = Curves.easeOutCubic.transform(animation.value);
          final animatedBorderRadius = BorderRadius.circular(
            _kPhoneBorderRadius + (_kDefaultBorderRadius - _kPhoneBorderRadius) * curvedValue,
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: animatedBorderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_kShadowOpacity),
                  blurRadius: _kShadowBlur,
                  offset: const Offset(0, _kShadowOffset),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: animatedBorderRadius,
              child: toHero.child,
            ),
          );
        },
      ),
    );
  }
}

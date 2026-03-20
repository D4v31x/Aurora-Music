/// Album artwork widget for the Now Playing screen.

library;

import 'package:flutter/material.dart';
import '../../../shared/services/artwork_cache_service.dart';

// Constants

const _kDefaultBorderRadius = 16.0;
const _kPhoneBorderRadius = 27.0;
const _kShadowBlur = 15.0;
const _kShadowOffset = 8.0;
const _kShadowOpacity = 0.2;
const _kFallbackArtworkPath = 'assets/images/UI/defaultAlbumArt.png';

// Now Playing Artwork Widget
class NowPlayingArtwork extends StatelessWidget {
  final int? songId;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;
  final ImageProvider<Object>? artworkProvider;
  final bool showShadow;
  final String heroTag;
  final ArtworkCacheService? artworkService;

  const NowPlayingArtwork({
    super.key,
    this.songId,
    required this.size,
    this.borderRadius = _kDefaultBorderRadius,
    this.onTap,
    this.artworkProvider,
    this.showShadow = true,
    this.heroTag = 'songArtwork',
    this.artworkService,
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
                  color: Colors.black.withValues(alpha: _kShadowOpacity),
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
    final service = artworkService ?? ArtworkCacheService();
    final bytes = await service.getArtwork(songId!);
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
                  color: Colors.black.withValues(alpha: _kShadowOpacity),
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

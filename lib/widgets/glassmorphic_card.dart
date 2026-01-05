import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../services/artwork_cache_service.dart';
import '../providers/performance_mode_provider.dart';

/// A unified glassmorphic card widget used across the app for songs, albums, artists, etc.
/// This provides a consistent UI for all card-based displays.
class GlassmorphicCard extends StatelessWidget {
  final Widget artwork;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? badge;
  final double width;
  final double artworkSize;

  const GlassmorphicCard({
    super.key,
    required this.artwork,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.badge,
    this.width = 130,
    this.artworkSize = 130,
  });

  /// Factory constructor for song cards
  factory GlassmorphicCard.song({
    Key? key,
    required int songId,
    required String title,
    required String artist,
    required VoidCallback onTap,
    Widget? badge,
    ArtworkCacheService? artworkService,
    double size = 130,
  }) {
    final service = artworkService ?? ArtworkCacheService();
    return GlassmorphicCard(
      key: key,
      artwork: service.buildCachedArtwork(songId, size: size),
      title: title,
      subtitle: artist,
      onTap: onTap,
      badge: badge,
      width: size,
      artworkSize: size,
    );
  }

  /// Factory constructor for album cards
  factory GlassmorphicCard.album({
    Key? key,
    required int albumId,
    required String albumName,
    String? artistName,
    required VoidCallback onTap,
    ArtworkCacheService? artworkService,
    double size = 130,
  }) {
    final service = artworkService ?? ArtworkCacheService();
    return GlassmorphicCard(
      key: key,
      artwork: service.buildCachedAlbumArtwork(albumId, size: size),
      title: albumName,
      subtitle: artistName,
      onTap: onTap,
      width: size,
      artworkSize: size,
    );
  }

  /// Factory constructor for artist cards
  factory GlassmorphicCard.artist({
    Key? key,
    required String artistName,
    String? info,
    required VoidCallback onTap,
    ArtworkCacheService? artworkService,
    bool circularArtwork = true,
    double size = 130,
  }) {
    final service = artworkService ?? ArtworkCacheService();
    return GlassmorphicCard(
      key: key,
      artwork: ClipRRect(
        borderRadius: circularArtwork
            ? BorderRadius.circular(size / 2)
            : const BorderRadius.vertical(top: Radius.circular(16)),
        child: service.buildArtistImageByName(
          artistName,
          size: size,
          circular: circularArtwork,
        ),
      ),
      title: artistName,
      subtitle: info,
      onTap: onTap,
      width: size,
      artworkSize: size,
    );
  }

  /// Factory constructor for playlist cards
  factory GlassmorphicCard.playlist({
    Key? key,
    required String playlistName,
    required int songCount,
    required VoidCallback onTap,
    String? playlistId,
    Widget? customArtwork,
    double size = 130,
  }) {
    // Determine artwork based on playlist ID for special playlists
    Widget artworkWidget;
    if (customArtwork != null) {
      artworkWidget = customArtwork;
    } else if (playlistId == 'liked_songs') {
      artworkWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.asset(
          'assets/images/UI/liked.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (playlistId == 'recently_added') {
      artworkWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.asset(
          'assets/images/UI/recentlyadded.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (playlistId == 'most_played') {
      artworkWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.asset(
          'assets/images/UI/mostplayed.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      artworkWidget = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.withOpacity(0.6),
              Colors.blue.withOpacity(0.6),
            ],
          ),
        ),
        child: Icon(
          Icons.playlist_play_rounded,
          color: Colors.white,
          size: size * 0.4,
        ),
      );
    }

    return GlassmorphicCard(
      key: key,
      artwork: artworkWidget,
      title: playlistName,
      subtitle: '$songCount tracks',
      onTap: onTap,
      width: size,
      artworkSize: size,
    );
  }

  /// Factory constructor for folder cards
  factory GlassmorphicCard.folder({
    Key? key,
    required String folderName,
    required VoidCallback onTap,
    double size = 130,
  }) {
    return GlassmorphicCard(
      key: key,
      artwork: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withOpacity(0.6),
              Colors.amber.withOpacity(0.6),
            ],
          ),
        ),
        child: Icon(
          Icons.folder_rounded,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
      title: folderName,
      onTap: onTap,
      width: size,
      artworkSize: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check if blur should be enabled based on performance mode
    // Use listen: false to prevent rebuilding all cards
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    final cardDecoration = BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(shouldBlur ? 0.1 : 0.15)
          : Colors.black.withOpacity(shouldBlur ? 0.05 : 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.1),
      ),
    );

    final cardContent = Container(
      width: width,
      decoration: cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork with optional badge
          Stack(
            children: [
              SizedBox(
                width: width,
                height: artworkSize,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: artwork,
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: badge!,
                ),
            ],
          ),
          // Title and subtitle
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ProductSans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 11,
                      fontFamily: 'ProductSans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: shouldBlur
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: cardContent,
                  ),
                )
              : cardContent,
        ),
      ),
    );
  }
}

/// A badge widget for cards (e.g., "NEW" badge)
class CardBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;

  const CardBadge({
    super.key,
    required this.text,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'ProductSans',
        ),
      ),
    );
  }
}

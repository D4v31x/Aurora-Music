import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/artwork_cache_service.dart';
import '../models/artist_utils.dart';

/// Optimized song tile widget that prevents unnecessary rebuilds
/// Uses RepaintBoundary and AutomaticKeepAliveClientMixin for performance
class OptimizedSongTile extends StatefulWidget {
  final SongModel song;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  const OptimizedSongTile({
    required Key key,
    required this.song,
    this.onTap,
    this.trailing,
    this.selected = false,
  }) : super(key: key);

  @override
  State<OptimizedSongTile> createState() => _OptimizedSongTileState();
}

class _OptimizedSongTileState extends State<OptimizedSongTile>
    with AutomaticKeepAliveClientMixin {
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: widget.selected
                ? BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    border: const Border(
                      left: BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 3,
                      ),
                    ),
                  )
                : null,
            child: Row(
              children: [
                // Artwork with RepaintBoundary
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _artworkService.buildCachedArtwork(
                      widget.song.id,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        splitArtists(widget.song.artist ?? 'Unknown Artist')
                            .join(', '),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Trailing widget
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Optimized grid tile for albums/artists
/// Uses const constructors where possible and RepaintBoundary
class OptimizedGridTile extends StatefulWidget {
  final int id;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isArtist;

  const OptimizedGridTile({
    required Key key,
    required this.id,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isArtist = false,
  }) : super(key: key);

  @override
  State<OptimizedGridTile> createState() => _OptimizedGridTileState();
}

class _OptimizedGridTileState extends State<OptimizedGridTile>
    with AutomaticKeepAliveClientMixin {
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artwork
                Expanded(
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: widget.isArtist
                          ? _artworkService.buildArtistImageByName(
                              widget.title,
                              size: double.infinity,
                            )
                          : _artworkService.buildCachedArtwork(
                              widget.id,
                              size: double.infinity,
                            ),
                    ),
                  ),
                ),
                // Title and subtitle
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
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
          ),
        ),
      ),
    );
  }
}

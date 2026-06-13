import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/constants/font_constants.dart';
import '../services/artwork_cache_service.dart';
import '../models/artist_utils.dart';

/// Accent colour used to highlight the currently-playing song.
const Color _kNowPlayingAccent = Color(0xFF3B82F6);

/// Optimized song tile widget that prevents unnecessary rebuilds
/// Uses RepaintBoundary and AutomaticKeepAliveClientMixin for performance
class OptimizedSongTile extends StatefulWidget {
  final SongModel song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selected;

  /// When provided, the tile listens to this and highlights itself whenever the
  /// current song's id matches this tile's song — so the now-playing indicator
  /// updates live as tracks switch, without rebuilding the whole list.
  final ValueListenable<SongModel?>? currentSongListenable;

  /// Drives the animated equalizer bars (animate while playing, freeze when
  /// paused). Only relevant when [currentSongListenable] marks this tile active.
  final ValueListenable<bool>? isPlayingListenable;

  const OptimizedSongTile({
    required Key key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selected = false,
    this.currentSongListenable,
    this.isPlayingListenable,
  }) : super(key: key);

  @override
  State<OptimizedSongTile> createState() => _OptimizedSongTileState();
}

class _OptimizedSongTileState extends State<OptimizedSongTile> {
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {
    // No reactive source — fall back to the static [selected] flag.
    if (widget.currentSongListenable == null) {
      return _buildTile(isCurrent: widget.selected, isPlaying: false);
    }

    // Listen to the current song so this single tile re-highlights the instant
    // playback moves to (or away from) it.
    return ValueListenableBuilder<SongModel?>(
      valueListenable: widget.currentSongListenable!,
      builder: (context, currentSong, _) {
        final isCurrent = currentSong?.id == widget.song.id;
        if (!isCurrent || widget.isPlayingListenable == null) {
          return _buildTile(isCurrent: isCurrent, isPlaying: false);
        }
        return ValueListenableBuilder<bool>(
          valueListenable: widget.isPlayingListenable!,
          builder: (context, isPlaying, __) =>
              _buildTile(isCurrent: true, isPlaying: isPlaying),
        );
      },
    );
  }

  Widget _buildTile({required bool isCurrent, required bool isPlaying}) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: isCurrent
                ? BoxDecoration(
                    color: _kNowPlayingAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _kNowPlayingAccent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  )
                : null,
            child: Row(
              children: [
                // Artwork with RepaintBoundary, overlaid with the now-playing
                // bars when this is the active song.
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        _artworkService.buildCachedArtwork(widget.song.id),
                        if (isCurrent)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: NowPlayingBars(
                                  isPlaying: isPlaying,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                        style: TextStyle(
                          color: isCurrent ? _kNowPlayingAccent : Colors.white,
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                          fontFamily: FontConstants.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        splitArtists(widget.song.artist ?? 'Unknown Artist')
                            .join(', '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontFamily: FontConstants.fontFamily,
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

/// 3-bar now-playing indicator backed by MiniMusicVisualizer.
class NowPlayingBars extends StatelessWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const NowPlayingBars({
    super.key,
    required this.isPlaying,
    this.color = Colors.white,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return MiniMusicVisualizer(
      color: color,
      width: 4,
      height: size * 0.5,
      radius: 1,
      animate: isPlaying,
    );
  }
}

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

class _OptimizedGridTileState extends State<OptimizedGridTile> {
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
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
                          fontFamily: FontConstants.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontFamily: FontConstants.fontFamily,
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

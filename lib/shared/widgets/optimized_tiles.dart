import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Animated "equalizer" indicator shown on the currently-playing song tile.
///
/// Each of the three bars oscillates at its own frequency using |sin()|, so
/// every bar rises to exactly full height on each cycle (“standing up for one
/// unit”). A dedicated amplitude controller smoothly slides bars down to a
/// small stub when playback pauses rather than freezing mid-bounce.
class NowPlayingBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const NowPlayingBars({
    super.key,
    required this.isPlaying,
    this.color = Colors.white,
    this.size = 40,
  });

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with TickerProviderStateMixin {
  // Drives the sine-wave phase; runs continuously while playing.
  late final AnimationController _controller;
  // Fades the live amplitude in (play) and out (pause) over 250 ms.
  late final AnimationController _amplitudeController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(NowPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _controller.repeat();
      _amplitudeController.animateTo(1.0);
    } else {
      // Slide bars down first, then stop the phase ticker.
      _amplitudeController.animateTo(0.0).then((_) {
        if (mounted && !widget.isPlaying) _controller.stop();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      // Merge both animations so the painter redraws on either tick.
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _amplitudeController]),
        builder: (context, _) => CustomPaint(
          painter: _EqBarsPainter(
            t: _controller.value,
            amplitude: _amplitudeController.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

/// Paints a 3-group × 3-bar (9-bar) equalizer on the canvas.
///
/// Groups simulate distinct audio frequency bands:
///   Group 0 — **Bass**:    slow, tall bars (0.80–1.10 Hz).
///   Group 1 — **Voice/Mid**: medium speed, medium height (1.80–2.35 Hz).
///   Group 2 — **Melody/Treble**: fast, shorter flicker (3.20–4.20 Hz).
///
/// Within each group the bars share similar-but-different frequencies with
/// small phase offsets so they move as a coherent unit while still having
/// independent micro-motion. [amplitude] (0–1) is animated by a separate
/// controller and smoothly slides every bar down to its floor stub on pause.
class _EqBarsPainter extends CustomPainter {
  static const double _barWidth  = 2.5;
  static const double _innerGap  = 1.0;  // gap between bars inside one group
  static const double _groupGap  = 4.5;  // gap between groups
  static const int    _groups       = 3;
  static const int    _barsPerGroup = 3;

  // Frequencies in Hz: [group][bar].  Bars inside a group are close together
  // so they visually "belong" to the same band.
  static const _freqs = [
    [0.80, 0.95, 1.10],  // bass
    [1.80, 2.10, 2.35],  // voice / mid
    [3.20, 3.70, 4.20],  // melody / treble
  ];

  // Phase offsets per bar position within a group: 0, π/6, π/3 radians.
  // Keeps bars slightly staggered so a group ripples rather than pulsing as one.
  static const _barPhases = [0.0, 0.5236, 1.0472];

  // Floor: minimum height fraction visible even when fully paused.
  static const _floor = [0.22, 0.13, 0.06];

  // Peak scale: how tall each group's bars can reach at amplitude = 1.
  // Bass reaches full height; treble stays shorter for a realistic spectrum shape.
  static const _peakScale = [1.00, 0.80, 0.60];

  final double t;         // AnimationController value [0, 1)
  final double amplitude; // 0 = paused (bars at floor), 1 = full live motion
  final Color color;

  const _EqBarsPainter({
    required this.t,
    required this.amplitude,
    required this.color,
  });

  /// |sin()| always peaks at 1.0 — each bar “stands up for one unit” per cycle.
  double _fraction(int g, int b) {
    final angle = t * 2 * math.pi * _freqs[g][b] + _barPhases[b];
    final wave = math.sin(angle).abs();
    return _floor[g] + wave * (1.0 - _floor[g]) * _peakScale[g] * amplitude;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    // Total drawn width (bars + inner gaps + group gaps) for centering.
    const totalWidth = _groups * _barsPerGroup * _barWidth
        + _groups * (_barsPerGroup - 1) * _innerGap
        + (_groups - 1) * _groupGap;

    var x = (size.width - totalWidth) / 2;

    for (var g = 0; g < _groups; g++) {
      for (var b = 0; b < _barsPerGroup; b++) {
        final barH = size.height * _fraction(g, b);
        final top  = size.height - barH;
        canvas.drawRRect(
          RRect.fromLTRBR(
            x, top, x + _barWidth, size.height,
            const Radius.circular(_barWidth / 2),
          ),
          paint,
        );
        x += _barWidth;
        if (b < _barsPerGroup - 1) {
          x += _innerGap;
        } else if (g < _groups - 1) {
          x += _groupGap;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EqBarsPainter old) =>
      t != old.t || amplitude != old.amplitude || color != old.color;
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

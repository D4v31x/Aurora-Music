import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../screens/now_playing.dart';

/// Expanding mini player that smoothly transforms into the Now Playing screen
/// Drag up to expand, drag down to collapse
class ExpandingPlayer extends StatefulWidget {
  const ExpandingPlayer({super.key});

  /// Height of the mini player bar (used for bottom padding in other screens)
  static const double miniPlayerHeight = 72.0;

  /// Total height including padding (mini player + bottom safe area + extra padding)
  /// Use this for bottom padding in scrollable content
  static double getMiniPlayerPaddingHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return miniPlayerHeight + bottomPadding + 16; // 16 for extra breathing room
  }

  /// Static controller to allow external access (e.g., for back button handling)
  static MiniplayerController? _activeController;
  static double _currentPercentage = 0.0;

  /// Check if the player is currently expanded
  static bool get isExpanded => _currentPercentage > 0.3;

  /// Minimize the player if it's expanded
  static void minimize() {
    _activeController?.animateToHeight(state: PanelState.MIN);
  }

  @override
  State<ExpandingPlayer> createState() => _ExpandingPlayerState();
}

class _ExpandingPlayerState extends State<ExpandingPlayer> {
  final MiniplayerController _controller = MiniplayerController();
  static const double _minHeight = ExpandingPlayer.miniPlayerHeight;

  @override
  void initState() {
    super.initState();
    ExpandingPlayer._activeController = _controller;
  }

  @override
  void dispose() {
    if (ExpandingPlayer._activeController == _controller) {
      ExpandingPlayer._activeController = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Only rebuild the main player structure when the song changes
    return Selector<AudioPlayerService, SongModel?>(
      selector: (context, audioService) => audioService.currentSong,
      builder: (context, currentSong, child) {
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        return Miniplayer(
          controller: _controller,
          minHeight: _minHeight + bottomPadding,
          maxHeight: maxHeight,
          elevation: 0,
          backgroundColor: Colors.transparent,
          builder: (height, percentage) {
            // Track current percentage for external access
            ExpandingPlayer._currentPercentage = percentage;

            // Show mini player when collapsed, NowPlayingScreen when expanded
            if (percentage < 0.3) {
              return _MiniPlayerContent(
                song: currentSong,
                height: height,
                percentage: percentage,
                bottomPadding: bottomPadding,
              );
            } else {
              return _ExpandedPlayerContent(
                percentage: percentage,
                controller: _controller,
              );
            }
          },
        );
      },
    );
  }
}

class _ExpandedPlayerContent extends StatelessWidget {
  final double percentage;
  final MiniplayerController controller;

  const _ExpandedPlayerContent({
    required this.percentage,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final expandedOpacity = ((percentage - 0.3) * 1.5).clamp(0.0, 1.0);

    // Add solid background to hide anything behind the player
    return Container(
      color: Colors.black, // Solid background to hide content behind
      child: Opacity(
        opacity: expandedOpacity,
        child: NowPlayingScreen(
          onClose: () => controller.animateToHeight(state: PanelState.MIN),
        ),
      ),
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final SongModel song;
  final double height;
  final double percentage;
  final double bottomPadding;
  static final _artworkService = ArtworkCacheService();

  const _MiniPlayerContent({
    required this.song,
    required this.height,
    required this.percentage,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final miniOpacity = (1 - percentage * 3).clamp(0.0, 1.0);
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Solid background to ensure nothing shows behind the mini player
    return Container(
      color: Colors.transparent,
      child: Opacity(
        opacity: miniOpacity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: bottomPadding + 8,
            ),
            child: Container(
              // Add solid background behind the blur to prevent content showing through
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Content row
                        Row(
                          children: [
                            // Artwork with hero animation
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Hero(
                                tag: 'songArtwork',
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _artworkService.buildCachedArtwork(
                                      song.id,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Song info with hero animations
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Hero(
                                      tag: 'songTitle',
                                      flightShuttleBuilder: (context, animation,
                                          direction, from, to) {
                                        return Material(
                                          color: Colors.transparent,
                                          child: DefaultTextStyle.merge(
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'ProductSans',
                                            ),
                                            child: (to.widget as Hero).child,
                                          ),
                                        );
                                      },
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Text(
                                          song.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'ProductSans',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Hero(
                                      tag: 'songArtist',
                                      flightShuttleBuilder: (context, animation,
                                          direction, from, to) {
                                        return Material(
                                          color: Colors.transparent,
                                          child: DefaultTextStyle.merge(
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.7),
                                              fontFamily: 'ProductSans',
                                            ),
                                            child: (to.widget as Hero).child,
                                          ),
                                        );
                                      },
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Text(
                                          splitArtists(song.artist ??
                                                  'Unknown Artist')
                                              .join(', '),
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontFamily: 'ProductSans',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Play/Pause button
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: audioService.isPlayingNotifier,
                                builder: (context, isPlaying, _) {
                                  return GestureDetector(
                                    onTap: () {
                                      if (isPlaying) {
                                        audioService.pause();
                                      } else {
                                        audioService.resume();
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        // Progress bar at bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _MiniProgressBar(audioService: audioService),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final AudioPlayerService audioService;

  const _MiniProgressBar({required this.audioService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioService.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = audioService.audioPlayer.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        return Container(
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

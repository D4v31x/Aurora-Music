import 'package:flutter/material.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/background_manager_service.dart';
import '../services/sleep_timer_controller.dart';
import '../screens/now_playing.dart';
import 'glassmorphic_container.dart';

/// Expanding mini player that smoothly transforms into the Now Playing screen
/// Drag up to expand, drag down to collapse
class ExpandingPlayer extends StatefulWidget {
  const ExpandingPlayer({super.key});

  /// Height of the mini player content (the island itself)
  static const double miniPlayerContentHeight = 70.0;

  /// Margin below the mini player (floating effect)
  static const double bottomMargin = 12.0;

  /// Total height reserved at the bottom of the screen for the mini player
  /// Used for padding in other screens
  static double getMiniPlayerPaddingHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return miniPlayerContentHeight + bottomMargin + bottomPadding + 16;
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

  /// Expand the player to show Now Playing screen
  static void expand() {
    _activeController?.animateToHeight(state: PanelState.MAX);
  }

  @override
  State<ExpandingPlayer> createState() => _ExpandingPlayerState();
}

class _ExpandingPlayerState extends State<ExpandingPlayer> {
  final MiniplayerController _controller = MiniplayerController();

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

    // Calculate the total height needed for the mini player area
    final minHeight = ExpandingPlayer.miniPlayerContentHeight +
        ExpandingPlayer.bottomMargin +
        bottomPadding;

    // Only rebuild the main player structure when the song changes
    return Selector<AudioPlayerService, SongModel?>(
      selector: (context, audioService) => audioService.currentSong,
      builder: (context, currentSong, child) {
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        // Force transparency on the Miniplayer by overriding theme colors
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            canvasColor: Colors.transparent,
            scaffoldBackgroundColor: Colors.transparent,
            cardColor: Colors.transparent,
            shadowColor: Colors.transparent,
            colorScheme: theme.colorScheme.copyWith(
              surface: Colors.transparent,
              surfaceContainer: Colors.transparent,
              surfaceContainerLow: Colors.transparent,
              surfaceContainerHigh: Colors.transparent,
              surfaceContainerHighest: Colors.transparent,
              surfaceDim: Colors.transparent,
              surfaceBright: Colors.transparent,
              surfaceTint: Colors.transparent,
              onSurface: theme.colorScheme.onSurface,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.transparent),
          ),
          child: Miniplayer(
            controller: _controller,
            minHeight: minHeight,
            maxHeight: maxHeight,
            elevation: 0,
            backgroundColor: Colors.transparent,
            builder: (height, percentage) {
              // Track current percentage for external access
              ExpandingPlayer._currentPercentage = percentage;

              // Calculate opacities for smooth cross-fade
              // Fade out mini player: 0.0 -> 0.15 (faster fade out)
              final miniOpacity = (1 - (percentage / 0.15)).clamp(0.0, 1.0);
              // Fade in expanded player: 0.15 -> 0.4
              final expandedOpacity =
                  ((percentage - 0.15) / 0.25).clamp(0.0, 1.0);

              // Slide effect for expanded player
              final slideOffset = (1 - expandedOpacity) * 50.0;

              return Stack(
                children: [
                  // Expanded Player (Now Playing)
                  IgnorePointer(
                    ignoring: percentage < 0.15,
                    child: Visibility(
                      visible: percentage > 0.01,
                      maintainState: true,
                      child: Opacity(
                        opacity: expandedOpacity,
                        child: OverflowBox(
                          minHeight: maxHeight,
                          maxHeight: maxHeight,
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: Offset(0, slideOffset),
                            child: Material(
                              type: MaterialType.transparency,
                              child: _ExpandedPlayerContent(
                                percentage: percentage,
                                controller: _controller,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Mini Player Island
                  IgnorePointer(
                    ignoring: percentage > 0.15,
                    child: Opacity(
                      opacity: miniOpacity,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: minHeight,
                          child: _MiniPlayerContent(
                            song: currentSong,
                            bottomPadding: bottomPadding,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
    // Get providers from parent context
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final backgroundManager =
        Provider.of<BackgroundManagerService>(context, listen: false);
    final sleepTimerController =
        Provider.of<SleepTimerController>(context, listen: false);

    // The NowPlayingScreen content
    // We keep the Navigator to support internal navigation (like Artist Details)
    // We wrap it in HeroControllerScope.none() to avoid conflicts with the main Navigator's HeroController
    return HeroControllerScope.none(
      child: Navigator(
        onGenerateRoute: (settings) {
          return PageRouteBuilder(
            opaque:
                false, // Ensure the route is transparent so we don't see a solid background
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                MultiProvider(
              providers: [
                ChangeNotifierProvider<AudioPlayerService>.value(
                    value: audioPlayerService),
                ChangeNotifierProvider<BackgroundManagerService>.value(
                    value: backgroundManager),
                ChangeNotifierProvider<SleepTimerController>.value(
                    value: sleepTimerController),
              ],
              child: NowPlayingScreen(
                onClose: () =>
                    controller.animateToHeight(state: PanelState.MIN),
              ),
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return child; // No internal transition, we handle it in ExpandingPlayer
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final SongModel song;
  final double bottomPadding;
  static final _artworkService = ArtworkCacheService();

  const _MiniPlayerContent({
    required this.song,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + ExpandingPlayer.bottomMargin,
      ),
      height: ExpandingPlayer.miniPlayerContentHeight,
      child: GlassmorphicContainer(
        borderRadius: BorderRadius.circular(24), // More rounded
        blur: 25,
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Artwork
                  Hero(
                    tag: 'mini_player_artwork',
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _artworkService.buildCachedArtwork(
                          song.id,
                          size: 54,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Song Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'ProductSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          splitArtists(song.artist ?? 'Unknown Artist')
                              .join(', '),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontFamily: 'ProductSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause
                      ValueListenableBuilder<bool>(
                        valueListenable: audioService.isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                if (isPlaying) {
                                  audioService.pause();
                                } else {
                                  audioService.resume();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // Progress Bar at bottom
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: _MiniProgressBar(audioService: audioService),
            ),
          ],
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
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

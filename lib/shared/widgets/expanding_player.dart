import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show navigatorKey;
import '../models/utils.dart';
import '../../features/player/screens/now_playing.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/background_manager_service.dart';
import '../services/sleep_timer_controller.dart';
import '../utils/responsive_utils.dart';
import '../providers/performance_mode_provider.dart';

/// A beautiful, simple mini player that opens the Now Playing screen.
class ExpandingPlayer extends StatefulWidget {
  const ExpandingPlayer({super.key});

  /// Height of the mini player
  static const double miniPlayerHeight = 72.0;

  /// Bottom margin for floating effect
  static const double bottomMargin = 16.0;

  /// Get the total height needed for bottom padding in other screens
  static double getMiniPlayerPaddingHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return miniPlayerHeight + bottomMargin + bottomPadding + 8;
  }

  /// Global state holder
  static _ExpandingPlayerState? _state;

  /// Notifier for when now playing screen is open/closed
  static final ValueNotifier<bool> isOpenNotifier = ValueNotifier<bool>(false);

  /// Check if player is expanded (now playing screen is open)
  static bool get isExpanded => isOpenNotifier.value;

  /// Minimize the player (close now playing screen)
  static void minimize() {
    if (isOpenNotifier.value) {
      navigatorKey.currentState?.maybePop();
    }
  }

  /// Expand the player (open now playing screen)
  static void expand() => _state?._openNowPlaying();

  @override
  State<ExpandingPlayer> createState() => _ExpandingPlayerState();
}

class _ExpandingPlayerState extends State<ExpandingPlayer> {
  @override
  void initState() {
    super.initState();
    ExpandingPlayer._state = this;
    // Reset the state in case it got stuck from a previous session
    ExpandingPlayer.isOpenNotifier.value = false;
  }

  @override
  void dispose() {
    if (ExpandingPlayer._state == this) {
      ExpandingPlayer._state = null;
    }
    super.dispose();
  }

  void _openNowPlaying() {
    // Don't open if already open
    if (ExpandingPlayer.isOpenNotifier.value) return;

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final backgroundManager =
        Provider.of<BackgroundManagerService>(context, listen: false);
    final sleepTimerController =
        Provider.of<SleepTimerController>(context, listen: false);

    // Use global navigator key since we're in MaterialApp.builder
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    HapticFeedback.lightImpact();
    ExpandingPlayer.isOpenNotifier.value = true;

    navigator
        .push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AudioPlayerService>.value(
                  value: audioPlayerService),
              ChangeNotifierProvider<BackgroundManagerService>.value(
                  value: backgroundManager),
              ChangeNotifierProvider<SleepTimerController>.value(
                  value: sleepTimerController),
            ],
            child: NowPlayingScreen(
              onClose: () {
                ExpandingPlayer.isOpenNotifier.value = false;
                navigatorKey.currentState?.pop();
              },
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    )
        .then((_) {
      ExpandingPlayer.isOpenNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ExpandingPlayer.isOpenNotifier,
      builder: (context, isOpen, _) {
        // Hide mini player when now playing screen is open
        if (isOpen) return const SizedBox.shrink();

        return Selector<AudioPlayerService, SongModel?>(
          selector: (_, service) => service.currentSong,
          builder: (context, currentSong, _) {
            if (currentSong == null) return const SizedBox.shrink();

            return _MiniPlayerWidget(
              song: currentSong,
              onTap: _openNowPlaying,
            );
          },
        );
      },
    );
  }
}

/// The beautiful floating mini player widget
/// Performance-aware: Respects device performance mode for blur effects.
class _MiniPlayerWidget extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const _MiniPlayerWidget({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = ResponsiveUtils.isTablet(context);
    final margin = isTablet ? 32.0 : 16.0;
    final colorScheme = Theme.of(context).colorScheme;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use solid surface colors for lowend devices
    final BoxDecoration playerDecoration;
    if (shouldBlur) {
      playerDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      );
    } else {
      // Solid player styling for lowend devices
      playerDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final playerContent = DecoratedBox(
      decoration: playerDecoration,
      child: Stack(
        children: [
          // Progress indicator at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ProgressBar(),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                // Artwork
                _ArtworkThumbnail(songId: song.id, size: 52),

                const SizedBox(width: 14),

                // Song info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        splitArtists(song.artist ?? 'Unknown').join(', '),
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Controls - these need to block parent GestureDetector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PlayPauseButton(size: 46),
                    if (isTablet) ...[
                      const SizedBox(width: 4),
                      _SkipButton(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: margin,
          right: margin,
          bottom: bottomPadding + ExpandingPlayer.bottomMargin,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 480 : screenWidth),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -300) onTap();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: ExpandingPlayer.miniPlayerHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  child: shouldBlur
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: playerContent,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: playerContent,
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

/// Artwork thumbnail with subtle glow effect
class _ArtworkThumbnail extends StatelessWidget {
  final int songId;
  final double size;

  const _ArtworkThumbnail({
    required this.songId,
    required this.size,
  });

  static final _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _artworkService.buildCachedArtwork(songId, size: size),
      ),
    );
  }
}

/// Progress bar at the bottom of mini player
class _ProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return StreamBuilder<Duration>(
      stream: audioService.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = audioService.audioPlayer.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        // Get light vibrant color from artwork
        final backgroundManager =
            Provider.of<BackgroundManagerService>(context);
        final progressColor = backgroundManager.currentColors.length > 2
            ? backgroundManager.currentColors[2]
            : (backgroundManager.currentColors.isNotEmpty
                ? backgroundManager.currentColors.first
                : Theme.of(context).colorScheme.primary);

        return SizedBox(
          height: 3,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor,
              ),
              minHeight: 3,
            ),
          ),
        );
      },
    );
  }
}

/// Play/Pause button
class _PlayPauseButton extends StatelessWidget {
  final double size;

  const _PlayPauseButton({this.size = 48});

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return ValueListenableBuilder<bool>(
      valueListenable: audioService.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            isPlaying ? audioService.pause() : audioService.resume();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          ),
        );
      },
    );
  }
}

/// Skip button for tablets
class _SkipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        audioService.skip();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.skip_next_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

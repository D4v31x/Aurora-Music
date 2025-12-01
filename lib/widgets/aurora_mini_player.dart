import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../screens/now_playing.dart';
import '../utils/audio_service_selectors.dart';

/// Aurora Music Mini Player using the miniplayer package
/// Provides smooth expanding/collapsing animation between mini and full player
/// with advanced hero animations
class AuroraMiniPlayer extends StatefulWidget {
  const AuroraMiniPlayer({super.key});

  @override
  State<AuroraMiniPlayer> createState() => _AuroraMiniPlayerState();
}

class _AuroraMiniPlayerState extends State<AuroraMiniPlayer> with SingleTickerProviderStateMixin {
  static final _artworkService = ArtworkCacheService();
  final MiniplayerController _controller = MiniplayerController();
  late AnimationController _pulseController;
  
  // Height constants
  static const double _minHeight = 76.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = screenHeight; // Full screen height

    // Use CurrentSongListenable for efficient rebuilds only when song changes
    return CurrentSongListenable(
      builder: (context, currentSong) {
        // Don't show player if no song is playing
        if (currentSong == null) {
          return const SizedBox.shrink();
        }
        
        // Get service reference once for callbacks
        final audioPlayerService = context.read<AudioPlayerService>();

        return Miniplayer(
          controller: _controller,
          minHeight: _minHeight,
          maxHeight: maxHeight,
          builder: (height, percentage) {
            // Calculate if we're in mini mode or expanded mode
            final isMini = percentage < 0.5;
            
            return Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: isMini
                  ? _buildMiniPlayer(
                      currentSong,
                      audioPlayerService,
                      height,
                      percentage,
                      bottomPadding,
                    )
                  : _buildExpandedPlayer(
                      currentSong,
                      audioPlayerService,
                      height,
                      percentage,
                      topPadding,
                    ),
            );
          },
        );
      },
    );
  }

  /// Build the mini player view (collapsed state)
  Widget _buildMiniPlayer(
    SongModel currentSong,
    AudioPlayerService audioPlayerService,
    double height,
    double percentage,
    double bottomPadding,
  ) {
    // Fade out mini player as it expands with smoother curve
    final opacity = (1 - (percentage * 2.5)).clamp(0.0, 1.0);
    final scale = 1.0 - (percentage * 0.05); // Subtle scale animation
    
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          margin: EdgeInsets.only(
            left: 12.0,
            right: 12.0,
            bottom: bottomPadding + 12.0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Stack(
                children: [
                  // Main container
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Artwork with advanced hero animation
                        _buildArtwork(currentSong),
                        // Song information
                        _buildSongInfo(currentSong),
                        // Play/pause button
                        _buildPlayPauseButton(audioPlayerService),
                      ],
                    ),
                  ),
                  // Progress bar at the bottom
                  _buildProgressBar(audioPlayerService),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build artwork with hero animation and pulse effect
  Widget _buildArtwork(SongModel currentSong) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Hero(
        tag: 'songArtwork',
        createRectTween: (begin, end) {
          return MaterialRectCenterArcTween(begin: begin, end: end);
        },
        flightShuttleBuilder: (
          BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext,
        ) {
          final Hero toHero = toHeroContext.widget as Hero;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final curvedValue = Curves.easeInOutCubic.transform(animation.value);
              // Animate border radius from mini (20) to expanded (8)
              final borderRadius = BorderRadius.circular(
                20 + (8 - 20) * curvedValue,
              );
              // Animate shadow
              final shadowBlur = 16.0 + (15.0 - 16.0) * curvedValue;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3 + (0.2 * curvedValue)),
                      blurRadius: shadowBlur,
                      offset: Offset(0, 4 + (4 * curvedValue)),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: toHero.child,
                ),
              );
            },
          );
        },
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16.0 + (_pulseController.value * 4),
                      spreadRadius: _pulseController.value * 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _artworkService.buildCachedArtwork(
                    currentSong.id,
                    size: 56,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build song info with hero animations
  Widget _buildSongInfo(SongModel currentSong) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'songTitle',
              flightShuttleBuilder: (
                BuildContext flightContext,
                Animation<double> animation,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final curvedValue = Curves.easeInOutCubic.transform(animation.value);
                    final fontSize = 15.0 + (18.0 - 15.0) * curvedValue;
                    return Material(
                      color: Colors.transparent,
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'ProductSans',
                        ),
                        child: (toHeroContext.widget as Hero).child,
                      ),
                    );
                  },
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Text(
                  currentSong.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    fontFamily: 'ProductSans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Hero(
              tag: 'songArtist',
              flightShuttleBuilder: (
                BuildContext flightContext,
                Animation<double> animation,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final curvedValue = Curves.easeInOutCubic.transform(animation.value);
                    final fontSize = 13.0 + (14.0 - 13.0) * curvedValue;
                    final opacity = 0.8 + (0.7 - 0.8) * curvedValue;
                    return Material(
                      color: Colors.transparent,
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.white.withOpacity(opacity),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'ProductSans',
                        ),
                        child: (toHeroContext.widget as Hero).child,
                      ),
                    );
                  },
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Text(
                  currentSong.artist ?? 'Unknown Artist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
    );
  }

  /// Build play/pause button with hero animation
  Widget _buildPlayPauseButton(AudioPlayerService audioPlayerService) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Hero(
        tag: 'playPauseButton',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (audioPlayerService.isPlaying) {
                audioPlayerService.pause();
              } else {
                audioPlayerService.resume();
              }
            },
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withOpacity(0.3),
            highlightColor: Colors.white.withOpacity(0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(audioPlayerService.isPlaying ? 0.3 : 0.25),
                    Colors.white.withOpacity(audioPlayerService.isPlaying ? 0.15 : 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: audioPlayerService.isPlaying ? 12 : 8,
                    spreadRadius: audioPlayerService.isPlaying ? 1 : 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: RotationTransition(
                      turns: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  audioPlayerService.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(audioPlayerService.isPlaying),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build progress bar with hero animation
  Widget _buildProgressBar(AudioPlayerService audioPlayerService) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: StreamBuilder<Duration>(
        stream: audioPlayerService.audioPlayer.positionStream,
        builder: (context, positionSnapshot) {
          final position = positionSnapshot.data ?? Duration.zero;
          final duration = audioPlayerService.audioPlayer.duration ?? Duration.zero;
          final progress = duration.inMilliseconds > 0
              ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;
          
          return Hero(
            tag: 'progressBar',
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build the expanded player view (full screen state)
  Widget _buildExpandedPlayer(
    SongModel currentSong,
    AudioPlayerService audioPlayerService,
    double height,
    double percentage,
    double topPadding,
  ) {
    // Fade in expanded player as it grows with smoother curve
    final opacity = ((percentage - 0.3) * 1.5).clamp(0.0, 1.0);
    final scale = 0.95 + (percentage * 0.05); // Subtle scale-in effect
    
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[900]!,
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Main content - Now Playing Screen
              const NowPlayingScreen(),
              
              // Enhanced close button with glassmorphic design
              Positioned(
                top: topPadding + 8,
                left: 8,
                child: SafeArea(
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            _controller.animateToHeight(state: PanelState.MIN);
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';

/// Fullscreen album artwork player screen
/// Shows edge-to-edge album art with auto-hiding controls overlay
class FullscreenArtworkScreen extends StatefulWidget {
  const FullscreenArtworkScreen({super.key});

  @override
  State<FullscreenArtworkScreen> createState() =>
      _FullscreenArtworkScreenState();
}

class _FullscreenArtworkScreenState extends State<FullscreenArtworkScreen>
    with TickerProviderStateMixin {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  ImageProvider? _artworkProvider;
  int? _lastSongId;

  StreamSubscription<SongModel?>? _songChangeSubscription;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _controlsController;
  late Animation<double> _controlsAnimation;

  // Controls visibility - controls means the full controls (buttons)
  // Song info and progress bar are always visible
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();

    // Screen fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Controls fade animation (only for playback buttons)
    _controlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeInOut,
    );
    _controlsController.forward();

    // Start auto-hide timer
    _startHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);

      _loadArtwork(audioService);

      _songChangeSubscription = audioService.currentSongStream.listen((song) {
        if (mounted && song != null && song.id != _lastSongId) {
          _loadArtwork(audioService);
        }
      });
    });
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controlsVisible) {
        _hideControls();
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _controlsController.forward();
    }
    _startHideTimer();
  }

  void _hideControls() {
    if (_controlsVisible) {
      _controlsController.reverse().then((_) {
        if (mounted) {
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  Future<void> _loadArtwork(AudioPlayerService audioService) async {
    final song = audioService.currentSong;
    if (song == null) return;

    _lastSongId = song.id;

    try {
      final provider = await _artworkService.getCachedImageProvider(
        song.id,
        highQuality: true,
      );
      if (mounted) {
        setState(() => _artworkProvider = provider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _artworkProvider = null);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controlsController.dispose();
    _hideControlsTimer?.cancel();
    _songChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final song = audioService.currentSong;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeController,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fullscreen artwork - edge to edge
            GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              child: Hero(
                tag: 'songArtwork',
                createRectTween: (begin, end) {
                  return MaterialRectCenterArcTween(begin: begin, end: end);
                },
                child: _artworkProvider != null
                    ? Image(
                        image: _artworkProvider!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        gaplessPlayback: true,
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            color: Colors.white24,
                            size: 100,
                          ),
                        ),
                      ),
              ),
            ),

            // Top gradient (only when controls visible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 280 + padding.top,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _controlsAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom gradient (always visible for song info)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _controlsVisible
                      ? 320 + padding.bottom
                      : 260 + padding.bottom,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Top bar with close button (only when controls visible)
            Positioned(
              top: padding.top + 8,
              left: 8,
              right: 8,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: FadeTransition(
                  opacity: _controlsAnimation,
                  child: _buildTopBar(context, audioService),
                ),
              ),
            ),

            // Bottom content - song info and progress (animates position)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _controlsVisible ? padding.bottom + 16 : -20,
              left: _controlsVisible ? 24 : 16,
              right: _controlsVisible ? 24 : 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Song info (always visible)
                  if (song != null) _buildSongInfo(song),

                  const SizedBox(height: 8),

                  // Progress bar (always visible)
                  _buildProgressBar(audioService, _controlsVisible),

                  // Playback controls (fade in/out)
                  IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: FadeTransition(
                      opacity: _controlsAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildControls(audioService),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AudioPlayerService audioService) {
    final sourceInfo = audioService.playbackSource;
    String sourceName = 'Library';

    switch (sourceInfo.source) {
      case PlaybackSource.album:
        sourceName = sourceInfo.name ?? 'Album';
        break;
      case PlaybackSource.artist:
        sourceName = sourceInfo.name ?? 'Artist';
        break;
      case PlaybackSource.playlist:
        sourceName = sourceInfo.name ?? 'Playlist';
        break;
      case PlaybackSource.forYou:
        sourceName = 'For You';
        break;
      case PlaybackSource.recentlyPlayed:
        sourceName = 'Recently Played';
        break;
      case PlaybackSource.recentlyAdded:
        sourceName = 'Recently Added';
        break;
      case PlaybackSource.mostPlayed:
        sourceName = 'Most Played';
        break;
      case PlaybackSource.folder:
        sourceName = sourceInfo.name ?? 'Folder';
        break;
      case PlaybackSource.search:
        sourceName = 'Search';
        break;
      default:
        sourceName = 'Library';
    }

    return Row(
      children: [
        // Close button (down arrow)
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),

        // Source info centered
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Playing from',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sourceName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
            ],
          ),
        ),

        // Menu button
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _startHideTimer();
          },
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSongInfo(SongModel song) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Song title - bold white, left aligned
        Text(
          song.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Artist - regular gray, left aligned
        Text(
          splitArtists(song.artist ?? 'Unknown Artist').join(', '),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.white.withOpacity(0.6),
            fontFamily: FontConstants.fontFamily,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  bool _isDragging = false;
  double? _dragValue;

  Widget _buildProgressBar(
      AudioPlayerService audioService, bool showTimeLabels) {
    return StreamBuilder<Duration>(
      stream: audioService.audioPlayer.positionStream,
      builder: (context, positionSnapshot) {
        var position = positionSnapshot.data ?? Duration.zero;
        final duration = audioService.audioPlayer.duration ?? Duration.zero;
        if (position > duration) position = duration;

        final displayPosition = _isDragging
            ? Duration(
                milliseconds: (_dragValue! * duration.inMilliseconds).round())
            : position;

        final progress = duration.inMilliseconds > 0
            ? (displayPosition.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time labels - only show when controls visible
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: showTimeLabels ? 24 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showTimeLabels ? 1.0 : 0.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(displayPosition),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Custom progress bar - no dot, matches now playing
            SizedBox(
              height: 32,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _startHideTimer();
                      final percentage =
                          (details.localPosition.dx / width).clamp(0.0, 1.0);
                      setState(() {
                        _isDragging = true;
                        _dragValue = percentage;
                      });
                    },
                    onTapUp: (details) {
                      if (_dragValue != null) {
                        final newPosition = duration * _dragValue!;
                        audioService.audioPlayer.seek(newPosition);
                      }
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                    },
                    onHorizontalDragStart: (details) {
                      _startHideTimer();
                      final percentage =
                          (details.localPosition.dx / width).clamp(0.0, 1.0);
                      setState(() {
                        _isDragging = true;
                        _dragValue = percentage;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      final percentage =
                          (details.localPosition.dx / width).clamp(0.0, 1.0);
                      setState(() {
                        _dragValue = percentage;
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragValue != null) {
                        final newPosition = duration * _dragValue!;
                        audioService.audioPlayer.seek(newPosition);
                      }
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: width,
                        height: _isDragging ? 8.0 : 4.0,
                        child: Stack(
                          children: [
                            Container(
                              width: width,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(
                                    _isDragging ? 4.0 : 2.0),
                              ),
                            ),
                            AnimatedContainer(
                              duration: _isDragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 100),
                              width: width *
                                  (_isDragging ? _dragValue! : progress),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                    _isDragging ? 4.0 : 2.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(AudioPlayerService audioService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle button
        ValueListenableBuilder<bool>(
          valueListenable: audioService.isShuffleNotifier,
          builder: (context, isShuffle, _) {
            return IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _startHideTimer();
                audioService.toggleShuffle();
              },
              icon: Icon(
                Icons.shuffle_rounded,
                color: isShuffle ? Colors.white : Colors.white.withOpacity(0.5),
                size: 24,
              ),
            );
          },
        ),

        // Previous button
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _startHideTimer();
            audioService.back();
          },
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),

        // Play/Pause button - modern icon, no circle
        ValueListenableBuilder<bool>(
          valueListenable: audioService.isPlayingNotifier,
          builder: (context, isPlaying, _) {
            return IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _startHideTimer();
                isPlaying ? audioService.pause() : audioService.resume();
              },
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 56,
              ),
            );
          },
        ),

        // Next button
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _startHideTimer();
            audioService.skip();
          },
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),

        // Repeat button
        ValueListenableBuilder<LoopMode>(
          valueListenable: audioService.loopModeNotifier,
          builder: (context, loopMode, _) {
            IconData icon;
            Color color;

            switch (loopMode) {
              case LoopMode.one:
                icon = Icons.repeat_one_rounded;
                color = Colors.white;
                break;
              case LoopMode.all:
                icon = Icons.repeat_rounded;
                color = Colors.white;
                break;
              default:
                icon = Icons.repeat_rounded;
                color = Colors.white.withOpacity(0.5);
            }

            return IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _startHideTimer();
                audioService.toggleRepeat();
              },
              icon: Icon(
                icon,
                color: color,
                size: 24,
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

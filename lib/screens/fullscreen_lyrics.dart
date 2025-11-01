import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/timed_lyrics.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../localization/app_localizations.dart';

class FullscreenLyricsScreen extends StatefulWidget {
  const FullscreenLyricsScreen({
    super.key,
  });

  @override
  State<FullscreenLyricsScreen> createState() => _FullscreenLyricsScreenState();
}

class _FullscreenLyricsScreenState extends State<FullscreenLyricsScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int _currentLyricIndex = 0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<SongModel?>? _songChangeSubscription;
  late AnimationController _fadeController;

  // For smooth scrolling to center
  final GlobalKey _scrollKey = GlobalKey();
  Map<int, GlobalKey> _lyricKeys = {};

  // Track current song and lyrics
  List<TimedLyric>? _currentLyrics;
  int? _lastSongId;
  bool _isLoadingLyrics = false;

  @override
  void initState() {
    super.initState();
    _currentLyricIndex = 0;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Listen to position and song changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      _loadLyricsForCurrentSong(audioService);

      _positionSubscription =
          audioService.audioPlayer.positionStream.listen((position) {
        if (mounted) {
          _updateCurrentLyric(position);
        }
      });

      // Listen for song changes
      _songChangeSubscription = audioService.currentSongStream.listen((song) {
        if (mounted && song != null && song.id != _lastSongId) {
          _loadLyricsForCurrentSong(audioService);
        }
      });
    });
  }

  Future<void> _loadLyricsForCurrentSong(
      AudioPlayerService audioService) async {
    final song = audioService.currentSong;
    if (song == null) return;

    // If it's the same song, don't reload
    if (_lastSongId == song.id && _currentLyrics != null) return;

    setState(() {
      _isLoadingLyrics = true;
      _lastSongId = song.id;
    });

    final timedLyricsService = TimedLyricsService();
    final artistRaw = song.artist ?? '';
    final titleRaw = song.title;
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = titleRaw.trim().isEmpty ? 'Unknown' : titleRaw.trim();

    // Load cached lyrics
    var lyrics = await timedLyricsService.loadLyricsFromFile(artist, title);
    if (!mounted || audioService.currentSong?.id != song.id) return;

    lyrics ??= await timedLyricsService.fetchTimedLyrics(artist, title);

    if (!mounted || audioService.currentSong?.id != song.id) return;

    setState(() {
      _currentLyrics = lyrics;
      _currentLyricIndex = 0;
      _isLoadingLyrics = false;

      // Recreate keys for new lyrics
      _lyricKeys = {};
      if (_currentLyrics != null) {
        for (int i = 0; i < _currentLyrics!.length; i++) {
          _lyricKeys[i] = GlobalKey();
        }
      }
    });

    // Scroll to top for new song
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _updateCurrentLyric(Duration position) {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) return;

    int newIndex = _currentLyricIndex;

    for (int i = 0; i < _currentLyrics!.length; i++) {
      if (position < _currentLyrics![i].time) {
        newIndex = i > 0 ? i - 1 : 0;
        break;
      }
      if (i == _currentLyrics!.length - 1) {
        newIndex = i;
      }
    }

    if (newIndex != _currentLyricIndex) {
      setState(() {
        _currentLyricIndex = newIndex;
      });
      _scrollToCurrentLyric();
    }
  }

  void _scrollToCurrentLyric({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final RenderBox? renderBox = _lyricKeys[_currentLyricIndex]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final RenderBox? scrollBox =
        _scrollKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero, ancestor: scrollBox);
    final itemHeight = renderBox.size.height;
    final scrollBoxHeight = scrollBox.size.height;

    // Calculate offset to center the current lyric
    final targetOffset = _scrollController.offset +
        position.dy -
        (scrollBoxHeight / 2) +
        (itemHeight / 2);

    if (animate) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _songChangeSubscription?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    // Check if song changed and reload lyrics
    if (audioService.currentSong != null &&
        audioService.currentSong!.id != _lastSongId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLyricsForCurrentSong(audioService);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(audioService),

                // Lyrics content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _isLoadingLyrics
                        ? _buildLoadingView()
                        : (_currentLyrics == null || _currentLyrics!.isEmpty)
                            ? _buildNoLyricsView()
                            : _buildLyricsView(),
                  ),
                ),

                // Bottom controls
                _buildBottomControls(audioService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AudioPlayerService audioService) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.expand_more,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                audioService.currentSong?.title ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'ProductSans',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                audioService.currentSong?.artist ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontFamily: 'ProductSans',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricsView() {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) {
      return _buildNoLyricsView();
    }

    return Hero(
      tag: 'lyrics_container',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView.builder(
                  key: _scrollKey,
                  controller: _scrollController,
                  cacheExtent: 200,
                  addRepaintBoundaries: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: MediaQuery.of(context).size.height * 0.35,
                  ),
                  itemCount: _currentLyrics!.length,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      key: ValueKey('lyric_$index'),
                      child: _buildLyricLine(index),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    );
  }

  Widget _buildLyricLine(int index) {
    if (_currentLyrics == null || index >= _currentLyrics!.length) {
      return const SizedBox.shrink();
    }

    final lyric = _currentLyrics![index];
    final isCurrent = index == _currentLyricIndex;
    final isPast = index < _currentLyricIndex;

    // Calculate distance from current for fade effect
    final distance = (index - _currentLyricIndex).abs();
    final opacity = isCurrent
        ? 1.0
        : isPast
            ? 0.4
            : (1.0 - (distance * 0.15)).clamp(0.3, 0.6);

    final fontSize = isCurrent ? 20.0 : 15.0;
    final fontWeight = isCurrent ? FontWeight.bold : FontWeight.w500;

    return GestureDetector(
      key: _lyricKeys[index],
      onTap: () => _seekToLyric(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCurrent ? 16 : 12,
          horizontal: 8,
        ),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: isCurrent ? 1.0 : 0.95 + (0.05 * value),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: opacity,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    if (isCurrent) {
                      // Gradient effect for current lyric (Apple Music style)
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.greenAccent.shade100,
                          Colors.white,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    }
                    return LinearGradient(
                      colors: [Colors.white, Colors.white],
                    ).createShader(bounds);
                  },
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      fontFamily: 'ProductSans',
                      height: 1.4,
                      letterSpacing: isCurrent ? 0.5 : 0.2,
                      color: Colors.white,
                    ),
                    child: Text(
                      lyric.text,
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoLyricsView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lyrics_outlined,
                      size: 64,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context).translate('no_lyrics'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'ProductSans',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(AudioPlayerService audioService) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: glassmorphicContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    StreamBuilder<Duration?>(
                      stream: audioService.audioPlayer.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration>(
                          stream: audioService.audioPlayer.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final progress = duration.inMilliseconds > 0
                                ? (position.inMilliseconds /
                                        duration.inMilliseconds)
                                    .clamp(0.0, 1.0)
                                : 0.0;

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 14),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor:
                                        Colors.white.withOpacity(0.3),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: (value) {
                                      final newPosition = duration * value;
                                      audioService.audioPlayer
                                          .seek(newPosition);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontFamily: 'ProductSans',
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontFamily: 'ProductSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: IconButton(
                                icon: Icon(
                                  audioService.isShuffle
                                      ? Icons.shuffle
                                      : Icons.shuffle,
                                  color: audioService.isShuffle
                                      ? Colors.greenAccent
                                      : Colors.white.withOpacity(0.7),
                                ),
                                onPressed: audioService.toggleShuffle,
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 400),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: IconButton(
                                icon: const Icon(Icons.skip_previous,
                                    color: Colors.white, size: 32),
                                onPressed: audioService.back,
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    audioService.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    if (audioService.isPlaying) {
                                      audioService.pause();
                                    } else {
                                      audioService.resume();
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 400),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: IconButton(
                                icon: const Icon(Icons.skip_next,
                                    color: Colors.white, size: 32),
                                onPressed: audioService.skip,
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: IconButton(
                                icon: Icon(
                                  audioService.isRepeat
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                  color: audioService.isRepeat
                                      ? Colors.greenAccent
                                      : Colors.white.withOpacity(0.7),
                                ),
                                onPressed: audioService.toggleRepeat,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _seekToLyric(int index) {
    if (_currentLyrics == null || index >= _currentLyrics!.length) return;

    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    audioService.audioPlayer.seek(_currentLyrics![index].time);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

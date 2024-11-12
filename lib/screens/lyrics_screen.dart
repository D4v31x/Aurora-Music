import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/timed_lyrics.dart';
import '../services/Audio_Player_Service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:on_audio_query/on_audio_query.dart';

class FullLyricsScreen extends StatefulWidget {
  final List<TimedLyric>? timedLyrics;
  final int initialLyricIndex;

  const FullLyricsScreen({
    super.key,
    this.timedLyrics,
    required this.initialLyricIndex,
  });

  static Route<void> route({
    required List<TimedLyric>? timedLyrics,
    required int currentLyricIndex,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => FullLyricsScreen(
        timedLyrics: timedLyrics,
        initialLyricIndex: currentLyricIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<FullLyricsScreen> createState() => _FullLyricsScreenState();
}

class _FullLyricsScreenState extends State<FullLyricsScreen> {
  late int currentLyricIndex;
  final Map<int, Uint8List?> _artworkCache = {};

  @override
  void initState() {
    super.initState();
    currentLyricIndex = widget.initialLyricIndex;
    _initializeArtwork();
  }

  Future<void> _initializeArtwork() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    if (audioPlayerService.currentSong != null) {
      await _loadArtwork(audioPlayerService.currentSong!.id);
    }
  }

  Future<void> _loadArtwork(int id) async {
    if (_artworkCache.containsKey(id)) return;
    
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 1000,
      );
      if (mounted) {
        setState(() {
          _artworkCache[id] = artwork;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final size = MediaQuery.of(context).size;

    if (widget.timedLyrics == null || widget.timedLyrics!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        appBar: _buildAppBar(context),
        body: const Center(
          child: Text(
            'Lyrics not available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: audioPlayerService.currentSong?.id != null
                    ? MemoryImage(_artworkCache[audioPlayerService.currentSong!.id] ?? Uint8List(0))
                    : const AssetImage('assets/images/logo/default_art.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          Hero(
            tag: 'lyrics-box',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: size.width,
                height: size.height,
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  audioPlayerService.currentSong?.title ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  audioPlayerService.currentSong?.artist ?? 'Unknown Artist',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                StreamBuilder<Duration>(
                                  stream: audioPlayerService.audioPlayer.positionStream,
                                  builder: (context, snapshot) {
                                    final position = snapshot.data ?? Duration.zero;
                                    final newIndex = _getCurrentLyricIndex(position);
                                    
                                    if (newIndex != currentLyricIndex) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() => currentLyricIndex = newIndex);
                                        }
                                      });
                                    }
                                    
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: widget.timedLyrics!.length,
                                      itemBuilder: (context, index) {
                                        final lyric = widget.timedLyrics![index];
                                        final isCurrent = index == currentLyricIndex;

                                        return AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 300),
                                          style: TextStyle(
                                            color: isCurrent
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                            fontSize: isCurrent ? 22 : 18,
                                            height: 1.5,
                                            letterSpacing: 0.3,
                                            fontWeight: isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8.0,
                                              horizontal: 20.0,
                                            ),
                                            child: Text(
                                              lyric.text,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildPlaybackControls(context, audioPlayerService),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getCurrentLyricIndex(Duration position) {
    if (widget.timedLyrics == null || widget.timedLyrics!.isEmpty) {
      return currentLyricIndex;
    }

    for (int i = 0; i < widget.timedLyrics!.length; i++) {
      if (i == widget.timedLyrics!.length - 1) {
        return i;
      }
      
      if (position < widget.timedLyrics![i + 1].time) {
        return i;
      }
    }
    
    return currentLyricIndex;
  }

  Widget _buildPlaybackControls(BuildContext context, AudioPlayerService audioPlayerService) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration?>(
            stream: audioPlayerService.audioPlayer.durationStream,
            builder: (context, snapshot) {
              final duration = snapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: audioPlayerService.audioPlayer.positionStream,
                builder: (context, snapshot) {
                  var position = snapshot.data ?? Duration.zero;
                  if (position > duration) {
                    position = duration;
                  }
                  return _buildProgressBar(position, duration, audioPlayerService);
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  audioPlayerService.isShuffle ? Icons.shuffle : Icons.shuffle,
                  color: audioPlayerService.isShuffle
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  size: 24,
                ),
                onPressed: audioPlayerService.toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                onPressed: audioPlayerService.back,
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: IconButton(
                  icon: Icon(
                    audioPlayerService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    if (audioPlayerService.isPlaying) {
                      audioPlayerService.pause();
                    } else {
                      audioPlayerService.resume();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                onPressed: audioPlayerService.skip,
              ),
              IconButton(
                icon: Icon(
                  audioPlayerService.isRepeat ? Icons.repeat_one : Icons.repeat,
                  color: audioPlayerService.isRepeat
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  size: 24,
                ),
                onPressed: audioPlayerService.toggleRepeat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Duration position, Duration duration, AudioPlayerService audioPlayerService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
          ),
          child: Slider(
            value: position.inMilliseconds.toDouble(),
            max: duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              audioPlayerService.audioPlayer.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white,
          size: 32,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white,
          ),
          onPressed: () {
            // Add menu options here
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
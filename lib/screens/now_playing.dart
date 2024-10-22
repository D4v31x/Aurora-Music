import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  // Load Genius API keys from .env
import '../models/utils.dart';
import '../services/Audio_Player_Service.dart';
import '../services/expandable_player_controller.dart';
import '../services/lyrics_service.dart';  // Genius lyrics fetching service
import 'Artist_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _lyrics;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchLyrics();  // Fetch lyrics for the current song
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final expandablePlayerController = Provider.of<ExpandablePlayerController>(context, listen: false);
    if (_scrollController.offset > 0 && expandablePlayerController.isExpanded) {
      expandablePlayerController.collapse();
    }
  }

  // Fetch lyrics using the Genius API
  Future<void> _fetchLyrics() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    if (audioPlayerService.currentSong != null) {
      final title = audioPlayerService.currentSong!.title;
      final artist = audioPlayerService.currentSong!.artist;
      _lyrics = await LyricsService.fetchLyrics(artist ?? 'Unknown', title ?? 'Unknown');
      setState(() {});  // Update lyrics display
    }
  }

  Widget _glassmorphicContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final expandablePlayerController = Provider.of<ExpandablePlayerController>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background image with blur effect
          if (audioPlayerService.currentSong != null)
            FutureBuilder<Uint8List?>(
              future: audioPlayerService.getCurrentSongArtwork(),
              builder: (context, snapshot) {
                ImageProvider backgroundImage;
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  backgroundImage = MemoryImage(snapshot.data!);
                } else {
                  backgroundImage = const AssetImage('assets/images/logo/default_art.png');
                }
                return Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: backgroundImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                );
              },
            ),
          // Main content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Album Artwork
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 70.0),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        spreadRadius: 5,
                                        blurRadius: 30,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: FutureBuilder<Uint8List?>(
                                      future: audioPlayerService.getCurrentSongArtwork(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        } else {
                                          return Image.asset(
                                            'assets/images/logo/default_art.png',
                                            fit: BoxFit.cover,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Song Title
                          Text(
                            audioPlayerService.currentSong?.title ?? 'No song playing',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Artist Name
                          GestureDetector(
                            onTap: () {
                              if (audioPlayerService.currentSong != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ArtistDetailsScreen(
                                      artistName: splitArtists(audioPlayerService.currentSong!.artist ?? 'Unknown artist').first,
                                      artistImagePath: null,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              audioPlayerService.currentSong?.artist ?? 'Unknown artist',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Progress Bar
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
                                  return Column(
                                    children: [
                                      Slider(
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white54,
                                        min: 0.0,
                                        max: duration.inMilliseconds.toDouble(),
                                        value: position.inMilliseconds.toDouble(),
                                        onChanged: (value) {
                                          audioPlayerService.audioPlayer.seek(Duration(milliseconds: value.round()));
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(position),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            Text(
                                              _formatDuration(duration),
                                              style: const TextStyle(color: Colors.white),
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
                          // Control Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(audioPlayerService.isShuffle ? Icons.shuffle : Icons.shuffle_outlined, color: Colors.white),
                                onPressed: audioPlayerService.toggleShuffle,
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous, color: Colors.white),
                                onPressed: audioPlayerService.back,
                              ),
                              IconButton(
                                icon: Icon(audioPlayerService.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                                onPressed: () {
                                  if (audioPlayerService.isPlaying) {
                                    audioPlayerService.pause();
                                  } else {
                                    audioPlayerService.resume();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, color: Colors.white),
                                onPressed: audioPlayerService.skip,
                              ),
                              IconButton(
                                icon: Icon(audioPlayerService.isRepeat ? Icons.repeat_one : Icons.repeat, color: Colors.white),
                                onPressed: audioPlayerService.toggleRepeat,
                              ),
                            ],
                          ),
                          // Like Button
                          IconButton(
                            icon: const Icon(Icons.favorite_border, color: Colors.white),
                            onPressed: () {
                              // Handle "like" action here
                            },
                          ),
                          const SizedBox(height: 20),
                          // Lyrics Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _glassmorphicContainer(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _lyrics ?? 'Lyrics not available',
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper function to format duration into mm:ss
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));

  if (duration.inHours > 0) {
    final hours = twoDigits(duration.inHours);
    return '$hours:$minutes:$seconds';
  } else {
    return '$minutes:$seconds';
  }
}

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
import 'package:on_audio_query/on_audio_query.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _lyrics;
  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};
  ImageProvider<Object>? _currentArtwork;
  bool _isLoadingArtwork = true;
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchLyrics();
    _initializeArtwork();
  }

  Future<void> _initializeArtwork() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    if (audioPlayerService.currentSong != null) {
      await _updateArtwork(audioPlayerService.currentSong!);
    }
  }

  Future<ImageProvider<Object>?> _getCachedImageProvider(int id) async {
    if (_imageProviderCache.containsKey(id)) {
      return _imageProviderCache[id];
    }

    final artwork = await _getArtwork(id);
    if (artwork != null) {
      final provider = MemoryImage(artwork) as ImageProvider<Object>;
      _imageProviderCache[id] = provider;
      return provider;
    }
    return null;
  }

  Future<void> _updateArtwork(SongModel song) async {
    setState(() => _isLoadingArtwork = true);
    
    try {
      final provider = await _getCachedImageProvider(song.id);
      if (mounted) {
        setState(() {
          _currentArtwork = provider ?? const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
          _isLoadingArtwork = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentArtwork = const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
          _isLoadingArtwork = false;
        });
      }
    }
  }

  Future<Uint8List?> _getArtwork(int id) async {
    if (_artworkCache.containsKey(id)) {
      return _artworkCache[id];
    }
    
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100, // Zvýšená kvalita
        size: 1000, // Větší velikost
      );
      _artworkCache[id] = artwork;
      return artwork;
    } catch (e) {
      print('Error loading artwork: $e');
      return null;
    }
  }

  // Upravený build method pro artwork
  Widget _buildArtwork() {
    if (_isLoadingArtwork) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Hero(
      tag: 'playerArtwork',
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _currentArtwork != null
              ? Image(image: _currentArtwork!, fit: BoxFit.cover)
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  // Upravený build method pro pozadí
  Widget _buildBackground() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(_currentArtwork),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _currentArtwork ?? const AssetImage('assets/images/logo/default_art.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
      ),
    );
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

    // Aktualizujte artwork pouze když se změní písnička
    if (audioPlayerService.currentSong != null && 
        (_currentArtwork == null || audioPlayerService.currentSong?.id != _lastSongId)) {
      _lastSongId = audioPlayerService.currentSong?.id;
      _updateArtwork(audioPlayerService.currentSong!);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              switch (value) {
                case 'sleep_timer':
                  _showSleepTimerOptions(context);
                  break;
                case 'lyrics':
                  // Implementace pro texty písní
                  break;
                case 'add_playlist':
                  // Implementace pro přidání do playlistu
                  break;
                // Další případy podle potřeby
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'sleep_timer',
                child: Row(
                  children: [
                    Icon(
                      Provider.of<AudioPlayerService>(context, listen: false).isSleepTimerActive 
                          ? Icons.timer 
                          : Icons.timer_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    const Text('Časovač vypnutí', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'lyrics',
                child: Row(
                  children: [
                    Icon(Icons.lyrics_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Texty písní', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'add_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Přidat do playlistu', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              // Další položky menu
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
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
                                child: _buildArtwork(),
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
                          _buildRemainingTime(),
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

  void _showSleepTimerOptions(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final minutesController = TextEditingController();
    final secondsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Přednastavené možnosti v řádku
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimerTile(context, '5', Duration(minutes: 5)),
                    _buildTimerTile(context, '15', Duration(minutes: 15)),
                    _buildTimerTile(context, '30', Duration(minutes: 30)),
                    _buildTimerTile(context, '60', Duration(minutes: 60)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Vlastní čas
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInput(
                      controller: minutesController,
                      label: 'min',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeInput(
                      controller: secondsController,
                      label: 'sec',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSetButton(
                    context,
                    minutesController,
                    secondsController,
                  ),
                ],
              ),
              if (audioPlayerService.isSleepTimerActive) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      audioPlayerService.cancelSleepTimer();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Časovač vypnutí byl zrušen'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.timer_off, color: Colors.red, size: 20),
                    label: const Text('Zrušit časovač', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerTile(BuildContext context, String minutes, Duration duration) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
          audioPlayerService.setSleepTimer(duration);
          Navigator.pop(context);
          _showTimerSetSnackBar(context, duration);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$minutes min',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String label,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: label,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildSetButton(
    BuildContext context,
    TextEditingController minutesController,
    TextEditingController secondsController,
  ) {
    return Container(
      height: 44,
      width: 44,
      child: ElevatedButton(
        onPressed: () {
          final minutes = int.tryParse(minutesController.text) ?? 0;
          final seconds = int.tryParse(secondsController.text) ?? 0;
          if (minutes > 0 || seconds > 0) {
            final duration = Duration(minutes: minutes, seconds: seconds);
            final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
            audioPlayerService.setSleepTimer(duration);
            Navigator.pop(context);
            _showTimerSetSnackBar(context, duration);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  void _showTimerSetSnackBar(BuildContext context, Duration duration) {
    String timeText;
    if (duration.inHours > 0) {
      timeText = '${duration.inHours} hodin';
    } else if (duration.inMinutes > 0) {
      timeText = '${duration.inMinutes} minut';
      if (duration.inSeconds % 60 > 0) {
        timeText += ' a ${duration.inSeconds % 60} sekund';
      }
    } else {
      timeText = '${duration.inSeconds} sekund';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Časovač nastaven na $timeText'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Přidejte nebo upravte _buildRemainingTime pro lepší zobrazení zbývajícího času
  Widget _buildRemainingTime() {
    return Consumer<AudioPlayerService>(
      builder: (context, service, child) {
        if (!service.isSleepTimerActive) return const SizedBox.shrink();
        
        final remaining = service.remainingTime;
        if (remaining == null) return const SizedBox.shrink();
        
        String timeText;
        if (remaining.inHours > 0) {
          timeText = '${remaining.inHours}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
        } else {
          timeText = '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
        }
        
        return _glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

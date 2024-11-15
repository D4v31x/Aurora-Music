import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
// Load Genius API keys from .env
import '../localization/app_localizations.dart';
import '../services/Audio_Player_Service.dart';
import '../services/expandable_player_controller.dart';
import '../services/lyrics_service.dart';  // Genius lyrics fetching service
// Importujte službu pro timed lyrics
import '../widgets/artist_card.dart';
import 'Artist_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/timed_lyrics.dart';
import 'lyrics_screen.dart'; // Importujte model

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  String? _lyrics;
  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};
  ImageProvider<Object>? _currentArtwork;
  bool _isLoadingArtwork = true;
  int? _lastSongId;

  // Přidáme proměnné pro timed lyrics
  List<TimedLyric>? _timedLyrics;
  int _currentLyricIndex = 0;

  // Přidejte tyto proměnné
  late AnimationController _timerExpandController;
  bool _isTimerExpanded = false;
  Timer? _autoCollapseTimer;

  // Přidáme proměnnou pro zdroj přehrávání
  final String _playingSource = "Library"; // Výchozí hodnota

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeArtwork();
    _initializeTimedLyrics();
    _timerExpandController = AnimationController(
      duration: const Duration(milliseconds: 300), // Rychlejší animace
      vsync: this,
    );
  }

  Future<void> _initializeTimedLyrics() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final timedLyricsService = TimedLyricsService();

    if (audioPlayerService.currentSong != null) {
      final song = audioPlayerService.currentSong!;
      // Nejprve se pokusíme načíst z lokálního úložiště
      var lyrics = await timedLyricsService.loadLyricsFromFile(song.artist ?? 'Unknown', song.title ?? 'Unknown');

      lyrics ??= await timedLyricsService.fetchTimedLyrics(song.artist ?? 'Unknown', song.title ?? 'Unknown');

      setState(() {
        _timedLyrics = lyrics;
        _currentLyricIndex = 0;
      });
    }

    // Přihlaste se k poslechu pozice přehrávání
    audioPlayerService.audioPlayer.positionStream.listen((position) {
      _updateCurrentLyric(position);
    });
  }

  void _updateCurrentLyric(Duration position) {
    if (_timedLyrics == null || _timedLyrics!.isEmpty) return;

    for (int i = 0; i < _timedLyrics!.length; i++) {
      if (position < _timedLyrics![i].time) {
        setState(() {
          _currentLyricIndex = i > 0 ? i - 1 : 0;
        });
        break;
      }
      if (i == _timedLyrics!.length - 1) {
        setState(() {
          _currentLyricIndex = i;
        });
      }
    }
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), // Smaller border radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8), // Match container radius
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
    _timerExpandController.dispose();
    _autoCollapseTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    final expandablePlayerController = Provider.of<ExpandablePlayerController>(context, listen: false);
    if (_scrollController.offset > 0 && expandablePlayerController.isExpanded) {
      expandablePlayerController.collapse();
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

  // Update the artwork and song info section
  Widget _buildArtworkWithInfo(AudioPlayerService audioPlayerService) {
    final artworkSize = MediaQuery.of(context).size.width * 0.6;
    
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Info container positioned under the artwork
          Positioned(
            top: artworkSize - 25,
            child: Container(
              width: artworkSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                  bottom: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScrollingText(
                    text: audioPlayerService.currentSong?.title ?? 'No song playing',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                    Text(
                      audioPlayerService.currentSong?.artist ?? 'Unknown artist',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Artwork on top
          SizedBox(
            width: artworkSize,
            height: artworkSize,
            child: _buildArtwork(),
          ),
        ],
      ),
    );
  }

  // Update the progress bar section
  Widget _buildProgressBar(Duration position, Duration duration, AudioPlayerService audioPlayerService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0), // Narrower padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom progress bar
          SizedBox(
            height: 3, // Slightly thicker
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final progress = position.inMilliseconds / duration.inMilliseconds;
                return Stack(
                  children: [
                    // Background track
                    Container(
                      width: width,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    // Progress track
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final position = details.localPosition.dx;
                        final percentage = position / width;
                        final newPosition = duration * percentage;
                        audioPlayerService.audioPlayer.seek(newPosition);
                      },
                      child: Container(
                        width: width * progress,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Time labels below slider
          Row(
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
        ],
      ),
    );
  }

  Widget _buildLyricsSection() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          AppLocalizations.of(context).translate('lyrics'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'ProductSans',
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        Hero(
          tag: 'lyrics-box', // Unique tag for Hero
          child: Stack(
            children: [
              // Glassmorphic container with enhanced blur
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: Opacity(
                      opacity: value,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8 * value, sigmaY: 8 * value),
                          child: Container(
                            width: double.infinity,
                            height: 280,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.7),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_timedLyrics != null && _timedLyrics!.isNotEmpty)
                                  ..._buildAnimatedLyricLines()
                                else
                                  _buildNoLyricsPlaceholder(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Enhanced maximize button
              Positioned(
                top: 8,
                right: 28,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: GestureDetector(
                        onTap: _navigateToFullLyrics,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.open_in_full,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToFullLyrics() {
    Navigator.of(context).push(
      FullLyricsScreen.route(),
    );
  }


  List<Widget> _buildAnimatedLyricLines() {
    final currentIndex = _currentLyricIndex;
    const visibleLines = 5;
    final startIndex = (currentIndex - 2).clamp(0, _timedLyrics!.length - 1);
    final endIndex = (currentIndex + 2).clamp(0, _timedLyrics!.length - 1);

    return _timedLyrics!
        .sublist(startIndex, endIndex + 1)
        .asMap()
        .entries
        .map((entry) {
      final index = entry.key + startIndex;
      final lyric = entry.value;
      final isCurrent = index == currentIndex;

      final distanceFromCenter = (index - currentIndex).abs();
      final opacity = 1.0 - (distanceFromCenter * 0.25);
      final scale = 1.0 - (distanceFromCenter * 0.08);
      final slideOffset = distanceFromCenter * 0.15;

      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..scale(scale)
              ..translate(0.0, 20.0 * (1 - value)),
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: opacity.clamp(0.3, 1.0) * value,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: Offset(0, isCurrent ? 0 : slideOffset),
                child: Container(
                  width: MediaQuery.of(context).size.width - 80, // Account for padding
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.white,
                          Colors.white.withOpacity(0.0)
                        ],
                        stops: const [0.0, 0.85, 0.9, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        fontSize: isCurrent ? 18 : 14,
                        fontFamily: 'ProductSans',
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        height: 1.2,
                        letterSpacing: isCurrent ? 0.2 : 0.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Text(
                          lyric.text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildNoLyricsPlaceholder() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Text(AppLocalizations.of(context).translate(
              'no_lyrics'),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'ProductSans',
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistSection(AudioPlayerService audioPlayerService) {
    final String? artistString = audioPlayerService.currentSong?.artist;
    if (artistString == null || artistString.isEmpty) return const SizedBox.shrink();

    final String mainArtist = artistString.split(RegExp(r'[/,&]')).first.trim();

  return Column(
    children: [
       Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text( AppLocalizations.of(context).translate(
          'about_artist'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'ProductSans',
          ),
          textAlign: TextAlign.center,
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: ArtistCard(
          artistName: mainArtist,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistDetailsScreen(artistName: mainArtist),
            ),
          ),
        ),
      ),
    ],
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
      _initializeTimedLyrics(); // Inicializujte timed lyrics při změně písničky
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
          onPressed: () {
            expandablePlayerController.collapse();
          },
        ),
        actions: [
          _buildSleepTimerIndicator(audioPlayerService),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              switch (value) {
                case 'sleep_timer':
                  _showSleepTimerOptions(context);
                  break;
                case 'view_artist':
                  _showArtistOptions(context, audioPlayerService);
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
                      audioPlayerService.isSleepTimerActive 
                          ? Icons.timer 
                          : Icons.timer_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text( AppLocalizations.of(context).translate('sleep_timer'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'view_artist',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Text( AppLocalizations.of(context).translate('view_artist'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'lyrics',
                child: Row(
                  children: [
                    Icon(Icons.lyrics_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Text( AppLocalizations.of(context).translate('lyrics'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'add_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: Colors.white),
                    SizedBox(width: 12),
                    Text( AppLocalizations.of(context).translate('add_to_playlist'), style: TextStyle(color: Colors.white)),
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
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
              children: [
                const SizedBox(height: 30),
                _buildArtworkWithInfo(audioPlayerService),
                const SizedBox(height: 110),
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
                // Playback Controls
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
                const SizedBox(height: 20),
                // Like Button
                Center(
                  child: IconButton(
                    icon: Icon(
                      audioPlayerService.isLiked(audioPlayerService.currentSong!)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: audioPlayerService.isLiked(audioPlayerService.currentSong!)
                          ? Colors.red
                          : Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      audioPlayerService.toggleLike(audioPlayerService.currentSong!);
                    },
                  ),
                ),
                _buildLyricsSection(),
                const SizedBox(height: 100),
                _buildArtistSection(audioPlayerService),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vytvořte widget pro zobrazení časovaných textů
  Widget _buildTimedLyrics() {
    if (_timedLyrics == null || _timedLyrics!.isEmpty) {
      return Text( AppLocalizations.of(context).translate(
        'no_lyrics'),
        style: TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _timedLyrics!.length,
      itemBuilder: (context, index) {
        final lyric = _timedLyrics![index];
        final isCurrent = index == _currentLyricIndex;
        return AnimatedOpacity(
          opacity: isCurrent ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              lyric.text,
              style: TextStyle(
                color: isCurrent ? Colors.blueAccent : Colors.white,
                fontSize: isCurrent ? 18 : 16,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerOptions(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    int? selectedMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Časovač vypnutí',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                // Nový design pro předvolby
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircularOption('5', selectedMinutes == 5, () => setState(() => selectedMinutes = 5)),
                    _buildCircularOption('10', selectedMinutes == 10, () => setState(() => selectedMinutes = 10)),
                    _buildCircularOption('15', selectedMinutes == 15, () => setState(() => selectedMinutes = 15)),
                    _buildCircularOption('30', selectedMinutes == 30, () => setState(() => selectedMinutes = 30)),
                  ],
                ),
                const SizedBox(height: 24),
                // Vlastní časovač
                GestureDetector(
                  onTap: () => _showNumberPicker(context, (value) => setState(() => selectedMinutes = value)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Text( AppLocalizations.of(context).translate(
                          'own_timer'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Tlačítka
                Row(
                  children: [
                    if (audioPlayerService.isSleepTimerActive)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            audioPlayerService.cancelSleepTimer();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.timer_off, color: Colors.redAccent),
                          label:Text( AppLocalizations.of(context).translate('cancel'), style: TextStyle(color: Colors.redAccent)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (audioPlayerService.isSleepTimerActive)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedMinutes != null ? () {
                          audioPlayerService.setSleepTimer(Duration(minutes: selectedMinutes!));
                          Navigator.pop(context);
                          // Po nastavení časovače rozbalíme indikátor
                          this.setState(() {
                            _isTimerExpanded = true;
                            // Nastavíme časovač pro sbalení po 3 sekundách
                            _autoCollapseTimer?.cancel();
                            _autoCollapseTimer = Timer(const Duration(seconds: 3), () {
                              if (mounted) {
                                this.setState(() {
                                  _isTimerExpanded = false;
                                });
                              }
                            });
                          });
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:Text( AppLocalizations.of(context).translate('set'),
                      ),
                    ))
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularOption(String minutes, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              minutes,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSelected ? 20 : 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              'min',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberPicker(BuildContext context, Function(int) onSelect) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text( AppLocalizations.of(context).translate(
                  'set_minutes'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    backgroundColor: Colors.transparent,
                    onSelectedItemChanged: (index) => onSelect(index + 1),
                    children: List.generate(
                      120,
                      (index) => Center(
                        child: Text(
                          '${index + 1} min',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:Text( AppLocalizations.of(context).translate('set'),
                ),)
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildSleepTimerIndicator(AudioPlayerService audioPlayerService) {
    if (!audioPlayerService.isSleepTimerActive) return const SizedBox.shrink();

    final remainingTime = audioPlayerService.remainingTime;
    if (remainingTime == null) return const SizedBox.shrink();

    final minutes = remainingTime.inMinutes;
    final seconds = (remainingTime.inSeconds % 60).toString().padLeft(2, '0');
    final progress = audioPlayerService.sleepTimerDuration != null
        ? remainingTime.inSeconds / audioPlayerService.sleepTimerDuration!.inSeconds
        : 0.0;

    return Container(
      width: 90.0,
      height: 32.0,
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isTimerExpanded = !_isTimerExpanded;
            if (_isTimerExpanded) {
              _autoCollapseTimer?.cancel();
              _autoCollapseTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _isTimerExpanded = false;
                  });
                }
              });
            } else {
              _autoCollapseTimer?.cancel();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500), // Zvýšení doby trvání pro plynulejší efekt
          curve: Curves.easeOut, // Změna křivky pro plynulejší přechod
          width: _isTimerExpanded ? 120.0 : 32.0,
          height: 32.0,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Kolapsovaný stav
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500), // Synchronizace doby trvání
                    curve: Curves.easeOut, // Změna křivky
                    opacity: _isTimerExpanded ? 0.0 : 1.0,
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                              strokeWidth: 1.5,
                            ),
                          ),
                          const Icon(
                            Icons.bedtime_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Rozbalený stav
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500), // Synchronizace doby trvání
                    curve: Curves.easeOut, // Změna křivky
                    opacity: _isTimerExpanded ? 1.0 : 0.0,
                    child: SizedBox(
                      width: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bedtime_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$minutes:$seconds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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

  void _showArtistOptions(BuildContext context, AudioPlayerService audioPlayerService) {
    final String? artistString = audioPlayerService.currentSong?.artist;
    if (artistString == null || artistString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text( AppLocalizations.of(context).translate('no_artist_info'))),
      );
      return;
    }

    // Split by both "/" and "," and handle potential multiple delimiters
    final List<String> artists = artistString
        .split(RegExp(r'[/,&]'))  // Split by both "/" and ","
        .map((e) => e.trim())  // Remove whitespace
        .where((e) => e.isNotEmpty)  // Remove empty strings
        .toList();

    if (artists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text( AppLocalizations.of(context).translate('no_artist_info'))),
      );
      return;
    }

    if (artists.length == 1) {
      // If there's only one artist, navigate directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArtistDetailsScreen(artistName: artists.first),
        ),
      );
      return;
    }

    // If there are multiple artists, show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text( AppLocalizations.of(context).translate(
                    'select_artist'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...artists.map((artist) => ListTile(
                  title: Text(
                    artist,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistDetailsScreen(artistName: artist),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text( AppLocalizations.of(context).translate(
                    'cancel'),
                    style: TextStyle(color: Colors.white),
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

class SpringCurve extends Curve {
  const SpringCurve({
    required this.mass,
    required this.stiffness,
    required this.damping,
  });

  final double mass;
  final double stiffness;
  final double damping;

  @override
  double transform(double t) {
    final oscillation = exp(-damping * t);
    final frequency = sqrt(stiffness / mass) / (2 * pi);
    return 1 - oscillation * cos(2 * pi * frequency * t);
  }
}

// Přidáme nový widget pro scrollování textu
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _showScrolling = false;
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        setState(() {
          _showScrolling = _scrollController.position.maxScrollExtent > 0;
        });
        if (_showScrolling) {
          _startScrollingWithPause();
        }
      }
    });
  }

  void _startScrollingWithPause() async {
    if (!_showScrolling || _isScrolling) return;

    _isScrolling = true;
    while (_scrollController.hasClients && _showScrolling) {
      // Wait at start
      await Future.delayed(const Duration(seconds: 2));
      
      // Scroll to end
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }

      // Wait at end
      await Future.delayed(const Duration(seconds: 2));

      // Scroll back to start
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0.0,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }
    }
    _isScrolling = false;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(), // Prevent manual scrolling
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

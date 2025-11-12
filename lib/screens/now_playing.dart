import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
// Load Genius API keys from .env
import '../localization/app_localizations.dart';
import '../services/audio_player_service.dart';
import '../services/expandable_player_controller.dart';
import '../services/sleep_timer_controller.dart';
import '../services/lyrics_service.dart'; // Genius lyrics fetching service
import '../services/artwork_cache_service.dart'; // Centralized artwork caching
import '../screens/fullscreen_lyrics.dart'; // Fullscreen lyrics viewer
// Importujte službu pro timed lyrics
import '../widgets/artist_card.dart';
import '../widgets/music_metadata_widget.dart';
import 'Artist_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/timed_lyrics.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

// Extracted constant widgets to avoid rebuilds
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  // Make artwork service static to prevent recreation on every rebuild
  static final _artworkService = ArtworkCacheService();
  ImageProvider<Object>? _currentArtwork;
  bool _isLoadingArtwork = true;
  int? _lastSongId;

  List<TimedLyric>? _timedLyrics;
  int _currentLyricIndex = 0;

  late AnimationController _timerExpandController;
  bool _isTimerExpanded = false;
  Timer? _autoCollapseTimer;

  bool _isDragging = false;

  StreamSubscription<Duration>? _positionSub; // position stream subscription

  int? _pendingSongLoadId; // track song load to prevent race after dispose

  StreamSubscription<SongModel?>?
      _songChangeSubscription; // Listen to song changes

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeArtwork();

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    _initializeTimedLyrics(audioPlayerService);

    // Listen to song changes
    _songChangeSubscription =
        audioPlayerService.currentSongStream.listen((song) {
      if (song != null && song.id != _lastSongId) {
        _lastSongId = song.id;
        _pendingSongLoadId = song.id;
        if (mounted) {
          _updateArtwork(song);
          _initializeTimedLyrics(audioPlayerService);
        }
      }
    });

    _timerExpandController = AnimationController(
      duration: const Duration(milliseconds: 300), // Rychlejší animace
      vsync: this,
    );
  }

  Future<void> _initializeTimedLyrics(
      AudioPlayerService audioPlayerService) async {
    if (!mounted) return;
    final song = audioPlayerService.currentSong;
    if (song == null) return;
    _pendingSongLoadId = song.id;

    final timedLyricsService = TimedLyricsService();
    final artistRaw = song.artist ?? '';
    final titleRaw = song.title; // assume non-nullable
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = titleRaw.trim().isEmpty ? 'Unknown' : titleRaw.trim();

    debugPrint('🎵 [NOW_PLAYING] Requesting lyrics for: "$title" by "$artist"');
    debugPrint(
        '🎵 [NOW_PLAYING] Song duration: ${audioPlayerService.audioPlayer.duration}');

    // Load cached
    var lyrics = await timedLyricsService.loadLyricsFromFile(artist, title);
    if (!mounted || song.id != _pendingSongLoadId) return;

    if (lyrics == null) {
      debugPrint(
          '🎵 [NOW_PLAYING] Cache miss, fetching from API with duration: ${audioPlayerService.audioPlayer.duration}');

      lyrics = await timedLyricsService.fetchTimedLyrics(
        artist,
        title,
        songDuration: audioPlayerService.audioPlayer.duration,
        onMultipleResults: (results) async {
          if (!mounted) return null;
          return await _showLyricsSelectionDialog(results);
        },
      );
    } else {
      debugPrint(
          '🎵 [NOW_PLAYING] ✓ Using cached lyrics (${lyrics.length} lines)');
    }
    if (!mounted || song.id != _pendingSongLoadId) return;

    if (lyrics != null) {
      debugPrint(
          '🎵 [NOW_PLAYING] ✓ Lyrics loaded successfully: ${lyrics.length} lines');
    } else {
      debugPrint('🎵 [NOW_PLAYING] ✗ No lyrics found');
    }

    setState(() {
      _timedLyrics = lyrics;
      _currentLyricIndex = 0;
    });

    _positionSub ??=
        audioPlayerService.audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      _updateCurrentLyric(position);
    });
  }

  Future<Map<String, dynamic>?> _showLyricsSelectionDialog(
      List<Map<String, dynamic>> results) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lyrics, color: Colors.purple[300]),
            const SizedBox(width: 8),
            const Text(
              'Choose Lyrics',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Multiple lyrics found. Select the correct version:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length > 10
                      ? 10
                      : results.length, // Max 10 results
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final trackName = result['trackName'] ?? 'Unknown';
                    final artistName = result['artistName'] ?? 'Unknown';
                    final albumName = result['albumName'] ?? '';

                    return Card(
                      color: Colors.grey[850],
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, result),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trackName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                artistName,
                                style: TextStyle(
                                  color: Colors.purple[300],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (albumName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  albumName,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _updateCurrentLyric(Duration position) {
    if (!mounted) return; // guard
    if (_timedLyrics == null || _timedLyrics!.isEmpty) return;
    for (int i = 0; i < _timedLyrics!.length; i++) {
      if (position < _timedLyrics![i].time) {
        final newIndex = i > 0 ? i - 1 : 0;
        if (newIndex != _currentLyricIndex && mounted) {
          setState(() => _currentLyricIndex = newIndex);
        }
        break;
      }
      if (i == _timedLyrics!.length - 1) {
        if (_currentLyricIndex != i && mounted) {
          setState(() => _currentLyricIndex = i);
        }
      }
    }
  }

  Future<void> _initializeArtwork() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    if (audioPlayerService.currentSong != null) {
      await _updateArtwork(audioPlayerService.currentSong!);
    }
  }

  Future<void> _updateArtwork(SongModel song) async {
    setState(() => _isLoadingArtwork = true);

    try {
      // Use centralized artwork service
      final provider = await _artworkService.getCachedImageProvider(song.id);

      if (mounted) {
        setState(() {
          _currentArtwork = provider;
          _isLoadingArtwork = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentArtwork =
              const AssetImage('assets/images/logo/default_art.png')
                  as ImageProvider<Object>;
          _isLoadingArtwork = false;
        });
      }
    }
  }

  // Optimized artwork display widget
  Widget _buildArtwork() {
    if (_isLoadingArtwork) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _currentArtwork != null
            ? Image(image: _currentArtwork!, fit: BoxFit.cover)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // Upravený build method pro pozadí

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _timerExpandController.dispose();
    _autoCollapseTimer?.cancel();
    _positionSub?.cancel();
    _songChangeSubscription?.cancel(); // Cancel song change subscription
    _pendingSongLoadId = null;
    super.dispose();
  }

  void _scrollListener() {
    final expandablePlayerController =
        Provider.of<ExpandablePlayerController>(context, listen: false);
    if (_scrollController.offset > 0 && expandablePlayerController.isExpanded) {
      expandablePlayerController.collapse();
    }
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
                  Hero(
                    tag: 'songTitle',
                    flightShuttleBuilder: (
                      BuildContext flightContext,
                      Animation<double> animation,
                      HeroFlightDirection flightDirection,
                      BuildContext fromHeroContext,
                      BuildContext toHeroContext,
                    ) {
                      return Material(
                        color: Colors.transparent,
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'ProductSans',
                          ),
                          child: (toHeroContext.widget as Hero).child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: ScrollingText(
                        text: audioPlayerService.currentSong?.title ??
                            'No song playing',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'ProductSans',
                        ),
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
                      return Material(
                        color: Colors.transparent,
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'ProductSans',
                          ),
                          child: (toHeroContext.widget as Hero).child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        audioPlayerService.currentSong?.artist ??
                            'Unknown artist',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'ProductSans',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: artworkSize,
            height: artworkSize,
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
                return Material(
                  color: Colors.transparent,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final curvedValue =
                          Curves.easeOutCubic.transform(animation.value);
                      final borderRadius = BorderRadius.circular(
                        27 + (8 - 27) * curvedValue,
                      );
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: toHero.child,
                        ),
                      );
                    },
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: _buildArtwork(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update the progress bar section
  Widget _buildProgressBar(Duration position, Duration duration,
      AudioPlayerService audioPlayerService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom progress bar
          StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                height: 20, // Increased touch target
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Prevent NaN when duration is zero
                    final progress = (duration.inMilliseconds > 0)
                        ? (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (details) {
                        setState(() => _isDragging = true);
                        audioPlayerService.pause();
                      },
                      onHorizontalDragUpdate: (details) {
                        final tapPos = details.localPosition;
                        final percentage = (tapPos.dx / width).clamp(0.0, 1.0);
                        final newPosition = duration * percentage;
                        audioPlayerService.audioPlayer.seek(newPosition);
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() => _isDragging = false);
                        audioPlayerService.resume();
                      },
                      onTapDown: (details) {
                        final tapPos = details.localPosition;
                        final percentage = (tapPos.dx / width).clamp(0.0, 1.0);
                        final newPosition = duration * percentage;
                        audioPlayerService.audioPlayer.seek(newPosition);
                      },
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: width,
                          height: _isDragging
                              ? 6.0
                              : 3.0, // Animate between normal and dragging height
                          child: Stack(
                            children: [
                              // Background track
                              Container(
                                width: width,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(
                                      _isDragging ? 3.0 : 1.5),
                                ),
                              ),
                              // Progress track
                              Container(
                                width: width * progress,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      _isDragging ? 3.0 : 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontFamily: 'ProductSans',
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontFamily: 'ProductSans',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context).translate('lyrics'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'ProductSans',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            if (_timedLyrics != null && _timedLyrics!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FullscreenLyricsScreen(),
                ),
              );
            }
          },
          child: Hero(
            tag: 'lyrics_container',
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 280,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15), width: 1.5),
                    ),
                    child: Center(
                      child: (_timedLyrics != null && _timedLyrics!.isNotEmpty)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildAnimatedLyricLines(),
                            )
                          : _buildNoLyricsPlaceholder(),
                    ),
                  ),
                  // Glassmorphic expand button positioned at top right
                  if (_timedLyrics != null && _timedLyrics!.isNotEmpty)
                    Positioned(
                      top: 32,
                      right: 32,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.open_in_full,
                                color: Colors.white,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FullscreenLyricsScreen(),
                                  ),
                                );
                              },
                              tooltip: AppLocalizations.of(context)
                                  .translate('expand_lyrics'),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAnimatedLyricLines() {
    if (_timedLyrics == null || _timedLyrics!.isEmpty) return [];

    final currentIndex = _currentLyricIndex;
    final startIndex = max(0, currentIndex - 2);
    final endIndex = min(_timedLyrics!.length - 1, currentIndex + 2);

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
      final slideOffset =
          distanceFromCenter * 0.15; // fraction for AnimatedSlide

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
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 80,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, Colors.white.withOpacity(0.0)],
                        stops: const [0.8, 1.0],
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
                        fontSize: isCurrent ? 20 : 16,
                        fontFamily: 'ProductSans',
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
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
            child: Text(
              AppLocalizations.of(context).translate('no_lyrics'),
              style: const TextStyle(
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
    if (artistString == null || artistString.isEmpty) {
      return const SizedBox.shrink();
    }

    final String mainArtist = artistString.split(RegExp(r'[/,&]')).first.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            AppLocalizations.of(context).translate('about_artist'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
                builder: (context) =>
                    ArtistDetailsScreen(artistName: mainArtist),
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
    final expandablePlayerController =
        Provider.of<ExpandablePlayerController>(context);

    // Only update artwork when song actually changes, not on every rebuild
    final currentSongId = audioPlayerService.currentSong?.id;
    if (currentSongId != null && currentSongId != _lastSongId) {
      _lastSongId = currentSongId;
      _pendingSongLoadId = currentSongId;
      // Schedule artwork update for next frame to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && audioPlayerService.currentSong?.id == currentSongId) {
          _updateArtwork(audioPlayerService.currentSong!);
          _initializeTimedLyrics(audioPlayerService);
        }
      });
    }

    // Add WillPopScope wrapper
    return WillPopScope(
      onWillPop: () async {
        // Collapse the player and return false to prevent default back behavior
        expandablePlayerController.collapse();
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
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
                    _openFullscreenLyrics(context, audioPlayerService);
                    break;
                  case 'add_playlist':
                    _showAddToPlaylistDialog(context, audioPlayerService);
                    break;
                  case 'share':
                    _shareSong(audioPlayerService);
                    break;
                  case 'queue':
                    _showQueueDialog(context, audioPlayerService);
                    break;
                  case 'info':
                    _showSongInfoDialog(context, audioPlayerService);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'sleep_timer',
                  child: Consumer<SleepTimerController>(
                    builder: (context, sleepTimer, child) {
                      return Row(
                        children: [
                          Icon(
                            sleepTimer.isActive
                                ? Icons.timer
                                : Icons.timer_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                              AppLocalizations.of(context)
                                  .translate('sleep_timer'),
                              style: const TextStyle(color: Colors.white)),
                        ],
                      );
                    },
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'view_artist',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                          AppLocalizations.of(context).translate('view_artist'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'lyrics',
                  child: Row(
                    children: [
                      const Icon(Icons.lyrics_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).translate('lyrics'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                          AppLocalizations.of(context)
                              .translate('add_to_playlist'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).translate('share'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'queue',
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_outlined,
                          color: Colors.white),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).translate('queue'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'info',
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).translate('song_info'),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 40.0),
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
                          return _buildProgressBar(
                              position, duration, audioPlayerService);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Music Metadata
                  if (audioPlayerService.currentSong != null)
                    MusicMetadataWidget(song: audioPlayerService.currentSong!),

                  const SizedBox(height: 20),
                  // Playback Controls - wrapped in RepaintBoundary
                  RepaintBoundary(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            audioPlayerService.isShuffle
                                ? Icons.shuffle
                                : Icons.shuffle,
                            color: audioPlayerService.isShuffle
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                            size: 24,
                          ),
                          onPressed: audioPlayerService.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white, size: 32),
                          onPressed: audioPlayerService.back,
                        ),
                        _PlayPauseButton(
                          isPlaying: audioPlayerService.isPlaying,
                          onPressed: () {
                            if (audioPlayerService.isPlaying) {
                              audioPlayerService.pause();
                            } else {
                              audioPlayerService.resume();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              color: Colors.white, size: 32),
                          onPressed: audioPlayerService.skip,
                        ),
                        IconButton(
                          icon: Icon(
                            audioPlayerService.isRepeat
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: audioPlayerService.isRepeat
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                            size: 24,
                          ),
                          onPressed: audioPlayerService.toggleRepeat,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Like Button
                  Center(
                    child: IconButton(
                      icon: Icon(
                        audioPlayerService
                                .isLiked(audioPlayerService.currentSong!)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: audioPlayerService
                                .isLiked(audioPlayerService.currentSong!)
                            ? Colors.red
                            : Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        audioPlayerService
                            .toggleLike(audioPlayerService.currentSong!);
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
      ),
    );
  }

  void _showSleepTimerOptions(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final sleepTimerController =
        Provider.of<SleepTimerController>(context, listen: false);
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircularOption('5', selectedMinutes == 5,
                        () => setState(() => selectedMinutes = 5)),
                    _buildCircularOption('10', selectedMinutes == 10,
                        () => setState(() => selectedMinutes = 10)),
                    _buildCircularOption('15', selectedMinutes == 15,
                        () => setState(() => selectedMinutes = 15)),
                    _buildCircularOption('30', selectedMinutes == 30,
                        () => setState(() => selectedMinutes = 30)),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _showNumberPicker(context,
                      (value) => setState(() => selectedMinutes = value)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
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
                        Text(
                          AppLocalizations.of(context).translate('own_timer'),
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
                Row(
                  children: [
                    if (sleepTimerController.isActive)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            sleepTimerController.cancelTimer();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.timer_off,
                              color: Colors.redAccent),
                          label: Text(
                              AppLocalizations.of(context).translate('cancel'),
                              style: const TextStyle(color: Colors.redAccent)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (sleepTimerController.isActive)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedMinutes != null
                            ? () {
                                sleepTimerController.startTimer(
                                  Duration(minutes: selectedMinutes!),
                                  () => audioPlayerService
                                      .pause(), // Callback to pause when timer completes
                                );
                                Navigator.pop(context);
                                setState(() {
                                  _isTimerExpanded = true;
                                  _autoCollapseTimer?.cancel();
                                  _autoCollapseTimer =
                                      Timer(const Duration(seconds: 3), () {
                                    if (mounted) {
                                      setState(() {
                                        _isTimerExpanded = false;
                                      });
                                    }
                                  });
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('set'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularOption(
      String minutes, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
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
                Text(
                  AppLocalizations.of(context).translate('set_minutes'),
                  style: const TextStyle(
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
                  child: Text(
                    AppLocalizations.of(context).translate('set'),
                  ),
                ),
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
    return Consumer<SleepTimerController>(
      builder: (context, sleepTimerController, child) {
        if (!sleepTimerController.isActive) return const SizedBox.shrink();

        final remainingTime = sleepTimerController.remainingTime;
        if (remainingTime == null) return const SizedBox.shrink();

        final minutes = remainingTime.inMinutes;
        final seconds =
            (remainingTime.inSeconds % 60).toString().padLeft(2, '0');
        final progress = sleepTimerController.duration != null
            ? remainingTime.inSeconds / sleepTimerController.duration!.inSeconds
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
              duration: const Duration(
                  milliseconds:
                      500), // Zvýšení doby trvání pro plynulejší efekt
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
                        duration: const Duration(
                            milliseconds: 500), // Synchronizace doby trvání
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
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
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
                        duration: const Duration(
                            milliseconds: 500), // Synchronizace doby trvání
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
      },
    );
  }

  void _showArtistOptions(
      BuildContext context, AudioPlayerService audioPlayerService) {
    final String? artistString = audioPlayerService.currentSong?.artist;
    if (artistString == null || artistString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).translate('no_artist_info'))),
      );
      return;
    }

    // Split by both "/" and "," and handle potential multiple delimiters
    final List<String> artists = artistString
        .split(RegExp(r'[/,&]')) // Split by both "/" and ","
        .map((e) => e.trim()) // Remove whitespace
        .where((e) => e.isNotEmpty) // Remove empty strings
        .toList();

    if (artists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).translate('no_artist_info'))),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    AppLocalizations.of(context).translate('select_artist'),
                    style: const TextStyle(
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
                            builder: (context) =>
                                ArtistDetailsScreen(artistName: artist),
                          ),
                        );
                      },
                    )),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).translate('cancel'),
                    style: const TextStyle(color: Colors.white),
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

void _openFullscreenLyrics(
    BuildContext context, AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const FullscreenLyricsScreen(),
    ),
  );
}

void _showAddToPlaylistDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_song_playing'))),
    );
    return;
  }

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
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context).translate('select_playlist'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              if (audioPlayerService.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('no_playlists'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: audioPlayerService.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = audioPlayerService.playlists[index];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play,
                            color: Colors.white),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${playlist.songs.length} songs',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () {
                          audioPlayerService.addSongToPlaylist(
                            playlist.id,
                            audioPlayerService.currentSong!,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)
                                    .translate('added_to_playlist'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _shareSong(AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) return;

  final song = audioPlayerService.currentSong!;
  final shareText = '${song.title} - ${song.artist ?? "Unknown Artist"}';

  Share.share(
    shareText,
    subject: 'Check out this song!',
  );
}

void _showQueueDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('queue'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              if (audioPlayerService.playlist.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('queue_empty'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: audioPlayerService.playlist.length,
                    itemBuilder: (context, index) {
                      final song = audioPlayerService.playlist[index];
                      final isCurrentSong =
                          audioPlayerService.currentSong?.id == song.id;
                      return ListTile(
                        leading: isCurrentSong
                            ? const Icon(Icons.play_circle_filled,
                                color: Colors.blue)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            color: isCurrentSong ? Colors.blue : Colors.white,
                            fontWeight: isCurrentSong
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          song.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            color: isCurrentSong
                                ? Colors.blue.shade200
                                : Colors.white70,
                          ),
                        ),
                        onTap: () {
                          audioPlayerService.setPlaylist(
                            audioPlayerService.playlist,
                            index,
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSongInfoDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_song_playing'))),
    );
    return;
  }

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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('song_info'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              MusicMetadataWidget(song: audioPlayerService.currentSong!),
              const SizedBox(height: 16),
              _buildInfoRow('Title', audioPlayerService.currentSong!.title),
              _buildInfoRow('Artist',
                  audioPlayerService.currentSong!.artist ?? 'Unknown'),
              _buildInfoRow(
                  'Album', audioPlayerService.currentSong!.album ?? 'Unknown'),
              _buildInfoRow('Path', audioPlayerService.currentSong!.data),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
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

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
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

import 'dart:async';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart'; // For LoopMode
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../../services/audio_player_service.dart';
import '../../services/sleep_timer_controller.dart';
import '../../services/lyrics_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../services/artist_separator_service.dart';
import '../../services/background_manager_service.dart';
import 'fullscreen_lyrics.dart';
import 'fullscreen_artwork.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/album_card.dart';
import '../../widgets/music_metadata_widget.dart';
import '../library/artist_detail_screen.dart';
import '../library/album_detail_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../models/timed_lyrics.dart';
import '../../widgets/app_background.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/player/player_progress_bar.dart';
import '../../widgets/player/player_controls.dart';
import '../../widgets/player/song_like_button.dart';
import '../../widgets/player/sleep_timer_widgets.dart';
import '../../widgets/player/player_dialogs.dart';
import '../../widgets/common/scrolling_text.dart';

class NowPlayingScreen extends StatefulWidget {
  /// Optional callback for when the down arrow is pressed.
  /// If not provided, will try Navigator.pop() (for when screen is pushed as route)
  final VoidCallback? onClose;

  const NowPlayingScreen({super.key, this.onClose});

  @override
  _NowPlayingScreenState createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  // Make artwork service static to prevent recreation on every rebuild
  static final _artworkService = ArtworkCacheService();
  ImageProvider<Object>? _currentArtwork;
  int? _lastSongId;

  List<TimedLyric>? _timedLyrics;
  final ValueNotifier<int> _currentLyricIndexNotifier = ValueNotifier<int>(0);

  StreamSubscription<Duration>? _positionSub; // position stream subscription

  int? _pendingSongLoadId; // track song load to prevent race after dispose

  StreamSubscription<SongModel?>?
      _songChangeSubscription; // Listen to song changes

  @override
  void initState() {
    super.initState();
    _initializeArtwork();

    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Initialize with current song
    final currentSong = audioPlayerService.currentSong;
    if (currentSong != null) {
      _lastSongId = currentSong.id;
      _initializeTimedLyrics(audioPlayerService);
    }

    // Ensure background artwork is loaded when screen is shown (deferred to avoid build-phase conflicts)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureBackgroundArtwork();
      }
    });

    // Listen to song changes (only trigger for NEW songs)
    _songChangeSubscription =
        audioPlayerService.currentSongStream.listen((song) {
      if (song != null && song.id != _lastSongId) {
        _lastSongId = song.id;
        _pendingSongLoadId = song.id;
        if (mounted) {
          _updateArtwork(song);
          _initializeTimedLyrics(audioPlayerService);
          _ensureBackgroundArtwork();
        }
      }
    });
  }

  /// Ensure background artwork is loaded and visible
  Future<void> _ensureBackgroundArtwork() async {
    final backgroundManager =
        Provider.of<BackgroundManagerService>(context, listen: false);
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // If we have a current song but no background artwork, trigger a refresh
    if (audioPlayerService.currentSong != null &&
        !backgroundManager.hasArtwork) {
      await backgroundManager
          .updateColorsFromSong(audioPlayerService.currentSong);
    }
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
          return _showLyricsSelectionDialog(results);
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
    });
    _currentLyricIndexNotifier.value = 0;

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
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.grey[900]?.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCurrentLyric(Duration position) {
    if (!mounted) return; // guard
    if (_timedLyrics == null || _timedLyrics!.isEmpty) return;
    for (int i = 0; i < _timedLyrics!.length; i++) {
      if (position < _timedLyrics![i].time) {
        final newIndex = i > 0 ? i - 1 : 0;
        if (newIndex != _currentLyricIndexNotifier.value) {
          _currentLyricIndexNotifier.value = newIndex;
        }
        break;
      }
      if (i == _timedLyrics!.length - 1) {
        if (_currentLyricIndexNotifier.value != i) {
          _currentLyricIndexNotifier.value = i;
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
    try {
      // Use centralized artwork service with high quality for now playing screen
      final provider = await _artworkService.getCachedImageProvider(song.id,
          highQuality: true);

      if (mounted) {
        setState(() {
          _currentArtwork = provider;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentArtwork =
              const AssetImage('assets/images/logo/default_art.png')
                  as ImageProvider<Object>;
        });
      }
    }
  }

  // Open fullscreen artwork view with hero animation
  void _openFullscreenArtwork() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChangeNotifierProvider<AudioPlayerService>.value(
            value: audioPlayerService,
            child: const FullscreenArtworkScreen(),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  // Optimized artwork display widget - tappable to open fullscreen view
  Widget _buildArtwork() {
    return GestureDetector(
      onTap: _openFullscreenArtwork,
      child: DecoratedBox(
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
              ? Image(
                  image: _currentArtwork!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Prevent flickering
                )
              : ColoredBox(
                  color: Colors.white.withOpacity(0.1),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 64,
                  ),
                ),
        ),
      ),
    );
  }

  // Upravený build method pro pozadí

  @override
  void dispose() {
    _currentLyricIndexNotifier.dispose();
    _positionSub?.cancel();
    _songChangeSubscription?.cancel();
    _pendingSongLoadId = null;
    super.dispose();
  }

  // Update the artwork and song info section
  Widget _buildArtworkWithInfo(AudioPlayerService audioPlayerService) {
    final size = MediaQuery.of(context).size;
    final isTablet = ResponsiveUtils.isTablet(context);
    final isLandscape = size.width > size.height;

    // Responsive artwork sizing
    final artworkSize = ResponsiveUtils.getNowPlayingArtworkSize(context);

    // On tablets in landscape, use a horizontal layout
    if (isTablet && isLandscape) {
      return _buildTabletLandscapeLayout(audioPlayerService, artworkSize);
    }

    return Padding(
      padding: const EdgeInsets.only(),
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
                            fontFamily: FontConstants.fontFamily,
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
                        style: TextStyle(
                          fontSize: isTablet ? 22 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: FontConstants.fontFamily,
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
                            fontFamily: FontConstants.fontFamily,
                          ),
                          child: (toHeroContext.widget as Hero).child,
                        ),
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        splitArtists(audioPlayerService.currentSong?.artist ??
                                'Unknown artist')
                            .join(', '),
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: FontConstants.fontFamily,
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
                      return DecoratedBox(
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

  /// Tablet landscape layout - artwork on left, info and controls on right
  Widget _buildTabletLandscapeLayout(
      AudioPlayerService audioPlayerService, double artworkSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork on the left
          SizedBox(
            width: artworkSize,
            height: artworkSize,
            child: Hero(
              tag: 'songArtwork',
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildArtwork(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
          // Song info on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Hero(
                  tag: 'songTitle',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      audioPlayerService.currentSong?.title ??
                          'No song playing',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Hero(
                  tag: 'songArtist',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      splitArtists(audioPlayerService.currentSong?.artist ??
                              'Unknown artist')
                          .join(', '),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (audioPlayerService.currentSong?.album != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    audioPlayerService.currentSong!.album!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: FontConstants.fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSection() {
    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalMargin = isTablet ? 40.0 : 20.0;
    final containerHeight = isTablet ? 340.0 : 280.0;

    return Column(
      children: [
        SizedBox(height: isTablet ? 80 : 60),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context).translate('lyrics'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.bold,
                fontFamily: FontConstants.fontFamily,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 24 : 20),
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
                    height: containerHeight,
                    margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                    padding: EdgeInsets.all(isTablet ? 28 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15), width: 1.5),
                    ),
                    child: ClipRect(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.15, 0.85, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Center(
                          child: (_timedLyrics != null &&
                                  _timedLyrics!.isNotEmpty)
                              ? ValueListenableBuilder<int>(
                                  valueListenable: _currentLyricIndexNotifier,
                                  builder: (context, currentIndex, _) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: _buildAnimatedLyricLines(
                                          currentIndex),
                                    );
                                  },
                                )
                              : _buildNoLyricsPlaceholder(),
                        ),
                      ),
                    ),
                  ),
                  // Expand button positioned at top right
                  // Performance: Removed BackdropFilter - use semi-transparent background
                  if (_timedLyrics != null && _timedLyrics!.isNotEmpty)
                    Positioned(
                      top: 32,
                      right: 32,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAnimatedLyricLines(int currentIndex) {
    if (_timedLyrics == null || _timedLyrics!.isEmpty) return [];

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
      final scale = 1.0 - (distanceFromCenter * 0.05);

      // Performance: Use simple transforms and color alpha instead of
      // ShaderMask and AnimatedOpacity which cause expensive compositing
      final effectiveOpacity = opacity.clamp(0.3, 1.0);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCurrent ? 10.0 : 6.0,
          horizontal: 4.0,
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: (isCurrent ? Colors.white : Colors.white60)
                  .withValues(alpha: effectiveOpacity),
              fontSize: isCurrent ? 17 : 14,
              fontFamily: FontConstants.fontFamily,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              height: 1.3,
              letterSpacing: isCurrent ? 0.2 : 0.0,
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 80,
              child: Text(
                lyric.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildNoLyricsPlaceholder() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        // Use color alpha instead of Opacity widget for better performance
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Text(
            AppLocalizations.of(context).translate('no_lyrics'),
            style: TextStyle(
              color: Colors.white70.withValues(alpha: value),
              fontSize: 16,
              fontFamily: FontConstants.fontFamily,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
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

    final String mainArtist =
        ArtistSeparatorService().getPrimaryArtist(artistString);

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
              fontFamily: FontConstants.fontFamily,
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

  Widget _buildAlbumSection(AudioPlayerService audioPlayerService) {
    final String? albumName = audioPlayerService.currentSong?.album;
    if (albumName == null || albumName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            AppLocalizations.of(context).translate('album'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: FontConstants.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: AlbumCard(
            albumName: albumName,
            artistName: audioPlayerService.currentSong?.artist,
            albumId: audioPlayerService.currentSong?.albumId,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlbumDetailScreen(albumName: albumName),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use read instead of watch/listen to avoid rebuilding entire screen
    // Individual components use ValueListenableBuilder or Selector for targeted updates
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

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

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Pop already happened, just call onClose callback if provided
        if (didPop && widget.onClose != null) {
          // The pop already happened, just trigger the callback for cleanup
          // Don't call maybePop again or it will cause issues
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: _buildPlayingFromHeader(audioPlayerService),
            leading: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  // Only pop if we can (screen was pushed as route)
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
            actions: [
              const SleepTimerIndicator(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'sleep_timer':
                      showSleepTimerOptions(context);
                      break;
                    case 'view_artist':
                      _showArtistOptions(context, audioPlayerService);
                      break;
                    case 'lyrics':
                      _openFullscreenLyrics(context, audioPlayerService);
                      break;
                    case 'add_playlist':
                      showAddToPlaylistDialog(context, audioPlayerService);
                      break;
                    case 'share':
                      shareSong(audioPlayerService);
                      break;
                    case 'queue':
                      showQueueDialog(context, audioPlayerService);
                      break;
                    case 'info':
                      showSongInfoDialog(context, audioPlayerService);
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
                              style: const TextStyle(color: Colors.white),
                            ),
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
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'lyrics',
                    child: Row(
                      children: [
                        const Icon(Icons.lyrics_outlined, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).translate('lyrics'),
                          style: const TextStyle(color: Colors.white),
                        ),
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
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).translate('share'),
                          style: const TextStyle(color: Colors.white),
                        ),
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
                        Text(
                          AppLocalizations.of(context).translate('queue'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'info',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).translate('song_info'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _buildResponsiveBody(audioPlayerService),
        ),
      ),
    );
  }

  /// Build the body with responsive layout for tablets
  Widget _buildResponsiveBody(AudioPlayerService audioPlayerService) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    final verticalPadding = isTablet ? 50.0 : 40.0;
    final maxContentWidth = isTablet ? 900.0 : double.infinity;

    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: ListView(
                // Use AlwaysScrollableScrollPhysics with BouncingScrollPhysics
                // to ensure the list always consumes the scroll gestures,
                // preventing the miniplayer from collapsing.
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                children: [
                  SizedBox(height: isTablet ? 40 : 30),
                  _buildArtworkWithInfo(audioPlayerService),
                  SizedBox(height: isTablet && isLandscape ? 40 : 90),
                  PlayerProgressBar(
                      audioService: audioPlayerService, isTablet: isTablet),
                  SizedBox(height: isTablet ? 28 : 20),
                  PlayerControls(
                      audioPlayerService: audioPlayerService,
                      isTablet: isTablet),
                  SizedBox(height: isTablet ? 28 : 20),
                  Center(
                    child: SongLikeButton(
                      audioPlayerService: audioPlayerService,
                      size: isTablet ? 34 : 30,
                    ),
                  ),
                  // Reordered: Lyrics first
                  _buildLyricsSection(),
                  SizedBox(height: isTablet ? 40 : 30),
                  // Album section
                  if (audioPlayerService.currentSong != null)
                    _buildAlbumSection(audioPlayerService),
                  SizedBox(height: isTablet ? 40 : 30),
                  // Artist section
                  _buildArtistSection(audioPlayerService),
                  SizedBox(height: isTablet ? 40 : 30),
                  // Metadata last
                  if (audioPlayerService.currentSong != null)
                    MusicMetadataWidget(
                      song: audioPlayerService.currentSong!,
                    ),
                  SizedBox(height: isTablet ? 40 : 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the "Playing from" header in the app bar
  Widget _buildPlayingFromHeader(AudioPlayerService audioPlayerService) {
    final source = audioPlayerService.playbackSource;

    String sourceLabel;
    switch (source.source) {
      case PlaybackSource.forYou:
        sourceLabel = AppLocalizations.of(context).translate('for_you');
        break;
      case PlaybackSource.recentlyPlayed:
        sourceLabel = AppLocalizations.of(context).translate('recently_played');
        break;
      case PlaybackSource.recentlyAdded:
        sourceLabel = AppLocalizations.of(context).translate('recently_added');
        break;
      case PlaybackSource.mostPlayed:
        sourceLabel = AppLocalizations.of(context).translate('most_played');
        break;
      case PlaybackSource.album:
        sourceLabel =
            source.name ?? AppLocalizations.of(context).translate('album');
        break;
      case PlaybackSource.artist:
        sourceLabel =
            source.name ?? AppLocalizations.of(context).translate('artist');
        break;
      case PlaybackSource.playlist:
        sourceLabel =
            source.name ?? AppLocalizations.of(context).translate('playlist');
        break;
      case PlaybackSource.folder:
        sourceLabel =
            source.name ?? AppLocalizations.of(context).translate('folder');
        break;
      case PlaybackSource.search:
        sourceLabel = AppLocalizations.of(context).translate('search');
        break;
      case PlaybackSource.library:
        sourceLabel = AppLocalizations.of(context).translate('library');
        break;
      case PlaybackSource.unknown:
        sourceLabel = AppLocalizations.of(context).translate('library');
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).translate('playing_from'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            fontFamily: FontConstants.fontFamily,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sourceLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: FontConstants.fontFamily,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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

    // Use centralized artist separator service
    final List<String> artists =
        ArtistSeparatorService().splitArtists(artistString);

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
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      style: const TextStyle(color: Colors.white70),
                    ),
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

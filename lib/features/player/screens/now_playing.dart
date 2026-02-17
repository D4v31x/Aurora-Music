/// Now Playing screen.
///
/// Displays the currently playing song with artwork, controls, lyrics,
/// and artist/album information.
library;

import 'dart:async';
import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/timed_lyrics.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/background_manager_service.dart';
import '../../../shared/services/lyrics_service.dart';
import '../../../shared/utils/responsive_utils.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/common/scrolling_text.dart';
import '../../../shared/widgets/music_metadata_widget.dart';
import '../../library/screens/artist_detail_screen.dart';
import '../widgets/player_widgets.dart';
import 'fullscreen_artwork.dart';
import 'fullscreen_lyrics.dart';

// MARK: - Now Playing Screen

/// The main Now Playing screen widget.
///
/// Displays the currently playing song with album artwork, playback controls,
/// lyrics, and artist/album information. Supports both phone and tablet layouts.
class NowPlayingScreen extends StatefulWidget {
  /// Optional callback for when the down arrow is pressed.
  final VoidCallback? onClose;

  const NowPlayingScreen({super.key, this.onClose});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  // MARK: - Private Fields

  static final _artworkService = ArtworkCacheService();
  ImageProvider<Object>? _currentArtwork;
  int? _lastSongId;

  List<TimedLyric>? _timedLyrics;
  final ValueNotifier<int> _currentLyricIndexNotifier = ValueNotifier<int>(0);

  StreamSubscription<Duration>? _positionSub;
  int? _pendingSongLoadId;
  StreamSubscription<SongModel?>? _songChangeSubscription;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _currentLyricIndexNotifier.dispose();
    _positionSub?.cancel();
    _songChangeSubscription?.cancel();
    _pendingSongLoadId = null;
    super.dispose();
  }

  // MARK: - Initialization

  void _initializeScreen() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    // Initialize with current song
    final currentSong = audioPlayerService.currentSong;
    if (currentSong != null) {
      _lastSongId = currentSong.id;
      _initializeTimedLyrics(audioPlayerService);
      _updateArtwork(currentSong);
    }

    // Ensure background artwork is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureBackgroundArtwork();
    });

    // Listen to song changes
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

  Future<void> _ensureBackgroundArtwork() async {
    final backgroundManager =
        Provider.of<BackgroundManagerService>(context, listen: false);
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    if (audioPlayerService.currentSong != null &&
        !backgroundManager.hasArtwork) {
      await backgroundManager
          .updateColorsFromSong(audioPlayerService.currentSong);
    }
  }

  // MARK: - Lyrics Loading

  Future<void> _initializeTimedLyrics(
      AudioPlayerService audioPlayerService) async {
    if (!mounted) return;
    final song = audioPlayerService.currentSong;
    if (song == null) return;
    _pendingSongLoadId = song.id;

    final timedLyricsService = TimedLyricsService();
    final artistRaw = song.artist ?? '';
    final titleRaw = song.title;
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = titleRaw.trim().isEmpty ? 'Unknown' : titleRaw.trim();

    // Load cached first
    var lyrics = await timedLyricsService.loadLyricsFromFile(artist, title);
    if (!mounted || song.id != _pendingSongLoadId) return;

    if (lyrics == null) {
      lyrics = await timedLyricsService.fetchTimedLyrics(
        artist,
        title,
        songDuration: audioPlayerService.audioPlayer.duration,
      );
    }
    if (!mounted || song.id != _pendingSongLoadId) return;

    setState(() => _timedLyrics = lyrics);
    _currentLyricIndexNotifier.value = 0;

    _positionSub ??=
        audioPlayerService.audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      _updateCurrentLyric(position);
    });
  }

  void _updateCurrentLyric(Duration position) {
    if (!mounted || _timedLyrics == null || _timedLyrics!.isEmpty) return;

    for (int i = 0; i < _timedLyrics!.length; i++) {
      if (position < _timedLyrics![i].time) {
        final newIndex = i > 0 ? i - 1 : 0;
        if (newIndex != _currentLyricIndexNotifier.value) {
          _currentLyricIndexNotifier.value = newIndex;
        }
        break;
      }
      if (i == _timedLyrics!.length - 1 &&
          _currentLyricIndexNotifier.value != i) {
        _currentLyricIndexNotifier.value = i;
      }
    }
  }

  // MARK: - Artwork Loading

  Future<void> _updateArtwork(SongModel song) async {
    try {
      final provider = await _artworkService.getCachedImageProvider(
        song.id,
        highQuality: true,
      );
      if (mounted) setState(() => _currentArtwork = provider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentArtwork =
              const AssetImage('assets/images/logo/default_art.png');
        });
      }
    }
  }

  // MARK: - Build Method

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.onClose != null) {
          // Pop happened, callback for cleanup
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(audioPlayerService),
          body: _buildBody(audioPlayerService),
        ),
      ),
    );
  }

  // MARK: - App Bar

  AppBar _buildAppBar(AudioPlayerService audioPlayerService) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: PlayingFromHeader(audioPlayerService: audioPlayerService),
      leading: IconButton(
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white,
          size: 32,
        ),
        onPressed: _handleClose,
      ),
      actions: [
        const SleepTimerIndicator(),
        PlayerMoreOptionsMenu(
          onSelected: (value) =>
              _handleMenuSelection(value, audioPlayerService),
        ),
      ],
    );
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleMenuSelection(
      String value, AudioPlayerService audioPlayerService) {
    switch (value) {
      case 'sleep_timer':
        showSleepTimerOptions(context);
        break;
      case 'view_artist':
        _showArtistOptions(context, audioPlayerService);
        break;
      case 'lyrics':
        _openFullscreenLyrics(audioPlayerService);
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
  }

  void _openFullscreenLyrics(AudioPlayerService audioPlayerService) {
    if (audioPlayerService.currentSong == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FullscreenLyricsScreen()),
    );
  }

  // MARK: - Body Layout

  Widget _buildBody(AudioPlayerService audioPlayerService) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    final verticalPadding = isTablet ? 50.0 : 40.0;
    final maxContentWidth = isTablet ? 900.0 : double.infinity;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            children: [
              SizedBox(height: isTablet ? 40 : 30),
              _buildArtworkWithInfo(audioPlayerService, isTablet, isLandscape),
              SizedBox(height: isTablet && isLandscape ? 40 : 90),
              PlayerProgressBar(
                audioService: audioPlayerService,
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 28 : 20),
              PlayerControls(
                audioPlayerService: audioPlayerService,
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 28 : 20),
              Center(
                child: SongLikeButton(
                  audioPlayerService: audioPlayerService,
                  size: isTablet ? 34 : 30,
                ),
              ),
              _buildLyricsSection(audioPlayerService, isTablet),
              SizedBox(height: isTablet ? 40 : 30),
              if (audioPlayerService.currentSong != null)
                AlbumSection(audioPlayerService: audioPlayerService),
              SizedBox(height: isTablet ? 40 : 30),
              ArtistSection(audioPlayerService: audioPlayerService),
              SizedBox(height: isTablet ? 40 : 30),
              if (audioPlayerService.currentSong != null)
                MusicMetadataWidget(song: audioPlayerService.currentSong!),
              SizedBox(height: isTablet ? 40 : 30),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Artwork Section

  Widget _buildArtworkWithInfo(
    AudioPlayerService audioPlayerService,
    bool isTablet,
    bool isLandscape,
  ) {
    final artworkSize = ResponsiveUtils.getNowPlayingArtworkSize(context);

    // Tablet landscape: side-by-side layout
    if (isTablet && isLandscape) {
      return _buildTabletLandscapeLayout(audioPlayerService, artworkSize);
    }

    // Phone/tablet portrait: stacked layout
    return _buildPhoneLayout(audioPlayerService, artworkSize, isTablet);
  }

  Widget _buildPhoneLayout(
    AudioPlayerService audioPlayerService,
    double artworkSize,
    bool isTablet,
  ) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Song info container below artwork
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
              child: _buildTrackInfo(audioPlayerService, isTablet),
            ),
          ),
          // Artwork
          SizedBox(
            width: artworkSize,
            height: artworkSize,
            child: _buildHeroArtwork(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLandscapeLayout(
    AudioPlayerService audioPlayerService,
    double artworkSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork
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
                    child: _buildArtworkImage(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                _buildTitleText(audioPlayerService, isTablet: true),
                const SizedBox(height: 8),
                _buildArtistText(audioPlayerService, isTablet: true),
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

  Widget _buildHeroArtwork() {
    return Hero(
      tag: 'songArtwork',
      createRectTween: (begin, end) {
        return MaterialRectCenterArcTween(begin: begin, end: end);
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
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
              child: _buildArtworkImage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkImage() {
    if (_currentArtwork != null) {
      return Image(
        image: _currentArtwork!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return ColoredBox(
      color: Colors.white.withOpacity(0.1),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withOpacity(0.3),
        size: 64,
      ),
    );
  }

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
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildTrackInfo(AudioPlayerService audioPlayerService, bool isTablet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current lyric line
        ValueListenableBuilder<int>(
          valueListenable: _currentLyricIndexNotifier,
          builder: (context, currentIndex, _) {
            final hasLyrics = _timedLyrics != null && _timedLyrics!.isNotEmpty;
            if (!hasLyrics) return const SizedBox.shrink();
            final lyricText = _timedLyrics![currentIndex].text.trim();
            if (lyricText.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                lyricText,
                style: TextStyle(
                  fontSize: isTablet ? 13 : 12,
                  color: Colors.white.withOpacity(0.45),
                  fontFamily: FontConstants.fontFamily,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        _buildTitleText(audioPlayerService, isTablet: isTablet),
        const SizedBox(height: 4),
        _buildArtistText(audioPlayerService, isTablet: isTablet),
      ],
    );
  }

  Widget _buildTitleText(AudioPlayerService audioPlayerService,
      {required bool isTablet}) {
    return Hero(
      tag: 'songTitle',
      child: Material(
        color: Colors.transparent,
        child: ScrollingText(
          text: audioPlayerService.currentSong?.title ?? 'No song playing',
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildArtistText(AudioPlayerService audioPlayerService,
      {required bool isTablet}) {
    final artistString =
        audioPlayerService.currentSong?.artist ?? 'Unknown artist';
    final artists = ArtistSeparatorService().splitArtists(artistString);

    return Hero(
      tag: 'songArtist',
      child: Material(
        color: Colors.transparent,
        child: Text(
          artists.join(', '),
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
    );
  }

  // MARK: - Lyrics Section

  Widget _buildLyricsSection(
      AudioPlayerService audioPlayerService, bool isTablet) {
    final hasLyrics = _timedLyrics != null && _timedLyrics!.isNotEmpty;

    return Column(
      children: [
        SizedBox(height: isTablet ? 80 : 60),
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
        SizedBox(height: isTablet ? 24 : 20),
        GestureDetector(
          onTap: hasLyrics
              ? () => _openFullscreenLyrics(audioPlayerService)
              : null,
          child: ValueListenableBuilder<int>(
            valueListenable: _currentLyricIndexNotifier,
            builder: (context, currentIndex, _) {
              return LyricsSection(
                timedLyrics: _timedLyrics,
                currentLyricIndex: currentIndex,
                audioPlayerService: audioPlayerService,
              );
            },
          ),
        ),
      ],
    );
  }

  // MARK: - Artist Options Dialog

  void _showArtistOptions(
      BuildContext context, AudioPlayerService audioPlayerService) {
    final artistString = audioPlayerService.currentSong?.artist;
    if (artistString == null || artistString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_artist_info')),
        ),
      );
      return;
    }

    final artists = ArtistSeparatorService().splitArtists(artistString);
    if (artists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_artist_info')),
        ),
      );
      return;
    }

    // Single artist: navigate directly
    if (artists.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArtistDetailsScreen(artistName: artists.first),
        ),
      );
      return;
    }

    // Multiple artists: show selection dialog
    showDialog(
      context: context,
      builder: (context) => _ArtistSelectionDialog(
        artists: artists,
        onArtistSelected: (artist) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistDetailsScreen(artistName: artist),
            ),
          );
        },
      ),
    );
  }
}

// MARK: - Artist Selection Dialog

class _ArtistSelectionDialog extends StatelessWidget {
  final List<String> artists;
  final void Function(String artist) onArtistSelected;

  const _ArtistSelectionDialog({
    required this.artists,
    required this.onArtistSelected,
  });

  @override
  Widget build(BuildContext context) {
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
              ...artists.map(
                (artist) => ListTile(
                  title: Text(
                    artist,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => onArtistSelected(artist),
                ),
              ),
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
  }
}

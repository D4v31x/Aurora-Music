import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_player_service.dart';
import '../localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/artwork_cache_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/app_background.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/expanding_player.dart';
import '../models/utils.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  late ValueNotifier<Color> _dominantColorNotifier;

  // Lazy loading state
  List<SongModel> _allSongs = [];
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  // Album metadata
  String? _artistName;
  Duration _totalDuration = Duration.zero;
  List<AlbumModel> _relatedAlbums = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _dominantColorNotifier = ValueNotifier(Colors.deepPurple.shade900);
    _loadSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _dominantColorNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final albumSongs = songs
        .where((song) => song.album == widget.albumName)
        .toList()
      ..sort((a, b) => (a.track ?? 0).compareTo(b.track ?? 0));

    // Get album metadata
    String? artistName;
    Duration totalDuration = Duration.zero;

    if (albumSongs.isNotEmpty) {
      artistName = albumSongs.first.artist;
      for (final song in albumSongs) {
        totalDuration += Duration(milliseconds: song.duration ?? 0);
      }
    }

    // Get related albums from same artist
    final allAlbums = await _audioQuery.queryAlbums();
    final related = allAlbums
        .where((album) =>
            album.artist == artistName && album.album != widget.albumName)
        .toList();

    setState(() {
      _allSongs = albumSongs;
      _artistName = artistName;
      _totalDuration = totalDuration;
      _relatedAlbums = related;
    });

    _loadMoreSongs();
    _updateDominantColor();
  }

  void _loadMoreSongs() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final int startIndex = _currentPage * _songsPerPage;
    final int endIndex =
        (startIndex + _songsPerPage).clamp(0, _allSongs.length);

    if (startIndex < _allSongs.length) {
      final newSongs = _allSongs.sublist(startIndex, endIndex);

      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoading = false;
        _hasMoreSongs = endIndex < _allSongs.length;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasMoreSongs = false;
      });
    }
  }

  Future<void> _updateDominantColor() async {
    if (_allSongs.isNotEmpty) {
      final artwork = await _artworkService.getArtwork(_allSongs.first.id);
      if (artwork != null) {
        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          MemoryImage(artwork),
          maximumColorCount: 8, // Get more colors for a richer mesh gradient
        );

        // Set the dominant color for the UI
        _dominantColorNotifier.value =
            paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;

        // Extract colors for the mesh background
        final List<Color> colors = [];

        // Add colors from palette in priority order
        if (paletteGenerator.dominantColor?.color != null) {
          colors.add(paletteGenerator.dominantColor!.color);
        }
        if (paletteGenerator.vibrantColor?.color != null) {
          colors.add(paletteGenerator.vibrantColor!.color);
        }
        if (paletteGenerator.lightVibrantColor?.color != null) {
          colors.add(paletteGenerator.lightVibrantColor!.color);
        }
        if (paletteGenerator.darkVibrantColor?.color != null) {
          colors.add(paletteGenerator.darkVibrantColor!.color);
        }
        if (paletteGenerator.mutedColor?.color != null) {
          colors.add(paletteGenerator.mutedColor!.color);
        }
        if (paletteGenerator.lightMutedColor?.color != null) {
          colors.add(paletteGenerator.lightMutedColor!.color);
        }
        if (paletteGenerator.darkMutedColor?.color != null) {
          colors.add(paletteGenerator.darkMutedColor!.color);
        }

        // Background colors are now only controlled by the currently playing song
        // Previously updated background manager with extracted colors here
        // if (colors.isNotEmpty) {
        //   Provider.of<BackgroundManagerService>(context, listen: false).setCustomColors(colors);
        // } else {
        //   Provider.of<BackgroundManagerService>(context, listen: false).updateColorsFromArtwork(artwork);
        // }
      } else {
        // Background colors are now only controlled by the currently playing song
        // Previously used default colors if no artwork
        // Provider.of<BackgroundManagerService>(context, listen: false).updateColorsFromArtwork(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ValueListenableBuilder<Color>(
        valueListenable: _dominantColorNotifier,
        builder: (context, dominantColor, _) {
          if (_displayedSongs.isEmpty && _isLoading) {
            return AppBackground(
              enableAnimation: true,
              child: SafeArea(
                child: Column(
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: DetailHeaderSkeleton(isArtist: false),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const ListSkeleton(itemCount: 5),
                  ],
                ),
              ),
            );
          }

          return AppBackground(
            enableAnimation: true,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildSliverAppBar(),
                // Stats section
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: glassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (_artistName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _artistName!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  Icons.music_note_rounded,
                                  '${_allSongs.length}',
                                  AppLocalizations.of(context)
                                      .translate('songs'),
                                ),
                                _buildStatDivider(),
                                _buildStatItem(
                                  Icons.timer_outlined,
                                  _formatDuration(_totalDuration),
                                  AppLocalizations.of(context)
                                      .translate('total'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            Icons.play_arrow_rounded,
                            AppLocalizations.of(context).translate('play_all'),
                            () => _playAllSongs(context),
                            dominantColor,
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            Icons.shuffle_rounded,
                            AppLocalizations.of(context).translate('shuffle'),
                            () => _shuffleAllSongs(context),
                            dominantColor,
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Songs header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      AppLocalizations.of(context).translate('songs'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildSongsList(),
                // Related albums section
                if (_relatedAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        'More from $_artistName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _relatedAlbums.length,
                        itemBuilder: (context, index) {
                          final album = _relatedAlbums[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AlbumDetailScreen(
                                      albumName: album.album,
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 130,
                                child: glassmorphicContainer(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: _artworkService
                                              .buildCachedAlbumArtwork(
                                            album.id,
                                            size: 100,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          album.album,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                // Bottom padding for mini player
                SliverToBoxAdapter(
                  child: Selector<AudioPlayerService, bool>(
                    selector: (_, service) => service.currentSong != null,
                    builder: (context, hasCurrentSong, _) {
                      return SizedBox(
                        height: hasCurrentSong
                            ? ExpandingPlayer.getMiniPlayerPaddingHeight(
                                context)
                            : 16,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 350,
      floating: false,
      pinned: true,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          var top = constraints.biggest.height;
          return FlexibleSpaceBar(
            centerTitle: true,
            title: top <= kToolbarHeight + 50
                ? Text(
                    widget.albumName,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontStyle: FontStyle.normal,
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            background: _allSongs.isEmpty
                ? Container()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 70),
                      Hero(
                        tag: 'album_image_${widget.albumName}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: _artworkService.buildCachedArtwork(
                            _allSongs.first.id,
                            size: 200,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.albumName,
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          fontStyle: FontStyle.normal,
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _playAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(_allSongs, 0);
    }
  }

  void _shuffleAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(_allSongs)..shuffle();
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(shuffledSongs, 0);
    }
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    Color dominantColor, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    dominantColor.withOpacity(0.8),
                    dominantColor.withOpacity(0.6),
                  ],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? dominantColor : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _displayedSongs.length) {
            return _hasMoreSongs
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox.shrink();
          }

          if (index >= _displayedSongs.length) return null;

          final song = _displayedSongs[index];
          final duration = Duration(milliseconds: song.duration ?? 0);
          final durationString =
              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      debugPrint(
                          'Tapped song at index: $index, song: ${song.title}');
                      Provider.of<AudioPlayerService>(context, listen: false)
                          .setPlaylist(_allSongs, index);
                      // Note: setPlaylist already starts playback, no need to call play()
                    },
                    onLongPress: () => _showSongOptions(song),
                    child: glassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Track number
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Song info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    splitArtists(
                                            song.artist ?? 'Unknown Artist')
                                        .join(', '),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Duration
                            Text(
                              durationString,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
      ),
    );
  }

  void _showSongOptions(SongModel song) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        _artworkService.buildCachedArtwork(song.id, size: 50),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          splitArtists(song.artist ?? 'Unknown').join(', '),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.white),
              title: const Text('Play', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                final songIndex = _allSongs.indexWhere((s) => s.id == song.id);
                if (songIndex >= 0) {
                  audioPlayerService.setPlaylist(_allSongs, songIndex);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white),
              title: const Text('Play Next',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${song.title} will play next'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

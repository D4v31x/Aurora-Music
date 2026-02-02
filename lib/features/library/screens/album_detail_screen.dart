import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/mixins/detail_screen_mixin.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen>
    with DetailScreenMixin {
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

  // DetailScreenMixin requirements
  @override
  Color get dominantColor => _dominantColorNotifier.value;

  @override
  List<SongModel> get allSongs => _allSongs;

  @override
  PlaybackSourceInfo get playbackSource => PlaybackSourceInfo(
        source: PlaybackSource.album,
        name: widget.albumName,
      );

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
                        child: DetailHeaderSkeleton(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const ListSkeleton(),
                  ],
                ),
              ),
            );
          }

          return AppBackground(
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
                                buildStatItem(
                                  Icons.music_note_rounded,
                                  '${_allSongs.length}',
                                  AppLocalizations.of(context)
                                      .translate('songs'),
                                ),
                                buildStatDivider(),
                                buildStatItem(
                                  Icons.timer_outlined,
                                  formatDuration(_totalDuration),
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
                  child: buildActionButtonsRow(),
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
                buildMiniPlayerPadding(),
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
      pinned: true,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          return FlexibleSpaceBar(
            centerTitle: true,
            title: top <= kToolbarHeight + 50
                ? Text(
                    widget.albumName,
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
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
                          fontFamily: FontConstants.fontFamily,
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
      builder: (context) => DecoratedBox(
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
                    child: _artworkService.buildCachedArtwork(song.id),
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
              title: Text(AppLocalizations.of(context).translate('play_next'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await audioPlayerService.playNext(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${song.title} will play next'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: Text(
                  AppLocalizations.of(context).translate('add_to_queue'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await audioPlayerService.addToQueue(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${song.title} added to queue'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

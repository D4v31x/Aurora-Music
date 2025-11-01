import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/local_caching_service.dart';
import '../widgets/glassmorphic_container.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistName;
  final String? artistImagePath;

  const ArtistDetailsScreen({
    super.key,
    required this.artistName,
    this.artistImagePath,
  });

  @override
  _ArtistDetailsScreenState createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  Color _dominantColor = Colors.deepPurple.shade900;
  late Future<void> _colorFuture;
  final LocalCachingArtistService _artistService = LocalCachingArtistService();

  // Lazy loading state
  List<SongModel> _allSongs = [];
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  // Categories
  int _selectedCategory = 0; // 0 = Songs, 1 = Albums
  List<AlbumModel> _albums = [];
  final Map<int, List<SongModel>> _albumSongs = {};

  @override
  void initState() {
    super.initState();
    _colorFuture = widget.artistImagePath != null
        ? _updateDominantColor()
        : _artistService
            .fetchArtistImage(widget.artistName)
            .then((path) => _updateDominantColor());
    _scrollController = ScrollController()..addListener(_scrollListener);
    _loadSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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

    // Load albums for this artist
    final allAlbums = await _audioQuery.queryAlbums(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    setState(() {
      _allSongs = songs
          .where((song) =>
              splitArtists(song.artist ?? '').contains(widget.artistName))
          .toList();
      _albums = allAlbums
          .where((album) => album.artist?.contains(widget.artistName) ?? false)
          .toList();
    });

    // Group songs by album
    for (final album in _albums) {
      _albumSongs[album.id] =
          _allSongs.where((song) => song.albumId == album.id).toList();
    }

    _loadMoreSongs();
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
    if (widget.artistImagePath != null) {
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        FileImage(File(widget.artistImagePath!)),
        maximumColorCount: 8, // Get more colors for a rich mesh gradient
        size: const Size(100, 100),
      );

      // Set dominant color for local use
      setState(() {
        _dominantColor =
            paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;
      });

      // Extract all colors for the mesh gradient
      final List<Color> colors = [];

      // Add colors in priority order
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
      // Previously updated the background manager with these colors
      // if (colors.isNotEmpty) {
      //   Provider.of<BackgroundManagerService>(context, listen: false).setCustomColors(colors);
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        return FutureBuilder(
          future: _colorFuture,
          builder: (context, snapshot) {
            return Scaffold(
                body: FutureBuilder<String?>(
                    future: widget.artistImagePath != null
                        ? Future.value(widget.artistImagePath)
                        : _artistService.fetchArtistImage(widget.artistName),
                    builder: (context, imageSnapshot) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: _dominantColor.withOpacity(0.1),
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              _buildSliverAppBar(imageSnapshot.data),
                              // Action buttons
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionPill(
                                        context,
                                        Icons.play_arrow,
                                        AppLocalizations.of(context)
                                            .translate('play_all'),
                                        () => _playAllSongs(context),
                                      ),
                                      _buildActionPill(
                                        context,
                                        Icons.shuffle,
                                        AppLocalizations.of(context)
                                            .translate('shuffle'),
                                        () => _shuffleAllSongs(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Category tabs
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildCategoryTab(
                                          'Songs (${_allSongs.length})',
                                          0,
                                          Icons.music_note_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildCategoryTab(
                                          'Albums (${_albums.length})',
                                          1,
                                          Icons.album_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Content based on selected category
                              _selectedCategory == 0
                                  ? _buildSongsList(audioPlayerService)
                                  : _buildAlbumsList(audioPlayerService),
                            ],
                          ),
                        ),
                      );
                    }));
          },
        );
      },
    );
  }

  Widget _buildSliverAppBar(String? artistImagePath) {
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
                    widget.artistName,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontStyle: FontStyle.normal,
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 70),
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: artistImagePath != null
                      ? Image.file(
                          File(artistImagePath),
                          fit: BoxFit.cover,
                          width: 200,
                          height: 200,
                        )
                      : Image.asset(
                          'assets/images/logo/default_art.png',
                          fit: BoxFit.cover,
                          width: 200,
                          height: 200,
                        ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.artistName,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionPill(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String label, int index, IconData icon) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
          _currentPage = 0;
          _displayedSongs.clear();
          if (index == 0) {
            _loadMoreSongs();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    _dominantColor.withOpacity(0.8),
                    _dominantColor.withOpacity(0.6),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _dominantColor : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsList(AudioPlayerService audioPlayerService) {
    if (_albums.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No albums found',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _albums.length) return null;

          final album = _albums[index];
          final albumSongs = _albumSongs[album.id] ?? [];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: glassmorphicContainer(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _artworkService.buildCachedArtwork(
                          album.id,
                          size: 50,
                        ),
                      ),
                      title: Text(album.album,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${albumSongs.length} ${albumSongs.length == 1 ? 'song' : 'songs'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white70),
                      onTap: () {
                        if (albumSongs.isNotEmpty) {
                          audioPlayerService.setPlaylist(albumSongs, 0);
                          final audioHandler =
                              Provider.of<AudioHandler>(context, listen: false);
                          audioHandler.play();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _albums.length,
      ),
    );
  }

  Widget _buildSongsList(AudioPlayerService audioPlayerService) {
    if (_displayedSongs.isEmpty && _isLoading) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }

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
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: glassmorphicContainer(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _artworkService.buildCachedArtwork(
                          song.id,
                          size: 50,
                        ),
                      ),
                      title: Text(song.title,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(song.album ?? 'Unknown Album',
                          style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                        audioPlayerService.setPlaylist(
                            _allSongs, _allSongs.indexOf(song));
                        final audioHandler =
                            Provider.of<AudioHandler>(context, listen: false);
                        audioHandler.play();
                      },
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
}

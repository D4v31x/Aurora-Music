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

    setState(() {
      _allSongs =
          songs.where((song) => song.album == widget.albumName).toList();
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
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, _) {
        return Scaffold(
          body: ValueListenableBuilder<Color>(
            valueListenable: _dominantColorNotifier,
            builder: (context, dominantColor, _) {
              if (_displayedSongs.isEmpty && _isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return AppBackground(
                enableAnimation: true,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                              AppLocalizations.of(context).translate('shuffle'),
                              () => _shuffleAllSongs(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildSongsList(audioPlayerService),
                  ],
                ),
              );
            },
          ),
        );
      },
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

  Widget _buildActionPill(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            splashColor: Colors.white.withOpacity(0.2),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      fontWeight: FontWeight.w600,
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

  void _playAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(_allSongs, 0);
      audioPlayerService.play();
    }
  }

  void _shuffleAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(_allSongs)..shuffle();
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(shuffledSongs, 0);
      audioPlayerService.play();
    }
  }

  Widget _buildSongsList(AudioPlayerService audioPlayerService) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: glassmorphicContainer(
                    child: ListTile(
                      leading: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        song.artist ?? 'Unknown Artist',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        audioPlayerService.setPlaylist(
                            _allSongs, _allSongs.indexOf(song));
                        audioPlayerService.play();
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
}

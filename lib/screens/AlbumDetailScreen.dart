import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/artwork_cache_service.dart';
import '../widgets/glassmorphic_container.dart';

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
  late Future<List<SongModel>> _songsFuture;
  int _displayedSongsCount = 8;
  final int _loadMoreStep = 8;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _dominantColorNotifier = ValueNotifier(Colors.deepPurple.shade900);
    _songsFuture = _loadSongs();
    _updateDominantColor();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _dominantColorNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      setState(() {
        _displayedSongsCount += _loadMoreStep;
      });
    }
  }

  Future<List<SongModel>> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs.where((song) => song.album == widget.albumName).toList();
  }

  Future<void> _updateDominantColor() async {
    final songs = await _songsFuture;
    if (songs.isNotEmpty) {
      final artwork = await _artworkService.getArtwork(songs.first.id);
      if (artwork != null) {
        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          MemoryImage(artwork),
        );
        _dominantColorNotifier.value = paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, _) {
        return Scaffold(
          body: FutureBuilder<List<SongModel>>(
            future: _songsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ValueListenableBuilder<Color>(
                valueListenable: _dominantColorNotifier,
                builder: (context, dominantColor, _) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          dominantColor.withOpacity(0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildSliverAppBar(snapshot.data!),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionPill(
                                  context,
                                  Icons.play_arrow,
                                  AppLocalizations.of(context).translate('play_all'),
                                  () => _playAllSongs(context, snapshot.data!),
                                ),
                                _buildActionPill(
                                  context,
                                  Icons.shuffle,
                                  AppLocalizations.of(context).translate('shuffle'),
                                  () => _shuffleAllSongs(context, snapshot.data!),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildSongsList(snapshot.data!, audioPlayerService),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(List<SongModel> songs) {
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
            background: FutureBuilder<List<SongModel>>(
              future: _songsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 70),
                    Hero(
                      tag: 'album_image_${widget.albumName}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: FutureBuilder<dynamic>(
                          future: _artworkService.getArtwork(snapshot.data!.first.id),
                          builder: (context, artworkSnapshot) {
                            if (!artworkSnapshot.hasData) {
                              return Image.asset(
                                'assets/images/logo/default_art.png',
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              );
                            }
                            return Image.memory(
                              artworkSnapshot.data!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            );
                          },
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
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionPill(BuildContext context, IconData icon, String label, VoidCallback onTap) {
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

  void _playAllSongs(BuildContext context, List<SongModel> songs) async {
    if (songs.isNotEmpty) {
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(songs, 0);
      audioPlayerService.play();
    }
  }

  void _shuffleAllSongs(BuildContext context, List<SongModel> songs) async {
    if (songs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(songs)..shuffle();
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(shuffledSongs, 0);
      audioPlayerService.play();
    }
  }

  Widget _buildSongsList(List<SongModel> songs, AudioPlayerService audioPlayerService) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= songs.length) return null;
          final song = songs[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
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
                        audioPlayerService.setPlaylist(songs, index);
                        audioPlayerService.play();
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
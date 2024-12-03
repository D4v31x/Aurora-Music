import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/utils.dart';
import '../services/Audio_Player_Service.dart';
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
  late ScrollController _scrollController;
  Color _dominantColor = Colors.deepPurple.shade900;
  late Future<void> _colorFuture;
  late Future<List<SongModel>> _songsFuture;
  int _displayedSongsCount = 8;
  final int _loadMoreStep = 8;
  final LocalCachingArtistService _artistService = LocalCachingArtistService();

  @override
  void initState() {
    super.initState();
    _colorFuture = widget.artistImagePath != null 
        ? _updateDominantColor() 
        : _artistService.fetchArtistImage(widget.artistName).then((path) => _updateDominantColor());
    _scrollController = ScrollController()..addListener(_scrollListener);
    _songsFuture = _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      setState(() {
        _displayedSongsCount += _loadMoreStep;
      });
    }
  }

  Future<void> _updateDominantColor() async {
    if (widget.artistImagePath != null) {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(File(widget.artistImagePath!)),
        size: const Size(100, 100),
      );
      setState(() {
        _dominantColor = paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;
      });
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
              return Container(
              decoration: BoxDecoration(
              image: imageSnapshot.hasData && imageSnapshot.data != null
              ? DecorationImage(
              image: FileImage(File(imageSnapshot.data!)),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
              _dominantColor.withOpacity(0.3),
              BlendMode.srcOver,
              ),
              )
                  : const DecorationImage(
              image: AssetImage('assets/images/background/dark_back.jpg'),
              fit: BoxFit.cover,
              ),
              ),
              child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50
              ),
              child: Container(
              color: _dominantColor.withOpacity(0.1),
              child: CustomScrollView(
              controller: _scrollController,
              slivers: [
              _buildSliverAppBar(imageSnapshot.data),
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
                  ),
                ));
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

  Widget _buildSongsList(AudioPlayerService audioPlayerService) {
    return FutureBuilder<List<SongModel>>(
      future: _songsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(child: Center(child: Text('Error: ${snapshot.error}')));
        }
        final songs = snapshot.data!.where((song) => splitArtists(song.artist ?? '').contains(widget.artistName)).toList();
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
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: glassmorphicContainer(
                        child: ListTile(
                          leading: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white),
                          ),
                          title: Text(song.title, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(song.album ?? 'Unknown Album', style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            audioPlayerService.setPlaylist(songs, index);
                            final audioHandler = Provider.of<AudioHandler>(context, listen: false);
                            audioHandler.play();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: _displayedSongsCount > songs.length ? songs.length : _displayedSongsCount,
          ),
        );
      },
    );
  }

  void _playAllSongs(BuildContext context) async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final artistSongs = songs.where((song) => splitArtists(song.artist ?? '').contains(widget.artistName)).toList();
    if (artistSongs.isNotEmpty) {
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(artistSongs, 0);
      audioPlayerService.play();
    }
  }

  void _shuffleAllSongs(BuildContext context) async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final artistSongs = songs.where((song) => splitArtists(song.artist ?? '').contains(widget.artistName)).toList();
    if (artistSongs.isNotEmpty) {
      artistSongs.shuffle();
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(artistSongs, 0);
      audioPlayerService.play();
    }
  }
}

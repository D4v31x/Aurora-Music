import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';
import '../services/expandable_player_controller.dart';
import 'now_playing.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderPath;

  const FolderDetailScreen({Key? key, required this.folderPath}) : super(key: key);

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  late ScrollController _scrollController;
  Color _dominantColor = Colors.deepPurple.shade900;
  late Future<void> _colorFuture;
  late Future<List<SongModel>> _songsFuture;
  int _displayedSongsCount = 8;
  final int _loadMoreStep = 8;

  @override
  void initState() {
    super.initState();
    _colorFuture = _updateDominantColor();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _songsFuture = _fetchSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<SongModel>> _fetchSongs() async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final allSongs = audioPlayerService.songs;

    return allSongs.where((song) {
      final songFile = File(song.data);
      return songFile.parent.path == widget.folderPath;
    }).toList();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      setState(() {
        _displayedSongsCount += _loadMoreStep;
      });
    }
  }

  Future<void> _updateDominantColor() async {
    // Since there's no image, use a default or dynamic color
    // You can customize this to fetch folder-specific colors if desired
    setState(() {
      _dominantColor = Colors.deepPurple.shade900;
    });
  }

  void _playAllSongs(BuildContext context, List<SongModel> songs) {
    if (songs.isNotEmpty) {
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(songs, 0);
      audioPlayerService.play();
    }
  }

  void _shuffleAllSongs(BuildContext context, List<SongModel> songs) {
    if (songs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(songs)..shuffle();
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(shuffledSongs, 0);
      audioPlayerService.play();
    }
  }

  void _onSongTap(SongModel song, List<SongModel> songs) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController = Provider.of<ExpandablePlayerController>(context, listen: false);

    audioPlayerService.setPlaylist(songs, songs.indexOf(song));
    audioPlayerService.play();
    expandableController.show();
  }

  Widget _buildSliverAppBar(Color backgroundColor, String folderName, SongModel? currentSong) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 350,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          folderName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        background: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: Hero(
              tag: 'folder_icon_${widget.folderPath}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.folder,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionPill(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: glassmorphicContainer(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList(List<SongModel> songs) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _displayedSongsCount) return null;
          final song = songs[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onSongTap(song, songs),
                      child: glassmorphicContainer(
                        child: ListTile(
                          leading: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white, size: 40),
                            artworkBorder: BorderRadius.circular(8),
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            song.artist ?? AppLocalizations.of(context).translate('unknown_artist'),
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Provider.of<AudioPlayerService>(context).isLiked(song)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Provider.of<AudioPlayerService>(context).isLiked(song)
                                  ? Colors.pink
                                  : Colors.white,
                            ),
                            onPressed: () {
                              Provider.of<AudioPlayerService>(context, listen: false).toggleLike(song);
                            },
                          ),
                        ),
                      ),
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
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image Layer
          Positioned.fill(
            child: currentSong != null
                ? FutureBuilder<Uint8List?>(
                    future: OnAudioQuery().queryArtwork(
                      currentSong.id,
                      ArtworkType.AUDIO,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return Container(
                        color: Colors.black,
                      );
                    },
                  )
                : Container(
                    color: Colors.black,
                  ),
          ),
          // Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Content Layer
          FutureBuilder<List<SongModel>>(
            future: _songsFuture,
            builder: (context, songsSnapshot) {
              if (songsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (songsSnapshot.hasError) {
                return Center(child: Text('Error: ${songsSnapshot.error}'));
              }
              final songs = songsSnapshot.data!;
              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(_dominantColor, folderName, currentSong),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionPill(
                            context,
                            Icons.play_arrow,
                            AppLocalizations.of(context).translate('play_all'),
                            () => _playAllSongs(context, songs),
                          ),
                          _buildActionPill(
                            context,
                            Icons.shuffle,
                            AppLocalizations.of(context).translate('shuffle'),
                            () => _shuffleAllSongs(context, songs),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildSongsList(songs),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
} 
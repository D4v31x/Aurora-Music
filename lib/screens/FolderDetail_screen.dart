import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/utils.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/app_background.dart';
import '../widgets/expanding_player.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderPath;

  const FolderDetailScreen({super.key, required this.folderPath});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  final Color _dominantColor = Colors.deepPurple.shade900;

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
    _fetchSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSongs() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final allSongs = audioPlayerService.songs;

    setState(() {
      _allSongs = allSongs.where((song) {
        final songFile = File(song.data);
        return songFile.parent.path == widget.folderPath;
      }).toList();
    });

    _loadMoreSongs();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
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

  void _playAllSongs(BuildContext context) {
    if (_allSongs.isNotEmpty) {
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(_allSongs, 0);
    }
  }

  void _shuffleAllSongs(BuildContext context) {
    if (_allSongs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(_allSongs)..shuffle();
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(shuffledSongs, 0);
    }
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    final songIndex = _allSongs.indexWhere((s) => s.id == song.id);
    if (songIndex >= 0) {
      audioPlayerService.setPlaylist(_allSongs, songIndex);
    }
  }

  Widget _buildSliverAppBar(
      Color backgroundColor, String folderName, SongModel? currentSong) {
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
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withOpacity(0.2),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onSongTap(song),
                      child: glassmorphicContainer(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _artworkService.buildCachedArtwork(
                              song.id,
                              size: 50,
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            splitArtists(song.artist ??
                                AppLocalizations.of(context)
                                    .translate('unknown_artist')).join(', '),
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Provider.of<AudioPlayerService>(context,
                                          listen: false)
                                      .isLiked(song)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Provider.of<AudioPlayerService>(context,
                                          listen: false)
                                      .isLiked(song)
                                  ? Colors.pink
                                  : Colors.white,
                            ),
                            onPressed: () {
                              Provider.of<AudioPlayerService>(context,
                                      listen: false)
                                  .toggleLike(song);
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
        childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final currentSong = audioPlayerService.currentSong;
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;

    return Scaffold(
      body: AppBackground(
        enableAnimation: true,
        child: Stack(
          children: [
            // Content Layer
            if (_displayedSongs.isEmpty && _isLoading)
              const Center(child: CircularProgressIndicator())
            else
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(_dominantColor, folderName, currentSong),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
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
                  _buildSongsList(),
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
          ],
        ),
      ),
    );
  }
}

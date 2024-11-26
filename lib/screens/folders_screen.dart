import 'package:aurora_music_v01/services/artwork_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../localization/app_localizations.dart';
import '../services/audio_player_service.dart';
import '../widgets/glassmorphic_container.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({Key? key}) : super(key: key);

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<String> _folders = [];
  int _displayedFoldersCount = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      setState(() {
        _displayedFoldersCount += 20;
      });
    }
  }

  Future<void> _loadFolders() async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final folderSet = <String>{};
    for (var song in songs) {
      if (song.data != null) {
        final folder = path.dirname(song.data);
        folderSet.add(folder);
      }
    }

    setState(() {
      _folders = folderSet.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLocalizations.of(context).translate('folders')),
      ),
      body: _folders.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context).translate('no_folders_found'),
                style: const TextStyle(color: Colors.white),
              ),
            )
          : AnimationLimiter(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: audioPlayerService.currentSong != null ? 90 : 0,
                ),
                itemCount: _displayedFoldersCount > _folders.length
                    ? _folders.length
                    : _displayedFoldersCount,
                itemBuilder: (context, index) {
                  final folder = _folders[index];
                  final folderName = path.basename(folder);
                  
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
                              leading: const Icon(
                                Icons.folder,
                                color: Colors.white,
                                size: 40,
                              ),
                              title: Text(
                                folderName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: FutureBuilder<int>(
                                future: _getSongCount(folder),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.hasData
                                        ? '${snapshot.data} ${AppLocalizations.of(context).translate('songs')}'
                                        : '',
                                    style: const TextStyle(color: Colors.grey),
                                  );
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FolderScreen(
                                      folderPath: folder,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<int> _getSongCount(String folderPath) async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs.where((song) => song.data != null && path.dirname(song.data) == folderPath).length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class FolderScreen extends StatefulWidget {
  final String folderPath;

  const FolderScreen({
    Key? key,
    required this.folderPath,
  }) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<SongModel> _songs = [];
  int _displayedSongsCount = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      setState(() {
        _displayedSongsCount += 20;
      });
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
      _songs = songs
          .where((song) => song.data != null && path.dirname(song.data) == widget.folderPath)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(path.basename(widget.folderPath)),
      ),
      body: _songs.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context).translate('no_songs_found'),
                style: const TextStyle(color: Colors.white),
              ),
            )
          : AnimationLimiter(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: audioPlayerService.currentSong != null ? 90 : 0,
                ),
                itemCount: _displayedSongsCount > _songs.length
                    ? _songs.length
                    : _displayedSongsCount,
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  
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
                              leading: _artworkService.buildCachedArtwork(
                                song.id,
                                size: 50,
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
                                audioPlayerService.setPlaylist(_songs, index);
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
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 
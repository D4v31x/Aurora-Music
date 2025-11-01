import 'package:aurora_music_v01/screens/tracks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  _PlaylistDetailScreenState createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  late TextEditingController _nameController;
  final ValueNotifier<bool> _isEditingNotifier = ValueNotifier<bool>(false);

  // Lazy loading state
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _nameController = TextEditingController(text: widget.playlist.name);
    _loadMoreSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _nameController.dispose();
    _isEditingNotifier.dispose();
    super.dispose();
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
        (startIndex + _songsPerPage).clamp(0, widget.playlist.songs.length);

    if (startIndex < widget.playlist.songs.length) {
      final newSongs = widget.playlist.songs.sublist(startIndex, endIndex);

      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoading = false;
        _hasMoreSongs = endIndex < widget.playlist.songs.length;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasMoreSongs = false;
      });
    }
  }

  void _saveNewName(BuildContext context) {
    if (_nameController.text.isNotEmpty &&
        _nameController.text != widget.playlist.name) {
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.renamePlaylist(
          widget.playlist.id, _nameController.text);
    } else {
      _nameController.text = widget.playlist.name;
    }
    _isEditingNotifier.value = false;
    FocusScope.of(context).unfocus();
  }

  void _playAllSongs(AudioPlayerService audioPlayerService) {
    if (audioPlayerService.playlists.isNotEmpty) {
      audioPlayerService.setPlaylist(
        widget.playlist.songs,
        0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, _) {
        final updatedPlaylist = audioPlayerService.playlists.firstWhere(
          (p) => p.id == widget.playlist.id,
          orElse: () => widget.playlist,
        );

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(updatedPlaylist, context),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: _buildActionPills(context, audioPlayerService),
                ),
              ),
              _buildSongsList(updatedPlaylist, audioPlayerService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(Playlist playlist, BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 300,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/UI/liked_icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: _isEditingNotifier,
              builder: (context, isEditing, _) {
                return isEditing
                    ? SizedBox(
                        width: 200,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                onSubmitted: (_) => _saveNewName(context),
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontStyle: FontStyle.normal,
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.white),
                              onPressed: () => _saveNewName(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _isEditingNotifier.value = true,
                        child: Text(
                          playlist.name,
                          style: const TextStyle(
                            fontFamily: 'ProductSans',
                            fontStyle: FontStyle.normal,
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList(
      Playlist playlist, AudioPlayerService audioPlayerService) {
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
                      subtitle: Text(song.artist ?? 'Unknown Artist',
                          style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                        audioPlayerService.setPlaylist(
                            playlist.songs, playlist.songs.indexOf(song));
                      },
                      onLongPress: () => _showRemoveSongDialog(
                          context, audioPlayerService, song),
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

  Widget _buildActionPills(
      BuildContext context, AudioPlayerService audioPlayerService) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildActionPill(
          context,
          Icons.play_arrow,
          AppLocalizations.of(context).translate('play_all'),
          () => _playAllSongs(audioPlayerService),
        ),
        _buildActionPill(
          context,
          Icons.add,
          AppLocalizations.of(context).translate('add_songs'),
          () => _showAddSongsDialog(context, audioPlayerService),
        ),
        _buildActionPill(
          context,
          Icons.delete,
          AppLocalizations.of(context).translate('delete_playlist'),
          () => _showDeleteConfirmation(context),
        ),
      ],
    );
  }

  Widget _buildActionPill(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

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
            child: Container(
              padding: EdgeInsets.symmetric(
                  vertical: 8, horizontal: isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  if (!isSmallScreen) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              Text(AppLocalizations.of(context).translate('delete_playlist')),
          content: Text(AppLocalizations.of(context)
              .translate('delete_playlist_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('delete')),
              onPressed: () {
                final audioPlayerService =
                    Provider.of<AudioPlayerService>(context, listen: false);
                audioPlayerService.deletePlaylist(widget.playlist);
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Go back to the previous screen
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddSongsDialog(
      BuildContext context, AudioPlayerService audioPlayerService) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TracksScreen(
          isEditingPlaylist: true,
          playlist: widget.playlist,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _showRemoveSongDialog(BuildContext context,
      AudioPlayerService audioPlayerService, SongModel song) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('remove_song')),
          content: Text(AppLocalizations.of(context)
              .translate('remove_song_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('remove')),
              onPressed: () {
                widget.playlist.songs.remove(song);
                audioPlayerService.savePlaylists();
                // Reload pagination after removing song
                setState(() {
                  _displayedSongs.clear();
                  _currentPage = 0;
                  _hasMoreSongs = true;
                });
                _loadMoreSongs();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

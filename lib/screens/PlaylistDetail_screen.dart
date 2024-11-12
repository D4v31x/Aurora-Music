import 'package:aurora_music_v01/screens/tracks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  _PlaylistDetailScreenState createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late ScrollController _scrollController;
  int _displayedSongsCount = 8;
  final int _loadMoreStep = 8;
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _nameController = TextEditingController(text: widget.playlist.name);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      setState(() {
        _displayedSongsCount += _loadMoreStep;
      });
    }
  }

  void _saveNewName(BuildContext context) {
    if (_nameController.text.isNotEmpty && _nameController.text != widget.playlist.name) {
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.renamePlaylist(widget.playlist.id, _nameController.text);
    } else {
      _nameController.text = widget.playlist.name;
    }
    setState(() {
      _isEditingName = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _playAllSongs(AudioPlayerService audioPlayerService) {
    if (audioPlayerService.playlists.isNotEmpty) {
      audioPlayerService.setPlaylist(
        widget.playlist.songs, 
        0,
      );
      audioPlayerService.play();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        final updatedPlaylist = audioPlayerService.playlists.firstWhere(
              (p) => p.id == widget.playlist.id,
          orElse: () => widget.playlist,
        );

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  MediaQuery.of(context).platformBrightness == Brightness.dark
                      ? 'assets/images/background/dark_back.jpg'
                      : 'assets/images/background/light_back.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: 300,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: QueryArtworkWidget(
                              id: int.tryParse(updatedPlaylist.id) ?? 0,
                              type: ArtworkType.PLAYLIST,
                              artworkBorder: BorderRadius.circular(20),
                              nullArtworkWidget: Image.asset(
                                'assets/images/logo/default_art.png',
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _isEditingName
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
                                icon: const Icon(Icons.check, color: Colors.white),
                                onPressed: () => _saveNewName(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        )
                            : GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingName = true;
                            });
                          },
                          child: Text(
                            updatedPlaylist.name,
                            style: const TextStyle(
                              fontFamily: 'ProductSans',
                              fontStyle: FontStyle.normal,
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: _buildActionPills(context, audioPlayerService),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index >= updatedPlaylist.songs.length) return null;
                      final song = updatedPlaylist.songs[index];
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
                                  subtitle: Text(song.artist ?? 'Unknown Artist', style: const TextStyle(color: Colors.grey)),
                                  onTap: () {
                                    audioPlayerService.setPlaylist(
                                      updatedPlaylist.songs, 
                                      index,
                                    );
                                    audioPlayerService.play();
                                  },
                                  onLongPress: () => _showRemoveSongDialog(context, audioPlayerService, song),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _displayedSongsCount,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionPills(BuildContext context, AudioPlayerService audioPlayerService) {
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

  Widget _buildActionPill(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: isSmallScreen ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('delete_playlist')),
          content: Text(AppLocalizations.of(context).translate('delete_playlist_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('delete')),
              onPressed: () {
                final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
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

  void _showAddSongsDialog(BuildContext context, AudioPlayerService audioPlayerService) {
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

  void _showRemoveSongDialog(BuildContext context, AudioPlayerService audioPlayerService, SongModel song) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('remove_song')),
          content: Text(AppLocalizations.of(context).translate('remove_song_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('remove')),
              onPressed: () {
                setState(() {
                  widget.playlist.songs.remove(song);
                });
                audioPlayerService.savePlaylists(); // Save the updated playlist without the song
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
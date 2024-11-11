import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';
import 'PlaylistDetail_screen.dart';

class PlaylistsScreenList extends StatelessWidget {
  const PlaylistsScreenList({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Stack(
      children: [
        // Background
        Container(
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            toolbarHeight: 180,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              AppLocalizations.of(context).translate('playlists'),
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontStyle: FontStyle.normal,
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.normal,
              ),
            ),
            centerTitle: true,
            actions: const [
              SizedBox(width: 48), // This balances out the leading icon
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _showCreatePlaylistDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Text(AppLocalizations.of(context).translate('create_playlist')),
                  ),
                  const SizedBox(height: 20),
                  if (audioPlayerService.likedSongsPlaylist != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: glassmorphicContainer(
                        child: ListTile(
                          leading: const Icon(Icons.favorite, color: Colors.red),
                          title: Text(
                            audioPlayerService.likedSongsPlaylist!.name,
                            style: const TextStyle(color: Colors.white)
                          ),
                          subtitle: Text(
                            '${audioPlayerService.likedSongsPlaylist!.songs.length} skladeb',
                            style: const TextStyle(color: Colors.grey)
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            onPressed: () {
                              audioPlayerService.setPlaylist(
                                audioPlayerService.likedSongsPlaylist!.songs,
                                0,
                              );
                              audioPlayerService.play();
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaylistDetailScreen(
                                  playlist: audioPlayerService.likedSongsPlaylist!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (audioPlayerService.playlists.isEmpty)
                    glassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          AppLocalizations.of(context).translate('no_playlists_created'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Consumer<AudioPlayerService>(
                      builder: (context, audioPlayerService, child) {
                      return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: audioPlayerService.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = audioPlayerService.playlists[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: glassmorphicContainer(
                            child: ListTile(
                              title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${playlist.songs.length} songs', style: const TextStyle(color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                                    onPressed: () {
                                      // Play the playlist
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.white),
                                    onPressed: () {
                                      _showDeletePlaylistDialog(context, audioPlayerService, playlist);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlaylistDetailScreen(playlist: playlist),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                      );
                      }
                      )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('create_playlist')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: AppLocalizations.of(context).translate('enter_playlist_name')),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('create')),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
                  audioPlayerService.createPlaylist(nameController.text, []);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, AudioPlayerService audioPlayerService, dynamic playlist) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('delete_playlist')),
          content: Text(AppLocalizations.of(context).translate('delete_playlist_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).translate('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).translate('delete')),
              onPressed: () {
                audioPlayerService.deletePlaylist(playlist);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
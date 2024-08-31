import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/Audio_Player_Service.dart';
import '../widgets/glassmorphic_container.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final albumsFuture = audioPlayerService.getMostPlayedAlbums();

    return Hero(
      tag: 'albums_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(context, 'Albums'),
              body: FutureBuilder<List<AlbumModel>>(
                future: albumsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No albums found'));
                  } else {
                    final albums = snapshot.data!;
                    return AnimationLimiter(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                        ),
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            columnCount: 2,
                            duration: const Duration(milliseconds: 375),
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: glassmorphicContainer(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        QueryArtworkWidget(
                                          id: album.id,
                                          type: ArtworkType.ALBUM,
                                          nullArtworkWidget: const Icon(Icons.album),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          album.album,
                                          style: const TextStyle(color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontStyle: FontStyle.normal,
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget buildBackground(SongModel? currentSong) {
    return FutureBuilder<Uint8List?>(
      future: currentSong != null
          ? OnAudioQuery().queryArtwork(currentSong.id, ArtworkType.AUDIO)
          : null,
      builder: (context, snapshot) {
        ImageProvider backgroundImage;
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          backgroundImage = MemoryImage(snapshot.data!);
        } else {
          backgroundImage = AssetImage(
              MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? 'assets/images/background/dark_back.jpg'
                  : 'assets/images/background/light_back.jpg');
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }
}

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final artistsFuture = audioPlayerService.getMostPlayedArtists();

    return Hero(
      tag: 'artists_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(context, 'Artists'),
              body: FutureBuilder<List<ArtistModel>>(
                future: artistsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No artists found'));
                  } else {
                    final artists = snapshot.data!;
                    return AnimationLimiter(
                      child: ListView.builder(
                        itemCount: artists.length,
                        itemBuilder: (context, index) {
                          final artist = artists[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                  child: glassmorphicContainer(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(artist.artist[0]),
                                      ),
                                      title: Text(
                                        artist.artist,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      onTap: () {
                                        // Implement artist view functionality
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontStyle: FontStyle.normal,
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget buildBackground(SongModel? currentSong) {
    return FutureBuilder<Uint8List?>(
      future: currentSong != null
          ? OnAudioQuery().queryArtwork(currentSong.id, ArtworkType.AUDIO)
          : null,
      builder: (context, snapshot) {
        ImageProvider backgroundImage;
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          backgroundImage = MemoryImage(snapshot.data!);
        } else {
          backgroundImage = AssetImage(
              MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? 'assets/images/background/dark_back.jpg'
                  : 'assets/images/background/light_back.jpg');
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final folders = audioPlayerService.getThreeFolders();

    return Hero(
      tag: 'folders_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(context, 'Folders'),
              body: ListView.builder(
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: glassmorphicContainer(
                            child: ListTile(
                              leading: const Icon(Icons.folder, color: Colors.white),
                              title: Text(
                                folder.split('/').last,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                // Implement folder view functionality
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
          ],
        ),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontStyle: FontStyle.normal,
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget buildBackground(SongModel? currentSong) {
    return FutureBuilder<Uint8List?>(
      future: currentSong != null
          ? OnAudioQuery().queryArtwork(currentSong.id, ArtworkType.AUDIO)
          : null,
      builder: (context, snapshot) {
        ImageProvider backgroundImage;
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          backgroundImage = MemoryImage(snapshot.data!);
        } else {
          backgroundImage = AssetImage(
              MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? 'assets/images/background/dark_back.jpg'
                  : 'assets/images/background/light_back.jpg');
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }
}



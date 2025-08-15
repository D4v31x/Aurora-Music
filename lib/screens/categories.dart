import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:mesh/mesh.dart';
import '../services/audio_player_service.dart';
import '../widgets/glassmorphic_container.dart';
import 'Artist_screen.dart';
import 'FolderDetail_screen.dart';
import 'AlbumDetailScreen.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final albumsFuture = OnAudioQuery().queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return Hero(
      tag: 'albums_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(context, audioPlayerService.currentSong),
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
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AlbumDetailScreen(
                                          albumName: album.album,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: glassmorphicContainer(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 100,
                                            width: 100,
                                            child: QueryArtworkWidget(
                                              id: album.id,
                                              type: ArtworkType.ALBUM,
                                              artworkQuality: FilterQuality.high,
                                              artworkBorder: BorderRadius.circular(10),
                                              nullArtworkWidget: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white24,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.album,
                                                  color: Colors.white,
                                                  size: 50,
                                                ),
                                              ),
                                              keepOldArtwork: true,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Flexible(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Text(
                                                album.album,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontStyle: FontStyle.normal,
            color: Theme.of(context).textTheme.headlineLarge?.color,
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget buildBackground(BuildContext context, SongModel? currentSong) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: OMeshGradient(
        mesh: OMeshRect(
          width: 2,
          height: 2,
          fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD),
          vertices: [
            // Top-left corner
            (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
            // Top-right corner  
            (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
            // Bottom-left corner
            (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
            // Bottom-right corner
            (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
          ],
        ),
      ),
    );
  }
}

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final artistsFuture = OnAudioQuery().queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return Hero(
      tag: 'artists_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(context, audioPlayerService.currentSong),
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
                                      leading: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.white24,
                                          child: Text(
                                            artist.artist.isNotEmpty ? artist.artist[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        artist.artist,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        '${artist.numberOfTracks} tracks',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ArtistDetailsScreen(
                                              artistName: artist.artist,
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

  Widget buildBackground(BuildContext context, SongModel? currentSong) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: OMeshGradient(
        mesh: OMeshRect(
          width: 2,
          height: 2,
          fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD),
          vertices: [
            // Top-left corner
            (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
            // Top-right corner  
            (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
            // Bottom-left corner
            (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
            // Bottom-right corner
            (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
          ],
        ),
      ),
    );
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final foldersFuture = OnAudioQuery().queryAllPath();

    return Hero(
      tag: 'folders_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(context, audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(context, 'Folders'),
              body: FutureBuilder<List<String>>(
                future: foldersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No folders found'));
                  }

                  final folders = snapshot.data!;
                  return ListView.builder(
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
                                  subtitle: Text(
                                    folder,
                                    style: const TextStyle(color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FolderDetailScreen(
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

  Widget buildBackground(BuildContext context, SongModel? currentSong) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: OMeshGradient(
        mesh: OMeshRect(
          width: 2,
          height: 2,
          fallbackColor: isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD),
          vertices: [
            // Top-left corner
            (0.0, 0.0).v.to(isDarkMode ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD)),
            // Top-right corner  
            (1.0, 0.0).v.to(isDarkMode ? const Color(0xFF311B92) : const Color(0xFFBBDEFB)),
            // Bottom-left corner
            (0.0, 1.0).v.to(isDarkMode ? const Color(0xFF512DA8) : const Color(0xFF90CAF9)),
            // Bottom-right corner
            (1.0, 1.0).v.to(isDarkMode ? const Color(0xFF7B1FA2) : const Color(0xFF64B5F6)),
          ],
        ),
      ),
    );
  }
}



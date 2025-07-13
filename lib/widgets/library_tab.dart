import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../screens/AlbumDetailScreen.dart';
import '../screens/Artist_screen.dart';
import '../screens/FolderDetail_screen.dart';
import '../screens/PlaylistDetail_screen.dart';
import '../screens/Playlist_screen.dart';
import '../screens/categories.dart';
import '../screens/tracks_screen.dart';
import '../services/Audio_Player_Service.dart';
import '../widgets/glassmorphic_container.dart';
import '../localization/app_localizations.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 30.0,
        bottom: audioPlayerService.currentSong != null ? 90.0 : 30.0,
      ),
      child: AnimationLimiter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              buildCategorySection(
                title: AppLocalizations.of(context).translate('tracks'),
                items: audioPlayerService.getMostPlayedTracks(),
                onDetailsTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const TracksScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                ),
                onItemTap: (song) {
                  if (song is SongModel) {
                    audioPlayerService.setPlaylist([song], 0);
                    audioPlayerService.play();
                  }
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('albums'),
                items: audioPlayerService.getMostPlayedAlbums(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlbumsScreen()),
                ),
                onItemTap: (album) {
                  if (album is AlbumModel) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailScreen(albumName: album.album),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 30.0),
              Consumer<AudioPlayerService>(
                builder: (context, audioPlayerService, child) {
                  return buildCategorySection(
                    title: AppLocalizations.of(context).translate('playlists'),
                    items: audioPlayerService.getThreePlaylists(),
                    onDetailsTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PlaylistsScreenList()),
                    ),
                    onItemTap: (playlist) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailScreen(playlist: playlist),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('artists'),
                items: audioPlayerService.getMostPlayedArtists(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArtistsScreen()),
                ),
                onItemTap: (artist) {
                  if (artist is ArtistModel) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistDetailsScreen(
                          artistName: artist.artist,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 30.0),
              buildCategorySection(
                title: AppLocalizations.of(context).translate('folders'),
                items: audioPlayerService.getThreeFolders(),
                onDetailsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FoldersScreen()),
                ),
                onItemTap: (folder) {
                  if (folder is String) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FolderDetailScreen(
                          folderPath: folder,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCategorySection({
    required String title,
    required dynamic items,
    required VoidCallback onDetailsTap,
    Function(dynamic)? onItemTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: onDetailsTap,
              child: glassmorphicContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    AppLocalizations.of(context).translate('details'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          height: 150,
          child: items is Future
              ? FutureBuilder<List<dynamic>>(
                  future: items as Future<List<dynamic>>,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No data available'));
                    } else {
                      return _buildAnimatedItemsList(snapshot.data!, onItemTap);
                    }
                  },
                )
              : _buildAnimatedItemsList(items, onItemTap),
        ),
      ],
    );
  }

  Widget _buildAnimatedItemsList(List<dynamic> items, Function(dynamic)? onItemTap) {
    const double itemWidth = 120.0;
    const double itemSpacing = 10.0;
    
    return AnimationLimiter(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: min(3, items.length),
        itemExtent: itemWidth + itemSpacing, // Performance optimization
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: RepaintBoundary( // Performance optimization
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onItemTap != null ? () => onItemTap(item) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: itemSpacing),
                        child: glassmorphicContainer(
                          child: SizedBox(
                            width: itemWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                getItemIcon(item),
                                const SizedBox(height: 8),
                                Text(
                                  getItemTitle(item),
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget getItemIcon(dynamic item) {
    if (item is SongModel) {
      return RepaintBoundary(
        child: QueryArtworkWidget(
          id: item.id,
          type: ArtworkType.AUDIO,
          nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white, size: 60),
        ),
      );
    } else if (item is AlbumModel) {
      return RepaintBoundary(
        child: QueryArtworkWidget(
          id: item.id,
          type: ArtworkType.ALBUM,
          nullArtworkWidget: const Icon(Icons.album, color: Colors.white, size: 60),
        ),
      );
    } else if (item is Playlist) {
      return const Icon(Icons.playlist_play, color: Colors.white, size: 60);
    } else if (item is ArtistModel) {
      return const CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/logo/default_art.png'),
      );
    } else if (item is String) {
      return const Icon(Icons.folder, color: Colors.white, size: 60);
    }
    return const Icon(Icons.error, color: Colors.white, size: 60);
  }

  String getItemTitle(dynamic item) {
    if (item is SongModel) return item.title;
    if (item is AlbumModel) return item.album;
    if (item is Playlist) return item.name;
    if (item is ArtistModel) return item.artist;
    if (item is String) return item.split('/').last;
    return 'Unknown';
  }
}
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
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/shimmer_loading.dart';
import '../localization/app_localizations.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  // Make artwork service static to prevent recreation on every build
  static final _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {
    // Access service without listening for methods
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    return Selector<AudioPlayerService, bool>(
      selector: (context, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 30.0,
            bottom: hasCurrentSong ? 90.0 : 30.0,
          ),
          child: child,
        );
      },
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
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const TracksScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                  ),
                ),
                onItemTap: (song) {
                  if (song is SongModel) {
                    audioPlayerService.setPlaylist([song], 0);
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
                        builder: (context) =>
                            AlbumDetailScreen(albumName: album.album),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 30.0),
              Selector<AudioPlayerService, List<Playlist>>(
                selector: (context, service) => service.playlists,
                builder: (context, playlists, child) {
                  return buildCategorySection(
                    title: AppLocalizations.of(context).translate('playlists'),
                    items: audioPlayerService.getThreePlaylists(),
                    onDetailsTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PlaylistsScreenList()),
                    ),
                    onItemTap: (playlist) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PlaylistDetailScreen(playlist: playlist),
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
                  MaterialPageRoute(
                      builder: (context) => const ArtistsScreen()),
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
                  MaterialPageRoute(
                      builder: (context) => const FoldersScreen()),
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
    return RepaintBoundary(
      child: Column(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          itemBuilder: (context, index) => const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: CardSkeleton(size: 100),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No data available'));
                      } else {
                        return _buildOptimizedItemsList(
                            snapshot.data!, onItemTap);
                      }
                    },
                  )
                : _buildOptimizedItemsList(items, onItemTap),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedItemsList(
      List<dynamic> items, Function(dynamic)? onItemTap) {
    final displayItems = items.take(3).toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: displayItems.length,
      itemExtent: 130, // Fixed width for better performance
      physics: const BouncingScrollPhysics(), // Better scroll performance
      cacheExtent: 200, // Pre-cache nearby items
      addAutomaticKeepAlives: false, // Don't keep offscreen items alive
      addRepaintBoundaries: true, // Optimize repaints
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return RepaintBoundary(
          key: ValueKey('${item.hashCode}_$index'), // Stable keys
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: glassmorphicContainer(
              child: InkWell(
                onTap: onItemTap != null ? () => onItemTap(item) : null,
                child: SizedBox(
                  width: 120,
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
        );
      },
    );
  }

  Widget getItemIcon(dynamic item) {
    if (item is SongModel) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _artworkService.buildCachedArtwork(
          item.id,
          size: 60,
        ),
      );
    } else if (item is AlbumModel) {
      return Hero(
        tag: 'album_image_${item.album}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _artworkService.buildCachedAlbumArtwork(
            item.id,
            size: 60,
          ),
        ),
      );
    } else if (item is Playlist) {
      return const Icon(Icons.playlist_play, color: Colors.white, size: 60);
    } else if (item is ArtistModel) {
      return Hero(
        tag: 'artist_image_${item.artist}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: _artworkService.buildArtistImageByName(
            item.artist,
            size: 60,
            circular: true,
          ),
        ),
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

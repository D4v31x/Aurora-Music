import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/playlist_model.dart';
import '../models/utils.dart';
import '../screens/AlbumDetailScreen.dart';
import '../screens/Artist_screen.dart';
import '../screens/FolderDetail_screen.dart';
import '../screens/PlaylistDetail_screen.dart';
import '../screens/Playlist_screen.dart';
import '../screens/categories.dart';
import '../screens/tracks_screen.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../widgets/glassmorphic_card.dart';
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
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return Selector<AudioPlayerService, bool>(
      selector: (context, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
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
              const SizedBox(height: 24.0),
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
              const SizedBox(height: 24.0),
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
              const SizedBox(height: 24.0),
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
              const SizedBox(height: 24.0),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ProductSans',
                ),
              ),
              GestureDetector(
                onTap: onDetailsTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('details'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            height: 180,
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
                            child: CardSkeleton(size: 130),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            AppLocalizations.of(context).translate('No_data'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        );
                      } else {
                        return _buildItemsList(snapshot.data!, onItemTap);
                      }
                    },
                  )
                : _buildItemsList(items, onItemTap),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items, Function(dynamic)? onItemTap) {
    final displayItems = items.take(5).toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: displayItems.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return _buildItemCard(item, onItemTap);
      },
    );
  }

  Widget _buildItemCard(dynamic item, Function(dynamic)? onItemTap) {
    if (item is SongModel) {
      return GlassmorphicCard.song(
        key: ValueKey('song_${item.id}'),
        songId: item.id,
        title: item.title,
        artist: splitArtists(item.artist ?? 'Unknown').join(', '),
        artworkService: _artworkService,
        onTap: () => onItemTap?.call(item),
      );
    } else if (item is AlbumModel) {
      return GlassmorphicCard.album(
        key: ValueKey('album_${item.id}'),
        albumId: item.id,
        albumName: item.album,
        artistName: item.artist,
        artworkService: _artworkService,
        onTap: () => onItemTap?.call(item),
      );
    } else if (item is Playlist) {
      return GlassmorphicCard.playlist(
        key: ValueKey('playlist_${item.name}'),
        playlistName: item.name,
        songCount: item.songs.length,
        playlistId: item.id,
        onTap: () => onItemTap?.call(item),
      );
    } else if (item is ArtistModel) {
      return GlassmorphicCard.artist(
        key: ValueKey('artist_${item.artist}'),
        artistName: item.artist,
        artworkService: _artworkService,
        circularArtwork: false,
        onTap: () => onItemTap?.call(item),
      );
    } else if (item is String) {
      return GlassmorphicCard.folder(
        key: ValueKey('folder_$item'),
        folderName: item.split('/').last,
        onTap: () => onItemTap?.call(item),
      );
    }
    return const SizedBox.shrink();
  }
}

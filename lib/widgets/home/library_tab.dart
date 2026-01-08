import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../models/playlist_model.dart';
import '../../models/utils.dart';
import '../../screens/library/album_detail_screen.dart';
import '../../screens/library/artist_detail_screen.dart';
import '../../screens/library/folder_detail_screen.dart';
import '../../screens/library/playlist_detail_screen.dart';
import '../../screens/library/playlists_screen.dart';
import '../../screens/library/categories.dart';
import '../../screens/library/tracks_screen.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../glassmorphic_card.dart';
import '../shimmer_loading.dart';
import '../../localization/app_localizations.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/performance_mode_provider.dart';

import '../expanding_player.dart';

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

    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);
    final layoutMode = ResponsiveUtils.getLayoutMode(context);

    return Selector<AudioPlayerService, bool>(
      selector: (context, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: isTablet ? 40.0 : 30.0,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : isTablet
                    ? 40.0
                    : 30.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.getContentMaxWidth(context),
              ),
              child: child,
            ),
          ),
        );
      },
      child: _buildContent(audioPlayerService, isTablet, layoutMode),
    );
  }

  Widget _buildContent(AudioPlayerService audioPlayerService, bool isTablet,
      LayoutMode layoutMode) {
    // On tablets with twoColumn layout, show a 2-column grid of sections
    // Each section looks like the mobile version but arranged side by side
    if (layoutMode == LayoutMode.twoColumn ||
        layoutMode == LayoutMode.wideWithPanel) {
      return _buildTabletLayout(audioPlayerService, layoutMode);
    }

    return AnimationLimiter(
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
            const SizedBox(height: 24.0),
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
    );
  }

  /// Build a tablet-optimized grid layout for library categories
  /// Uses the same visual style as mobile but arranged in a 2-column grid
  Widget _buildTabletLayout(
      AudioPlayerService audioPlayerService, LayoutMode layoutMode) {
    final spacing = ResponsiveUtils.getSpacing(context);
    final isWideLayout = layoutMode == LayoutMode.wideWithPanel;

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: [
            // First row: Tracks and Albums
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTabletCategorySection(
                    title: AppLocalizations.of(context).translate('tracks'),
                    items: audioPlayerService.getMostPlayedTracks(),
                    onDetailsTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const TracksScreen(),
                        transitionsBuilder: (context, animation,
                                secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    onItemTap: (song) {
                      if (song is SongModel) {
                        audioPlayerService.setPlaylist([song], 0);
                      }
                    },
                    isWideLayout: isWideLayout,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildTabletCategorySection(
                    title: AppLocalizations.of(context).translate('albums'),
                    items: audioPlayerService.getMostPlayedAlbums(),
                    onDetailsTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AlbumsScreen()),
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
                    isWideLayout: isWideLayout,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            // Second row: Playlists and Artists
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Selector<AudioPlayerService, List<Playlist>>(
                    selector: (context, service) => service.playlists,
                    builder: (context, playlists, child) {
                      return _buildTabletCategorySection(
                        title:
                            AppLocalizations.of(context).translate('playlists'),
                        items: audioPlayerService.getThreePlaylists(),
                        onDetailsTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PlaylistsScreenList()),
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
                        isWideLayout: isWideLayout,
                      );
                    },
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildTabletCategorySection(
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
                    isWideLayout: isWideLayout,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            // Third row: Folders (full width)
            _buildTabletCategorySection(
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
              isWideLayout: isWideLayout,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Build a category section for tablet layout that matches mobile visual style
  Widget _buildTabletCategorySection({
    required String title,
    required dynamic items,
    required VoidCallback onDetailsTap,
    Function(dynamic)? onItemTap,
    bool isWideLayout = false,
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final cardSize = isWideLayout ? 120.0 : 110.0;
    final sectionHeight = cardSize + 60; // Card size + text space

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use solid surface colors for lowend devices
    final BoxDecoration detailsButtonDecoration;
    if (shouldBlur) {
      detailsButtonDecoration = BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.1),
        ),
      );
    } else {
      // Solid button styling for lowend devices
      detailsButtonDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      );
    }

    final detailsButtonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: detailsButtonDecoration,
      child: Text(
        AppLocalizations.of(context).translate('details'),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontFamily: 'Outfit',
          fontSize: 12,
        ),
      ),
    );

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 26,
                ),
              ),
              GestureDetector(
                onTap: onDetailsTap,
                child: shouldBlur
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: detailsButtonContent,
                        ),
                      )
                    : detailsButtonContent,
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            height: sectionHeight,
            child: items is Future
                ? FutureBuilder<List<dynamic>>(
                    future: items as Future<List<dynamic>>,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: CardSkeleton(size: cardSize),
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
                        return _buildTabletItemsList(
                          snapshot.data!,
                          onItemTap,
                          cardSize,
                          isFullWidth ? 6 : 4,
                        );
                      }
                    },
                  )
                : _buildTabletItemsList(
                    items,
                    onItemTap,
                    cardSize,
                    isFullWidth ? 6 : 4,
                  ),
          ),
        ],
      ),
    );
  }

  /// Build items list for tablet layout with specified card size
  Widget _buildTabletItemsList(
    List<dynamic> items,
    Function(dynamic)? onItemTap,
    double cardSize,
    int maxItems,
  ) {
    final displayItems = items.take(maxItems).toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: displayItems.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return _buildTabletItemCard(item, onItemTap, cardSize);
      },
    );
  }

  /// Build individual item card for tablet layout
  Widget _buildTabletItemCard(
    dynamic item,
    Function(dynamic)? onItemTap,
    double cardSize,
  ) {
    if (item is SongModel) {
      return GlassmorphicCard.song(
        key: ValueKey('tablet_song_${item.id}'),
        songId: item.id,
        title: item.title,
        artist: splitArtists(item.artist ?? 'Unknown').join(', '),
        artworkService: _artworkService,
        onTap: () => onItemTap?.call(item),
        size: cardSize,
      );
    } else if (item is AlbumModel) {
      return GlassmorphicCard.album(
        key: ValueKey('tablet_album_${item.id}'),
        albumId: item.id,
        albumName: item.album,
        artistName: item.artist,
        artworkService: _artworkService,
        onTap: () => onItemTap?.call(item),
        size: cardSize,
      );
    } else if (item is Playlist) {
      return GlassmorphicCard.playlist(
        key: ValueKey('tablet_playlist_${item.name}'),
        playlistName: item.name,
        songCount: item.songs.length,
        playlistId: item.id,
        onTap: () => onItemTap?.call(item),
        size: cardSize,
      );
    } else if (item is ArtistModel) {
      return GlassmorphicCard.artist(
        key: ValueKey('tablet_artist_${item.artist}'),
        artistName: item.artist,
        artworkService: _artworkService,
        circularArtwork: false,
        onTap: () => onItemTap?.call(item),
        size: cardSize,
      );
    } else if (item is String) {
      return GlassmorphicCard.folder(
        key: ValueKey('tablet_folder_$item'),
        folderName: item.split('/').last,
        onTap: () => onItemTap?.call(item),
        size: cardSize,
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildCategorySection({
    required String title,
    required dynamic items,
    required VoidCallback onDetailsTap,
    Function(dynamic)? onItemTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use solid surface colors for lowend devices
    final BoxDecoration detailsButtonDecoration;
    if (shouldBlur) {
      detailsButtonDecoration = BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.1),
        ),
      );
    } else {
      // Solid button styling for lowend devices
      detailsButtonDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      );
    }

    final detailsButtonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: detailsButtonDecoration,
      child: Text(
        AppLocalizations.of(context).translate('details'),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontFamily: 'Outfit',
        ),
      ),
    );

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: ResponsiveUtils.isTablet(context) ? 26 : null,
                ),
              ),
              GestureDetector(
                onTap: onDetailsTap,
                child: shouldBlur
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: detailsButtonContent,
                        ),
                      )
                    : detailsButtonContent,
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            height: 190,
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

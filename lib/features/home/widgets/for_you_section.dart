import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/local_caching_service.dart';
import '../../../shared/models/playlist_model.dart';
import '../../library/screens/playlist_detail_screen.dart';
import '../../library/screens/album_detail_screen.dart';
import '../../library/screens/artist_detail_screen.dart';
import '../../../l10n/app_localizations.dart';

/// A "For You" section with a 2-row fixed grid of personalized content
/// Based on currently playing, recently played, liked songs, and listening habits
class ForYouSection extends StatefulWidget {
  final List<SongModel> randomSongs;
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;

  const ForYouSection({
    super.key,
    required this.randomSongs,
    required this.randomArtists,
    required this.artistService,
  });

  @override
  State<ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends State<ForYouSection> {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<_ForYouItem> _cachedItems = [];
  bool _isInitialized = false;
  SongModel? _lastCurrentSong;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _buildForYouItems();
      _isInitialized = true;
    }
  }

  @override
  void didUpdateWidget(ForYouSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild if randomSongs or randomArtists content changed
    final songsChanged =
        oldWidget.randomSongs.length != widget.randomSongs.length ||
            !_listEquals(oldWidget.randomSongs, widget.randomSongs);
    final artistsChanged =
        oldWidget.randomArtists.length != widget.randomArtists.length ||
            !_listEquals(oldWidget.randomArtists, widget.randomArtists);

    if (songsChanged || artistsChanged) {
      _buildForYouItems();
    }
  }

  // Helper to compare lists by content
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] is SongModel && b[i] is SongModel) {
        if ((a[i] as SongModel).id != (b[i] as SongModel).id) return false;
      } else if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _buildForYouItems() {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final List<_ForYouItem> items = [];
    final addedIds = <String>{};

    // 1. If currently playing, add the current artist(s)
    final currentSong = audioService.currentSong;
    if (currentSong != null && currentSong.artist != null) {
      final artistNames = splitArtists(currentSong.artist!);
      for (final artistName in artistNames) {
        if (!addedIds.contains('artist_$artistName')) {
          items.add(_ForYouItem(
            type: _ForYouItemType.artist,
            artistName: artistName,
            title: artistName,
            subtitle: AppLocalizations.of(context).translate('now_playing'),
          ));
          addedIds.add('artist_$artistName');
          break; // Only add the first/primary artist to avoid cluttering
        }
      }
    }

    // 2. Add most played playlist
    for (final playlist in audioService.playlists) {
      if (playlist.id == 'most_played' && playlist.songs.isNotEmpty) {
        items.add(_ForYouItem(
          type: _ForYouItemType.playlist,
          playlist: playlist,
          title: playlist.name,
          subtitle:
              '${playlist.songs.length} ${AppLocalizations.of(context).translate('tracks')}',
        ));
        break;
      }
    }

    // 3. Add recently added playlist
    for (final playlist in audioService.playlists) {
      if (playlist.id == 'recently_added' && playlist.songs.isNotEmpty) {
        items.add(_ForYouItem(
          type: _ForYouItemType.playlist,
          playlist: playlist,
          title: playlist.name,
          subtitle:
              '${playlist.songs.length} ${AppLocalizations.of(context).translate('tracks')}',
        ));
        break;
      }
    }

    // 4. Add random songs if we need more items
    for (var i = 0; i < widget.randomSongs.length && items.length < 4; i++) {
      final song = widget.randomSongs[i];
      final songKey = 'song_${song.id}';
      if (!addedIds.contains(songKey)) {
        items.add(_ForYouItem(
          type: _ForYouItemType.song,
          song: song,
          title: song.title,
          subtitle: splitArtists(song.artist ?? 'Unknown').join(', '),
        ));
        addedIds.add(songKey);
      }
    }

    // 5. Add random artists if still need more
    for (var i = 0; i < widget.randomArtists.length && items.length < 4; i++) {
      final artistKey = 'artist_${widget.randomArtists[i]}';
      if (!addedIds.contains(artistKey)) {
        items.add(_ForYouItem(
          type: _ForYouItemType.artist,
          artistName: widget.randomArtists[i],
          title: widget.randomArtists[i],
        ));
        addedIds.add(artistKey);
      }
    }

    // Take exactly 4 items for 2x2 grid
    _cachedItems = items.take(4).toList();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to current song changes to update recommendations
    return Selector<AudioPlayerService, SongModel?>(
      selector: (_, service) => service.currentSong,
      shouldRebuild: (prev, next) {
        // Only rebuild if we switched to a different song
        if (prev?.id != next?.id && _lastCurrentSong?.id != next?.id) {
          _lastCurrentSong = next;
          // Schedule rebuild for next frame to avoid setState during build
          Future.microtask(() {
            if (mounted) _buildForYouItems();
          });
        }
        return false; // Never rebuild from selector, let setState handle it
      },
      builder: (context, _, __) {
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);
        final likedPlaylist = audioService.likedSongsPlaylist;
        final hasLiked =
            likedPlaylist != null && likedPlaylist.songs.isNotEmpty;

        if (!hasLiked && _cachedItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // First row - Favorite Songs (full width)
              if (hasLiked)
                _FavoriteSongsCard(
                  playlist: likedPlaylist,
                  artworkService: _artworkService,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PlaylistDetailScreen(
                          playlist: likedPlaylist,
                        ),
                      ),
                    );
                  },
                ),
              if (hasLiked && _cachedItems.isNotEmpty)
                const SizedBox(height: 10),
              // Second row (2 items)
              if (_cachedItems.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: _cachedItems.isNotEmpty
                          ? _ForYouItemCard(
                              key: const ValueKey('foryou_0'),
                              item: _cachedItems[0],
                              artworkService: _artworkService,
                              onTap: () =>
                                  _handleItemTap(_cachedItems[0], audioService),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _cachedItems.length > 1
                          ? _ForYouItemCard(
                              key: const ValueKey('foryou_1'),
                              item: _cachedItems[1],
                              artworkService: _artworkService,
                              onTap: () =>
                                  _handleItemTap(_cachedItems[1], audioService),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              if (_cachedItems.length > 2) const SizedBox(height: 10),
              // Third row (2 items)
              if (_cachedItems.length > 2)
                Row(
                  children: [
                    Expanded(
                      child: _ForYouItemCard(
                        key: const ValueKey('foryou_2'),
                        item: _cachedItems[2],
                        artworkService: _artworkService,
                        onTap: () =>
                            _handleItemTap(_cachedItems[2], audioService),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _cachedItems.length > 3
                          ? _ForYouItemCard(
                              key: const ValueKey('foryou_3'),
                              item: _cachedItems[3],
                              artworkService: _artworkService,
                              onTap: () =>
                                  _handleItemTap(_cachedItems[3], audioService),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleItemTap(_ForYouItem item, AudioPlayerService audioService) {
    switch (item.type) {
      case _ForYouItemType.song:
        final songs =
            widget.randomSongs.isNotEmpty ? widget.randomSongs : [item.song!];
        final index = songs.indexWhere((s) => s.id == item.song!.id);
        audioService.setPlaylist(
          songs,
          index >= 0 ? index : 0,
          source: const PlaybackSourceInfo(source: PlaybackSource.forYou),
        );
        break;
      case _ForYouItemType.album:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(albumName: item.title),
          ),
        );
        break;
      case _ForYouItemType.artist:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailsScreen(artistName: item.artistName!),
          ),
        );
        break;
      case _ForYouItemType.playlist:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PlaylistDetailScreen(playlist: item.playlist!),
          ),
        );
        break;
    }
  }
}

/// Card widget for For You items
// Full-width Favorite Songs card for the first row
class _FavoriteSongsCard extends StatelessWidget {
  final Playlist playlist;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _FavoriteSongsCard({
    required this.playlist,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            // Liked songs artwork
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Image.asset(
                  'assets/images/UI/liked.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Title & subtitle
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        localizations.translate('favorite_songs'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: FontConstants.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        '${playlist.songs.length} ${localizations.translate('tracks')}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black54,
                          fontSize: 12,
                          fontFamily: FontConstants.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Play button
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: theme.colorScheme.primary,
                ),
                iconSize: 24,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (playlist.songs.isNotEmpty) {
                    final audioService = Provider.of<AudioPlayerService>(
                      context,
                      listen: false,
                    );
                    audioService.setPlaylist(
                      playlist.songs,
                      0,
                      source: PlaybackSourceInfo(
                        source: PlaybackSource.playlist,
                        name: playlist.name,
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
}

class _ForYouItemCard extends StatelessWidget {
  final _ForYouItem item;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _ForYouItemCard({
    super.key,
    required this.item,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _buildArtwork(),
              ),
            ),
            // Title & subtitle
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: FontConstants.fontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          item.subtitle!,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black54,
                            fontSize: 11,
                            fontFamily: FontConstants.fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    switch (item.type) {
      case _ForYouItemType.song:
        return artworkService.buildCachedArtwork(
          item.song!.id,
          size: 64,
        );
      case _ForYouItemType.album:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.withOpacity(0.8),
                Colors.purple.withOpacity(0.8),
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.album_rounded, color: Colors.white, size: 28),
          ),
        );
      case _ForYouItemType.artist:
        return artworkService.buildArtistImageByName(
          item.artistName!,
          size: 64,
        );
      case _ForYouItemType.playlist:
        return _buildPlaylistArtwork(item.playlist!);
    }
  }

  Widget _buildPlaylistArtwork(Playlist playlist) {
    String? imagePath;
    if (playlist.id == 'liked_songs') {
      imagePath = 'assets/images/UI/liked.png';
    } else if (playlist.id == 'recently_added') {
      imagePath = 'assets/images/UI/recentlyadded.png';
    } else if (playlist.id == 'most_played') {
      imagePath = 'assets/images/UI/mostplayed.png';
    }

    if (imagePath != null) {
      return Image.asset(imagePath, fit: BoxFit.cover);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.8),
            Colors.blue.withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.playlist_play_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

enum _ForYouItemType { song, album, artist, playlist }

class _ForYouItem {
  final _ForYouItemType type;
  final SongModel? song;
  final String? artistName;
  final Playlist? playlist;
  final String title;
  final String? subtitle;

  _ForYouItem({
    required this.type,
    this.song,
    this.artistName,
    this.playlist,
    required this.title,
    this.subtitle,
  });
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/playlist_model.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../../l10n/app_localizations.dart';
import '../models/artist_utils.dart';

/// Glassmorphic song picker bottom sheet for adding songs to playlists
class SongPickerSheet extends HookWidget {
  final Playlist playlist;

  const SongPickerSheet({super.key, required this.playlist});

  static Future<void> show(BuildContext context, Playlist playlist) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SongPickerSheet(playlist: playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioQuery = useMemoized(() => OnAudioQuery());
    final artworkService = useMemoized(() => ArtworkCacheService());
    final searchController = useTextEditingController();
    final scrollController = useScrollController();

    final allSongs = useState<List<SongModel>>([]);
    final filteredSongs = useState<List<SongModel>>([]);
    final selectedSongIds = useState<Set<int>>({});
    final isLoading = useState(true);
    final searchQuery = useState('');
    final displayedCount = useState(50);

    const pageSize = 50;

    // Load songs on mount
    useEffect(() {
      Future<void> loadSongs() async {
        try {
          final songs = await audioQuery.querySongs(
            sortType: SongSortType.TITLE,
            orderType: OrderType.ASC_OR_SMALLER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );

          final playlistSongIds = playlist.songs.map((s) => s.id).toSet();
          allSongs.value =
              songs.where((s) => !playlistSongIds.contains(s.id)).toList();
          filteredSongs.value = List.from(allSongs.value);

          isLoading.value = false;
        } catch (e) {
          isLoading.value = false;
        }
      }

      loadSongs();
      return null;
    }, const []);

    // Scroll listener for pagination
    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          if (displayedCount.value < filteredSongs.value.length) {
            displayedCount.value = (displayedCount.value + pageSize)
                .clamp(0, filteredSongs.value.length);
          }
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    void onSearchChanged(String query) {
      searchQuery.value = query.toLowerCase();
      displayedCount.value = pageSize;

      if (searchQuery.value.isEmpty) {
        filteredSongs.value = List.from(allSongs.value);
      } else {
        filteredSongs.value = allSongs.value.where((song) {
          final title = song.title.toLowerCase();
          final artistNames = splitArtists(song.artist ?? '')
              .map((a) => a.toLowerCase())
              .toList();
          final artistCombined = artistNames.join(' ');
          return title.contains(searchQuery.value) ||
              artistCombined.contains(searchQuery.value) ||
              artistNames.any((a) => a.contains(searchQuery.value));
        }).toList();
      }
    }

    void toggleSelection(SongModel song) {
      final newSet = Set<int>.from(selectedSongIds.value);
      if (newSet.contains(song.id)) {
        newSet.remove(song.id);
      } else {
        newSet.add(song.id);
      }
      selectedSongIds.value = newSet;
    }

    void addSelectedSongs() {
      if (selectedSongIds.value.isEmpty) return;

      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      final songsToAdd = allSongs.value
          .where((s) => selectedSongIds.value.contains(s.id))
          .toList();

      audioService.addSongsToPlaylist(playlist.id, songsToAdd);
      Navigator.pop(context);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('add_songs'),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (selectedSongIds.value.isNotEmpty)
                            Text(
                              '${selectedSongIds.value.length} ${localizations.translate('selected')}',
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (selectedSongIds.value.isNotEmpty)
                      GestureDetector(
                        onTap: addSelectedSongs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                localizations.translate('add'),
                                style: const TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          localizations.translate('cancel'),
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontFamily: FontConstants.fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: localizations.translate('search_tracks'),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 22,
                      ),
                      suffixIcon: searchQuery.value.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                              child: Icon(
                                Icons.clear_rounded,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 20,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),

              // Quick Actions
              if (!isLoading.value && filteredSongs.value.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (selectedSongIds.value.length ==
                              filteredSongs.value.length) {
                            selectedSongIds.value = {};
                          } else {
                            selectedSongIds.value =
                                filteredSongs.value.map((s) => s.id).toSet();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selectedSongIds.value.length ==
                                        filteredSongs.value.length
                                    ? Icons.deselect
                                    : Icons.select_all_rounded,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedSongIds.value.length ==
                                        filteredSongs.value.length
                                    ? localizations.translate('deselect_all')
                                    : localizations.translate('select_all'),
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  fontSize: 13,
                                  color:
                                      isDark ? Colors.white60 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredSongs.value.length} ${localizations.translate('tracks')}',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // Song List
              Expanded(
                child: isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : filteredSongs.value.isEmpty
                        ? _buildEmptyState(
                            isDark, localizations, searchQuery.value)
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: displayedCount.value
                                .clamp(0, filteredSongs.value.length),
                            itemBuilder: (context, index) {
                              final song = filteredSongs.value[index];
                              final isSelected =
                                  selectedSongIds.value.contains(song.id);

                              return _buildSongTile(
                                song,
                                isSelected,
                                isDark,
                                theme.colorScheme.primary,
                                artworkService,
                                toggleSelection,
                              );
                            },
                          ),
              ),
            ],
      ),
        ),
      ),
    );
  }

  static Widget _buildSongTile(
    SongModel song,
    bool isSelected,
    bool isDark,
    Color primaryColor,
    ArtworkCacheService artworkService,
    void Function(SongModel) onTap,
  ) {
    return GestureDetector(
      onTap: () => onTap(song),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Selection Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: artworkService.buildCachedArtwork(song.id, size: 44),
              ),
            ),
            const SizedBox(width: 12),

            // Song Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    splitArtists(song.artist ?? 'Unknown').join(', '),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildEmptyState(
      bool isDark, AppLocalizations localizations, String searchQuery) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.library_music_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty
                ? localizations.translate('no_results')
                : localizations.translate('no_songs_available'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

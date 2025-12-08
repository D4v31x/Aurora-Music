import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/playlist_model.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../localization/app_localizations.dart';
import '../models/utils.dart';
import 'dart:ui';

/// Glassmorphic song picker bottom sheet for adding songs to playlists
class SongPickerSheet extends StatefulWidget {
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
  State<SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<SongPickerSheet> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SongModel> _allSongs = [];
  List<SongModel> _filteredSongs = [];
  final Set<int> _selectedSongIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  final int _pageSize = 50;
  int _displayedCount = 50;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_displayedCount < _filteredSongs.length) {
      setState(() {
        _displayedCount =
            (_displayedCount + _pageSize).clamp(0, _filteredSongs.length);
      });
    }
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final playlistSongIds = widget.playlist.songs.map((s) => s.id).toSet();
      _allSongs = songs.where((s) => !playlistSongIds.contains(s.id)).toList();
      _filteredSongs = List.from(_allSongs);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _displayedCount = _pageSize;

      if (_searchQuery.isEmpty) {
        _filteredSongs = List.from(_allSongs);
      } else {
        _filteredSongs = _allSongs.where((song) {
          final title = song.title.toLowerCase();
          final artistNames = splitArtists(song.artist ?? '').map((a) => a.toLowerCase()).toList();
          final artistCombined = artistNames.join(' ');
          return title.contains(_searchQuery) || 
                 artistCombined.contains(_searchQuery) ||
                 artistNames.any((a) => a.contains(_searchQuery));
        }).toList();
      }
    });
  }

  void _toggleSelection(SongModel song) {
    setState(() {
      if (_selectedSongIds.contains(song.id)) {
        _selectedSongIds.remove(song.id);
      } else {
        _selectedSongIds.add(song.id);
      }
    });
  }

  void _addSelectedSongs() {
    if (_selectedSongIds.isEmpty) return;

    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songsToAdd =
        _allSongs.where((s) => _selectedSongIds.contains(s.id)).toList();

    audioService.addSongsToPlaylist(widget.playlist.id, songsToAdd);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.8)
                : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
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
                              fontFamily: 'ProductSans',
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedSongIds.isNotEmpty)
                            Text(
                              '${_selectedSongIds.length} ${localizations.translate('selected')}',
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_selectedSongIds.isNotEmpty)
                      GestureDetector(
                        onTap: _addSelectedSongs,
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
                                  fontFamily: 'ProductSans',
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
                            fontFamily: 'ProductSans',
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'ProductSans',
                        ),
                        decoration: InputDecoration(
                          hintText: localizations.translate('search_tracks'),
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontFamily: 'ProductSans',
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 22,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
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
                ),
              ),

              // Quick Actions
              if (!_isLoading && _filteredSongs.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedSongIds.length ==
                                _filteredSongs.length) {
                              _selectedSongIds.clear();
                            } else {
                              _selectedSongIds
                                  .addAll(_filteredSongs.map((s) => s.id));
                            }
                          });
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
                                _selectedSongIds.length == _filteredSongs.length
                                    ? Icons.deselect
                                    : Icons.select_all_rounded,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedSongIds.length == _filteredSongs.length
                                    ? localizations.translate('deselect_all')
                                    : localizations.translate('select_all'),
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
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
                        '${_filteredSongs.length} ${localizations.translate('tracks')}',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSongs.isEmpty
                        ? _buildEmptyState(isDark, localizations)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount:
                                _displayedCount.clamp(0, _filteredSongs.length),
                            itemBuilder: (context, index) {
                              final song = _filteredSongs[index];
                              final isSelected =
                                  _selectedSongIds.contains(song.id);

                              return _buildSongTile(
                                song,
                                isSelected,
                                isDark,
                                theme.colorScheme.primary,
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

  Widget _buildSongTile(
    SongModel song,
    bool isSelected,
    bool isDark,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () => _toggleSelection(song),
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
                child: _artworkService.buildCachedArtwork(song.id, size: 44),
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
                      fontFamily: 'ProductSans',
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
                      fontFamily: 'ProductSans',
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

  Widget _buildEmptyState(bool isDark, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.library_music_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? localizations.translate('no_results')
                : localizations.translate('no_songs_available'),
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

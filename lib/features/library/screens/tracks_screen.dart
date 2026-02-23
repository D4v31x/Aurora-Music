import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/models/playlist_model.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/optimized_tiles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/library_screen_header.dart';
import '../../../shared/utils/responsive_utils.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

enum TrackSortOption { title, artist, duration, dateAdded }

class TracksScreen extends StatefulWidget {
  final bool isEditingPlaylist;
  final Playlist? playlist;

  const TracksScreen({
    super.key,
    this.isEditingPlaylist = false,
    this.playlist,
  });

  @override
  _TracksScreenState createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  final ScrollController _scrollController = ScrollController();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final _artworkService = ArtworkCacheService();
  List<SongModel> _allSongs = [];
  List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 50;
  bool _isLoading = false;
  bool _hasMoreSongs = true;
  String _searchQuery = '';
  Timer? _debounce;
  String _errorMessage = '';
  final Set<SongModel> _selectedSongs = {};

  // Sort state
  TrackSortOption _sortOption = TrackSortOption.title;
  bool _isAscending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchAllSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
  }

  Future<void> _fetchAllSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final bool permissionStatus = await _audioQuery.permissionsStatus();

      if (!permissionStatus) {
        setState(() {
          _errorMessage = 'Permission to access media library is required. '
              'Please grant permissions in the onboarding or app settings.';
          _isLoading = false;
        });
        return;
      }

      if (permissionStatus) {
        _allSongs = await _audioQuery.querySongs(
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        setState(() => _isLoading = false);

        if (_allSongs.isEmpty) {
          setState(() {
            _errorMessage = 'No songs found on the device.';
          });
        } else {
          _applySorting();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching songs: $e';
        _isLoading = false;
      });
    }
  }

  void _applySorting() {
    switch (_sortOption) {
      case TrackSortOption.title:
        _allSongs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case TrackSortOption.artist:
        _allSongs.sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
        break;
      case TrackSortOption.duration:
        _allSongs.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
        break;
      case TrackSortOption.dateAdded:
        _allSongs
            .sort((a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
        break;
    }
    if (!_isAscending) _allSongs = _allSongs.reversed.toList();
    // Reset paging and load first page in one setState
    _displayedSongs.clear();
    _currentPage = 0;
    _hasMoreSongs = true;
    _loadMoreSongs();
  }

  String _getSortLabel(TrackSortOption opt) {
    switch (opt) {
      case TrackSortOption.title:
        return 'Title';
      case TrackSortOption.artist:
        return 'Artist';
      case TrackSortOption.duration:
        return 'Duration';
      case TrackSortOption.dateAdded:
        return 'Date added';
    }
  }

  void _loadMoreSongs() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final int startIndex = _currentPage * _songsPerPage;
    final int endIndex =
        (startIndex + _songsPerPage).clamp(0, _allSongs.length);

    if (startIndex < _allSongs.length) {
      final newSongs = _allSongs.sublist(startIndex, endIndex);

      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoading = false;
        _hasMoreSongs = endIndex < _allSongs.length;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasMoreSongs = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchQuery = query.toLowerCase();
      _searchSongs();
    });
  }

  void _searchSongs() {
    final filteredSongs = _searchQuery.isEmpty
        ? List<SongModel>.from(_allSongs)
        : _allSongs
            .where((song) =>
                song.title.toLowerCase().contains(_searchQuery) ||
                splitArtists(song.artist ?? '').any(
                    (artist) => artist.toLowerCase().contains(_searchQuery)))
            .toList();

    final int endIndex = _songsPerPage.clamp(0, filteredSongs.length);

    setState(() {
      _displayedSongs = filteredSongs.sublist(0, endIndex);
      _currentPage = 1;
      _hasMoreSongs = endIndex < filteredSongs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final loc = AppLocalizations.of(context);
    final totalCount = _allSongs.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            LibraryScreenHeader(
              badge: 'Library',
              title: loc.translate('tracks'),
              subtitle: totalCount > 0 ? '$totalCount songs' : null,
              accentColor: Colors.deepPurple,
              expandedHeight: 310,
              showBackButton: true,
              actions: [
                if (widget.isEditingPlaylist)
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: () {
                      audioPlayerService.addSongsToPlaylist(
                          widget.playlist!.id, _selectedSongs.toList());
                      Navigator.pop(context);
                    },
                  ),
              ],
              searchField: LibrarySearchField(
                controller: _searchController,
                hint: loc.translate('search_tracks'),
                onChanged: _onSearchChanged,
                hasQuery: _searchQuery.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
              controlsRow: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<TrackSortOption>(
                      onSelected: (opt) {
                        setState(() => _sortOption = opt);
                        _applySorting();
                      },
                      color: Colors.grey.shade900,
                      child: LibraryControlPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getSortLabel(_sortOption),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: Colors.white70),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        _sortItem(TrackSortOption.title, 'Title'),
                        _sortItem(TrackSortOption.artist, 'Artist'),
                        _sortItem(TrackSortOption.duration, 'Duration'),
                        _sortItem(TrackSortOption.dateAdded, 'Date added'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  LibraryControlPill(
                    onTap: () {
                      setState(() => _isAscending = !_isAscending);
                      _applySorting();
                    },
                    child: Icon(
                      _isAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            buildBody(audioPlayerService),
            SliverToBoxAdapter(
              child: SizedBox(
                height: ExpandingPlayer.getMiniPlayerPaddingHeight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<TrackSortOption> _sortItem(TrackSortOption opt, String label) {
    return PopupMenuItem(
      value: opt,
      child: Row(
        children: [
          if (_sortOption == opt)
            const Icon(Icons.check, color: Colors.white, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget buildBody(AudioPlayerService audioPlayerService) {
    if (_isLoading && _displayedSongs.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
            child: Text(_errorMessage,
                style: const TextStyle(color: Colors.white))),
      );
    } else if (_displayedSongs.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
            child:
                Text('No songs found', style: TextStyle(color: Colors.white))),
      );
    } else {
      final isTablet = ResponsiveUtils.isTablet(context);
      final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);

      // On tablets, use a grid layout for songs
      if (isTablet) {
        return _buildTabletSongGrid(audioPlayerService, horizontalPadding);
      }

      return AnimationLimiter(
        child: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _displayedSongs.length) {
                return _hasMoreSongs
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink();
              }
              final song = _displayedSongs[index];
              return RepaintBoundary(
                key: ValueKey(
                    song.id), // Use song ID as key for better performance
                child: AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(
                      milliseconds: 200), // Reduced for better performance
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: horizontalPadding),
                        child: _buildSongCard(song, audioPlayerService, index),
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
          ),
        ),
      );
    }
  }

  /// Build a grid layout for tablets
  Widget _buildTabletSongGrid(
      AudioPlayerService audioPlayerService, double horizontalPadding) {
    final columns = ResponsiveUtils.getCardColumns(context);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3.5, // Wide cards for song tiles
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _displayedSongs.length) {
                return _hasMoreSongs
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink();
              }
              final song = _displayedSongs[index];
              return RepaintBoundary(
                key: ValueKey(song.id),
                child: AnimationConfiguration.staggeredGrid(
                  position: index,
                  columnCount: columns,
                  duration: const Duration(milliseconds: 200),
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: _buildSongCard(song, audioPlayerService, index),
                    ),
                  ),
                ),
              );
            },
            childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
          ),
        ),
      ),
    );
  }

  Widget _buildSongCard(
      SongModel song, AudioPlayerService audioPlayerService, int index) {
    if (widget.isEditingPlaylist) {
      // Use original ListTile for editing mode with checkboxes
      return glassmorphicContainer(
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _artworkService.buildCachedArtwork(
              song.id,
            ),
          ),
          title: Text(
            song.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            splitArtists(song.artist ?? 'Unknown Artist').join(', '),
            style: TextStyle(color: Colors.grey[400]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Checkbox(
            value: _selectedSongs.contains(song),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedSongs.add(song);
                } else {
                  _selectedSongs.remove(song);
                }
              });
            },
            fillColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.blue;
              }
              return Colors.grey;
            }),
          ),
          onTap: () {
            setState(() {
              if (_selectedSongs.contains(song)) {
                _selectedSongs.remove(song);
              } else {
                _selectedSongs.add(song);
              }
            });
          },
        ),
      );
    }

    // Use OptimizedSongTile for better performance
    return glassmorphicContainer(
      child: OptimizedSongTile(
        key: ValueKey(song.id),
        song: song,
        selected: audioPlayerService.currentSong?.id == song.id,
        onTap: () {
          audioPlayerService.setPlaylist(
            _displayedSongs,
            index,
          );
        },
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            // Show options for the song
          },
        ),
      ),
    );
  }
}

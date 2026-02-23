import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/library_screen_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import 'album_detail_screen.dart';

enum AlbumSortOption { name, artist, numSongs, year }

/// Screen displaying all albums with search, sort, and view options.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  final TextEditingController _searchController = TextEditingController();

  List<AlbumModel> _allAlbums = [];
  List<AlbumModel> _filteredAlbums = [];
  List<AlbumModel> _displayedAlbums = [];
  AlbumSortOption _sortOption = AlbumSortOption.name;
  bool _isAscending = true;
  bool _isGridView = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  static const int _pageSize = 40;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadAlbums();
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
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || !_hasMore) return;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredAlbums.length);
    if (start >= _filteredAlbums.length) return;
    setState(() {
      _isLoadingMore = true;
      _displayedAlbums.addAll(_filteredAlbums.sublist(start, end));
      _currentPage++;
      _hasMore = end < _filteredAlbums.length;
      _isLoadingMore = false;
    });
  }

  void _resetPaging() {
    final end = _pageSize.clamp(0, _filteredAlbums.length);
    _displayedAlbums = _filteredAlbums.sublist(0, end);
    _currentPage = 1;
    _hasMore = end < _filteredAlbums.length;
  }

  Future<void> _loadAlbums() async {
    final albums = await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    setState(() {
      _allAlbums = albums;
      _filteredAlbums = albums;
      _isLoading = false;
    });
    _applySorting();
    _resetPaging();
  }

  void _filterAlbums(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAlbums = List.from(_allAlbums);
      } else {
        _filteredAlbums = _allAlbums.where((album) {
          return album.album.toLowerCase().contains(query.toLowerCase()) ||
              (album.artist?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
      _applySorting();
      setState(() => _resetPaging());
    });
  }

  void _applySorting() {
    switch (_sortOption) {
      case AlbumSortOption.name:
        _filteredAlbums.sort((a, b) => a.album.compareTo(b.album));
        break;
      case AlbumSortOption.artist:
        _filteredAlbums
            .sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
        break;
      case AlbumSortOption.numSongs:
        _filteredAlbums.sort((a, b) => (a.numOfSongs).compareTo(b.numOfSongs));
        break;
      case AlbumSortOption.year:
        _filteredAlbums.sort((a, b) {
          final yearA =
              int.tryParse(a.getMap['first_year']?.toString() ?? '0') ?? 0;
          final yearB =
              int.tryParse(b.getMap['first_year']?.toString() ?? '0') ?? 0;
          return yearA.compareTo(yearB);
        });
        break;
    }
    if (!_isAscending) {
      _filteredAlbums = _filteredAlbums.reversed.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final loc = AppLocalizations.of(context);
    final count = _filteredAlbums.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            LibraryScreenHeader(
              badge: 'Library',
              title: loc.translate('albums'),
              subtitle: _isLoading
                  ? null
                  : '$count ${count == 1 ? 'album' : 'albums'}',
              accentColor: Colors.indigo,
              expandedHeight: 310,
              showBackButton: true,
              searchField: LibrarySearchField(
                controller: _searchController,
                hint: loc.translate('search_albums'),
                onChanged: _filterAlbums,
                hasQuery: _searchQuery.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  _filterAlbums('');
                },
              ),
              controlsRow: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<AlbumSortOption>(
                      onSelected: (option) {
                        setState(() => _sortOption = option);
                        _applySorting();
                        setState(() => _resetPaging());
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
                                _getSortOptionLabel(_sortOption),
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
                        _buildSortMenuItem(AlbumSortOption.name, 'Name'),
                        _buildSortMenuItem(AlbumSortOption.artist, 'Artist'),
                        _buildSortMenuItem(AlbumSortOption.numSongs, 'Tracks'),
                        _buildSortMenuItem(AlbumSortOption.year, 'Year'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  LibraryControlPill(
                    onTap: () {
                      setState(() => _isAscending = !_isAscending);
                      _applySorting();
                      setState(() => _resetPaging());
                    },
                    child: Icon(
                      _isAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  LibraryControlPill(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    child: Icon(
                      _isGridView
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              _buildLoadingSkeleton()
            else if (_filteredAlbums.isEmpty)
              _buildEmptyState(loc)
            else
              _isGridView
                  ? _buildAlbumsGrid(audioPlayerService)
                  : _buildAlbumsList(audioPlayerService),
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

  Widget _buildLoadingSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SongTileSkeleton(),
          ),
          childCount: 8,
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.album, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? loc.translate('no_albums_found')
                  : loc.translate('no_results'),
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AlbumSortOption> _buildSortMenuItem(
      AlbumSortOption option, String label) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          if (_sortOption == option)
            const Icon(Icons.check, color: Colors.white, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  String _getSortOptionLabel(AlbumSortOption option) {
    switch (option) {
      case AlbumSortOption.name:
        return 'Name';
      case AlbumSortOption.artist:
        return 'Artist';
      case AlbumSortOption.numSongs:
        return 'Tracks';
      case AlbumSortOption.year:
        return 'Year';
    }
  }

  Widget _buildAlbumsGrid(AudioPlayerService audioPlayerService) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = _displayedAlbums[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: _buildAlbumGridTile(album),
                ),
              ),
            );
          },
          childCount: _displayedAlbums.length,
        ),
      ),
    );
  }

  Widget _buildAlbumGridTile(AlbumModel album) {
    return GestureDetector(
      onTap: () => _navigateToAlbumDetail(album),
      onLongPress: () => _showAlbumOptions(album),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _artworkService.buildCachedAlbumArtwork(
                        album.id,
                        size: 150,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.album,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${splitArtists(album.artist ?? 'Unknown').join(', ')} • ${album.numOfSongs} tracks',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
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
      ),
    );
  }

  Widget _buildAlbumsList(AudioPlayerService audioPlayerService) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _displayedAlbums.length) {
              return _hasMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            final album = _displayedAlbums[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 30,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAlbumListTile(album),
                  ),
                ),
              ),
            );
          },
          childCount: _displayedAlbums.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildAlbumListTile(AlbumModel album) {
    return GestureDetector(
      onTap: () => _navigateToAlbumDetail(album),
      onLongPress: () => _showAlbumOptions(album),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Hero(
                tag: 'album_image_${album.album}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _artworkService.buildCachedAlbumArtwork(
                    album.id,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.album,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      splitArtists(album.artist ?? 'Unknown Artist').join(', '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${album.numOfSongs} tracks',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_filled,
                    color: Colors.white70, size: 36),
                onPressed: () => _playAlbum(album),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAlbumDetail(AlbumModel album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(albumName: album.album),
      ),
    );
  }

  void _showAlbumOptions(AlbumModel album) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _artworkService.buildCachedAlbumArtwork(album.id),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.album,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          splitArtists(album.artist ?? 'Unknown').join(', '),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.white),
              title: const Text('Play', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _playAlbum(album);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle, color: Colors.white),
              title:
                  const Text('Shuffle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shuffleAlbum(album);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Add to Queue',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addAlbumToQueue(album);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _playAlbum(AlbumModel album) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList();
    if (albumSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(
        albumSongs,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.album,
          name: album.album,
        ),
      );
    }
  }

  Future<void> _shuffleAlbum(AlbumModel album) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList()
      ..shuffle();
    if (albumSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(
        albumSongs,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.album,
          name: album.album,
        ),
      );
    }
  }

  Future<void> _addAlbumToQueue(AlbumModel album) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList();

    if (albumSongs.isNotEmpty) {
      await audioPlayerService.addMultipleToQueue(albumSongs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${albumSongs.length} songs added to queue'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

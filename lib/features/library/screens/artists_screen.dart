import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/artist_aggregator_service.dart';
import '../../../shared/models/separated_artist.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/library_screen_header.dart';
import '../../../l10n/app_localizations.dart';
import 'artist_detail_screen.dart';

enum ArtistSortOption { name, tracks, albums }

/// Screen displaying all artists with search, sort, and view options.
class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  final ArtistAggregatorService _artistAggregator = ArtistAggregatorService();
  final TextEditingController _searchController = TextEditingController();

  List<SeparatedArtist> _allArtists = [];
  List<SeparatedArtist> _filteredArtists = [];
  List<SeparatedArtist> _displayedArtists = [];
  final Map<String, String?> _artistImages = {};
  ArtistSortOption _sortOption = ArtistSortOption.name;
  bool _isAscending = true;
  bool _isGridView = false;
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
    _loadArtists();
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
    final end = (start + _pageSize).clamp(0, _filteredArtists.length);
    if (start >= _filteredArtists.length) return;
    setState(() {
      _isLoadingMore = true;
      _displayedArtists.addAll(_filteredArtists.sublist(start, end));
      _currentPage++;
      _hasMore = end < _filteredArtists.length;
      _isLoadingMore = false;
    });
  }

  void _resetPaging() {
    final end = _pageSize.clamp(0, _filteredArtists.length);
    _displayedArtists = _filteredArtists.sublist(0, end);
    _currentPage = 1;
    _hasMore = end < _filteredArtists.length;
  }

  Future<void> _loadArtists() async {
    final artists = await _artistAggregator.getAllArtists();

    setState(() {
      _allArtists = artists;
      _filteredArtists = artists;
      _isLoading = false;
    });
    _applySorting();
    setState(() => _resetPaging());
    _loadArtistImages();
  }

  Future<void> _loadArtistImages() async {
    for (final artist in _allArtists) {
      final imagePath = await _artworkService.getArtistImageByName(artist.name);
      if (mounted && imagePath != null) {
        setState(() {
          _artistImages[artist.name] = imagePath;
        });
      }
    }
  }

  void _filterArtists(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredArtists = List.from(_allArtists);
      } else {
        _filteredArtists = _allArtists.where((artist) {
          return artist.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _applySorting();
      setState(() => _resetPaging());
    });
  }

  void _applySorting() {
    switch (_sortOption) {
      case ArtistSortOption.name:
        _filteredArtists.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ArtistSortOption.tracks:
        _filteredArtists
            .sort((a, b) => a.numberOfTracks.compareTo(b.numberOfTracks));
        break;
      case ArtistSortOption.albums:
        _filteredArtists
            .sort((a, b) => a.numberOfAlbums.compareTo(b.numberOfAlbums));
        break;
    }
    if (!_isAscending) {
      _filteredArtists = _filteredArtists.reversed.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final count = _filteredArtists.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            LibraryScreenHeader(
              badge: 'Library',
              title: loc.translate('artists'),
              subtitle: _isLoading
                  ? null
                  : '$count ${count == 1 ? 'artist' : 'artists'}',
              accentColor: Colors.teal,
              expandedHeight: 310,
              showBackButton: true,
              searchField: LibrarySearchField(
                controller: _searchController,
                hint: loc.translate('search_artists'),
                onChanged: _filterArtists,
                hasQuery: _searchQuery.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  _filterArtists('');
                },
              ),
              controlsRow: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<ArtistSortOption>(
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
                                _getArtistSortLabel(_sortOption),
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
                        _buildArtistSortMenuItem(ArtistSortOption.name, 'Name'),
                        _buildArtistSortMenuItem(
                            ArtistSortOption.tracks, 'Tracks'),
                        _buildArtistSortMenuItem(
                            ArtistSortOption.albums, 'Albums'),
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
            else if (_filteredArtists.isEmpty)
              _buildEmptyState(loc)
            else
              _isGridView ? _buildArtistsGrid() : _buildArtistsList(),
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
            Icon(Icons.person, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? loc.translate('no_artists_found')
                  : loc.translate('no_results'),
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ArtistSortOption> _buildArtistSortMenuItem(
      ArtistSortOption option, String label) {
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

  String _getArtistSortLabel(ArtistSortOption option) {
    switch (option) {
      case ArtistSortOption.name:
        return 'Name';
      case ArtistSortOption.tracks:
        return 'Tracks';
      case ArtistSortOption.albums:
        return 'Albums';
    }
  }

  Widget _buildArtistsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final artist = _displayedArtists[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 3,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: _buildArtistGridTile(artist),
                ),
              ),
            );
          },
          childCount: _displayedArtists.length,
        ),
      ),
    );
  }

  Widget _buildArtistGridTile(SeparatedArtist artist) {
    final imagePath = _artistImages[artist.name];

    return GestureDetector(
      onTap: () => _navigateToArtistDetail(artist),
      onLongPress: () => _showArtistOptions(artist),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: imagePath != null
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        )
                      : Image.asset(
                          'assets/images/UI/unknown.png',
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${artist.numberOfTracks} songs',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _displayedArtists.length) {
              return _hasMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            final artist = _displayedArtists[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 30,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildArtistListTile(artist),
                  ),
                ),
              ),
            );
          },
          childCount: _displayedArtists.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildArtistListTile(SeparatedArtist artist) {
    final imagePath = _artistImages[artist.name];
    final albumCount = artist.numberOfAlbums;

    return GestureDetector(
      onTap: () => _navigateToArtistDetail(artist),
      onLongPress: () => _showArtistOptions(artist),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'artist_image_${artist.name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: imagePath != null
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        )
                      : Image.asset(
                          'assets/images/UI/unknown.png',
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.music_note,
                            size: 14, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          '${artist.numberOfTracks} songs',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.album,
                            size: 14, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          '$albumCount albums',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_filled,
                    color: Colors.white70, size: 36),
                onPressed: () => _playArtist(artist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToArtistDetail(SeparatedArtist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(
          artistName: artist.name,
          artistImagePath: _artistImages[artist.name],
        ),
      ),
    );
  }

  void _showArtistOptions(SeparatedArtist artist) {
    final imagePath = _artistImages[artist.name];

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
                    borderRadius: BorderRadius.circular(25),
                    child: imagePath != null
                        ? Image.file(File(imagePath),
                            width: 50, height: 50, fit: BoxFit.cover)
                        : Image.asset(
                            'assets/images/UI/unknown.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${artist.numberOfTracks} songs',
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
              title:
                  const Text('Play All', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _playArtist(artist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle, color: Colors.white),
              title: const Text('Shuffle All',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shuffleArtist(artist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('View Details',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _navigateToArtistDetail(artist);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _playArtist(SeparatedArtist artist) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final artistSongs = await _artistAggregator.getSongsByArtist(artist.name);
    if (artistSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(
        artistSongs,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.artist,
          name: artist.name,
        ),
      );
    }
  }

  Future<void> _shuffleArtist(SeparatedArtist artist) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final artistSongs = await _artistAggregator.getSongsByArtist(artist.name);
    if (artistSongs.isNotEmpty) {
      final shuffled = List<SongModel>.from(artistSongs)..shuffle();
      audioPlayerService.setPlaylist(
        shuffled,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.artist,
          name: artist.name,
        ),
      );
    }
  }
}

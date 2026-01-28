import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../mixins/services/audio_player_service.dart';
import '../../mixins/services/artwork_cache_service.dart';
import '../../mixins/services/artist_aggregator_service.dart';
import '../../mixins/models/separated_artist.dart';
import '../../mixins/widgets/glassmorphic_container.dart';
import '../../mixins/widgets/shimmer_loading.dart';
import '../../mixins/widgets/common_screen_scaffold.dart';
import '../../l10n/app_localizations.dart';
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
  final Map<String, String?> _artistImages = {};
  ArtistSortOption _sortOption = ArtistSortOption.name;
  bool _isAscending = true;
  bool _isGridView = false;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArtists() async {
    final artists = await _artistAggregator.getAllArtists();

    setState(() {
      _allArtists = artists;
      _filteredArtists = artists;
      _isLoading = false;
    });
    _applySorting();
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
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredArtists = List.from(_allArtists);
      } else {
        _filteredArtists = _allArtists.where((artist) {
          return artist.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
    _applySorting();
  }

  void _applySorting() {
    setState(() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return CommonScreenScaffold(
      title: loc.translate('artists'),
      showBackButton: false,
      searchBar: _buildSearchAndFilterBar(loc),
      slivers: [
        if (_isLoading)
          _buildLoadingSkeleton()
        else if (_filteredArtists.isEmpty)
          _buildEmptyState(loc)
        else
          _isGridView ? _buildArtistsGrid() : _buildArtistsList(),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(AppLocalizations loc) {
    return Column(
      children: [
        glassmorphicContainer(
          child: TextField(
            controller: _searchController,
            onChanged: _filterArtists,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: loc.translate('search_artists'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        _filterArtists('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: glassmorphicContainer(
                child: PopupMenuButton<ArtistSortOption>(
                  onSelected: (option) {
                    setState(() => _sortOption = option);
                    _applySorting();
                  },
                  color: Colors.grey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getArtistSortLabel(_sortOption),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    _buildArtistSortMenuItem(ArtistSortOption.name, 'Name'),
                    _buildArtistSortMenuItem(ArtistSortOption.tracks, 'Tracks'),
                    _buildArtistSortMenuItem(ArtistSortOption.albums, 'Albums'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            glassmorphicContainer(
              child: IconButton(
                icon: Icon(
                  _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() => _isAscending = !_isAscending);
                  _applySorting();
                },
              ),
            ),
            const SizedBox(width: 8),
            glassmorphicContainer(
              child: IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list : Icons.grid_view,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
            ),
          ],
        ),
      ],
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
            final artist = _filteredArtists[index];
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
          childCount: _filteredArtists.length,
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
            final artist = _filteredArtists[index];
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
          childCount: _filteredArtists.length,
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

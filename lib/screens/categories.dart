import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/app_background.dart';
import '../widgets/shimmer_loading.dart';
import '../localization/app_localizations.dart';
import 'Artist_screen.dart';
import 'FolderDetail_screen.dart';
import 'AlbumDetailScreen.dart';
import 'dart:io';

enum AlbumSortOption { name, artist, numSongs, year }

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
  AlbumSortOption _sortOption = AlbumSortOption.name;
  bool _isAscending = true;
  bool _isGridView = true;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
  }

  void _filterAlbums(String query) {
    setState(() {
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
    });
    _applySorting();
  }

  void _applySorting() {
    setState(() {
      switch (_sortOption) {
        case AlbumSortOption.name:
          _filteredAlbums.sort((a, b) => a.album.compareTo(b.album));
          break;
        case AlbumSortOption.artist:
          _filteredAlbums
              .sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
          break;
        case AlbumSortOption.numSongs:
          _filteredAlbums
              .sort((a, b) => (a.numOfSongs).compareTo(b.numOfSongs));
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final loc = AppLocalizations.of(context);

    return Hero(
      tag: 'albums_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            AppBackground(
              enableAnimation: true,
              child: Container(),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: CustomScrollView(
                slivers: [
                  // Header with title
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 120,
                    floating: true,
                    pinned: false,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        loc.translate('albums'),
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          color:
                              Theme.of(context).textTheme.headlineLarge?.color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Search and filter bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // Search bar
                          glassmorphicContainer(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _filterAlbums,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: loc.translate('search_albums'),
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white70),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.white70),
                                        onPressed: () {
                                          _searchController.clear();
                                          _filterAlbums('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filter and view options
                          Row(
                            children: [
                              // Sort dropdown
                              Expanded(
                                child: glassmorphicContainer(
                                  child: PopupMenuButton<AlbumSortOption>(
                                    onSelected: (option) {
                                      setState(() {
                                        _sortOption = option;
                                      });
                                      _applySorting();
                                    },
                                    color: Colors.grey.shade900,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.sort,
                                              color: Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getSortOptionLabel(_sortOption),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down,
                                              color: Colors.white70),
                                        ],
                                      ),
                                    ),
                                    itemBuilder: (context) => [
                                      _buildSortMenuItem(
                                          AlbumSortOption.name, 'Name'),
                                      _buildSortMenuItem(
                                          AlbumSortOption.artist, 'Artist'),
                                      _buildSortMenuItem(
                                          AlbumSortOption.numSongs, 'Tracks'),
                                      _buildSortMenuItem(
                                          AlbumSortOption.year, 'Year'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ascending/Descending toggle
                              glassmorphicContainer(
                                child: IconButton(
                                  icon: Icon(
                                    _isAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isAscending = !_isAscending;
                                    });
                                    _applySorting();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Grid/List toggle
                              glassmorphicContainer(
                                child: IconButton(
                                  icon: Icon(
                                    _isGridView
                                        ? Icons.view_list
                                        : Icons.grid_view,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isGridView = !_isGridView;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Album count
                          Row(
                            children: [
                              Text(
                                '${_filteredAlbums.length} ${loc.translate('albums').toLowerCase()}',
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
                  ),
                  // Albums content
                  if (_isLoading)
                    SliverPadding(
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
                    )
                  else if (_filteredAlbums.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.album,
                                size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? loc.translate('no_albums_found')
                                  : loc.translate('no_results'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _isGridView
                        ? _buildAlbumsGrid(audioPlayerService)
                        : _buildAlbumsList(audioPlayerService),
                ],
              ),
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
            final album = _filteredAlbums[index];
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
          childCount: _filteredAlbums.length,
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
              // Album artwork
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
              // Album name
              Expanded(
                flex: 1,
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
                      '${album.artist ?? 'Unknown'} • ${album.numOfSongs} tracks',
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
            final album = _filteredAlbums[index];
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
          childCount: _filteredAlbums.length,
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
              // Album artwork with hero animation
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
              // Album info
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
                      album.artist ?? 'Unknown Artist',
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
              // Quick play button
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
      builder: (context) => Container(
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
                    child: _artworkService.buildCachedAlbumArtwork(album.id,
                        size: 50),
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
                          album.artist ?? 'Unknown',
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
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList();
    if (albumSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(albumSongs, 0);
    }
  }

  Future<void> _shuffleAlbum(AlbumModel album) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList()
      ..shuffle();
    if (albumSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(albumSongs, 0);
    }
  }

  Future<void> _addAlbumToQueue(AlbumModel album) async {
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final albumSongs = songs.where((s) => s.album == album.album).toList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${albumSongs.length} songs ready to play'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Play Now',
            onPressed: () => _playAlbum(album),
          ),
        ),
      );
    }
  }
}

enum ArtistSortOption { name, tracks, albums }

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  final TextEditingController _searchController = TextEditingController();

  List<ArtistModel> _allArtists = [];
  List<ArtistModel> _filteredArtists = [];
  Map<String, int> _artistAlbumCounts = {};
  Map<String, String?> _artistImages = {};
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
    final artists = await _audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Get album counts for each artist
    final albums = await _audioQuery.queryAlbums();
    final albumCounts = <String, int>{};
    for (final album in albums) {
      final artistName = album.artist ?? '';
      albumCounts[artistName] = (albumCounts[artistName] ?? 0) + 1;
    }

    setState(() {
      _allArtists = artists;
      _filteredArtists = artists;
      _artistAlbumCounts = albumCounts;
      _isLoading = false;
    });
    _applySorting();

    // Load artist images in the background
    _loadArtistImages();
  }

  Future<void> _loadArtistImages() async {
    for (final artist in _allArtists) {
      final imagePath =
          await _artworkService.getArtistImageByName(artist.artist);
      if (mounted && imagePath != null) {
        setState(() {
          _artistImages[artist.artist] = imagePath;
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
          return artist.artist.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
    _applySorting();
  }

  void _applySorting() {
    setState(() {
      switch (_sortOption) {
        case ArtistSortOption.name:
          _filteredArtists.sort((a, b) => a.artist.compareTo(b.artist));
          break;
        case ArtistSortOption.tracks:
          _filteredArtists.sort((a, b) =>
              (a.numberOfTracks ?? 0).compareTo(b.numberOfTracks ?? 0));
          break;
        case ArtistSortOption.albums:
          _filteredArtists.sort((a, b) => (_artistAlbumCounts[a.artist] ?? 0)
              .compareTo(_artistAlbumCounts[b.artist] ?? 0));
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

    return Hero(
      tag: 'artists_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            AppBackground(
              enableAnimation: true,
              child: Container(),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: CustomScrollView(
                slivers: [
                  // Header with title
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 120,
                    floating: true,
                    pinned: false,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        loc.translate('artists'),
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Search and filter bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // Search bar
                          glassmorphicContainer(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _filterArtists,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: loc.translate('search_artists'),
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white70),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.white70),
                                        onPressed: () {
                                          _searchController.clear();
                                          _filterArtists('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filter and view options
                          Row(
                            children: [
                              // Sort dropdown
                              Expanded(
                                child: glassmorphicContainer(
                                  child: PopupMenuButton<ArtistSortOption>(
                                    onSelected: (option) {
                                      setState(() {
                                        _sortOption = option;
                                      });
                                      _applySorting();
                                    },
                                    color: Colors.grey.shade900,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.sort,
                                              color: Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getArtistSortLabel(_sortOption),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down,
                                              color: Colors.white70),
                                        ],
                                      ),
                                    ),
                                    itemBuilder: (context) => [
                                      _buildArtistSortMenuItem(
                                          ArtistSortOption.name, 'Name'),
                                      _buildArtistSortMenuItem(
                                          ArtistSortOption.tracks, 'Tracks'),
                                      _buildArtistSortMenuItem(
                                          ArtistSortOption.albums, 'Albums'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ascending/Descending toggle
                              glassmorphicContainer(
                                child: IconButton(
                                  icon: Icon(
                                    _isAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isAscending = !_isAscending;
                                    });
                                    _applySorting();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Grid/List toggle
                              glassmorphicContainer(
                                child: IconButton(
                                  icon: Icon(
                                    _isGridView
                                        ? Icons.view_list
                                        : Icons.grid_view,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isGridView = !_isGridView;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Artist count
                          Row(
                            children: [
                              Text(
                                '${_filteredArtists.length} ${loc.translate('artists').toLowerCase()}',
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
                  ),
                  // Artists content
                  if (_isLoading)
                    SliverPadding(
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
                    )
                  else if (_filteredArtists.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person,
                                size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? loc.translate('no_artists_found')
                                  : loc.translate('no_results'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _isGridView ? _buildArtistsGrid() : _buildArtistsList(),
                ],
              ),
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

  Widget _buildArtistGridTile(ArtistModel artist) {
    final imagePath = _artistImages[artist.artist];

    return GestureDetector(
      onTap: () => _navigateToArtistDetail(artist),
      onLongPress: () => _showArtistOptions(artist),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Artist image
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
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.blue.shade400,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              artist.artist.isNotEmpty
                                  ? artist.artist[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              // Artist name
              Text(
                artist.artist,
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

  Widget _buildArtistListTile(ArtistModel artist) {
    final imagePath = _artistImages[artist.artist];
    final albumCount = _artistAlbumCounts[artist.artist] ?? 0;

    return GestureDetector(
      onTap: () => _navigateToArtistDetail(artist),
      onLongPress: () => _showArtistOptions(artist),
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Artist image with hero animation
              Hero(
                tag: 'artist_image_${artist.artist}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: imagePath != null
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.blue.shade400,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              artist.artist.isNotEmpty
                                  ? artist.artist[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Artist info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.artist,
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
              // Quick play button
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

  void _navigateToArtistDetail(ArtistModel artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(
          artistName: artist.artist,
          artistImagePath: _artistImages[artist.artist],
        ),
      ),
    );
  }

  void _showArtistOptions(ArtistModel artist) {
    final imagePath = _artistImages[artist.artist];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purple.shade400,
                            ),
                            child: Center(
                              child: Text(
                                artist.artist.isNotEmpty
                                    ? artist.artist[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.artist,
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

  Future<void> _playArtist(ArtistModel artist) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final artistSongs = songs
        .where((s) =>
            s.artist?.toLowerCase().contains(artist.artist.toLowerCase()) ??
            false)
        .toList();
    if (artistSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(artistSongs, 0);
    }
  }

  Future<void> _shuffleArtist(ArtistModel artist) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final artistSongs = songs
        .where((s) =>
            s.artist?.toLowerCase().contains(artist.artist.toLowerCase()) ??
            false)
        .toList()
      ..shuffle();
    if (artistSongs.isNotEmpty) {
      audioPlayerService.setPlaylist(artistSongs, 0);
    }
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final foldersFuture = OnAudioQuery().queryAllPath();

    return Hero(
      tag: 'folders_screen',
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            buildBackground(context, audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              appBar: buildAppBar(context, 'Folders'),
              body: FutureBuilder<List<String>>(
                future: foldersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No folders found'));
                  }

                  final folders = snapshot.data!;
                  return ListView.builder(
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16.0),
                              child: glassmorphicContainer(
                                child: ListTile(
                                  leading: const Icon(Icons.folder,
                                      color: Colors.white),
                                  title: Text(
                                    folder.split('/').last,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    folder,
                                    style: const TextStyle(color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FolderDetailScreen(
                                          folderPath: folder,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontStyle: FontStyle.normal,
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget buildBackground(BuildContext context, SongModel? currentSong) {
    return AppBackground(
      enableAnimation: true,
      child: Container(), // Empty container since this is just a background
    );
  }
}

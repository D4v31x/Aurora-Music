import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../services/artist_aggregator_service.dart';
import '../../models/separated_artist.dart';
import '../../widgets/glassmorphic_container.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/common_screen_scaffold.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../../constants/app_config.dart';
import 'artist_detail_screen.dart';
import 'folder_detail_screen.dart';
import 'album_detail_screen.dart';
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
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final loc = AppLocalizations.of(context);

    return CommonScreenScaffold(
      title: loc.translate('albums'),
      searchBar: Column(
        children: [
          // Search bar
          glassmorphicContainer(
            child: TextField(
              controller: _searchController,
              onChanged: _filterAlbums,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: loc.translate('search_albums'),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _filterAlbums('');
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
                                  color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
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
              ),
              const SizedBox(width: 8),
              // Ascending/Descending toggle
              glassmorphicContainer(
                child: IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
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
                    _isGridView ? Icons.view_list : Icons.grid_view,
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
        ],
      ),
      slivers: [
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
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
            // Remove staggered animations for better scroll performance
            return _AlbumGridTile(
              key: ValueKey(album.id),
              album: album,
              artworkService: _artworkService,
              onTap: () => _navigateToAlbumDetail(album),
              onLongPress: () => _showAlbumOptions(album),
            );
          },
          childCount: _filteredAlbums.length,
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
            // Remove staggered animations for better scroll performance
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlbumListTile(
                key: ValueKey(album.id),
                album: album,
                artworkService: _artworkService,
                onTap: () => _navigateToAlbumDetail(album),
                onLongPress: () => _showAlbumOptions(album),
                onPlay: () => _playAlbum(album),
              ),
            );
          },
          childCount: _filteredAlbums.length,
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
    // Use the aggregator service to get properly separated artists
    final artists = await _artistAggregator.getAllArtists();

    setState(() {
      _allArtists = artists;
      _filteredArtists = artists;
      _isLoading = false;
    });
    _applySorting();

    // Load artist images in the background
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
      searchBar: Column(
        children: [
          // Search bar
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
                                  color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
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
              ),
              const SizedBox(width: 8),
              // Ascending/Descending toggle
              glassmorphicContainer(
                child: IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
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
                    _isGridView ? Icons.view_list : Icons.grid_view,
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
        ],
      ),
      slivers: [
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
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          )
        else
          _isGridView ? _buildArtistsGrid() : _buildArtistsList(),
      ],
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
            // Remove staggered animations for better scroll performance
            return _ArtistGridTile(
              key: ValueKey(artist.name),
              artist: artist,
              imagePath: _artistImages[artist.name],
              onTap: () => _navigateToArtistDetail(artist),
              onLongPress: () => _showArtistOptions(artist),
            );
          },
          childCount: _filteredArtists.length,
        ),
      ),
    );
  }

  }

  Widget _buildArtistsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final artist = _filteredArtists[index];
            // Remove staggered animations for better scroll performance
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ArtistListTile(
                key: ValueKey(artist.name),
                artist: artist,
                imagePath: _artistImages[artist.name],
                onTap: () => _navigateToArtistDetail(artist),
                onLongPress: () => _showArtistOptions(artist),
                onPlay: () => _playArtist(artist),
              ),
            );
          },
          childCount: _filteredArtists.length,
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
      audioPlayerService.setPlaylist(artistSongs, 0);
    }
  }

  Future<void> _shuffleArtist(SeparatedArtist artist) async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final artistSongs = await _artistAggregator.getSongsByArtist(artist.name);
    if (artistSongs.isNotEmpty) {
      final shuffled = List<SongModel>.from(artistSongs)..shuffle();
      audioPlayerService.setPlaylist(shuffled, 0);
    }
  }
}

// Extracted Album Grid Tile Widget for Performance
class _AlbumGridTile extends StatelessWidget {
  final AlbumModel album;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AlbumGridTile({
    required Key key,
    required this.album,
    required this.artworkService,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Memoize text styles for better performance
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album artwork with RepaintBoundary
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: artworkService.buildCachedAlbumArtwork(
                            album.id,
                            size: 150,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Album info
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.album,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${splitArtists(album.artist ?? 'Unknown').join(', ')} • ${album.numOfSongs} tracks',
                        style: const TextStyle(
                          color: AppConfig.white60,
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
      ),
    );
  }
}

// Extracted Album List Tile Widget for Performance
class _AlbumListTile extends StatelessWidget {
  final AlbumModel album;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlay;

  const _AlbumListTile({
    required Key key,
    required this.album,
    required this.artworkService,
    required this.onTap,
    required this.onLongPress,
    required this.onPlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Memoize text styles
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Album artwork with Hero and RepaintBoundary
                RepaintBoundary(
                  child: Hero(
                    tag: 'album_image_${album.album}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: artworkService.buildCachedAlbumArtwork(
                        album.id,
                        size: 60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Album info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        album.album,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        splitArtists(album.artist ?? 'Unknown Artist').join(', '),
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF), // Pre-computed opacity
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${album.numOfSongs} tracks',
                        style: const TextStyle(
                          color: Color(0x80FFFFFF), // Pre-computed opacity
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick play button
                IconButton(
                  icon: const Icon(Icons.play_circle_filled,
                      color: Color(0xB3FFFFFF), size: 36),
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extracted Artist Grid Tile Widget for Performance
class _ArtistGridTile extends StatelessWidget {
  final SeparatedArtist artist;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ArtistGridTile({
    required Key key,
    required this.artist,
    required this.imagePath,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                // Artist image with RepaintBoundary
                Expanded(
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath!),
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
                ),
                const SizedBox(height: 8),
                // Artist name
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
                  style: const TextStyle(
                    color: Color(0x80FFFFFF), // Pre-computed opacity
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extracted Artist List Tile Widget for Performance
class _ArtistListTile extends StatelessWidget {
  final SeparatedArtist artist;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlay;

  const _ArtistListTile({
    required Key key,
    required this.artist,
    required this.imagePath,
    required this.onTap,
    required this.onLongPress,
    required this.onPlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final albumCount = artist.numberOfAlbums;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Artist image with Hero and RepaintBoundary
                RepaintBoundary(
                  child: Hero(
                    tag: 'artist_image_${artist.name}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath!),
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
                ),
                const SizedBox(width: 16),
                // Artist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                          const Icon(Icons.music_note,
                              size: 14, color: Color(0x99FFFFFF)),
                          const SizedBox(width: 4),
                          Text(
                            '${artist.numberOfTracks} songs',
                            style: const TextStyle(
                              color: Color(0x99FFFFFF), // Pre-computed opacity
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.album,
                              size: 14, color: Color(0x99FFFFFF)),
                          const SizedBox(width: 4),
                          Text(
                            '$albumCount albums',
                            style: const TextStyle(
                              color: Color(0x99FFFFFF), // Pre-computed opacity
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
                      color: Color(0xB3FFFFFF), size: 36),
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final foldersFuture = OnAudioQuery().queryAllPath();

    return CommonScreenScaffold(
      title: 'Folders',
      showBackButton: false,
      slivers: [
        FutureBuilder<List<String>>(
          future: foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white))),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                    child: Text('No folders found',
                        style: TextStyle(color: Colors.white))),
              );
            }

            final folders = snapshot.data!;
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final folder = folders[index];
                  // Remove staggered animations for better scroll performance
                  return RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: glassmorphicContainer(
                        child: ListTile(
                          leading:
                              const Icon(Icons.folder, color: Colors.white),
                          title: Text(
                            folder.split('/').last,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            folder,
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FolderDetailScreen(
                                  folderPath: folder,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                childCount: folders.length,
              ),
            );
          },
        ),
      ],
    );
  }
}

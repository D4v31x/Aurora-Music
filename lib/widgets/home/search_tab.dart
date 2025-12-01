import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../localization/app_localizations.dart';
import '../../services/audio_player_service.dart';
import '../../services/music_search_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../screens/Artist_screen.dart';
import '../../screens/AlbumDetailScreen.dart';
import '../../widgets/shimmer_loading.dart';

class SearchTab extends StatefulWidget {
  final List<SongModel> songs;
  final List<ArtistModel> artists;
  final List<AlbumModel>? albums;
  final bool isInitialized;

  const SearchTab({
    super.key,
    required this.songs,
    required this.artists,
    this.albums,
    required this.isInitialized,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  static final _artworkService = ArtworkCacheService();
  
  List<SongModel> _filteredSongs = [];
  List<ArtistModel> _filteredArtists = [];
  List<AlbumModel> _filteredAlbums = [];
  
  // Top results
  SongModel? _topSong;
  ArtistModel? _topArtist;
  AlbumModel? _topAlbum;
  String _topResultType = ''; // 'song', 'artist', 'album'
  
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final query = _searchController.text.trim();

      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _filteredSongs = [];
            _filteredArtists = [];
            _filteredAlbums = [];
            _topSong = null;
            _topArtist = null;
            _topAlbum = null;
            _topResultType = '';
          });
        }
        return;
      }

      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) {
    final queryLower = query.toLowerCase();
    
    // Search songs with scoring
    _filteredSongs = MusicSearchService.searchSongs(
      widget.songs,
      query,
      limit: 50,
      minScore: 10.0,
    );
    
    // Search artists with improved scoring
    _filteredArtists = _searchArtistsWithScore(widget.artists, query);
    
    // Search albums with improved scoring
    _filteredAlbums = _searchAlbumsWithScore(widget.albums ?? [], query);
    
    // Determine top result based on match quality
    _determineTopResult(queryLower);
    
    setState(() {});
  }

  List<ArtistModel> _searchArtistsWithScore(List<ArtistModel> artists, String query) {
    final queryLower = query.toLowerCase();
    
    final scored = artists.map((artist) {
      final name = artist.artist.toLowerCase();
      double score = 0;
      
      if (name == queryLower) score += 100;
      if (name.startsWith(queryLower)) score += 50;
      if (name.contains(queryLower)) score += 30;
      
      // Word match
      final words = name.split(' ');
      for (final word in words) {
        if (word == queryLower) score += 40;
        if (word.startsWith(queryLower)) score += 20;
      }
      
      return MapEntry(artist, score);
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    return scored.take(20).map((e) => e.key).toList();
  }

  List<AlbumModel> _searchAlbumsWithScore(List<AlbumModel> albums, String query) {
    final queryLower = query.toLowerCase();
    
    final scored = albums.map((album) {
      final name = album.album.toLowerCase();
      final artist = (album.artist ?? '').toLowerCase();
      double score = 0;
      
      if (name == queryLower) score += 100;
      if (name.startsWith(queryLower)) score += 50;
      if (name.contains(queryLower)) score += 30;
      if (artist.contains(queryLower)) score += 20;
      
      return MapEntry(album, score);
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    return scored.take(20).map((e) => e.key).toList();
  }

  void _determineTopResult(String query) {
    _topSong = null;
    _topArtist = null;
    _topAlbum = null;
    _topResultType = '';
    
    double bestSongScore = 0;
    double bestArtistScore = 0;
    double bestAlbumScore = 0;
    
    // Calculate best song score
    if (_filteredSongs.isNotEmpty) {
      final song = _filteredSongs.first;
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      
      if (title == query) bestSongScore = 100;
      else if (title.startsWith(query)) bestSongScore = 70;
      else if (artist == query) bestSongScore = 60;
      else if (title.contains(query)) bestSongScore = 40;
      else bestSongScore = 20;
      
      _topSong = song;
    }
    
    // Calculate best artist score
    if (_filteredArtists.isNotEmpty) {
      final artist = _filteredArtists.first;
      final name = artist.artist.toLowerCase();
      
      if (name == query) bestArtistScore = 100;
      else if (name.startsWith(query)) bestArtistScore = 80;
      else if (name.contains(query)) bestArtistScore = 50;
      else bestArtistScore = 25;
      
      _topArtist = artist;
    }
    
    // Calculate best album score
    if (_filteredAlbums.isNotEmpty) {
      final album = _filteredAlbums.first;
      final name = album.album.toLowerCase();
      
      if (name == query) bestAlbumScore = 100;
      else if (name.startsWith(query)) bestAlbumScore = 75;
      else if (name.contains(query)) bestAlbumScore = 45;
      else bestAlbumScore = 22;
      
      _topAlbum = album;
    }
    
    // Determine which is the top result
    if (bestArtistScore >= bestSongScore && bestArtistScore >= bestAlbumScore && bestArtistScore > 0) {
      _topResultType = 'artist';
    } else if (bestAlbumScore >= bestSongScore && bestAlbumScore > 0) {
      _topResultType = 'album';
    } else if (bestSongScore > 0) {
      _topResultType = 'song';
    }
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    List<SongModel> playlist = _filteredSongs;
    int initialIndex = playlist.indexWhere((s) => s.id == song.id);

    if (initialIndex >= 0) {
      audioPlayerService.setPlaylist(playlist, initialIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInitialized) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Fake search bar
            const ShimmerLoading(width: double.infinity, height: 56, borderRadius: 28),
            const SizedBox(height: 24),
            // Fake results
            const ListSkeleton(itemCount: 5),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white, fontFamily: 'ProductSans'),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'ProductSans'),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).translate('Start_type'),
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final hasResults = _filteredSongs.isNotEmpty || 
                       _filteredArtists.isNotEmpty || 
                       _filteredAlbums.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Top Result Card
        if (_topResultType.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context).translate('top_result')),
          const SizedBox(height: 8),
          _buildTopResultCard(),
          const SizedBox(height: 24),
        ],
        
        // Artists section (horizontal scroll)
        if (_filteredArtists.isNotEmpty && _topResultType != 'artist') ...[
          _buildSectionHeader(AppLocalizations.of(context).translate('artists')),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredArtists.length.clamp(0, 10),
              itemBuilder: (context, index) => _buildArtistChip(_filteredArtists[index]),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Albums section (horizontal scroll)
        if (_filteredAlbums.isNotEmpty && _topResultType != 'album') ...[
          _buildSectionHeader(AppLocalizations.of(context).translate('albums')),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredAlbums.length.clamp(0, 10),
              itemBuilder: (context, index) => _buildAlbumCard(_filteredAlbums[index]),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Songs section
        if (_filteredSongs.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context).translate('songs')),
          const SizedBox(height: 8),
          ..._filteredSongs.take(20).map((song) => _SearchSongTile(
            song: song,
            artworkService: _artworkService,
            onTap: () => _onSongTap(song),
          )),
        ],
        
        // Bottom padding for mini player + keyboard
        SizedBox(height: 100 + MediaQuery.of(context).viewInsets.bottom),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'ProductSans',
        color: Theme.of(context).textTheme.titleLarge?.color,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTopResultCard() {
    switch (_topResultType) {
      case 'artist':
        return _buildTopArtistCard(_topArtist!);
      case 'album':
        return _buildTopAlbumCard(_topAlbum!);
      case 'song':
        return _buildTopSongCard(_topSong!);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopArtistCard(ArtistModel artist) {
    return _TopArtistResultCard(
      artist: artist,
      artworkService: _artworkService,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(
              artistName: artist.artist,
              artistImagePath: null,
            ),
          ),
        );
      },
      typeLabel: AppLocalizations.of(context).translate('artists').toUpperCase(),
    );
  }

  Widget _buildTopAlbumCard(AlbumModel album) {
    return _TopResultCardWithArtwork(
      id: album.id,
      artworkService: _artworkService,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(albumName: album.album),
          ),
        );
      },
      typeLabel: AppLocalizations.of(context).translate('albums').toUpperCase(),
      title: album.album,
      subtitle: album.artist ?? '',
      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 32),
      heroTag: 'album_image_${album.album}',
    );
  }

  Widget _buildTopSongCard(SongModel song) {
    return _TopResultCardWithArtwork(
      id: song.id,
      artworkService: _artworkService,
      onTap: () => _onSongTap(song),
      typeLabel: AppLocalizations.of(context).translate('songs').toUpperCase(),
      title: song.title,
      subtitle: song.artist ?? '',
      trailing: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildArtistChip(ArtistModel artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(
              artistName: artist.artist,
              artistImagePath: null,
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Hero(
              tag: 'artist_image_${artist.artist}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: _artworkService.buildArtistImageByName(artist.artist, size: 80, circular: true),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.artist,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCard(AlbumModel album) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(albumName: album.album),
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'album_image_${album.album}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _artworkService.buildCachedAlbumArtwork(album.id, size: 130),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.album,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artist ?? '',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSongTile extends StatelessWidget {
  final SongModel song;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _SearchSongTile({
    required this.song,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: artworkService.buildCachedArtwork(song.id, size: 50),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist ?? '',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
          onPressed: () {
            // TODO: Show song options
          },
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Top result card with glassmorphic effect and color accent extraction from artwork
class _TopResultCardWithArtwork extends StatefulWidget {
  final int id;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  final String typeLabel;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? heroTag;

  const _TopResultCardWithArtwork({
    required this.id,
    required this.artworkService,
    required this.onTap,
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.heroTag,
  });

  @override
  State<_TopResultCardWithArtwork> createState() => _TopResultCardWithArtworkState();
}

class _TopResultCardWithArtworkState extends State<_TopResultCardWithArtwork> {
  Color? _dominantColor;
  Color? _accentColor;
  bool _hasArtwork = false;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(_TopResultCardWithArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    try {
      final artwork = await widget.artworkService.getArtwork(widget.id);
      if (artwork != null && artwork.isNotEmpty && mounted) {
        final imageProvider = MemoryImage(artwork);
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(100, 100),
          maximumColorCount: 8,
        );

        if (mounted) {
          setState(() {
            _hasArtwork = true;
            _dominantColor = palette.dominantColor?.color ?? palette.vibrantColor?.color;
            _accentColor = palette.vibrantColor?.color ?? 
                          palette.lightVibrantColor?.color ?? 
                          palette.mutedColor?.color;
          });
        }
      } else if (mounted) {
        setState(() {
          _hasArtwork = false;
          _dominantColor = null;
          _accentColor = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasArtwork = false;
          _dominantColor = null;
          _accentColor = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _hasArtwork && _dominantColor != null
                  ? LinearGradient(
                      colors: [
                        _dominantColor!.withOpacity(0.35),
                        (_accentColor ?? _dominantColor!).withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _hasArtwork ? null : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasArtwork && _dominantColor != null
                    ? _dominantColor!.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                widget.heroTag != null
                    ? Hero(
                        tag: widget.heroTag!,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.artworkService.buildCachedArtwork(widget.id, size: 100),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.artworkService.buildCachedArtwork(widget.id, size: 100),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasArtwork && _accentColor != null
                              ? _accentColor!.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.typeLabel,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: _hasArtwork && _accentColor != null
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top artist result card with artwork extraction for glassmorphic styling
class _TopArtistResultCard extends StatefulWidget {
  final ArtistModel artist;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  final String typeLabel;

  const _TopArtistResultCard({
    required this.artist,
    required this.artworkService,
    required this.onTap,
    required this.typeLabel,
  });

  @override
  State<_TopArtistResultCard> createState() => _TopArtistResultCardState();
}

class _TopArtistResultCardState extends State<_TopArtistResultCard> {
  Color? _dominantColor;
  Color? _accentColor;
  bool _hasArtwork = false;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(_TopArtistResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.artist != widget.artist.artist) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    try {
      final imagePath = await widget.artworkService.getArtistImageByName(widget.artist.artist);
      if (imagePath != null && mounted) {
        final imageProvider = FileImage(File(imagePath));
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(100, 100),
          maximumColorCount: 8,
        );

        if (mounted) {
          setState(() {
            _hasArtwork = true;
            _dominantColor = palette.dominantColor?.color ?? palette.vibrantColor?.color;
            _accentColor = palette.vibrantColor?.color ?? 
                          palette.lightVibrantColor?.color ?? 
                          palette.mutedColor?.color;
          });
        }
      } else if (mounted) {
        setState(() {
          _hasArtwork = false;
          _dominantColor = null;
          _accentColor = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasArtwork = false;
          _dominantColor = null;
          _accentColor = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _hasArtwork && _dominantColor != null
                  ? LinearGradient(
                      colors: [
                        _dominantColor!.withOpacity(0.35),
                        (_accentColor ?? _dominantColor!).withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _hasArtwork ? null : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasArtwork && _dominantColor != null
                    ? _dominantColor!.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'artist_image_${widget.artist.artist}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: widget.artworkService.buildArtistImageByName(
                      widget.artist.artist, 
                      size: 100, 
                      circular: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasArtwork && _accentColor != null
                              ? _accentColor!.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.typeLabel,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: _hasArtwork && _accentColor != null
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.artist.artist,
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.artist.numberOfTracks ?? 0} ${AppLocalizations.of(context).translate('songs').toLowerCase()}',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

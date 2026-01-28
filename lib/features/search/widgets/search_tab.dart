import 'dart:async';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/music_search_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/models/separated_artist.dart';
import '../../library/screens/artist_detail_screen.dart';
import '../../library/screens/album_detail_screen.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/providers/performance_mode_provider.dart';

class SearchTab extends StatefulWidget {
  final List<SongModel> songs;
  final List<SeparatedArtist> artists;
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
  List<SeparatedArtist> _filteredArtists = [];
  List<AlbumModel> _filteredAlbums = [];

  // Top results
  SongModel? _topSong;
  SeparatedArtist? _topArtist;
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
    );

    // Search artists with improved scoring
    // Search artists with improved scoring (now using SeparatedArtist)
    _filteredArtists = _searchArtistsWithScore(widget.artists, query);

    // Search albums with improved scoring
    _filteredAlbums = _searchAlbumsWithScore(widget.albums ?? [], query);

    // Determine top result based on match quality
    _determineTopResult(queryLower);

    setState(() {});
  }

  List<SeparatedArtist> _searchArtistsWithScore(
      List<SeparatedArtist> artists, String query) {
    final queryLower = query.toLowerCase();

    final scored = artists
        .map((artist) {
          final name = artist.name.toLowerCase();
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

          // Bonus for artists with more tracks
          if (score > 0) {
            score += artist.numberOfTracks * 0.1;
          }

          return MapEntry(artist, score);
        })
        .where((e) => e.value > 0)
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(20).map((e) => e.key).toList();
  }

  List<AlbumModel> _searchAlbumsWithScore(
      List<AlbumModel> albums, String query) {
    final queryLower = query.toLowerCase();

    final scored = albums
        .map((album) {
          final name = album.album.toLowerCase();
          final artist = (album.artist ?? '').toLowerCase();
          double score = 0;

          if (name == queryLower) score += 100;
          if (name.startsWith(queryLower)) score += 50;
          if (name.contains(queryLower)) score += 30;
          if (artist.contains(queryLower)) score += 20;

          return MapEntry(album, score);
        })
        .where((e) => e.value > 0)
        .toList();

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

      if (title == query) {
        bestSongScore = 100;
      } else if (title.startsWith(query))
        bestSongScore = 70;
      else if (artist == query)
        bestSongScore = 60;
      else if (title.contains(query))
        bestSongScore = 40;
      else
        bestSongScore = 20;

      _topSong = song;
    }

    // Calculate best artist score
    if (_filteredArtists.isNotEmpty) {
      final artist = _filteredArtists.first;
      final name = artist.name.toLowerCase();

      if (name == query) {
        bestArtistScore = 100;
      } else if (name.startsWith(query))
        bestArtistScore = 80;
      else if (name.contains(query))
        bestArtistScore = 50;
      else
        bestArtistScore = 25;

      _topArtist = artist;
    }

    // Calculate best album score
    if (_filteredAlbums.isNotEmpty) {
      final album = _filteredAlbums.first;
      final name = album.album.toLowerCase();

      if (name == query) {
        bestAlbumScore = 100;
      } else if (name.startsWith(query))
        bestAlbumScore = 75;
      else if (name.contains(query))
        bestAlbumScore = 45;
      else
        bestAlbumScore = 22;

      _topAlbum = album;
    }

    // Determine which is the top result
    if (bestArtistScore >= bestSongScore &&
        bestArtistScore >= bestAlbumScore &&
        bestArtistScore > 0) {
      _topResultType = 'artist';
    } else if (bestAlbumScore >= bestSongScore && bestAlbumScore > 0) {
      _topResultType = 'album';
    } else if (bestSongScore > 0) {
      _topResultType = 'song';
    }
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    final List<SongModel> playlist = _filteredSongs;
    final int initialIndex = playlist.indexWhere((s) => s.id == song.id);

    if (initialIndex >= 0) {
      audioPlayerService.setPlaylist(
        playlist,
        initialIndex,
        source: const PlaybackSourceInfo(source: PlaybackSource.search),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Fake search bar
            ShimmerLoading(height: 56, borderRadius: 28),
            SizedBox(height: 24),
            // Fake results
            ListSkeleton(),
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
            style: const TextStyle(
                color: Colors.white, fontFamily: FontConstants.fontFamily),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              hintStyle: const TextStyle(
                  color: Colors.white54, fontFamily: FontConstants.fontFamily),
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
                fontFamily: FontConstants.fontFamily,
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
            Icon(Icons.search_off,
                size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
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
          _buildSectionHeader(
              AppLocalizations.of(context).translate('top_result')),
          const SizedBox(height: 8),
          _buildTopResultCard(),
          const SizedBox(height: 24),
        ],

        // Artists section (horizontal scroll)
        if (_filteredArtists.isNotEmpty && _topResultType != 'artist') ...[
          _buildSectionHeader(
              AppLocalizations.of(context).translate('artists')),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredArtists.length.clamp(0, 10),
              itemBuilder: (context, index) =>
                  _buildArtistChip(_filteredArtists[index]),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Albums section (horizontal scroll)
        if (_filteredAlbums.isNotEmpty && _topResultType != 'album') ...[
          _buildSectionHeader(AppLocalizations.of(context).translate('albums')),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filteredAlbums.length.clamp(0, 10),
              itemBuilder: (context, index) =>
                  _buildAlbumCard(_filteredAlbums[index]),
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
        Selector<AudioPlayerService, bool>(
          selector: (_, service) => service.currentSong != null,
          builder: (context, hasCurrentSong, _) {
            final miniPlayerPadding = hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : 16.0;
            return SizedBox(
              height:
                  miniPlayerPadding + MediaQuery.of(context).viewInsets.bottom,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: FontConstants.fontFamily,
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

  Widget _buildTopArtistCard(SeparatedArtist artist) {
    return _TopArtistResultCard(
      artist: artist,
      artworkService: _artworkService,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(
              artistName: artist.name,
            ),
          ),
        );
      },
      typeLabel:
          AppLocalizations.of(context).translate('artists').toUpperCase(),
    );
  }

  Widget _buildTopAlbumCard(AlbumModel album) {
    return _TopResultCardWithArtwork(
      id: album.id,
      artworkService: _artworkService,
      isAlbum: true,
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
      trailing: Icon(Icons.chevron_right,
          color: Colors.white.withOpacity(0.5), size: 32),
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
        child:
            const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildArtistChip(SeparatedArtist artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(
              artistName: artist.name,
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
              tag: 'artist_image_${artist.name}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: _artworkService.buildArtistImageByName(artist.name,
                    size: 80, circular: true),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'album_image_${album.album}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _artworkService.buildCachedAlbumArtwork(album.id,
                    size: 130),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.album,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
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
                fontFamily: FontConstants.fontFamily,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.7),
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
          child: artworkService.buildCachedArtwork(song.id),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist ?? '',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.more_vert,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
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
/// Performance-aware: Respects device performance mode for blur effects.
class _TopResultCardWithArtwork extends HookWidget {
  final int id;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  final String typeLabel;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? heroTag;
  final bool isAlbum;

  const _TopResultCardWithArtwork({
    required this.id,
    required this.artworkService,
    required this.onTap,
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.heroTag,
    this.isAlbum = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorState =
        useState<({Color? dominant, Color? accent, bool hasArtwork})>(
      (dominant: null, accent: null, hasArtwork: false),
    );

    // Store previous id for comparison
    final prevId = usePrevious(id);

    useEffect(() {
      if (id != prevId || colorState.value.dominant == null) {
        _extractColors(colorState);
      }
      return null;
    }, [id]);

    final hasArtwork = colorState.value.hasArtwork;
    final dominantColor = colorState.value.dominant;
    final accentColor = colorState.value.accent;
    final colorScheme = Theme.of(context).colorScheme;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use solid surface colors for lowend devices
    final BoxDecoration cardDecoration;
    if (shouldBlur) {
      cardDecoration = BoxDecoration(
        gradient: hasArtwork && dominantColor != null
            ? LinearGradient(
                colors: [
                  dominantColor.withOpacity(0.35),
                  (accentColor ?? dominantColor).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasArtwork ? null : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasArtwork && dominantColor != null
              ? dominantColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.2),
        ),
      );
    } else {
      // Solid card styling for lowend devices
      cardDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Row(
        children: [
          heroTag != null
              ? Hero(
                  tag: heroTag!,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isAlbum
                        ? artworkService.buildCachedAlbumArtwork(id, size: 100)
                        : artworkService.buildCachedArtwork(id, size: 100),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isAlbum
                      ? artworkService.buildCachedAlbumArtwork(id, size: 100)
                      : artworkService.buildCachedArtwork(id, size: 100),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasArtwork && accentColor != null
                        ? accentColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: hasArtwork && accentColor != null
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
                  title,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: shouldBlur
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: cardContent,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: cardContent,
              ),
      ),
    );
  }

  Future<void> _extractColors(
    ValueNotifier<({Color? dominant, Color? accent, bool hasArtwork})>
        colorState,
  ) async {
    try {
      final artwork = isAlbum
          ? await artworkService.getAlbumArtwork(id)
          : await artworkService.getArtwork(id);
      if (artwork != null && artwork.isNotEmpty) {
        final imageProvider = MemoryImage(artwork);
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(100, 100),
          maximumColorCount: 8,
        );

        colorState.value = (
          dominant: palette.dominantColor?.color ?? palette.vibrantColor?.color,
          accent: palette.vibrantColor?.color ??
              palette.lightVibrantColor?.color ??
              palette.mutedColor?.color,
          hasArtwork: true,
        );
      } else {
        colorState.value = (dominant: null, accent: null, hasArtwork: false);
      }
    } catch (e) {
      colorState.value = (dominant: null, accent: null, hasArtwork: false);
    }
  }
}

/// Top artist result card with artwork extraction for glassmorphic styling
/// Performance-aware: Respects device performance mode for blur effects.
class _TopArtistResultCard extends HookWidget {
  final SeparatedArtist artist;
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
  Widget build(BuildContext context) {
    final colorState =
        useState<({Color? dominant, Color? accent, bool hasArtwork})>(
      (dominant: null, accent: null, hasArtwork: false),
    );

    // Store previous artist name for comparison
    final prevArtistName = usePrevious(artist.name);

    useEffect(() {
      if (artist.name != prevArtistName || colorState.value.dominant == null) {
        _extractColors(colorState);
      }
      return null;
    }, [artist.name]);

    final hasArtwork = colorState.value.hasArtwork;
    final dominantColor = colorState.value.dominant;
    final accentColor = colorState.value.accent;
    final colorScheme = Theme.of(context).colorScheme;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use solid surface colors for lowend devices
    final BoxDecoration cardDecoration;
    if (shouldBlur) {
      cardDecoration = BoxDecoration(
        gradient: hasArtwork && dominantColor != null
            ? LinearGradient(
                colors: [
                  dominantColor.withOpacity(0.35),
                  (accentColor ?? dominantColor).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasArtwork ? null : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasArtwork && dominantColor != null
              ? dominantColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.2),
        ),
      );
    } else {
      // Solid card styling for lowend devices
      cardDecoration = BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      );
    }

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Row(
        children: [
          Hero(
            tag: 'artist_image_${artist.name}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: artworkService.buildArtistImageByName(
                artist.name,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasArtwork && accentColor != null
                        ? accentColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: hasArtwork && accentColor != null
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
                  artist.name,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${artist.numberOfTracks} ${AppLocalizations.of(context).translate('songs').toLowerCase()}',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: Colors.white.withOpacity(0.5), size: 32),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: shouldBlur
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: cardContent,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: cardContent,
              ),
      ),
    );
  }

  Future<void> _extractColors(
    ValueNotifier<({Color? dominant, Color? accent, bool hasArtwork})>
        colorState,
  ) async {
    try {
      final imagePath = await artworkService.getArtistImageByName(artist.name);
      if (imagePath != null) {
        final imageProvider = FileImage(File(imagePath));
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          size: const Size(100, 100),
          maximumColorCount: 8,
        );

        colorState.value = (
          dominant: palette.dominantColor?.color ?? palette.vibrantColor?.color,
          accent: palette.vibrantColor?.color ??
              palette.lightVibrantColor?.color ??
              palette.mutedColor?.color,
          hasArtwork: true,
        );
      } else {
        colorState.value = (dominant: null, accent: null, hasArtwork: false);
      }
    } catch (e) {
      colorState.value = (dominant: null, accent: null, hasArtwork: false);
    }
  }
}

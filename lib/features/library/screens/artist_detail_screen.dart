import 'dart:io';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../shared/services/local_caching_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/detail_header.dart';
import '../../../shared/utils/responsive_utils.dart';
import 'album_detail_screen.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistName;
  final String? artistImagePath;

  const ArtistDetailsScreen({
    super.key,
    required this.artistName,
    this.artistImagePath,
  });

  @override
  _ArtistDetailsScreenState createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  Color _dominantColor = Colors.deepPurple.shade900;
  late Future<void> _colorFuture;
  final LocalCachingArtistService _artistService = LocalCachingArtistService();

  // Lazy loading state
  List<SongModel> _allSongs = [];
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 50;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  // Categories
  int _selectedCategory = 0; // 0 = Songs, 1 = Albums
  List<AlbumModel> _albums = [];
  final Map<int, List<SongModel>> _albumSongs = {};

  // Stats
  Duration _totalDuration = Duration.zero;
  String? _artistImagePath;

  @override
  void initState() {
    super.initState();
    _colorFuture = widget.artistImagePath != null
        ? _updateDominantColor()
        : _artistService
            .fetchArtistImage(widget.artistName)
            .then((path) => _updateDominantColor());
    _scrollController = ScrollController()..addListener(_scrollListener);
    _loadSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Load albums for this artist
    final allAlbums = await _audioQuery.queryAlbums(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final artistSongs = songs
        .where((song) =>
            splitArtists(song.artist ?? '').contains(widget.artistName))
        .toList();

    final artistAlbums = allAlbums
        .where((album) => album.artist?.contains(widget.artistName) ?? false)
        .toList();

    // Calculate total duration
    Duration totalDuration = Duration.zero;
    for (final song in artistSongs) {
      totalDuration += Duration(milliseconds: song.duration ?? 0);
    }

    setState(() {
      _allSongs = artistSongs;
      _albums = artistAlbums;
      _totalDuration = totalDuration;
    });

    // Group songs by album
    for (final album in _albums) {
      _albumSongs[album.id] =
          _allSongs.where((song) => song.albumId == album.id).toList();
    }

    _loadMoreSongs();

    // Load artist image if not provided
    if (widget.artistImagePath == null) {
      final imagePath =
          await _artistService.fetchArtistImage(widget.artistName);
      if (mounted && imagePath != null) {
        setState(() {
          _artistImagePath = imagePath;
        });
      }
    } else {
      _artistImagePath = widget.artistImagePath;
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

  Future<void> _updateDominantColor() async {
    if (widget.artistImagePath != null) {
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        FileImage(File(widget.artistImagePath!)),
        maximumColorCount: 8,
        size: const Size(100, 100),
      );

      setState(() {
        _dominantColor =
            paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return FutureBuilder(
      future: _colorFuture,
      builder: (context, snapshot) {
        final effectiveImagePath = widget.artistImagePath ?? _artistImagePath;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: AppBackground(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Blurred artwork header
                DetailHeader(
                  artworkFilePath: effectiveImagePath,
                  fallbackAsset: 'assets/images/UI/unknown.png',
                  title: widget.artistName,
                  metadata: _allSongs.isNotEmpty
                      ? '${_allSongs.length} ${localizations.translate('songs')} · ${_albums.length} ${localizations.translate('albums')} · ${_formatDuration(_totalDuration)}'
                      : null,
                  badge: localizations.translate('artist'),
                  heroTag: 'artist_image_${widget.artistName}',
                  accentColor: _dominantColor == Colors.deepPurple.shade900
                      ? Colors.cyan
                      : _dominantColor,
                ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            Icons.play_arrow_rounded,
                            localizations.translate('play_all'),
                            () => _playAllSongs(context),
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            Icons.shuffle_rounded,
                            localizations.translate('shuffle'),
                            () => _shuffleAllSongs(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCategoryTab(
                            '${localizations.translate('songs')} (${_allSongs.length})',
                            0,
                            Icons.music_note_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryTab(
                            '${localizations.translate('albums')} (${_albums.length})',
                            1,
                            Icons.album_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content based on selected category
                _selectedCategory == 0 ? _buildSongsList() : _buildAlbumsList(),

                // Bottom padding for mini player
                SliverToBoxAdapter(
                  child: Selector<AudioPlayerService, bool>(
                    selector: (_, service) => service.currentSong != null,
                    builder: (context, hasCurrentSong, _) {
                      return SizedBox(
                        height: hasCurrentSong
                            ? ExpandingPlayer.getMiniPlayerPaddingHeight(
                                context)
                            : 16,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(String label, int index, IconData icon) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
          _currentPage = 0;
          _displayedSongs.clear();
          if (index == 0) {
            _loadMoreSongs();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    _dominantColor.withOpacity(0.8),
                    _dominantColor.withOpacity(0.6),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _dominantColor : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsList() {
    if (_albums.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.album, size: 64, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('no_albums_found'),
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      );
    }

    final isTablet = ResponsiveUtils.isTablet(context);
    final columns = isTablet ? 4 : 2;
    final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: isTablet ? 0.9 : 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _albums.length) return null;

            final album = _albums[index];
            final albumSongs = _albumSongs[album.id] ?? [];
            final artworkSize = isTablet ? 100.0 : 120.0;

            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: columns,
              duration: const Duration(milliseconds: 200),
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AlbumDetailScreen(albumName: album.album),
                        ),
                      );
                    },
                    onLongPress: () => _showAlbumOptions(album, albumSongs),
                    child: GlassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child:
                                        _artworkService.buildCachedAlbumArtwork(
                                      album.id,
                                      size: artworkSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              album.album,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${albumSongs.length} ${albumSongs.length == 1 ? 'song' : 'songs'}',
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _albums.length,
        ),
      ),
    );
  }

  void _showAlbumOptions(AlbumModel album, List<SongModel> albumSongs) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
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
                          '${albumSongs.length} songs',
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
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle, color: Colors.white),
              title:
                  const Text('Shuffle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (albumSongs.isNotEmpty) {
                  final shuffled = List<SongModel>.from(albumSongs)..shuffle();
                  audioPlayerService.setPlaylist(
                    shuffled,
                    0,
                    source: PlaybackSourceInfo(
                      source: PlaybackSource.album,
                      name: album.album,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('View Album',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AlbumDetailScreen(albumName: album.album),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    if (_displayedSongs.isEmpty && _isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SongTileSkeleton(),
            ),
            childCount: 6,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _displayedSongs.length) {
            return _hasMoreSongs
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SongTileSkeleton(),
                  )
                : const SizedBox.shrink();
          }

          if (index >= _displayedSongs.length) return null;

          final song = _displayedSongs[index];
          final duration = Duration(milliseconds: song.duration ?? 0);
          final durationString =
              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: GestureDetector(
                    onTap: () {
                      Provider.of<AudioPlayerService>(context, listen: false)
                          .setPlaylist(
                        _allSongs,
                        _allSongs.indexWhere((s) => s.id == song.id),
                        source: PlaybackSourceInfo(
                          source: PlaybackSource.artist,
                          name: widget.artistName,
                        ),
                      );
                    },
                    child: GlassmorphicContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Track number
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Artwork
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: _artworkService
                                    .buildCachedArtwork(song.id, size: 42),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Song info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: const TextStyle(
                                      fontFamily: FontConstants.fontFamily,
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.album ?? 'Unknown Album',
                                    style: TextStyle(
                                      fontFamily: FontConstants.fontFamily,
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Duration
                            Text(
                              durationString,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                            // More
                            const SizedBox(width: 4),
                            Icon(
                              Icons.more_vert,
                              color: Colors.white.withOpacity(0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
      ),
    );
  }

  void _playAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(
        _allSongs,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.artist,
          name: widget.artistName,
        ),
      );
    }
  }

  void _shuffleAllSongs(BuildContext context) async {
    if (_allSongs.isNotEmpty) {
      final shuffledSongs = List<SongModel>.from(_allSongs)..shuffle();
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.setPlaylist(
        shuffledSongs,
        0,
        source: PlaybackSourceInfo(
          source: PlaybackSource.artist,
          name: widget.artistName,
        ),
      );
    }
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    _dominantColor.withOpacity(0.8),
                    _dominantColor.withOpacity(0.6),
                  ],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? _dominantColor : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:typed_data';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/detail_header.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/mixins/detail_screen_mixin.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen>
    with DetailScreenMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  late ValueNotifier<Color> _dominantColorNotifier;

  // Lazy loading state
  List<SongModel> _allSongs = [];
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  // Album metadata
  String? _artistName;
  Duration _totalDuration = Duration.zero;
  List<AlbumModel> _relatedAlbums = [];
  Uint8List? _artworkBytes;

  // DetailScreenMixin requirements
  @override
  Color get dominantColor => _dominantColorNotifier.value;

  @override
  List<SongModel> get allSongs => _allSongs;

  @override
  PlaybackSourceInfo get playbackSource => PlaybackSourceInfo(
        source: PlaybackSource.album,
        name: widget.albumName,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _dominantColorNotifier = ValueNotifier(Colors.deepPurple.shade900);
    _loadSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _dominantColorNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200 &&
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

    final albumSongs = songs
        .where((song) => song.album == widget.albumName)
        .toList()
      ..sort((a, b) => (a.track ?? 0).compareTo(b.track ?? 0));

    // Get album metadata
    String? artistName;
    Duration totalDuration = Duration.zero;

    if (albumSongs.isNotEmpty) {
      artistName = albumSongs.first.artist;
      for (final song in albumSongs) {
        totalDuration += Duration(milliseconds: song.duration ?? 0);
      }
    }

    // Get related albums from same artist
    final allAlbums = await _audioQuery.queryAlbums();
    final related = allAlbums
        .where((album) =>
            album.artist == artistName && album.album != widget.albumName)
        .toList();

    setState(() {
      _allSongs = albumSongs;
      _artistName = artistName;
      _totalDuration = totalDuration;
      _relatedAlbums = related;
    });

    _loadMoreSongs();
    _updateDominantColor();
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
    if (_allSongs.isNotEmpty) {
      final artwork = await _artworkService.getArtwork(_allSongs.first.id);
      if (artwork != null) {
        setState(() {
          _artworkBytes = artwork;
        });

        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          MemoryImage(artwork),
          maximumColorCount: 8,
        );

        _dominantColorNotifier.value =
            paletteGenerator.dominantColor?.color ?? Colors.deepPurple.shade900;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ValueListenableBuilder<Color>(
        valueListenable: _dominantColorNotifier,
        builder: (context, dominantColor, _) {
          if (_displayedSongs.isEmpty && _isLoading) {
            return AppBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: DetailHeaderSkeleton(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const ListSkeleton(),
                  ],
                ),
              ),
            );
          }

          return AppBackground(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Blurred artwork header
                DetailHeader(
                  artworkBytes: _artworkBytes,
                  title: widget.albumName,
                  subtitle: _artistName,
                  metadata: _allSongs.isNotEmpty
                      ? '${_allSongs.length} ${localizations.translate('songs')} · ${formatDuration(_totalDuration)}'
                      : null,
                  badge: localizations.translate('album'),
                  heroTag: 'album_image_${widget.albumName}',
                  accentColor: dominantColor == Colors.deepPurple.shade900
                      ? Colors.cyan
                      : dominantColor,
                ),

                // Action row (play, search, shuffle)
                SliverToBoxAdapter(
                  child: _buildActionRow(localizations),
                ),

                // Songs list
                _buildSongsList(),

                // Related albums section
                if (_relatedAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        'More from $_artistName',
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _relatedAlbums.length,
                        itemBuilder: (context, index) {
                          final album = _relatedAlbums[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AlbumDetailScreen(
                                      albumName: album.album,
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 130,
                                child: GlassmorphicContainer(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: _artworkService
                                              .buildCachedAlbumArtwork(
                                            album.id,
                                            size: 100,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          album.album,
                                          style: const TextStyle(
                                            fontFamily:
                                                FontConstants.fontFamily,
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Bottom padding for mini player
                buildMiniPlayerPadding(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionRow(AppLocalizations localizations) {
    final color = dominantColor == Colors.deepPurple.shade900
        ? Colors.blue
        : dominantColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: playAllSongs,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Search field placeholder
          Expanded(
            child: GlassmorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localizations.translate('search_tracks'),
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Shuffle button
          GestureDetector(
            onTap: shuffleAllSongs,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shuffle_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _displayedSongs.length) {
            return _hasMoreSongs
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Provider.of<AudioPlayerService>(context, listen: false)
                          .setPlaylist(_allSongs, index);
                    },
                    onLongPress: () => _showSongOptions(song),
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
                            // Song info
                            Expanded(
                              child: Text(
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
                            // More options
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showSongOptions(song),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
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

  void _showSongOptions(SongModel song) {
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
                    child: _artworkService.buildCachedArtwork(song.id),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          splitArtists(song.artist ?? 'Unknown').join(', '),
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
                final songIndex = _allSongs.indexWhere((s) => s.id == song.id);
                if (songIndex >= 0) {
                  audioPlayerService.setPlaylist(_allSongs, songIndex);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white),
              title: Text(AppLocalizations.of(context).translate('play_next'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await audioPlayerService.playNext(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${song.title} will play next'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: Text(
                  AppLocalizations.of(context).translate('add_to_queue'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await audioPlayerService.addToQueue(song);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${song.title} added to queue'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

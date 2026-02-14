import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/local_caching_service.dart';
import '../../../shared/widgets/unified_detail_screen.dart';
import '../../../l10n/app_localizations.dart';
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
  final LocalCachingArtistService _artistService = LocalCachingArtistService();

  List<SongModel> _allSongs = [];
  List<AlbumModel> _albums = [];
  final Map<int, List<SongModel>> _albumSongs = {};
  Duration _totalDuration = Duration.zero;
  Color _accentColor = Colors.deepPurple.shade900;
  String? _artistImagePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _artistImagePath = widget.artistImagePath;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_artistImagePath == null) {
      final imagePath =
          await _artistService.fetchArtistImage(widget.artistName);
      if (mounted && imagePath != null) {
        setState(() => _artistImagePath = imagePath);
      }
    }

    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

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

    Duration totalDuration = Duration.zero;
    for (final song in artistSongs) {
      totalDuration += Duration(milliseconds: song.duration ?? 0);
    }

    for (final album in artistAlbums) {
      _albumSongs[album.id] =
          artistSongs.where((song) => song.albumId == album.id).toList();
    }

    setState(() {
      _allSongs = artistSongs;
      _albums = artistAlbums;
      _totalDuration = totalDuration;
      _isLoading = false;
    });

    _updateAccentColor();
  }

  Future<void> _updateAccentColor() async {
    final imagePath = _artistImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      try {
        final paletteGenerator = await PaletteGenerator.fromImageProvider(
          FileImage(File(imagePath)),
          maximumColorCount: 8,
          size: const Size(100, 100),
        );
        if (mounted) {
          setState(() {
            _accentColor = paletteGenerator.dominantColor?.color ??
                Colors.deepPurple.shade900;
          });
        }
      } catch (_) {}
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return UnifiedDetailScreen(
      config: DetailScreenConfig(
        type: DetailScreenType.artist,
        title: widget.artistName,
        playbackSource: PlaybackSourceInfo(
          source: PlaybackSource.artist,
          name: widget.artistName,
        ),
        heroTag: 'artist_image_${widget.artistName}',
        accentColor: _accentColor,
        stats: [
          DetailStat(
            icon: Icons.music_note_rounded,
            value: '${_allSongs.length}',
            label: localizations.translate('songs'),
          ),
          DetailStat(
            icon: Icons.album_rounded,
            value: '${_albums.length}',
            label: localizations.translate('albums'),
          ),
          DetailStat(
            icon: Icons.timer_outlined,
            value: _formatDuration(_totalDuration),
            label: localizations.translate('total'),
          ),
        ],
        tabLabels: [
          localizations.translate('songs'),
          localizations.translate('albums'),
        ],
        tabSlivers: [
          // Index 0: Songs — handled automatically by UnifiedDetailScreen
          [],
          // Index 1: Albums grid
          [_buildAlbumsGrid(isDark)],
        ],
      ),
      songs: _allSongs,
      headerArtwork: _buildArtistImage(),
      isLoading: _isLoading,
    );
  }

  Widget _buildArtistImage() {
    final imagePath = _artistImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        width: 140,
        height: 140,
      );
    }
    return Image.asset(
      'assets/images/UI/unknown.png',
      fit: BoxFit.cover,
      width: 140,
      height: 140,
    );
  }

  Widget _buildAlbumsGrid(bool isDark) {
    if (_albums.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.album_rounded,
                  size: 56,
                  color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('no_albums_found'),
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = _albums[index];
            final albumSongs = _albumSongs[album.id] ?? [];

            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
              duration: const Duration(milliseconds: 200),
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AlbumDetailScreen(albumName: album.album),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
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
                                      size: 120,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              album.album,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: isDark ? Colors.white : Colors.black87,
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
                                color: isDark ? Colors.white54 : Colors.black45,
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
}

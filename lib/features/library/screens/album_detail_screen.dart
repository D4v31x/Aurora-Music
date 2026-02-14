import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/unified_detail_screen.dart';
import '../../../l10n/app_localizations.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  List<SongModel> _allSongs = [];
  String? _artistName;
  Duration _totalDuration = Duration.zero;
  List<AlbumModel> _relatedAlbums = [];
  Color _accentColor = Colors.deepPurple.shade900;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final songs = await _audioQuery.querySongs(
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final albumSongs = songs
        .where((song) => song.album == widget.albumName)
        .toList()
      ..sort((a, b) => (a.track ?? 0).compareTo(b.track ?? 0));

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
      _isLoading = false;
    });

    _updateAccentColor();
  }

  Future<void> _updateAccentColor() async {
    if (_allSongs.isNotEmpty) {
      final artwork = await _artworkService.getArtwork(_allSongs.first.id);
      if (artwork != null) {
        try {
          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            MemoryImage(artwork),
            maximumColorCount: 8,
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
        type: DetailScreenType.album,
        title: widget.albumName,
        subtitle: _artistName,
        playbackSource: PlaybackSourceInfo(
          source: PlaybackSource.album,
          name: widget.albumName,
        ),
        heroTag: 'album_image_${widget.albumName}',
        accentColor: _accentColor,
        stats: [
          DetailStat(
            icon: Icons.music_note_rounded,
            value: '${_allSongs.length}',
            label: localizations.translate('songs'),
          ),
          DetailStat(
            icon: Icons.timer_outlined,
            value: _formatDuration(_totalDuration),
            label: localizations.translate('total'),
          ),
        ],
        extraSlivers: [
          // Related albums section
          if (_relatedAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  '${localizations.translate('more_from_artist')}',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white : Colors.black87,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        _artworkService.buildCachedAlbumArtwork(
                                      album.id,
                                      size: 100,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    album.album,
                                    style: TextStyle(
                                      fontFamily: FontConstants.fontFamily,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
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
        ],
      ),
      songs: _allSongs,
      headerArtwork: _allSongs.isNotEmpty
          ? _artworkService.buildCachedArtwork(_allSongs.first.id, size: 140)
          : null,
      isLoading: _isLoading,
    );
  }
}

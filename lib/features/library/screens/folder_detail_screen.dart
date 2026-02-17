import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/detail_header.dart';
import '../../../shared/mixins/detail_screen_mixin.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderPath;

  const FolderDetailScreen({super.key, required this.folderPath});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen>
    with DetailScreenMixin {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  final Color _dominantColor = Colors.deepPurple.shade900;

  // Lazy loading state
  List<SongModel> _allSongs = [];
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  Uint8List? _artworkBytes;

  // DetailScreenMixin requirements
  @override
  Color get dominantColor => _dominantColor;

  @override
  List<SongModel> get allSongs => _allSongs;

  @override
  PlaybackSourceInfo get playbackSource => PlaybackSourceInfo(
        source: PlaybackSource.folder,
        name: widget.folderPath.split('/').last,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _fetchSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSongs() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final allSongs = audioPlayerService.songs;

    final folderSongs = allSongs.where((song) {
      final songFile = File(song.data);
      return songFile.parent.path == widget.folderPath;
    }).toList();

    setState(() {
      _allSongs = folderSongs;
    });

    _loadMoreSongs();
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    if (_allSongs.isNotEmpty) {
      final artwork = await _artworkService.getArtwork(_allSongs.first.id);
      if (mounted && artwork != null) {
        setState(() {
          _artworkBytes = artwork;
        });
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;

    // Calculate total duration
    Duration totalDuration = Duration.zero;
    for (final song in _allSongs) {
      totalDuration += Duration(milliseconds: song.duration ?? 0);
    }

    return Scaffold(
      body: AppBackground(
        child: _displayedSongs.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Blurred artwork header
                  DetailHeader(
                    artworkBytes: _artworkBytes,
                    title: folderName,
                    metadata: _allSongs.isNotEmpty
                        ? '${_allSongs.length} ${localizations.translate('songs')} · ${formatDuration(totalDuration)}'
                        : null,
                    badge: localizations.translate('folder'),
                    heroTag: 'folder_icon_${widget.folderPath}',
                    accentColor: Colors.amber,
                  ),

                  // Action buttons
                  SliverToBoxAdapter(
                    child: buildActionButtonsRow(),
                  ),

                  // Songs list
                  _buildSongsList(),

                  // Bottom padding for mini player
                  buildMiniPlayerPadding(),
                ],
              ),
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
                      horizontal: 16.0, vertical: 4.0),
                  child: GestureDetector(
                    onTap: () {
                      final songIndex =
                          _allSongs.indexWhere((s) => s.id == song.id);
                      if (songIndex >= 0) {
                        Provider.of<AudioPlayerService>(context, listen: false)
                            .setPlaylist(
                          _allSongs,
                          songIndex,
                          source: playbackSource,
                        );
                      }
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
                                    splitArtists(song.artist ??
                                            AppLocalizations.of(context)
                                                .translate('unknown_artist'))
                                        .join(', '),
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
}

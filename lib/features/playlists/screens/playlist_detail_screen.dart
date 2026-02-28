import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/playlist_model.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/song_picker_sheet.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/detail_header.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/models/artist_utils.dart';
import 'dart:typed_data';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late ScrollController _scrollController;
  late TextEditingController _nameController;
  final ValueNotifier<bool> _isEditingNotifier = ValueNotifier<bool>(false);

  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 30;
  bool _isLoading = false;
  bool _hasMoreSongs = true;

  Uint8List? _artworkBytes;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _nameController = TextEditingController(text: widget.playlist.name);
    _loadMoreSongs();
    _loadArtwork();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _nameController.dispose();
    _isEditingNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 300 &&
        !_isLoading &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
  }

  void _loadMoreSongs() {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final int startIndex = _currentPage * _songsPerPage;
    final int endIndex =
        (startIndex + _songsPerPage).clamp(0, widget.playlist.songs.length);

    if (startIndex < widget.playlist.songs.length) {
      final newSongs = widget.playlist.songs.sublist(startIndex, endIndex);
      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoading = false;
        _hasMoreSongs = endIndex < widget.playlist.songs.length;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasMoreSongs = false;
      });
    }
  }

  void _refreshSongs() {
    setState(() {
      _displayedSongs.clear();
      _currentPage = 0;
      _hasMoreSongs = true;
    });
    _loadMoreSongs();
  }

  Future<void> _loadArtwork() async {
    // Load artwork from first song if available
    if (widget.playlist.songs.isNotEmpty && !_isAutoPlaylist) {
      final artwork =
          await _artworkService.getArtwork(widget.playlist.songs.first.id);
      if (mounted && artwork != null) {
        setState(() {
          _artworkBytes = artwork;
        });
      }
    }
  }

  bool get _isAutoPlaylist =>
      widget.playlist.id == 'liked_songs' ||
      widget.playlist.id == 'most_played' ||
      widget.playlist.id == 'recently_added';

  String? get _playlistAssetImage {
    if (widget.playlist.id == 'liked_songs') {
      return 'assets/images/UI/liked.png';
    } else if (widget.playlist.id == 'recently_added') {
      return 'assets/images/UI/recentlyadded.png';
    } else if (widget.playlist.id == 'most_played') {
      return 'assets/images/UI/mostplayed.png';
    }
    return null;
  }

  Color _getPlaylistColor(String playlistId) {
    switch (playlistId) {
      case 'liked_songs':
        return Colors.pink;
      case 'most_played':
        return Colors.orange;
      case 'recently_added':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return Selector<AudioPlayerService, Playlist>(
      selector: (context, audioService) => audioService.playlists.firstWhere(
        (p) => p.id == widget.playlist.id,
        orElse: () => widget.playlist,
      ),
      builder: (context, updatedPlaylist, _) {
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);

        // Calculate total duration
        Duration totalDuration = Duration.zero;
        for (final song in updatedPlaylist.songs) {
          totalDuration += Duration(milliseconds: song.duration ?? 0);
        }

        final durationStr = _formatDuration(totalDuration);

        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Blurred artwork header
                DetailHeader(
                  artworkBytes: _artworkBytes,
                  fallbackAsset: _playlistAssetImage,
                  title: updatedPlaylist.name,
                  metadata:
                      '${updatedPlaylist.songs.length} ${localizations.translate('tracks')} · $durationStr',
                  badge: localizations.translate('playlist'),
                  heroTag: 'playlist_${updatedPlaylist.id}',
                  accentColor: _getPlaylistColor(updatedPlaylist.id),
                  actions: [
                    if (!_isAutoPlaylist)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: () =>
                              _showPlaylistOptions(context, updatedPlaylist),
                          child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),

                // Action buttons
                SliverToBoxAdapter(
                  child: _buildActionRow(
                    context,
                    audioService,
                    updatedPlaylist,
                    isDark,
                    localizations,
                  ),
                ),

                // Songs List
                _buildSongsList(updatedPlaylist, audioService, isDark),

                // Bottom Padding
                SliverToBoxAdapter(
                  child: Selector<AudioPlayerService, bool>(
                    selector: (_, service) => service.currentSong != null,
                    builder: (context, hasCurrentSong, _) {
                      return SizedBox(
                        height: hasCurrentSong
                            ? ExpandingPlayer.getMiniPlayerPaddingHeight(
                                context)
                            : 24,
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildActionRow(
    BuildContext context,
    AudioPlayerService audioService,
    Playlist playlist,
    bool isDark,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final color = _getPlaylistColor(playlist.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play Button
          Expanded(
            child: GestureDetector(
              onTap: playlist.songs.isEmpty
                  ? null
                  : () => audioService.setPlaylist(
                        playlist.songs,
                        0,
                        source: PlaybackSourceInfo(
                          source: PlaybackSource.playlist,
                          name: playlist.name,
                        ),
                      ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: playlist.songs.isEmpty
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: playlist.songs.isNotEmpty
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        localizations.translate('play_all'),
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Shuffle Button
          Expanded(
            child: GestureDetector(
              onTap: playlist.songs.isEmpty
                  ? null
                  : () {
                      final shuffled = List.of(playlist.songs)..shuffle();
                      audioService.setPlaylist(
                        shuffled,
                        0,
                        source: PlaybackSourceInfo(
                          source: PlaybackSource.playlist,
                          name: playlist.name,
                        ),
                      );
                    },
              child: GlassmorphicContainer(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shuffle_rounded,
                      color: playlist.songs.isEmpty
                          ? Colors.white30
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        localizations.translate('shuffle'),
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: playlist.songs.isEmpty
                              ? Colors.white30
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_isAutoPlaylist) ...[
            const SizedBox(width: 10),
            // Add Button
            GestureDetector(
              onTap: () async {
                await SongPickerSheet.show(context, playlist);
                _refreshSongs();
                _loadArtwork(); // Refresh artwork after adding songs
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.4),
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: color,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSongsList(
    Playlist playlist,
    AudioPlayerService audioService,
    bool isDark,
  ) {
    if (playlist.songs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(isDark),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _displayedSongs.length) {
            return _hasMoreSongs
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final song = _displayedSongs[index];
          final isPlaying = audioService.currentSong?.id == song.id;
          final duration = Duration(milliseconds: song.duration ?? 0);
          final durationString =
              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 20.0,
              child: FadeInAnimation(
                child: _buildSongTile(
                  context,
                  song,
                  index,
                  isPlaying,
                  isDark,
                  audioService,
                  playlist,
                  durationString,
                ),
              ),
            ),
          );
        },
        childCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
      ),
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    SongModel song,
    int index,
    bool isPlaying,
    bool isDark,
    AudioPlayerService audioService,
    Playlist playlist,
    String durationString,
  ) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(song.id),
      direction:
          _isAutoPlaylist ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withOpacity(0.15),
        child: Icon(Icons.delete_rounded, color: Colors.red.withOpacity(0.8)),
      ),
      confirmDismiss: (_) async {
        if (!_isAutoPlaylist) {
          _removeSong(context, audioService, song, playlist);
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          // Find the correct index by song ID to handle dynamic playlist updates
          final songIndex = playlist.songs.indexWhere((s) => s.id == song.id);
          audioService.setPlaylist(
            playlist.songs,
            songIndex >= 0 ? songIndex : 0,
            source: PlaybackSourceInfo(
              source: PlaybackSource.playlist,
              name: playlist.name,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GlassmorphicContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Index
                  SizedBox(
                    width: 32,
                    child: isPlaying
                        ? Icon(
                            Icons.equalizer_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: isPlaying
                                ? theme.colorScheme.primary
                                : Colors.white,
                            fontSize: 15,
                            fontWeight:
                                isPlaying ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          splitArtists(song.artist ?? 'Unknown').join(', '),
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
                  // More button
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
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.translate('no_songs_in_playlist'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 15,
            ),
          ),
          if (!_isAutoPlaylist) ...[
            const SizedBox(height: 6),
            Text(
              localizations.translate('tap_add_to_add_songs'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _removeSong(
    BuildContext context,
    AudioPlayerService audioService,
    SongModel song,
    Playlist playlist,
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.translate('remove_song'),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.translate('remove_song_confirmation'),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            localizations.translate('cancel'),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            playlist.songs.remove(song);
                            audioService.savePlaylists();
                            _refreshSongs();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.translate('remove'),
                                style: const TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                        )
                  ),
                ],
              ),
                ],
          )
        )));
  }

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Playlist name
                Text(
                  playlist.name,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Rename
                _buildOptionTile(
                  context,
                  Icons.edit_rounded,
                  localizations.translate('rename'),
                  isDark,
                  () {
                    Navigator.pop(context);
                    _isEditingNotifier.value = true;
                  },
                ),
                // Delete
                _buildOptionTile(
                  context,
                  Icons.delete_outline_rounded,
                  localizations.translate('delete'),
                  isDark,
                  () {
                    Navigator.pop(context);
                    _confirmDeletePlaylist(context, playlist);
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Colors.red
                  : (isDark ? Colors.white70 : Colors.black54),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDestructive
                    ? Colors.red
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, Playlist playlist) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.withOpacity(0.8),
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    localizations.translate('delete_playlist'),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.translate('delete_playlist_confirmation'),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            localizations.translate('cancel'),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final audioService =
                                Provider.of<AudioPlayerService>(context,
                                    listen: false);
                            audioService.deletePlaylist(widget.playlist);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.translate('delete'),
                                style: const TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                        ),
                  ),
                ],
              ),
                ],
          ),
        ),
      ),
    );
  }
}

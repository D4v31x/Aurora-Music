import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/playlist_model.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/song_picker_sheet.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/detail_header.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/song_context_menu.dart';
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

  String _autoPlaylistName(AppLocalizations loc, String id) {
    switch (id) {
      case 'most_played':
        return loc.mostPlayed;
      case 'recently_added':
        return loc.recentlyAdded;
      default:
        return widget.playlist.name;
    }
  }

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
                  title: _isAutoPlaylist
                      ? _autoPlaylistName(localizations, updatedPlaylist.id)
                      : updatedPlaylist.name,
                  metadata:
                      '${updatedPlaylist.songs.length} ${localizations.tracks} · $durationStr',
                  badge: localizations.playlist,
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
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Iconoir.MoreVert(
                                  color: Colors.white,
                                  width: 20,
                                  height: 20,
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
              // Play Button — always expanded with full label
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
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: playlist.songs.isNotEmpty
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
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
                        const Iconoir.Play(color: Colors.white, width: 22, height: 22),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            localizations.playAll,
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
              // Shuffle Button — always icon-only
              GestureDetector(
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
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  child: Iconoir.Shuffle(
                    color: playlist.songs.isEmpty ? Colors.white30 : Colors.white,
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Queue Button — always icon-only
              GestureDetector(
                onTap: playlist.songs.isEmpty
                    ? null
                    : () async {
                        await audioService.addMultipleToQueue(playlist.songs);
                        if (context.mounted) {
                          NotificationManager.showMessage(
                            context,
                            AppLocalizations.of(context).songsAddedToQueue(playlist.songs.length),
                          );
                        }
                      },
                child: GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  child: Iconoir.Playlist(
                    color: playlist.songs.isEmpty ? Colors.white30 : Colors.white,
                    width: 22,
                    height: 22,
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
                    unawaited(_loadArtwork());
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Iconoir.PlusCircle(
                      color: color,
                      width: 24,
                      height: 24,
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
        color: Colors.red.withValues(alpha: 0.15),
        child: Iconoir.Trash(color: Colors.red.withValues(alpha: 0.8), width: 24, height: 24),
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
        onLongPress: () => showSongContextMenu(context, song),
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
                        ? Iconoir.SoundHigh(
                            color: theme.colorScheme.primary,
                            width: 18,
                            height: 18,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: Colors.white.withValues(alpha: 0.5),
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
                            color: Colors.white.withValues(alpha: 0.5),
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
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  // More button
                  const SizedBox(width: 4),
                  Iconoir.MoreVert(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 20,
                    height: 20,
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
          Iconoir.MusicNote(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 56,
            height: 56,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.noSongsInPlaylist,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 15,
            ),
          ),
          if (!_isAutoPlaylist) ...[
            const SizedBox(height: 6),
            Text(
              localizations.tapAddToAddSongs,
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
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.removeSong,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.removeSongConfirmation,
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
                            localizations.cancel,
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
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.remove,
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
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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
                  Iconoir.Edit(
                    color: isDark ? Colors.white70 : Colors.black54,
                    width: 22,
                    height: 22,
                  ),
                  localizations.rename,
                  isDark,
                  () {
                    Navigator.pop(context);
                    _isEditingNotifier.value = true;
                  },
                ),
                // Delete
                _buildOptionTile(
                  context,
                  const Iconoir.Trash(
                    color: Colors.red,
                    width: 22,
                    height: 22,
                  ),
                  localizations.delete,
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
    Widget icon,
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
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            icon,
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
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Iconoir.Trash(
                    color: Colors.red.withValues(alpha: 0.8),
                    width: 44,
                    height: 44,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    localizations.deletePlaylist,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.deletePlaylistConfirmation,
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
                            localizations.cancel,
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
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.delete,
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

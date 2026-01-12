import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../models/playlist_model.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/expanding_player.dart';
import '../../widgets/song_picker_sheet.dart';
import '../../widgets/app_background.dart';
import '../../models/utils.dart';
import 'dart:ui';

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
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _nameController = TextEditingController(text: widget.playlist.name);
    _loadMoreSongs();
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
    if (_scrollController.hasClients) {
      final isScrolled = _scrollController.offset > 180;
      if (isScrolled != _isScrolled) {
        setState(() => _isScrolled = isScrolled);
      }
    }

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

  bool get _isAutoPlaylist =>
      widget.playlist.id == 'liked_songs' ||
      widget.playlist.id == 'most_played' ||
      widget.playlist.id == 'recently_added';

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

        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Header
                _buildHeader(updatedPlaylist, context, isDark, localizations),

                // Action Buttons
                SliverToBoxAdapter(
                  child: _buildActionRow(
                    context,
                    audioService,
                    updatedPlaylist,
                    isDark,
                    localizations,
                  ),
                ),

                // Song Count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '${updatedPlaylist.songs.length} ${localizations.translate('tracks')}',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13,
                      ),
                    ),
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

  Widget _buildHeader(
    Playlist playlist,
    BuildContext context,
    bool isDark,
    AppLocalizations localizations,
  ) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 260,
      floating: false,
      pinned: true,
      centerTitle: true,
      title: _isScrolled
          ? Text(
              playlist.name,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      leading: _buildGlassButton(
        context,
        Icons.arrow_back,
        () => Navigator.pop(context),
        isDark,
      ),
      actions: [
        if (!_isAutoPlaylist)
          _buildGlassButton(
            context,
            Icons.more_vert,
            () => _showPlaylistOptions(context, playlist),
            isDark,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _isScrolled ? 20 : 0,
            sigmaY: _isScrolled ? 20 : 0,
          ),
          child: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient Background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _getPlaylistColor(playlist.id),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Artwork
                          Hero(
                            tag: 'playlist_${playlist.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: _buildPlaylistArtwork(playlist),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Name
                          ValueListenableBuilder<bool>(
                            valueListenable: _isEditingNotifier,
                            builder: (context, isEditing, _) {
                              if (isEditing && !_isAutoPlaylist) {
                                return _buildNameEditor(context, isDark);
                              }
                              return GestureDetector(
                                onTap: _isAutoPlaylist
                                    ? null
                                    : () => _isEditingNotifier.value = true,
                                child: Text(
                                  playlist.name,
                                  style: TextStyle(
                                    fontFamily: FontConstants.fontFamily,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameEditor(BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  onSubmitted: (_) => _saveNewName(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _saveNewName(context),
                child: Icon(
                  Icons.check_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveNewName(BuildContext context) {
    if (_nameController.text.isNotEmpty &&
        _nameController.text != widget.playlist.name) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      audioService.renamePlaylist(widget.playlist.id, _nameController.text);
    } else {
      _nameController.text = widget.playlist.name;
    }
    _isEditingNotifier.value = false;
    FocusScope.of(context).unfocus();
  }

  Widget _buildActionRow(
    BuildContext context,
    AudioPlayerService audioService,
    Playlist playlist,
    bool isDark,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: playlist.songs.isEmpty
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white
                              .withOpacity(playlist.songs.isEmpty ? 0.04 : 0.08)
                          : Colors.black.withOpacity(
                              playlist.songs.isEmpty ? 0.02 : 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          color: playlist.songs.isEmpty
                              ? (isDark ? Colors.white30 : Colors.black26)
                              : (isDark ? Colors.white : Colors.black87),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            localizations.translate('shuffle'),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: playlist.songs.isEmpty
                                  ? (isDark ? Colors.white30 : Colors.black26)
                                  : (isDark ? Colors.white : Colors.black87),
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
            ),
          ),
          if (!_isAutoPlaylist) ...[
            const SizedBox(width: 10),
            // Add Button
            GestureDetector(
              onTap: () async {
                await SongPickerSheet.show(context, playlist);
                _refreshSongs();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 22,
                    ),
                  ),
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
        onTap: () => audioService.setPlaylist(playlist.songs, index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: isPlaying
                ? theme.colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Index
                SizedBox(
                  width: 26,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isPlaying
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontSize: 13,
                    ),
                  ),
                ),
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child:
                        _artworkService.buildCachedArtwork(song.id, size: 46),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
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
                              : (isDark ? Colors.white : Colors.black87),
                          fontSize: 14,
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
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Playing Indicator
                if (isPlaying)
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.equalizer_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
              ],
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

  Widget _buildPlaylistArtwork(Playlist playlist) {
    String? imagePath;
    if (playlist.id == 'liked_songs') {
      imagePath = 'assets/images/UI/liked.png';
    } else if (playlist.id == 'recently_added') {
      imagePath = 'assets/images/UI/recentlyadded.png';
    } else if (playlist.id == 'most_played') {
      imagePath = 'assets/images/UI/mostplayed.png';
    }

    if (imagePath != null) {
      return Image.asset(imagePath, fit: BoxFit.cover);
    }

    if (playlist.songs.isNotEmpty) {
      return _artworkService.buildCachedArtwork(playlist.songs.first.id,
          size: 130);
    }

    return _buildDefaultArtwork();
  }

  Widget _buildDefaultArtwork() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.7),
            Colors.blue.withOpacity(0.7),
          ],
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 50),
      ),
    );
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                ),
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
              ),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.7)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                ),
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
        ),
      ),
    );
  }
}

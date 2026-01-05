import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/playlist_model.dart';
import '../../widgets/common_screen_scaffold.dart';
import '../../widgets/glassmorphic_card.dart';
import 'playlist_detail_screen.dart';
import 'dart:ui';

/// Data class to hold playlist-related state for efficient rebuilds
class _PlaylistsState {
  final Playlist? likedPlaylist;
  final List<Playlist> autoPlaylists;
  final List<Playlist> userPlaylists;

  const _PlaylistsState({
    required this.likedPlaylist,
    required this.autoPlaylists,
    required this.userPlaylists,
  });

  static _PlaylistsState fromService(AudioPlayerService service) {
    final likedPlaylist = service.likedSongsPlaylist;
    final autoPlaylists = service.playlists
        .where((p) => p.id == 'most_played' || p.id == 'recently_added')
        .toList();
    final userPlaylists = service.playlists
        .where((p) =>
            p.id != 'most_played' &&
            p.id != 'recently_added' &&
            p.id != 'liked_songs')
        .toList();
    return _PlaylistsState(
      likedPlaylist: likedPlaylist,
      autoPlaylists: autoPlaylists,
      userPlaylists: userPlaylists,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PlaylistsState &&
          likedPlaylist?.songs.length == other.likedPlaylist?.songs.length &&
          autoPlaylists.length == other.autoPlaylists.length &&
          userPlaylists.length == other.userPlaylists.length;

  @override
  int get hashCode =>
      (likedPlaylist?.songs.length ?? 0).hashCode ^
      autoPlaylists.length.hashCode ^
      userPlaylists.length.hashCode;
}

class PlaylistsScreenList extends StatefulWidget {
  const PlaylistsScreenList({super.key});

  @override
  State<PlaylistsScreenList> createState() => _PlaylistsScreenListState();
}

class _PlaylistsScreenListState extends State<PlaylistsScreenList> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    // Use Selector to only rebuild when playlists actually change
    return Selector<AudioPlayerService, _PlaylistsState>(
      selector: (_, service) => _PlaylistsState.fromService(service),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, state, _) {
        final audioService = context.read<AudioPlayerService>();
        final likedPlaylist = state.likedPlaylist;
        final autoPlaylists = state.autoPlaylists;
        final userPlaylists = state.userPlaylists;

        return CommonScreenScaffold(
          title: localizations.translate('playlists'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => _showCreatePlaylistDialog(context),
            ),
            const SizedBox(width: 8),
          ],
          slivers: [
            // Liked Songs
            if (likedPlaylist != null && likedPlaylist.songs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildLikedSongsCard(
                    context,
                    likedPlaylist,
                    audioService,
                    isDark,
                    localizations,
                  ),
                ),
              ),

            // Auto Playlists Header
            if (autoPlaylists.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    localizations.translate('auto_playlists'),
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Auto Playlists Horizontal List
            if (autoPlaylists.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: autoPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = autoPlaylists[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GlassmorphicCard.playlist(
                          playlistName: playlist.name,
                          songCount: playlist.songs.length,
                          playlistId: playlist.id,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaylistDetailScreen(playlist: playlist),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Your Playlists Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  localizations.translate('your_playlists'),
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // User Playlists List
            userPlaylists.isEmpty
                ? SliverToBoxAdapter(
                    child: _buildEmptyState(context, isDark, localizations),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: _buildPlaylistTile(
                            context,
                            userPlaylists[index],
                            audioService,
                            isDark,
                            localizations,
                          ),
                        );
                      },
                      childCount: userPlaylists.length,
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildLikedSongsCard(
    BuildContext context,
    Playlist playlist,
    AudioPlayerService audioService,
    bool isDark,
    AppLocalizations localizations,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pink.withOpacity(0.2),
                  Colors.red.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                    child: Image.asset(
                      'assets/images/UI/liked.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Text
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations.translate('favorite_songs'),
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlist.songs.length} ${localizations.translate('tracks')}',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Play Button
                GestureDetector(
                  onTap: playlist.songs.isEmpty
                      ? null
                      : () => audioService.setPlaylist(playlist.songs, 0),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
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

  Widget _buildPlaylistTile(
    BuildContext context,
    Playlist playlist,
    AudioPlayerService audioService,
    bool isDark,
    AppLocalizations localizations,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      ),
      onLongPress: () =>
          _showPlaylistOptions(context, audioService, playlist, localizations),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(14)),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: _buildPlaylistArtwork(playlist),
                  ),
                ),
                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          playlist.name,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlist.songs.length} ${localizations.translate('tracks')}',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black26,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistArtwork(Playlist playlist) {
    if (playlist.songs.isEmpty) {
      return Container(
        color: Colors.grey.withOpacity(0.2),
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.grey.withOpacity(0.5),
          size: 28,
        ),
      );
    }

    // Use first song artwork
    return _artworkService.buildCachedArtwork(playlist.songs.first.id,
        size: 64);
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    AppLocalizations localizations,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.translate('no_playlists'),
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            localizations.translate('create_first_playlist'),
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: isDark ? Colors.white38 : Colors.black26,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final controller = TextEditingController();

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
                    localizations.translate('new_playlist'),
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: localizations.translate('playlist_name'),
                        hintStyle: TextStyle(
                          fontFamily: 'ProductSans',
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
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
                              fontFamily: 'ProductSans',
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (controller.text.isNotEmpty) {
                              final audioService =
                                  Provider.of<AudioPlayerService>(context,
                                      listen: false);
                              audioService.createPlaylist(controller.text, []);
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.translate('create'),
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
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

  void _showPlaylistOptions(
    BuildContext context,
    AudioPlayerService audioService,
    Playlist playlist,
    AppLocalizations localizations,
  ) {
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
                    fontFamily: 'ProductSans',
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Rename option
                _buildOptionTile(
                  context,
                  Icons.edit_rounded,
                  localizations.translate('rename'),
                  isDark,
                  () {
                    Navigator.pop(context);
                    _showRenameDialog(context, audioService, playlist);
                  },
                ),
                // Delete option
                _buildOptionTile(
                  context,
                  Icons.delete_outline_rounded,
                  localizations.translate('delete'),
                  isDark,
                  () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(
                        context, audioService, playlist, localizations);
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
                fontFamily: 'ProductSans',
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

  void _showRenameDialog(
    BuildContext context,
    AudioPlayerService audioService,
    Playlist playlist,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final controller = TextEditingController(text: playlist.name);

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
                    localizations.translate('rename_playlist'),
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: localizations.translate('playlist_name'),
                        hintStyle: TextStyle(
                          fontFamily: 'ProductSans',
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
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
                              fontFamily: 'ProductSans',
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (controller.text.isNotEmpty) {
                              audioService.renamePlaylist(
                                  playlist.id, controller.text);
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                localizations.translate('save'),
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
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

  void _showDeleteConfirmation(
    BuildContext context,
    AudioPlayerService audioService,
    Playlist playlist,
    AppLocalizations localizations,
  ) {
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
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.translate('delete_playlist'),
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${localizations.translate('delete_playlist_confirm')} "${playlist.name}"?',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            localizations.translate('cancel'),
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            audioService.deletePlaylist(playlist);
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
                                  fontFamily: 'ProductSans',
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

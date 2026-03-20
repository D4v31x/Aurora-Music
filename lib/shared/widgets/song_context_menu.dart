import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/font_constants.dart';
import '../../features/library/library_feature.dart';
import '../../features/settings/settings_feature.dart';
import '../../l10n/generated/app_localizations.dart';
import '../models/models.dart';
import '../services/artwork_cache_service.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../services/notification_manager.dart';

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

/// Shows the song context bottom sheet for [song].
///
/// Call this from any long-press or 3-dot button tap.
Future<void> showSongContextMenu(BuildContext context, SongModel song) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => _SongContextMenu(song: song),
  );
}

// ---------------------------------------------------------------------------
// Private bottom-sheet widget
// ---------------------------------------------------------------------------

class _SongContextMenu extends StatelessWidget {
  final SongModel song;

  static final _artworkService = ArtworkCacheService();
  static const _channel = MethodChannel('aurora/media_actions');

  const _SongContextMenu({required this.song});

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withValues(alpha: 0.88),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Song header
                _buildHeader(context),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 4),
                // Menu items
                _item(
                  context,
                  icon: Icons.playlist_add_rounded,
                  label: AppLocalizations.of(context).addToPlaylist,
                  onTap: () => _addToPlaylist(context, audioService),
                ),
                _item(
                  context,
                  icon: Icons.queue_music_rounded,
                  label: AppLocalizations.of(context).addToQueue,
                  onTap: () => _addToQueue(context, audioService),
                ),
                _item(
                  context,
                  icon: Icons.notifications_active_rounded,
                  label: AppLocalizations.of(context).setAsRingtone,
                  onTap: () => _setAsRingtone(context),
                ),
                _item(
                  context,
                  icon: Icons.share_rounded,
                  label: AppLocalizations.of(context).share,
                  onTap: () => _share(context),
                ),
                _item(
                  context,
                  icon: Icons.edit_rounded,
                  label: AppLocalizations.of(context).songInfoEdit,
                  onTap: () => _editInfo(context),
                ),
                _item(
                  context,
                  icon: Icons.album_rounded,
                  label: AppLocalizations.of(context).goToAlbum,
                  onTap: () => _goToAlbum(context),
                ),
                _item(
                  context,
                  icon: Icons.person_rounded,
                  label: AppLocalizations.of(context).goToArtist,
                  onTap: () => _goToArtist(context),
                ),
                _item(
                  context,
                  icon: Icons.lyrics_rounded,
                  label: AppLocalizations.of(context).clearCachedLyrics,
                  onTap: () => _clearCachedLyrics(context),
                ),
                const Divider(color: Colors.white12, height: 1),
                _item(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: AppLocalizations.of(context).deleteFromDevice,
                  color: Colors.redAccent,
                  onTap: () => _deleteSong(context),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _artworkService.buildCachedArtwork(song.id, size: 52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  splitArtists(song.artist ?? AppLocalizations.of(context).unknownArtist).join(', '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: FontConstants.fontFamily,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  // ---- Actions ----

  void _addToPlaylist(
      BuildContext context, AudioPlayerService audioService) {
    Navigator.pop(context);
    _showPlaylistPicker(context, audioService);
  }

  Future<void> _addToQueue(
      BuildContext context, AudioPlayerService audioService) async {
    Navigator.pop(context);
    await audioService.addToQueue(song);
    if (context.mounted) {
      NotificationManager.showMessage(context, AppLocalizations.of(context).songAddedToQueue(song.title));
    }
  }

  Future<void> _setAsRingtone(BuildContext context) async {
    Navigator.pop(context);
    try {
      await _channel.invokeMethod('setAsRingtone', {'path': song.data});
      if (context.mounted) {
        NotificationManager.showMessage(context, AppLocalizations.of(context).songSetAsRingtone(song.title));
      }
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'PERMISSION_NEEDED') {
        NotificationManager.showMessage(context, AppLocalizations.of(context).modifySystemSettingsPermission);
      } else {
        NotificationManager.showMessage(context, AppLocalizations.of(context).failedToSetRingtone(e.message ?? ''));
      }
    }
  }

  void _share(BuildContext context) {
    Navigator.pop(context);
    final text =
        '${song.title} — ${splitArtists(song.artist ?? AppLocalizations.of(context).unknownArtist).join(', ')}';
    Share.share(text, subject: AppLocalizations.of(context).checkOutThisSong);
  }

  void _editInfo(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MetadataDetailScreen(song: song)),
    );
  }

  void _goToAlbum(BuildContext context) {
    Navigator.pop(context);
    if (song.album == null || song.album!.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AlbumDetailScreen(albumName: song.album!)),
    );
  }

  void _goToArtist(BuildContext context) {
    Navigator.pop(context);
    final artist = splitArtists(song.artist ?? AppLocalizations.of(context).unknownArtist).first;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ArtistDetailsScreen(artistName: artist)),
    );
  }

  Future<void> _clearCachedLyrics(BuildContext context) async {
    Navigator.pop(context);
    final artist = song.artist?.trim().isNotEmpty == true
        ? song.artist!.trim()
        : AppLocalizations.of(context).unknown;
    final title =
        song.title.trim().isNotEmpty ? song.title.trim() : AppLocalizations.of(context).unknown;
    final deleted =
        await TimedLyricsService().deleteCachedLyricsForSong(artist, title);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    NotificationManager.showMessage(
      context,
      deleted ? l10n.lyricsCleared(song.title) : l10n.noLyricsCached,
    );
  }

  Future<void> _deleteSong(BuildContext context) async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
        backgroundColor: Colors.grey[900]!.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          l10n.deleteSong,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.deleteSongConfirm(song.title),
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: FontConstants.fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(
                color: Colors.redAccent,
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _channel.invokeMethod('deleteSong', {'path': song.data});
      if (context.mounted) {
        NotificationManager.showMessage(context, AppLocalizations.of(context).songDeleted(song.title));
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        NotificationManager.showMessage(context, AppLocalizations.of(context).failedToDelete(e.message ?? ''));
      }
    }
  }

  // ---- Playlist picker ----

  void _showPlaylistPicker(
      BuildContext context, AudioPlayerService audioService) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Add to playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  if (audioService.playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No playlists yet',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: FontConstants.fontFamily),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: audioService.playlists.length,
                        itemBuilder: (_, i) {
                          final playlist = audioService.playlists[i];
                          return ListTile(
                            leading: const Icon(Icons.playlist_play,
                                color: Colors.white),
                            title: Text(
                              playlist.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: FontConstants.fontFamily),
                            ),
                            subtitle: Text(
                              '${playlist.songs.length} songs',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () {
                              audioService.addSongToPlaylist(
                                  playlist.id, song);
                              Navigator.pop(ctx);
                              NotificationManager.showMessage(
                                context,
                                AppLocalizations.of(context).addedToNamedPlaylist(playlist.name),
                              );
                            },
                          );
                        },
                      ),
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

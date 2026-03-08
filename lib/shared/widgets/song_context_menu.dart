import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/font_constants.dart';
import '../../features/library/screens/album_detail_screen.dart';
import '../../features/library/screens/artist_detail_screen.dart';
import '../../features/settings/screens/metadata_detail_screen.dart';
import '../models/artist_utils.dart';
import '../services/artwork_cache_service.dart';
import '../services/audio_player_service.dart';

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
        child: Container(
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
                  label: 'Add to playlist',
                  onTap: () => _addToPlaylist(context, audioService),
                ),
                _item(
                  context,
                  icon: Icons.queue_music_rounded,
                  label: 'Add to queue',
                  onTap: () => _addToQueue(context, audioService),
                ),
                _item(
                  context,
                  icon: Icons.notifications_active_rounded,
                  label: 'Set as ringtone',
                  onTap: () => _setAsRingtone(context),
                ),
                _item(
                  context,
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _share(context),
                ),
                _item(
                  context,
                  icon: Icons.edit_rounded,
                  label: 'Song info / Edit',
                  onTap: () => _editInfo(context),
                ),
                _item(
                  context,
                  icon: Icons.album_rounded,
                  label: 'Go to album',
                  onTap: () => _goToAlbum(context),
                ),
                _item(
                  context,
                  icon: Icons.person_rounded,
                  label: 'Go to artist',
                  onTap: () => _goToArtist(context),
                ),
                const Divider(color: Colors.white12, height: 1),
                _item(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete from device',
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
                  splitArtists(song.artist ?? 'Unknown Artist').join(', '),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${song.title}" added to queue')),
      );
    }
  }

  Future<void> _setAsRingtone(BuildContext context) async {
    Navigator.pop(context);
    try {
      await _channel.invokeMethod('setAsRingtone', {'path': song.data});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${song.title}" set as ringtone')),
        );
      }
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'PERMISSION_NEEDED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Allow "Modify system settings" in the page that opened, then try again.'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set ringtone: ${e.message}')),
        );
      }
    }
  }

  void _share(BuildContext context) {
    Navigator.pop(context);
    final text =
        '${song.title} — ${splitArtists(song.artist ?? 'Unknown Artist').join(', ')}';
    Share.share(text, subject: 'Check out this song!');
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
    final artist = splitArtists(song.artist ?? 'Unknown Artist').first;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ArtistDetailsScreen(artistName: artist)),
    );
  }

  Future<void> _deleteSong(BuildContext context) async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900]!.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text(
          'Delete song',
          style: TextStyle(
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete "${song.title}" from your device? This cannot be undone.',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.white70,
                  fontFamily: FontConstants.fontFamily),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _channel.invokeMethod('deleteSong', {'path': song.data});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${song.title}" deleted')),
        );
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.message}')),
        );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Added to ${playlist.name}')),
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/playlist_model.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/unified_detail_screen.dart';
import '../../../shared/widgets/song_picker_sheet.dart';
import '../../../l10n/app_localizations.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  bool get _isAutoPlaylist =>
      widget.playlist.id == 'liked_songs' ||
      widget.playlist.id == 'most_played' ||
      widget.playlist.id == 'recently_added';

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

  void _refreshSongs() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AudioPlayerService, Playlist>(
      selector: (context, audioService) => audioService.playlists.firstWhere(
        (p) => p.id == widget.playlist.id,
        orElse: () => widget.playlist,
      ),
      builder: (context, updatedPlaylist, _) {
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);

        return UnifiedDetailScreen(
          config: DetailScreenConfig(
            type: DetailScreenType.playlist,
            title: updatedPlaylist.name,
            playbackSource: PlaybackSourceInfo(
              source: PlaybackSource.playlist,
              name: updatedPlaylist.name,
            ),
            heroTag: 'playlist_${updatedPlaylist.id}',
            accentColor: _getPlaylistColor(updatedPlaylist.id),
            showAddButton: !_isAutoPlaylist,
            allowSongRemoval: !_isAutoPlaylist,
            onAddPressed: () async {
              await SongPickerSheet.show(context, updatedPlaylist);
              _refreshSongs();
            },
            onSongRemoved: (song) {
              _removeSong(context, audioService, song, updatedPlaylist);
            },
          ),
          songs: updatedPlaylist.songs,
          headerArtwork: _buildPlaylistArtwork(updatedPlaylist),
          isLoading: false,
        );
      },
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
      return Image.asset(imagePath, fit: BoxFit.cover, width: 140, height: 140);
    }

    if (playlist.songs.isNotEmpty) {
      return _artworkService.buildCachedArtwork(playlist.songs.first.id,
          size: 140);
    }

    return _buildDefaultArtwork();
  }

  Widget _buildDefaultArtwork() {
    return DecoratedBox(
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
      child: const SizedBox(
        width: 140,
        height: 140,
        child: Center(
          child: Icon(Icons.playlist_play_rounded,
              color: Colors.white70, size: 60),
        ),
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
}

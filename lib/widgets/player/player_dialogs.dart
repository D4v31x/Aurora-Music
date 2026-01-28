import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/music_metadata_widget.dart';

/// Shows a dialog for adding the current song to a playlist.
void showAddToPlaylistDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_song_playing'))),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppLocalizations.of(context).translate('select_playlist'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
                if (audioPlayerService.playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      AppLocalizations.of(context).translate('no_playlists'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: audioPlayerService.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = audioPlayerService.playlists[index];
                        return ListTile(
                          leading:
                              const Icon(Icons.playlist_play, color: Colors.white),
                          title: Text(
                            playlist.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${playlist.songs.length} songs',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () {
                            audioPlayerService.addSongToPlaylist(
                              playlist.id,
                              audioPlayerService.currentSong!,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)
                                      .translate('added_to_playlist'),
                                ),
                              ),
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
      );
    },
  );
}

/// Share the current song.
void shareSong(AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) return;

  final song = audioPlayerService.currentSong!;
  final shareText =
      '${song.title} - ${splitArtists(song.artist ?? "Unknown Artist").join(", ")}';

  Share.share(
    shareText,
    subject: 'Check out this song!',
  );
}

/// Shows a dialog displaying the current playback queue.
void showQueueDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('queue'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                if (audioPlayerService.playlist.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      AppLocalizations.of(context).translate('queue_empty'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: audioPlayerService.playlist.length,
                      itemBuilder: (context, index) {
                        final song = audioPlayerService.playlist[index];
                        final isCurrentSong =
                            audioPlayerService.currentSong?.id == song.id;
                        return ListTile(
                          leading: isCurrentSong
                              ? const Icon(Icons.play_circle_filled,
                                  color: Colors.blue)
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                          title: Text(
                            song.title,
                            style: TextStyle(
                              color: isCurrentSong ? Colors.blue : Colors.white,
                              fontWeight: isCurrentSong
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            splitArtists(song.artist ?? 'Unknown Artist')
                                .join(', '),
                            style: TextStyle(
                              color: isCurrentSong
                                  ? Colors.blue.shade200
                                  : Colors.white70,
                            ),
                          ),
                          onTap: () {
                            audioPlayerService.setPlaylist(
                              audioPlayerService.playlist,
                              index,
                            );
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shows a dialog displaying detailed song information.
void showSongInfoDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  if (audioPlayerService.currentSong == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).translate('no_song_playing'))),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('song_info'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                MusicMetadataWidget(song: audioPlayerService.currentSong!),
                const SizedBox(height: 16),
                _buildInfoRow('Title', audioPlayerService.currentSong!.title),
                _buildInfoRow(
                    'Artist',
                    splitArtists(
                            audioPlayerService.currentSong!.artist ?? 'Unknown')
                        .join(', ')),
                _buildInfoRow('Album',
                    audioPlayerService.currentSong!.album ?? 'Unknown'),
                _buildInfoRow('Path', audioPlayerService.currentSong!.data),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

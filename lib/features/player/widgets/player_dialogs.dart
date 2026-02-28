import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/widgets/music_metadata_widget.dart';

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
      return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
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
                          leading: const Icon(Icons.playlist_play,
                              color: Colors.white),
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

/// Shows a dialog displaying the current playback queue with full management capabilities.
void showQueueDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _QueueBottomSheet(audioPlayerService: audioPlayerService);
    },
  );
}

/// Stateful widget for the queue bottom sheet to handle updates
class _QueueBottomSheet extends StatefulWidget {
  final AudioPlayerService audioPlayerService;

  const _QueueBottomSheet({required this.audioPlayerService});

  @override
  State<_QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<_QueueBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final audioPlayerService = widget.audioPlayerService;
    final playlist = audioPlayerService.playlist;
    final currentIndex = audioPlayerService.currentIndex;
    final screenHeight = MediaQuery.of(context).size.height;

    return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: screenHeight * 0.75,
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
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('queue'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${playlist.length} ${AppLocalizations.of(context).translate('tracks')}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Clear upcoming button
                      if (audioPlayerService.hasUpcoming)
                        IconButton(
                          icon: const Icon(Icons.clear_all,
                              color: Colors.white70),
                          tooltip: AppLocalizations.of(context)
                              .translate('clear_upcoming'),
                          onPressed: () async {
                            await audioPlayerService.clearUpcoming();
                            if (context.mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),

            // Now Playing section
            if (audioPlayerService.currentSong != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('now_playing'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _QueueSongTile(
                      song: audioPlayerService.currentSong!,
                      isCurrentSong: true,
                      index: currentIndex,
                      onTap: () {},
                      onRemove: null, // Can't remove current song
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
            ],

            // Up Next section
            Expanded(
              child: playlist.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context).translate('queue_empty'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (audioPlayerService.hasUpcoming)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              AppLocalizations.of(context).translate('up_next'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: playlist.length,
                            onReorder: (oldIndex, newIndex) async {
                              // Adjust indices for the internal reordering
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              await audioPlayerService.moveInQueue(
                                  oldIndex, newIndex);
                              if (context.mounted) {
                                setState(() {});
                              }
                            },
                            itemBuilder: (context, index) {
                              final song = playlist[index];
                              final isCurrentSong = index == currentIndex;

                              return Dismissible(
                                key: ValueKey('${song.id}_$index'),
                                direction: isCurrentSong
                                    ? DismissDirection.none
                                    : DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red.withOpacity(0.8),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                onDismissed: (_) async {
                                  await audioPlayerService
                                      .removeFromQueue(index);
                                },
                                child: _QueueSongTile(
                                  key: ValueKey('tile_${song.id}_$index'),
                                  song: song,
                                  isCurrentSong: isCurrentSong,
                                  index: index,
                                  showDragHandle: true,
                                  onTap: () {
                                    audioPlayerService.play(index: index);
                                    Navigator.pop(context);
                                  },
                                  onRemove: isCurrentSong
                                      ? null
                                      : () async {
                                          await audioPlayerService
                                              .removeFromQueue(index);
                                          if (context.mounted) {
                                            setState(() {});
                                          }
                                        },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
          ),
        ),
    );
  }
}

/// Individual song tile in the queue
class _QueueSongTile extends StatelessWidget {
  final dynamic song; // SongModel
  final bool isCurrentSong;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool showDragHandle;

  const _QueueSongTile({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.index,
    required this.onTap,
    this.onRemove,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle,
                    color: Colors.white38, size: 20),
              ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCurrentSong
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: isCurrentSong
                    ? const Icon(Icons.play_arrow, color: Colors.blue, size: 18)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: isCurrentSong ? Colors.blue : Colors.white,
            fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          splitArtists(song.artist ?? 'Unknown Artist').join(', '),
          style: TextStyle(
            color: isCurrentSong ? Colors.blue.shade200 : Colors.white60,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onRemove != null
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white38,
                onPressed: onRemove,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
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
      return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
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
                    InfoRow(
                        label: 'Title',
                        value: audioPlayerService.currentSong!.title),
                    InfoRow(
                        label: 'Artist',
                        value: splitArtists(
                                audioPlayerService.currentSong!.artist ??
                                    'Unknown')
                            .join(', ')),
                    InfoRow(
                        label: 'Album',
                        value:
                            audioPlayerService.currentSong!.album ?? 'Unknown'),
                    InfoRow(
                        label: 'Path',
                        value: audioPlayerService.currentSong!.data),
                  ],
                ),
              ),
            ),
          ),
      );
    },
  );
}

/// A labeled info row widget for displaying label-value pairs.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
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
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

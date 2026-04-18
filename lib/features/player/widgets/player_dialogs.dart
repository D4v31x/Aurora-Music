import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/providers/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/music_metadata_widget.dart';

/// Shows a dialog for adding the current song to a playlist.
void showAddToPlaylistDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  final song = audioPlayerService.currentSong;
  if (song == null) {
    NotificationManager.showMessage(
      context,
      AppLocalizations.of(context).noSongPlaying,
    );
    return;
  }

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (BuildContext context) {
      return Dialog(
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppLocalizations.of(context).selectPlaylist,
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
                      AppLocalizations.of(context).noPlaylists,
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
                          leading: const iconoir.PlaylistPlay(
                              color: Colors.white, width: 24, height: 24),
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
                              song,
                            );
                            Navigator.pop(context);
                            NotificationManager.showMessage(
                              context,
                              AppLocalizations.of(context).addedToPlaylist,
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
    shape: const RoundedRectangleBorder(),
    barrierColor: Colors.black.withValues(alpha: 0.75),
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
  static const TextStyle _sectionLabelStyle = TextStyle(
    color: Colors.white54,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  Widget _dismissibleSongTile({
    required String keyPrefix,
    required dynamic song,
    required int playlistIndex,
    required int reorderIndex,
    required AudioPlayerService audio,
    bool isQueued = false,
  }) {
    return Dismissible(
      key: ValueKey('${keyPrefix}_${song.id}_$playlistIndex'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const iconoir.Trash(color: Colors.white, width: 22, height: 22),
      ),
      onDismissed: (_) async {
        await audio.removeFromQueue(playlistIndex);
        if (mounted) setState(() {});
      },
      child: _QueueSongTile(
        key: ValueKey('tile_${keyPrefix}_${song.id}_$playlistIndex'),
        song: song,
        isCurrentSong: false,
        reorderIndex: isQueued ? reorderIndex : null,
        isQueued: isQueued,
        onTap: () {
          audio.play(index: playlistIndex);
          Navigator.pop(context);
        },
        onRemove: () async {
          await audio.removeFromQueue(playlistIndex);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.audioPlayerService;
    final currentSong = audio.currentSong;
    final currentIndex = audio.currentIndex;
    final queuedSongs = audio.queuedSongs;
    final sourceSongs = audio.sourceUpcoming;
    final queueBoundary = audio.queueBoundary;
    final screenHeight = MediaQuery.of(context).size.height;

    final sourceName = audio.playbackSource.name;
    final sourceLabel = sourceName != null && sourceName.isNotEmpty
        ? 'Next from $sourceName'
        : 'Next Up';

    final hasAnything = currentSong != null ||
        queuedSongs.isNotEmpty ||
        sourceSongs.isNotEmpty;

    final totalSongs =
        (currentSong != null ? 1 : 0) + queuedSongs.length + sourceSongs.length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: screenHeight * 0.78,
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withValues(alpha: 0.88),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 4, 8, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const iconoir.Playlist(
                          color: Colors.blue, width: 20, height: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).queue,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$totalSongs song${totalSongs == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (audio.hasUpcoming)
                      IconButton(
                        icon: const iconoir.Trash(
                            color: Colors.white54, width: 24, height: 24),
                        tooltip: AppLocalizations.of(context)
                            .clearUpcoming,
                        onPressed: () async {
                          await audio.clearUpcoming();
                          if (mounted) setState(() {});
                        },
                      ),
                    IconButton(
                    icon: iconoir.Xmark(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 24,
                        height: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                  color: Colors.white.withValues(alpha: 0.1), height: 1),

              Expanded(
                child: !hasAnything
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            iconoir.Playlist(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 48,
                                height: 48),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context)
                                  .queueEmpty,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          // ── Now Playing ────────────────────────────
                          if (currentSong != null) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 16, 20, 8),
                                child: Text(
                                  AppLocalizations.of(context)
                                      .nowPlaying
                                      .toUpperCase(),
                                  style: _sectionLabelStyle,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _QueueSongTile(
                                song: currentSong,
                                isCurrentSong: true,
                                reorderIndex: null,
                                onTap: () {},
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Divider(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  height: 12,
                                  indent: 20,
                                  endIndent: 20),
                            ),
                          ],

                          // ── Queue (user-added songs) ────────────────
                          if (queuedSongs.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 8, 20, 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(AppLocalizations.of(context).queue.toUpperCase(),
                                        style: _sectionLabelStyle.copyWith(
                                            color: Colors.blue.shade300)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                            alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${queuedSongs.length}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: ReorderableListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: queuedSongs.length,
                                onReorder: (oldIdx, newIdx) async {
                                  if (oldIdx < newIdx) newIdx -= 1;
                                  final base = currentIndex + 1;
                                  await audio.moveInQueue(
                                      base + oldIdx, base + newIdx);
                                  if (mounted) setState(() {});
                                },
                                itemBuilder: (context, i) {
                                  final song = queuedSongs[i];
                                  final pIdx = currentIndex + 1 + i;
                                  return _dismissibleSongTile(
                                    keyPrefix: 'queued',
                                    song: song,
                                    playlistIndex: pIdx,
                                    reorderIndex: i,
                                    audio: audio,
                                    isQueued: true,
                                  );
                                },
                              ),
                            ),
                          ],

                          // ── Next from Source ─────────────────────────
                          if (sourceSongs.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 16, 20, 8),
                                child: Text(
                                  sourceLabel.toUpperCase(),
                                  style: _sectionLabelStyle,
                                ),
                              ),
                            ),
                            SliverList.builder(
                              itemCount: sourceSongs.length,
                              itemBuilder: (context, i) {
                                final song = sourceSongs[i];
                                final pIdx = queueBoundary + i;
                                return _dismissibleSongTile(
                                  keyPrefix: 'source',
                                  song: song,
                                  playlistIndex: pIdx,
                                  reorderIndex: i,
                                  audio: audio,
                                );
                              },
                            ),
                          ],

                          const SliverToBoxAdapter(
                              child: SizedBox(height: 24)),
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
  final int? reorderIndex; // null = not reorderable
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isQueued;

  const _QueueSongTile({
    super.key,
    required this.song,
    required this.isCurrentSong,
    required this.reorderIndex,
    required this.onTap,
    this.onRemove,
    this.isQueued = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: isCurrentSong
              ? BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3)),
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
          child: Row(
            children: [
              // Artwork thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ArtworkCacheService()
                          .buildCachedArtwork(song.id, size: 46),
                      if (isCurrentSong)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                          ),
                            child: const Center(
                              child: iconoir.Play(
                                color: Colors.white,
                                width: 24,
                                height: 24,
                              ),
                            ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        color: isCurrentSong
                            ? Colors.blue.shade300
                            : Colors.white,
                        fontWeight: isCurrentSong
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      splitArtists(song.artist ?? 'Unknown Artist')
                          .join(', '),
                      style: TextStyle(
                        color: isCurrentSong
                            ? Colors.blue.shade200.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Remove button
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: iconoir.Xmark(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 16,
                        height: 16),
                  ),
                ),
              // Drag handle
              if (reorderIndex != null) ...[
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: iconoir.Drag(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 20,
                      height: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a dialog displaying detailed song information.
void showSongInfoDialog(
    BuildContext context, AudioPlayerService audioPlayerService) {
  final song = audioPlayerService.currentSong;
  if (song == null) {
    NotificationManager.showMessage(
      context,
      AppLocalizations.of(context).noSongPlaying,
    );
    return;
  }

  final isLowEnd = Provider.of<PerformanceModeProvider>(context, listen: false).isLowEndDevice;
  final colorScheme = Theme.of(context).colorScheme;
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (BuildContext context) {
      return Dialog(
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isLowEnd ? colorScheme.surfaceContainerHigh : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLowEnd ? colorScheme.outlineVariant : Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                          AppLocalizations.of(context).songInfo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const iconoir.Xmark(color: Colors.white, width: 24, height: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    MusicMetadataWidget(song: song),
                    const SizedBox(height: 16),
                    InfoRow(
                        label: 'Title',
                        value: song.title),
                    InfoRow(
                        label: 'Artist',
                        value: splitArtists(
                                song.artist ??
                                    'Unknown')
                            .join(', ')),
                    InfoRow(
                        label: 'Album',
                        value: song.album ?? 'Unknown'),
                    InfoRow(
                        label: 'Path',
                        value: song.data),
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

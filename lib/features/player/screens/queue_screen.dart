/// Queue screen for managing the playback queue.
///
/// Displays the current queue with drag & drop reordering,
/// remove actions, and save as playlist functionality.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';

/// Screen for managing the playback queue.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen>
    with SingleTickerProviderStateMixin {
  final _artworkService = ArtworkCacheService();
  final _scrollController = ScrollController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Consumer<AudioPlayerService>(
      builder: (context, audioService, _) {
        final queue = audioService.playlist;
        final currentIndex = audioService.currentIndex;
        final currentSong = audioService.currentSong;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App bar
              _buildAppBar(context, isDark, l10n, audioService, queue),

              // Current playing section
              if (currentSong != null)
                SliverToBoxAdapter(
                  child: _buildNowPlayingSection(
                    context,
                    isDark,
                    l10n,
                    currentSong,
                    audioService,
                  ),
                ),

              // Up next header
              if (queue.length > currentIndex + 1)
                SliverToBoxAdapter(
                  child: _buildUpNextHeader(
                    context,
                    isDark,
                    l10n,
                    audioService,
                    queue.length - currentIndex - 1,
                  ),
                ),

              // Queue list
              if (queue.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, isDark, l10n),
                )
              else
                _buildQueueList(
                  context,
                  isDark,
                  audioService,
                  queue,
                  currentIndex,
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    AudioPlayerService audioService,
    List<SongModel> queue,
  ) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 80,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : Colors.black,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        l10n.translate('queue'),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: [
        if (queue.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white : Colors.black,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) => _handleMenuAction(
              context,
              value,
              audioService,
              queue,
              l10n,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save_playlist',
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add),
                    const SizedBox(width: 12),
                    Text(l10n.translate('saveAsPlaylist')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_upcoming',
                child: Row(
                  children: [
                    const Icon(Icons.clear_all),
                    const SizedBox(width: 12),
                    Text(l10n.translate('clearUpcoming')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_queue',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      l10n.translate('clearQueue'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildNowPlayingSection(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    SongModel song,
    AudioPlayerService audioService,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.translate('nowPlaying'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          GlassmorphicContainer(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Artwork with playing indicator
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _artworkService.buildCachedArtwork(
                          song.id,
                          size: 64,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black.withOpacity(0.3),
                          ),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: audioService.isPlayingNotifier,
                            builder: (context, isPlaying, _) {
                              return Icon(
                                isPlaying
                                    ? Icons.equalizer_rounded
                                    : Icons.pause_rounded,
                                color: Colors.white,
                                size: 28,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          splitArtists(song.artist ?? 'Unknown Artist')
                              .join(', '),
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 14,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpNextHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    AudioPlayerService audioService,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${l10n.translate('upNext')} ($count)',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          if (count > 0)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                audioService.clearUpcoming();
              },
              child: Text(
                l10n.translate('clearUpcoming'),
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    bool isDark,
    AudioPlayerService audioService,
    List<SongModel> queue,
    int currentIndex,
  ) {
    // Only show songs after current
    final upcomingStart = currentIndex + 1;
    if (upcomingStart >= queue.length) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final upcomingSongs = queue.sublist(upcomingStart);

    return SliverReorderableList(
      itemCount: upcomingSongs.length,
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.mediumImpact();
        // Adjust indices to account for the current song offset
        final actualOldIndex = oldIndex + upcomingStart;
        var actualNewIndex = newIndex + upcomingStart;
        if (newIndex > oldIndex) {
          actualNewIndex--;
        }
        audioService.moveInQueue(actualOldIndex, actualNewIndex);
      },
      itemBuilder: (context, index) {
        final song = upcomingSongs[index];
        final actualIndex = index + upcomingStart;

        return _QueueItemTile(
          key: ValueKey('queue_$actualIndex'),
          song: song,
          index: index,
          isDark: isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            audioService.play(index: actualIndex);
          },
          onRemove: () {
            HapticFeedback.mediumImpact();
            audioService.removeFromQueue(actualIndex);
          },
          onPlayNext: actualIndex > currentIndex + 1
              ? () {
                  HapticFeedback.lightImpact();
                  audioService.moveInQueue(actualIndex, currentIndex + 1);
                }
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 80,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('queueEmpty'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('addSongsToQueue'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 14,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    AudioPlayerService audioService,
    List<SongModel> queue,
    AppLocalizations l10n,
  ) {
    switch (action) {
      case 'save_playlist':
        _showSaveAsPlaylistDialog(context, audioService, queue, l10n);
        break;
      case 'clear_upcoming':
        HapticFeedback.mediumImpact();
        audioService.clearUpcoming();
        break;
      case 'clear_queue':
        _showClearQueueConfirmation(context, audioService, l10n);
        break;
    }
  }

  void _showSaveAsPlaylistDialog(
    BuildContext context,
    AudioPlayerService audioService,
    List<SongModel> queue,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.translate('saveAsPlaylist'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: l10n.translate('enterPlaylistName'),
            hintStyle: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                audioService.createPlaylist(name, List.from(queue));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${l10n.translate('playlistCreated')}: $name',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showClearQueueConfirmation(
    BuildContext context,
    AudioPlayerService audioService,
    AppLocalizations l10n,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.translate('clearQueue'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          l10n.translate('clearQueueConfirm'),
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              audioService.clearQueue();
              Navigator.pop(context);
            },
            child: Text(l10n.translate('clear')),
          ),
        ],
      ),
    );
  }
}

/// Individual queue item tile with reorder and remove actions
class _QueueItemTile extends StatelessWidget {
  final SongModel song;
  final int index;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onPlayNext;

  static final _artworkService = ArtworkCacheService();

  const _QueueItemTile({
    required super.key,
    required this.song,
    required this.index,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
    this.onPlayNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ReorderableDragStartListener(
      index: index,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showContextMenu(context, l10n),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 12),
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _artworkService.buildCachedArtwork(
                    song.id,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 12),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        splitArtists(song.artist ?? 'Unknown Artist').join(', '),
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Remove button
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Song info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _artworkService.buildCachedArtwork(
                        song.id,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist ?? 'Unknown Artist',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              fontSize: 14,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Actions
              if (onPlayNext != null)
                ListTile(
                  leading: const Icon(Icons.queue_play_next_rounded),
                  title: Text(l10n.translate('playNext')),
                  onTap: () {
                    Navigator.pop(context);
                    onPlayNext?.call();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(l10n.translate('removeFromQueue')),
                onTap: () {
                  Navigator.pop(context);
                  onRemove();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

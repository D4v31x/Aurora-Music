import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../services/notification_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/expanding_player.dart';

/// A mixin that provides common UI patterns for detail screens.
mixin DetailScreenMixin<T extends StatefulWidget> on State<T> {
  /// The dominant color for theming action buttons. Must be implemented.
  Color get dominantColor;

  /// The list of all songs available. Must be implemented.
  List<SongModel> get allSongs;

  /// The playback source info for tracking where playback started from.
  /// Override this in detail screens to provide correct source.
  PlaybackSourceInfo get playbackSource => PlaybackSourceInfo.unknown;

  /// Format a duration to a human-readable string (e.g., "1h 23m" or "23m").
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format a song duration to mm:ss format.
  String formatSongDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Play all songs starting from the first.
  void playAllSongs() {
    if (allSongs.isEmpty) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    audioService.setPlaylist(allSongs, 0, source: playbackSource);
  }

  /// Shuffle and play all songs.
  void shuffleAllSongs() {
    if (allSongs.isEmpty) return;
    final shuffledSongs = List<SongModel>.from(allSongs)..shuffle();
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    audioService.setPlaylist(shuffledSongs, 0, source: playbackSource);
  }

  /// Add all songs in this collection to the playback queue.
  Future<void> addAllToQueue() async {
    if (allSongs.isEmpty) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    await audioService.addMultipleToQueue(allSongs);
    if (mounted) {
      NotificationManager.showMessage(
        context,
        AppLocalizations.of(context).songsAddedToQueue(allSongs.length),
      );
    }
  }

  /// Build a stat item widget for displaying counts and labels.
  Widget buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build a vertical divider for stat sections.
  Widget buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  /// Build an action button (play all, shuffle, etc.).
  Widget buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool iconOnly = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: 14,
          horizontal: iconOnly ? 14 : 20,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    dominantColor.withValues(alpha: 0.8),
                    dominantColor.withValues(alpha: 0.6),
                  ],
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? dominantColor : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (!iconOnly) ...
              [
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  /// Build the action buttons row with Play All, Shuffle, and Add to Queue.
  /// Play All is always fully visible. Shuffle and Queue collapse to icon-only
  /// on narrow screens (< 360 dp) and show labels on wider screens (≥ 360 dp).
  Widget buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: buildActionButton(
              icon: const Iconoir.Play(color: Colors.white, width: 22, height: 22),
              label: AppLocalizations.of(context).playAll,
              onTap: playAllSongs,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 8),
          buildActionButton(
            icon: const Iconoir.Shuffle(color: Colors.white, width: 22, height: 22),
            label: AppLocalizations.of(context).shuffle,
            onTap: shuffleAllSongs,
            iconOnly: true,
          ),
          const SizedBox(width: 8),
          buildActionButton(
            icon: const Iconoir.Playlist(color: Colors.white, width: 22, height: 22),
            label: AppLocalizations.of(context).queue,
            onTap: addAllToQueue,
            iconOnly: true,
          ),
        ],
      ),
    );
  }

  /// Build mini player padding sliver.
  Widget buildMiniPlayerPadding() {
    return SliverToBoxAdapter(
      child: Selector<AudioPlayerService, bool>(
        selector: (_, service) => service.currentSong != null,
        builder: (context, hasCurrentSong, _) {
          return SizedBox(
            height: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 16,
          );
        },
      ),
    );
  }
}

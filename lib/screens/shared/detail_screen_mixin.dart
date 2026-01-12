import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/expanding_player.dart';

/// A mixin that provides common UI patterns for detail screens.
///
/// This mixin handles:
/// - Building stat items (song count, duration, etc.)
/// - Building action buttons (play all, shuffle)
/// - Formatting durations
/// - Building mini player padding
///
/// Usage:
/// ```dart
/// class _MyDetailScreenState extends State<MyDetailScreen>
///     with DetailScreenMixin {
///   @override
///   Color get dominantColor => _dominantColor;
///
///   @override
///   List<SongModel> get allSongs => _allSongs;
/// }
/// ```
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
            color: Colors.white.withOpacity(0.6),
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
      color: Colors.white.withOpacity(0.2),
    );
  }

  /// Build an action button (play all, shuffle, etc.).
  Widget buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    dominantColor.withOpacity(0.8),
                    dominantColor.withOpacity(0.6),
                  ],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? dominantColor : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
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
        ),
      ),
    );
  }

  /// Build the action buttons row with Play All and Shuffle.
  Widget buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: buildActionButton(
              icon: Icons.play_arrow_rounded,
              label: AppLocalizations.of(context).translate('play_all'),
              onTap: playAllSongs,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildActionButton(
              icon: Icons.shuffle_rounded,
              label: AppLocalizations.of(context).translate('shuffle'),
              onTap: shuffleAllSongs,
              isPrimary: false,
            ),
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
                : 16,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/glassmorphic_container.dart';

/// Holds computed library statistics
class _LibraryStats {
  final int totalSongs;
  final int totalArtists;
  final int totalAlbums;
  final int totalPlaylists;
  final int totalHours;
  final int totalMinutes;

  const _LibraryStats({
    required this.totalSongs,
    required this.totalArtists,
    required this.totalAlbums,
    required this.totalPlaylists,
    required this.totalHours,
    required this.totalMinutes,
  });

  /// Compute stats from songs and playlists - expensive, should be cached
  static _LibraryStats compute(List<SongModel> songs, int playlistCount) {
    final uniqueArtists = <String>{};
    final uniqueAlbums = <String>{};
    int totalDurationMs = 0;

    for (final song in songs) {
      if (song.artist != null && song.artist!.isNotEmpty) {
        uniqueArtists.addAll(splitArtists(song.artist!));
      }
      if (song.album != null && song.album!.isNotEmpty) {
        uniqueAlbums.add(song.album!);
      }
      totalDurationMs += song.duration ?? 0;
    }

    return _LibraryStats(
      totalSongs: songs.length,
      totalArtists: uniqueArtists.length,
      totalAlbums: uniqueAlbums.length,
      totalPlaylists: playlistCount,
      totalHours: (totalDurationMs / 1000 / 60 / 60).floor(),
      totalMinutes: ((totalDurationMs / 1000 / 60) % 60).floor(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LibraryStats &&
          totalSongs == other.totalSongs &&
          totalPlaylists == other.totalPlaylists;

  @override
  int get hashCode => totalSongs.hashCode ^ totalPlaylists.hashCode;
}

/// A minimalistic glassmorphic card showing music library statistics.
/// Performance-aware: Respects device performance mode for blur effects.
class MusicStatsCard extends StatefulWidget {
  const MusicStatsCard({super.key});

  @override
  State<MusicStatsCard> createState() => _MusicStatsCardState();
}

class _MusicStatsCardState extends State<MusicStatsCard> {
  // Memoization: only re-run the expensive _LibraryStats.compute() when the
  // song or playlist count actually changes.  During normal playback the
  // AudioPlayerService fires ~60 notifyListeners/sec (position debounce);
  // without memoization, compute() would iterate every song on every tick.
  _LibraryStats? _cachedStats;
  int _lastSongCount = -1;
  int _lastPlaylistCount = -1;

  _LibraryStats _getMemoizedStats(List<SongModel> songs, int playlistCount) {
    if (songs.length == _lastSongCount &&
        playlistCount == _lastPlaylistCount &&
        _cachedStats != null) {
      return _cachedStats!;
    }
    _lastSongCount = songs.length;
    _lastPlaylistCount = playlistCount;
    _cachedStats = _LibraryStats.compute(songs, playlistCount);
    return _cachedStats!;
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Selector only extracts the two integer counts — O(1) per notification.
    // shouldRebuild ensures the builder body only runs when counts change, at
    // which point _getMemoizedStats() performs the full O(n) computation once.
    return Selector<AudioPlayerService, (int, int)>(
      selector: (_, service) => (service.songs.length, service.playlists.length),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, counts, _) {
        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);
        final stats =
            _getMemoizedStats(audioPlayerService.songs, counts.$2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassmorphicContainer(
            borderRadius: BorderRadius.circular(20),
            blur: 15,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal header
                Row(
                  children: [
                    Icon(
                      Icons.library_music_outlined,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).yourLibrary,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stats.totalHours}h ${stats.totalMinutes}m',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats row - minimalistic
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MinimalStat(
                      value: _formatNumber(stats.totalSongs),
                      label: AppLocalizations.of(context).songs,
                      isDark: isDark,
                    ),
                    _MinimalStat(
                      value: _formatNumber(stats.totalArtists),
                      label: AppLocalizations.of(context).artists,
                      isDark: isDark,
                    ),
                    _MinimalStat(
                      value: _formatNumber(stats.totalAlbums),
                      label: AppLocalizations.of(context).albums,
                      isDark: isDark,
                    ),
                    _MinimalStat(
                      value: _formatNumber(stats.totalPlaylists),
                      label:
                          AppLocalizations.of(context).playlists,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MinimalStat extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _MinimalStat({
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: FontConstants.fontFamily,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

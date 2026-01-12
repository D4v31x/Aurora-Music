import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../../providers/performance_mode_provider.dart';

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
class MusicStatsCard extends StatelessWidget {
  const MusicStatsCard({super.key});

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
    final colorScheme = theme.colorScheme;

    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    // Use Selector to only rebuild when songs or playlists count changes
    return Selector<AudioPlayerService, _LibraryStats>(
      selector: (_, service) => _LibraryStats.compute(
        service.songs,
        service.playlists.length,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, stats, _) {
        // Use solid surface colors for lowend devices
        final BoxDecoration cardDecoration;
        if (shouldBlur) {
          cardDecoration = BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          );
        } else {
          // Solid card styling for lowend devices
          cardDecoration = BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          );
        }

        final cardContent = Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration,
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
                    AppLocalizations.of(context).translate('your_library'),
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
                    label: AppLocalizations.of(context).translate('songs'),
                    isDark: isDark,
                  ),
                  _MinimalStat(
                    value: _formatNumber(stats.totalArtists),
                    label: AppLocalizations.of(context).translate('artists'),
                    isDark: isDark,
                  ),
                  _MinimalStat(
                    value: _formatNumber(stats.totalAlbums),
                    label: AppLocalizations.of(context).translate('albums'),
                    isDark: isDark,
                  ),
                  _MinimalStat(
                    value: _formatNumber(stats.totalPlaylists),
                    label: AppLocalizations.of(context).translate('playlists'),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RepaintBoundary(
            child: shouldBlur
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: cardContent,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: cardContent,
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

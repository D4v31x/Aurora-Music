import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';

/// A visually appealing glassmorphic card showing music library statistics
class MusicStatsCard extends StatefulWidget {
  const MusicStatsCard({super.key});

  @override
  State<MusicStatsCard> createState() => _MusicStatsCardState();
}

class _MusicStatsCardState extends State<MusicStatsCard> {
  int _totalSongs = 0;
  int _totalArtists = 0;
  int _totalAlbums = 0;
  int _totalPlaylists = 0;
  int _totalHours = 0;
  int _totalMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    _totalSongs = audioPlayerService.songs.length;

    // Derive unique artists and albums from songs
    final uniqueArtists = <String>{};
    final uniqueAlbums = <String>{};
    for (final song in audioPlayerService.songs) {
      if (song.artist != null && song.artist!.isNotEmpty) {
        uniqueArtists.addAll(splitArtists(song.artist!));
      }
      if (song.album != null && song.album!.isNotEmpty) {
        uniqueAlbums.add(song.album!);
      }
    }
    _totalArtists = uniqueArtists.length;
    _totalAlbums = uniqueAlbums.length;
    _totalPlaylists = audioPlayerService.playlists.length;

    // Calculate total duration
    int totalDurationMs = 0;
    for (final song in audioPlayerService.songs) {
      totalDurationMs += song.duration ?? 0;
    }
    _totalHours = (totalDurationMs / 1000 / 60 / 60).floor();
    _totalMinutes = ((totalDurationMs / 1000 / 60) % 60).floor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.library_music_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('library'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ProductSans',
                            ),
                          ),
                          Text(
                            '${_totalHours}h ${_totalMinutes}m of music',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontFamily: 'ProductSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatItem(
                      icon: Icons.music_note_rounded,
                      value: _totalSongs.toString(),
                      label: AppLocalizations.of(context).translate('songs'),
                      color: theme.colorScheme.primary,
                    ),
                    _StatItem(
                      icon: Icons.person_rounded,
                      value: _totalArtists.toString(),
                      label: AppLocalizations.of(context).translate('artists'),
                      color: theme.colorScheme.primary,
                    ),
                    _StatItem(
                      icon: Icons.album_rounded,
                      value: _totalAlbums.toString(),
                      label: AppLocalizations.of(context).translate('albums'),
                      color: theme.colorScheme.primary,
                    ),
                    _StatItem(
                      icon: Icons.queue_music_rounded,
                      value: _totalPlaylists.toString(),
                      label:
                          AppLocalizations.of(context).translate('playlists'),
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'ProductSans',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

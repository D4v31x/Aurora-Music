import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../services/audio_player_service.dart';

/// Horizontal scrollable glassmorphic genre/mood chips for quick filtering
class GenreChipsSection extends StatelessWidget {
  const GenreChipsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        // Extract unique genres from songs
        final genreSet = <String>{};
        for (final song in audioPlayerService.songs) {
          if (song.genre != null && song.genre!.isNotEmpty) {
            // Split by common separators and clean up
            final genres = song.genre!.split(RegExp(r'[,;/]'));
            for (var genre in genres) {
              genre = genre.trim();
              if (genre.isNotEmpty && genre.toLowerCase() != 'unknown') {
                genreSet.add(genre);
              }
            }
          }
        }

        // Convert to list and take top genres
        final genres = genreSet.take(10).toList();

        // Add some mood-based categories
        final moods = [
          _GenreItem('🎵', 'All Songs', null),
          _GenreItem('❤️', 'Favorites', 'favorites'),
          _GenreItem('🔀', 'Shuffle', 'shuffle'),
        ];

        if (genres.isEmpty && moods.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Mood chips first
              ...moods.map((mood) => _GenreChip(
                    emoji: mood.emoji,
                    label: mood.label,
                    onTap: () => _handleMoodTap(
                        context, mood.action, audioPlayerService),
                  )),
              // Genre chips
              ...genres.map((genre) => _GenreChip(
                    label: genre,
                    onTap: () => _playGenre(context, genre, audioPlayerService),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _handleMoodTap(
      BuildContext context, String? action, AudioPlayerService audioService) {
    if (action == null) {
      // Play all songs
      if (audioService.songs.isNotEmpty) {
        audioService.setPlaylist(audioService.songs, 0);
      }
    } else if (action == 'favorites') {
      // Play liked songs
      final likedPlaylist = audioService.likedSongsPlaylist;
      if (likedPlaylist != null && likedPlaylist.songs.isNotEmpty) {
        audioService.setPlaylist(likedPlaylist.songs, 0);
      }
    } else if (action == 'shuffle') {
      // Shuffle all songs
      if (audioService.songs.isNotEmpty) {
        final shuffled = List.from(audioService.songs)..shuffle();
        audioService.setPlaylist(shuffled.cast(), 0);
      }
    }
  }

  void _playGenre(
      BuildContext context, String genre, AudioPlayerService audioService) {
    final genreSongs = audioService.songs.where((song) {
      return song.genre?.toLowerCase().contains(genre.toLowerCase()) ?? false;
    }).toList();

    if (genreSongs.isNotEmpty) {
      audioService.setPlaylist(genreSongs, 0);
    }
  }
}

class _GenreItem {
  final String emoji;
  final String label;
  final String? action;

  _GenreItem(this.emoji, this.label, this.action);
}

class _GenreChip extends StatelessWidget {
  final String? emoji;
  final String label;
  final VoidCallback onTap;

  const _GenreChip({
    this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji != null) ...[
                      Text(
                        emoji!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ProductSans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../glassmorphic_card.dart';

/// Horizontal scrollable glassmorphic section showing recently added songs
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key});

  static final ArtworkCacheService _artworkService = ArtworkCacheService();

  /// Get recently added songs - sorted and limited
  static List<SongModel> _getRecentSongs(List<SongModel> songs) {
    if (songs.isEmpty) return [];
    final sorted = List<SongModel>.from(songs)
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return sorted.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector with songs hashCode to detect actual list changes
    // This is more efficient than rebuilding on every notifyListeners call
    return Selector<AudioPlayerService, List<SongModel>>(
      selector: (_, service) => service.songs,
      // Only rebuild when songs list identity changes
      shouldRebuild: (previous, next) =>
          previous.length != next.length ||
          (previous.isNotEmpty &&
              next.isNotEmpty &&
              previous.first.id != next.first.id),
      builder: (context, allSongs, _) {
        final recentSongs = _getRecentSongs(allSongs);

        if (recentSongs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppLocalizations.of(context).translate('No_data'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ),
          );
        }

        final audioPlayerService = context.read<AudioPlayerService>();

        return SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recentSongs.length,
            itemBuilder: (context, index) {
              final song = recentSongs[index];
              return RepaintBoundary(
                child: GlassmorphicCard.song(
                  key: ValueKey(song.id),
                  songId: song.id,
                  title: song.title,
                  artist: splitArtists(song.artist ?? '').first,
                  artworkService: _artworkService,
                  badge: const CardBadge(text: 'NEW'),
                  onTap: () {
                    audioPlayerService.setPlaylist(recentSongs, index);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

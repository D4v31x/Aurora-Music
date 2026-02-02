import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:aurora_music_v01/core/constants/app_config.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/widgets/glassmorphic_card.dart';

/// Horizontal scrollable glassmorphic section showing recently added songs
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key});

  static final ArtworkCacheService _artworkService = ArtworkCacheService();

  /// Get recently added songs for display - sorted and limited to 10
  static List<SongModel> _getDisplaySongs(List<SongModel> songs) {
    if (songs.isEmpty) return [];
    final sorted = List<SongModel>.from(songs)
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return sorted.take(10).toList();
  }

  /// Get full recently added playlist for playback - all songs sorted by date
  static List<SongModel> _getFullPlaylist(List<SongModel> songs) {
    if (songs.isEmpty) return [];
    final sorted = List<SongModel>.from(songs)
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return sorted;
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
        final displaySongs = _getDisplaySongs(allSongs);
        final fullPlaylist = _getFullPlaylist(allSongs);

        if (displaySongs.isEmpty) {
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
            itemCount: displaySongs.length,
            // Performance: Pre-cache items beyond visible area for smoother scrolling
            cacheExtent: AppConfig.horizontalListCacheExtent,
            itemBuilder: (context, index) {
              final song = displaySongs[index];
              // Find the index in the full playlist
              final fullPlaylistIndex =
                  fullPlaylist.indexWhere((s) => s.id == song.id);
              return RepaintBoundary(
                child: GlassmorphicCard.song(
                  key: ValueKey(song.id),
                  songId: song.id,
                  title: song.title,
                  artist: splitArtists(song.artist ?? '').first,
                  artworkService: _artworkService,
                  badge: const CardBadge(text: 'NEW'),
                  onTap: () {
                    // Play from full playlist, starting at the correct index
                    audioPlayerService.setPlaylist(
                      fullPlaylist,
                      fullPlaylistIndex >= 0 ? fullPlaylistIndex : index,
                      source: const PlaybackSourceInfo(
                          source: PlaybackSource.recentlyAdded),
                    );
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

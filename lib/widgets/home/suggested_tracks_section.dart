import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/expandable_player_controller.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';

class SuggestedTracksSection extends StatelessWidget {
  final List<SongModel> randomSongs;

  const SuggestedTracksSection({
    super.key,
    required this.randomSongs,
  });

  void _onSuggestedSongTap(
      BuildContext context, SongModel song, List<SongModel> suggestedSongs) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController =
        Provider.of<ExpandablePlayerController>(context, listen: false);

    final initialIndex = suggestedSongs.indexOf(song);

    audioPlayerService.setPlaylist(suggestedSongs, initialIndex);
    expandableController.show();
  }

  @override
  Widget build(BuildContext context) {
    final artworkService = ArtworkCacheService();

    if (randomSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context).translate('No_data'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final topThreeSongs = randomSongs.take(3).toList();

    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        final likedSongsPlaylist = audioPlayerService.likedSongsPlaylist;

        return RepaintBoundary(
          child: AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: topThreeSongs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final song = entry.value;
                  final isLiked =
                      likedSongsPlaylist?.songs.any((s) => s.id == song.id) ??
                          false;

                  return RepaintBoundary(
                    key: ValueKey(song.id),
                    child: _buildSongItem(context, song, isLiked, topThreeSongs,
                        artworkService, index),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongItem(
    BuildContext context,
    SongModel song,
    bool isLiked,
    List<SongModel> topThreeSongs,
    ArtworkCacheService artworkService,
    int index,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onSuggestedSongTap(context, song, topThreeSongs),
        child: Row(
          children: [
            RepaintBoundary(
              child: artworkService.buildCachedArtwork(
                song.id,
                size: 60,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ProductSans',
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    splitArtists(song.artist ?? '').join(', '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontFamily: 'ProductSans',
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).iconTheme.color,
                ),
                onPressed: () {
                  // Handle like/unlike action
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

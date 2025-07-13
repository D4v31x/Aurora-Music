import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/Audio_Player_Service.dart';
import '../../services/expandable_player_controller.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../glassmorphic_container.dart';

class SuggestedTracksSection extends StatelessWidget {
  final List<SongModel> randomSongs;
  
  const SuggestedTracksSection({
    super.key,
    required this.randomSongs,
  });

  void _onSuggestedSongTap(BuildContext context, SongModel song, List<SongModel> suggestedSongs) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController = Provider.of<ExpandablePlayerController>(context, listen: false);

    final initialIndex = suggestedSongs.indexOf(song);

    audioPlayerService.setPlaylist(suggestedSongs, initialIndex);
    audioPlayerService.play();
    expandableController.show();
  }

  @override
  Widget build(BuildContext context) {
    final artworkService = ArtworkCacheService();
    
    if (randomSongs.isEmpty) {
      return glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context).translate('No_data'),
            style: const TextStyle(color: Colors.white),
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
                children: topThreeSongs.map((song) {
                  final isLiked = likedSongsPlaylist?.songs.any((s) => s.id == song.id) ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onSuggestedSongTap(context, song, topThreeSongs),
                        child: glassmorphicContainer(
                          child: ListTile(
                            leading: RepaintBoundary(
                              child: artworkService.buildCachedArtwork(
                                song.id,
                                size: 50,
                              ),
                            ),
                            title: Text(
                              song.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              splitArtists(song.artist ?? '').join(', '),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.pink : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
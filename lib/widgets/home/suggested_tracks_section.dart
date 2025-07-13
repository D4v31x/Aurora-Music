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
    const artworkService = ArtworkCacheService();
    
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
            child: topThreeSongs.length > 5 
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topThreeSongs.length,
                  cacheExtent: 200, // Optimize cache for performance
                  itemExtent: 80, // Fixed height for better performance
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final song = topThreeSongs[index];
                    final isLiked = likedSongsPlaylist?.songs.any((s) => s.id == song.id) ?? false;
                    
                    return _OptimizedSongItem(
                      key: ValueKey(song.id),
                      song: song,
                      isLiked: isLiked,
                      topThreeSongs: topThreeSongs,
                      artworkService: artworkService,
                      onTap: () => _onSuggestedSongTap(context, song, topThreeSongs),
                    );
                  },
                )
              : Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: topThreeSongs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final song = entry.value;
                      final isLiked = likedSongsPlaylist?.songs.any((s) => s.id == song.id) ?? false;

                      return _OptimizedSongItem(
                        key: ValueKey(song.id),
                        song: song,
                        isLiked: isLiked,
                        topThreeSongs: topThreeSongs,
                        artworkService: artworkService,
                        onTap: () => _onSuggestedSongTap(context, song, topThreeSongs),
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

/// Optimized song item widget with AutomaticKeepAliveClientMixin for performance
class _OptimizedSongItem extends StatefulWidget {
  final SongModel song;
  final bool isLiked;
  final List<SongModel> topThreeSongs;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;
  
  const _OptimizedSongItem({
    Key? key,
    required this.song,
    required this.isLiked,
    required this.topThreeSongs,
    required this.artworkService,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_OptimizedSongItem> createState() => _OptimizedSongItemState();
}

class _OptimizedSongItemState extends State<_OptimizedSongItem> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Keep expensive list items alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: glassmorphicContainer(
            child: ListTile(
              leading: RepaintBoundary(
                child: widget.artworkService.buildCachedArtwork(
                  widget.song.id,
                  size: 50,
                ),
              ),
              title: Text(
                widget.song.title,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                splitArtists(widget.song.artist ?? '').join(', '),
                style: const TextStyle(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                color: widget.isLiked ? Colors.pink : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
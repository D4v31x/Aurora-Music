import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../../models/playlist_model.dart';

class SuggestedTracksSection extends StatelessWidget {
  final List<SongModel> randomSongs;
  static final ArtworkCacheService _artworkService = ArtworkCacheService();

  const SuggestedTracksSection({
    super.key,
    required this.randomSongs,
  });

  void _onSuggestedSongTap(
      BuildContext context, SongModel song, List<SongModel> suggestedSongs) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);

    final initialIndex = suggestedSongs.indexWhere((s) => s.id == song.id);

    if (initialIndex >= 0) {
      audioPlayerService.setPlaylist(suggestedSongs, initialIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Selector<AudioPlayerService, Playlist?>(
      selector: (context, audioService) => audioService.likedSongsPlaylist,
      builder: (context, likedSongsPlaylist, child) {
        return AnimationLimiter(
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: topThreeSongs.asMap().entries.map((entry) {
                final song = entry.value;
                final isLiked =
                    likedSongsPlaylist?.songs.any((s) => s.id == song.id) ??
                        false;

                return RepaintBoundary(
                  key: ValueKey(song.id),
                  child: _SuggestedTrackTile(
                    song: song,
                    isLiked: isLiked,
                    artworkService: _artworkService,
                    onTap: () =>
                        _onSuggestedSongTap(context, song, topThreeSongs),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestedTrackTile extends StatelessWidget {
  final SongModel song;
  final bool isLiked;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _SuggestedTrackTile({
    required this.song,
    required this.isLiked,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12.0),
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
              child: Row(
                children: [
                  RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: artworkService.buildCachedArtwork(
                        song.id,
                        size: 56,
                      ),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'ProductSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          splitArtists(song.artist ?? '').join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: 'ProductSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked
                          ? theme.colorScheme.primary
                          : theme.iconTheme.color,
                    ),
                    onPressed: () {
                      final audioPlayerService =
                          Provider.of<AudioPlayerService>(context,
                              listen: false);
                      audioPlayerService.toggleLike(song);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

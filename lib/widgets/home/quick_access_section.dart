import 'package:aurora_music_v01/models/playlist_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../screens/PlaylistDetail_screen.dart';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        final likedSongsPlaylist = audioPlayerService.likedSongsPlaylist;

        if (likedSongsPlaylist == null) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  _buildLikedSongsCard(context, likedSongsPlaylist),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikedSongsCard(
      BuildContext context, Playlist likedSongsPlaylist) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PlaylistDetailScreen(playlist: likedSongsPlaylist),
            ),
          );
        },
        child: Row(
          children: [
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/UI/liked_icon.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
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
                    likedSongsPlaylist.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ProductSans',
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${likedSongsPlaylist.songs.length} ${AppLocalizations.of(context).translate('tracks')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontFamily: 'ProductSans',
                        ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.play_arrow_rounded, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

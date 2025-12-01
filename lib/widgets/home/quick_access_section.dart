import 'package:aurora_music_v01/models/playlist_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../screens/PlaylistDetail_screen.dart';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';
import '../glassmorphic_container.dart';

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AudioPlayerService, Playlist?>(
      selector: (context, audioService) => audioService.likedSongsPlaylist,
      builder: (context, likedSongsPlaylist, child) {
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
                  _QuickAccessCard(likedSongsPlaylist: likedSongsPlaylist),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final Playlist likedSongsPlaylist;

  const _QuickAccessCard({required this.likedSongsPlaylist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PlaylistDetailScreen(playlist: likedSongsPlaylist),
          ),
        );
      },
      child: glassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/UI/liked_icon.png',
                    width: 56,
                    height: 56,
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
                                .withValues(alpha: 0.6),
                            fontFamily: 'ProductSans',
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                children: [
                  if (likedSongsPlaylist != null)
                    glassmorphicContainer(
                      child: ListTile(
                        leading: RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/UI/liked_icon.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          likedSongsPlaylist.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${likedSongsPlaylist.songs.length} ${AppLocalizations.of(context).translate('tracks')}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailScreen(
                                playlist: likedSongsPlaylist,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (likedSongsPlaylist == null)
                    glassmorphicContainer(
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No data to display',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
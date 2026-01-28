import 'package:flutter/material.dart';
import '../../mixins/services/audio_player_service.dart';

/// A like/favorite button for the current song.
///
/// Uses ValueListenableBuilder to efficiently update only when the
/// liked songs set changes.
class SongLikeButton extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final double size;
  final Color likedColor;
  final Color unlikedColor;

  const SongLikeButton({
    super.key,
    required this.audioPlayerService,
    this.size = 30,
    this.likedColor = Colors.red,
    this.unlikedColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: audioPlayerService.likedSongsNotifier,
      builder: (context, likedSongs, _) {
        final currentSong = audioPlayerService.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final isLiked = likedSongs.contains(currentSong.id.toString());
        return IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? likedColor : unlikedColor,
            size: size,
          ),
          onPressed: () {
            audioPlayerService.toggleLike(currentSong);
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../shared/services/audio_player_service.dart';

/// Playback controls for the music player.
///
/// Displays shuffle, skip previous, play/pause, skip next, and repeat buttons.
/// Uses ValueListenableBuilder for efficient updates when playback state changes.
class PlayerControls extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final bool isTablet;

  const PlayerControls({
    super.key,
    required this.audioPlayerService,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isTablet ? 28.0 : 24.0;
    final playIconSize = isTablet ? 56.0 : 48.0;
    final skipIconSize = isTablet ? 40.0 : 36.0;

    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildShuffleButton(iconSize),
          _buildSkipPreviousButton(skipIconSize),
          _buildPlayPauseButton(playIconSize),
          _buildSkipNextButton(skipIconSize),
          _buildRepeatButton(iconSize),
        ],
      ),
    );
  }

  Widget _buildShuffleButton(double iconSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioPlayerService.isShuffleNotifier,
      builder: (context, isShuffle, _) {
        return IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color:
                isShuffle ? Colors.white : Colors.white.withValues(alpha: 0.5),
            size: iconSize,
          ),
          onPressed: audioPlayerService.toggleShuffle,
        );
      },
    );
  }

  Widget _buildSkipPreviousButton(double iconSize) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous_rounded,
        color: Colors.white,
        size: iconSize,
      ),
      onPressed: audioPlayerService.back,
    );
  }

  Widget _buildPlayPauseButton(double iconSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioPlayerService.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: iconSize,
          ),
          onPressed: () {
            if (isPlaying) {
              audioPlayerService.pause();
            } else {
              audioPlayerService.resume();
            }
          },
        );
      },
    );
  }

  Widget _buildSkipNextButton(double iconSize) {
    return IconButton(
      icon: Icon(
        Icons.skip_next_rounded,
        color: Colors.white,
        size: iconSize,
      ),
      onPressed: audioPlayerService.skip,
    );
  }

  Widget _buildRepeatButton(double iconSize) {
    return ValueListenableBuilder<LoopMode>(
      valueListenable: audioPlayerService.loopModeNotifier,
      builder: (context, loopMode, _) {
        IconData icon;
        Color color;

        switch (loopMode) {
          case LoopMode.off:
            icon = Icons.repeat_rounded;
            color = Colors.white.withValues(alpha: 0.5);
            break;
          case LoopMode.one:
            icon = Icons.repeat_one_rounded;
            color = Colors.white;
            break;
          case LoopMode.all:
            icon = Icons.repeat_rounded;
            color = Colors.white;
            break;
        }

        return IconButton(
          icon: Icon(icon, color: color, size: iconSize),
          onPressed: audioPlayerService.toggleRepeat,
        );
      },
    );
  }
}

/// A simple play/pause button widget.
///
/// Standalone button that can be used in various contexts.
class PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final Color color;
  final Color? backgroundColor;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 64,
    this.color = Colors.white,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.1),
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: color,
          size: size * 0.5,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

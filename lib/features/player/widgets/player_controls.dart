import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart';
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
    final iconSize = isTablet ? 26.0 : 22.0;
    final playIconSize = isTablet ? 50.0 : 42.0;
    final skipIconSize = isTablet ? 38.0 : 31.0;

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
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          icon: Shuffle(
            color:
                isShuffle ? Colors.white : Colors.white.withValues(alpha: 0.5),
            width: iconSize,
            height: iconSize,
          ),
          onPressed: audioPlayerService.toggleShuffle,
        );
      },
    );
  }

  Widget _buildSkipPreviousButton(double iconSize) {
    return IconButton(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      icon: SkipPrevSolid(
        color: Colors.white,
        width: iconSize,
        height: iconSize,
      ),
      onPressed: audioPlayerService.back,
    );
  }

  Widget _buildPlayPauseButton(double iconSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioPlayerService.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return IconButton(
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          icon: isPlaying
              ? PauseSolid(color: Colors.white, width: iconSize, height: iconSize)
              : PlaySolid(color: Colors.white, width: iconSize, height: iconSize),
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
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      icon: SkipNextSolid(
        color: Colors.white,
        width: iconSize,
        height: iconSize,
      ),
      onPressed: audioPlayerService.skip,
    );
  }

  Widget _buildRepeatButton(double iconSize) {
    return ValueListenableBuilder<LoopMode>(
      valueListenable: audioPlayerService.loopModeNotifier,
      builder: (context, loopMode, _) {
        Widget icon;

        switch (loopMode) {
          case LoopMode.off:
            icon = Repeat(
              color: Colors.white.withValues(alpha: 0.5),
              width: iconSize,
              height: iconSize,
            );
            break;
          case LoopMode.one:
            icon = RepeatOnce(
              color: Colors.white,
              width: iconSize,
              height: iconSize,
            );
            break;
          case LoopMode.all:
            icon = Repeat(
              color: Colors.white,
              width: iconSize,
              height: iconSize,
            );
            break;
        }

        return IconButton(
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          icon: icon,
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
        icon: isPlaying
            ? Pause(color: color, width: size * 0.5, height: size * 0.5)
            : Play(color: color, width: size * 0.5, height: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }
}

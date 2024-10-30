import 'package:flutter/material.dart';
import '../services/Audio_Player_Service.dart';

class PlayerControls extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final bool isPlaying;

  const PlayerControls({
    super.key,
    required this.audioPlayerService,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              audioPlayerService.isShuffle ? Icons.shuffle : Icons.shuffle_outlined,
              color: audioPlayerService.isShuffle ? Colors.greenAccent : Colors.white,
              size: 24,
            ),
            onPressed: audioPlayerService.toggleShuffle,
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 35),
            onPressed: audioPlayerService.back,
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 35,
              ),
              onPressed: () {
                if (isPlaying) {
                  audioPlayerService.pause();
                } else {
                  audioPlayerService.resume();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 35),
            onPressed: audioPlayerService.skip,
          ),
          IconButton(
            icon: Icon(
              audioPlayerService.isRepeat ? Icons.repeat_one : Icons.repeat,
              color: audioPlayerService.isRepeat ? Colors.greenAccent : Colors.white,
              size: 24,
            ),
            onPressed: audioPlayerService.toggleRepeat,
          ),
        ],
      ),
    );
  }
}
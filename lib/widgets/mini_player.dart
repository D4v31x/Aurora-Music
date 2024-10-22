import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/Audio_Player_Service.dart';
import 'dart:typed_data';

class MiniPlayer extends StatelessWidget {
  final SongModel currentSong;

  const MiniPlayer({
    super.key,
    required this.currentSong,
  });

  String sanitizeText(String? text) {
    return text?.replaceAll(RegExp(r'[^\x20-\x7E]'), '') ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Material(
      color: Colors.transparent, // Make the Material background transparent
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'albumArtHero',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FutureBuilder<Uint8List?>(
                      future: audioPlayerService.getCurrentSongArtwork(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          );
                        } else {
                          return Image.asset(
                            'assets/images/logo/default_art.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'songTitleHero',
                        child: Text(
                          sanitizeText(currentSong.title),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Hero(
                        tag: 'artistNameHero',
                        child: Text(
                          sanitizeText(currentSong.artist),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    audioPlayerService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (audioPlayerService.isPlaying) {
                      audioPlayerService.pause();
                    } else {
                      audioPlayerService.resume();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

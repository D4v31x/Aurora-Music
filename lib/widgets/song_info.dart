import 'package:flutter/material.dart';
import '../screens/Artist_screen.dart';
import '../services/Audio_Player_Service.dart';

import '../models/utils.dart';

class SongInfo extends StatelessWidget {
  final AudioPlayerService audioPlayerService;

  const SongInfo({
    super.key,
    required this.audioPlayerService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          audioPlayerService.currentSong?.title ?? 'No song playing',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (audioPlayerService.currentSong != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistDetailsScreen(
                    artistName: splitArtists(
                      audioPlayerService.currentSong!.artist ?? 'Unknown artist',
                    ).first,
                    artistImagePath: null,
                  ),
                ),
              );
            }
          },
          child: Text(
            audioPlayerService.currentSong?.artist ?? 'Unknown artist',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}
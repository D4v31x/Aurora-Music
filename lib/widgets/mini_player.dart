import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/Audio_Player_Service.dart';
import '../services/expandable_player_controller.dart';
import '../services/artwork_cache_service.dart';

class MiniPlayer extends StatefulWidget {
  final SongModel currentSong;
  
  const MiniPlayer({
    Key? key,
    required this.currentSong,
  }) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _artworkService = ArtworkCacheService();
  Color? dominantColor;
  final double _minHeight = 65.0;

  @override
  void initState() {
    super.initState();
    _updateDominantColor();
  }

  @override
  void didUpdateWidget(MiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong.id != widget.currentSong.id) {
      _updateDominantColor();
    }
  }

  Future<void> _updateDominantColor() async {
    final artwork = await _artworkService.getArtwork(widget.currentSong.id);
    if (artwork != null) {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        MemoryImage(artwork),
        size: const Size(50, 50), // menší velikost pro rychlejší zpracování
      );
      if (mounted) {
        setState(() {
          dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
        });
      }
    }
  }

  Color getTextColor(Color backgroundColor) {
    // Výpočet relativní luminance podle WCAG 2.0
    double luminance = (0.299 * backgroundColor.red + 
                       0.587 * backgroundColor.green + 
                       0.114 * backgroundColor.blue) / 255;
    
    // Pokud je pozadí světlé, vrátíme černou, jinak bílou
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final textColor = dominantColor != null ? getTextColor(dominantColor!) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 65 + bottomPadding,
        decoration: BoxDecoration(
          color: dominantColor?.withOpacity(0.95) ?? Colors.black.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // Artwork s vylepšenou Hero animací
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Hero(
                tag: 'artwork',
                createRectTween: (begin, end) {
                  return MaterialRectCenterArcTween(begin: begin, end: end);
                },
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: QueryArtworkWidget(
                        id: widget.currentSong.id,
                        type: ArtworkType.AUDIO,
                        nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Informace o skladbě s vylepšenými Hero animacemi
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'title',
                      createRectTween: (begin, end) {
                        return MaterialRectCenterArcTween(begin: begin, end: end);
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.currentSong.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Hero(
                      tag: 'artist',
                      createRectTween: (begin, end) {
                        return MaterialRectCenterArcTween(begin: begin, end: end);
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.currentSong.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Play/Pause tlačítko
            GestureDetector(
              onTap: () {
                if (audioPlayerService.isPlaying) {
                  audioPlayerService.pause();
                } else {
                  audioPlayerService.resume();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  audioPlayerService.isPlaying 
                      ? Icons.pause_rounded 
                      : Icons.play_arrow_rounded,
                  color: textColor,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

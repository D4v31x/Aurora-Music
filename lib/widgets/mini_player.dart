import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/Audio_Player_Service.dart';
import '../services/artwork_cache_service.dart';
import '../services/performance/performance_manager.dart';

class MiniPlayer extends StatefulWidget {
  final SongModel currentSong;
  
  const MiniPlayer({
    super.key,
    required this.currentSong,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _artworkService = ArtworkCacheService();
  Color? dominantColor;
  final double _minHeight = 65.0;
  
  // Cache for palette colors to avoid expensive recalculation
  static final Map<int, Color> _paletteCache = {};

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
    // Check cache first
    if (_paletteCache.containsKey(widget.currentSong.id)) {
      if (mounted) {
        setState(() {
          dominantColor = _paletteCache[widget.currentSong.id];
        });
      }
      return;
    }

    final artwork = await _artworkService.getArtwork(widget.currentSong.id);
    if (artwork != null) {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        MemoryImage(artwork),
        size: const Size(50, 50), // menší velikost pro rychlejší zpracování
      );
      if (mounted) {
        final color = paletteGenerator.dominantColor?.color ?? Colors.black;
        
        // Cache the result
        _paletteCache[widget.currentSong.id] = color;
        
        // Clean up cache if it gets too large
        if (PerformanceManager.shouldCleanup(_paletteCache)) {
          PerformanceManager.cleanupCache(_paletteCache);
        }
        
        setState(() {
          dominantColor = color;
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final textColor = dominantColor != null ? getTextColor(dominantColor!) : Colors.white;

    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        return RepaintBoundary(
          child: Material(
      color: Colors.transparent,
      child: Container(
        height: _minHeight + bottomPadding,
        decoration: BoxDecoration(
          color: dominantColor?.withOpacity(0.95) ?? Colors.black.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // Artwork s Hero animací
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Hero(
                tag: 'currentArtwork',
                createRectTween: (begin, end) {
                  return MaterialRectCenterArcTween(begin: begin, end: end);
                },
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _artworkService.buildCachedArtwork(
                        widget.currentSong.id,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Informace o skladbě s Hero animacemi
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'currentTitle',
                      placeholderBuilder: (context, size, child) {
                        return child;
                      },
                      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
                        return DefaultTextStyleTransition(
                          style: TextStyleTween(
                            begin: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            end: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate(animation),
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              widget.currentSong.title,
                              style: const TextStyle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
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
                      tag: 'currentArtist',
                      placeholderBuilder: (context, size, child) {
                        return child;
                      },
                      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
                        return DefaultTextStyleTransition(
                          style: TextStyleTween(
                            begin: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                            end: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ).animate(animation),
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              widget.currentSong.artist ?? 'Unknown Artist',
                              style: const TextStyle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
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
            // Tlačítko pro přehrávání/pauzu
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (audioPlayerService.isPlaying) {
                  audioPlayerService.pause();
                } else {
                  audioPlayerService.resume();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
      },
    );
  }
}

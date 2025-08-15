import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/performance/performance_manager.dart';
import '../services/expandable_player_controller.dart';
import '../services/background_manager_service.dart';

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

    // Update background manager colors
    if (mounted) {
      final backgroundManager = Provider.of<BackgroundManagerService>(context, listen: false);
      await backgroundManager.updateColorsFromSong(widget.currentSong);
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
          child: GestureDetector(
            onTap: () => Provider.of<ExpandablePlayerController>(context, listen: false).expand(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: bottomPadding + 16.0, // Add space underneath
                ),
                height: _minHeight,
                decoration: BoxDecoration(
                  color: dominantColor?.withOpacity(0.95) ?? Colors.black.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32.0), // Pill-shaped design
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20.0,
                      spreadRadius: 0.0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Artwork with Hero animation and enhanced styling
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Hero(
                        tag: 'playerArtwork', // updated to match NowPlayingScreen
                        createRectTween: (begin, end) {
                          return MaterialRectCenterArcTween(begin: begin, end: end);
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20), // Circular artwork
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8.0,
                                  spreadRadius: 0.0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _artworkService.buildCachedArtwork(
                                widget.currentSong.id,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Song information with Hero animations
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'playerTitle',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  widget.currentSong.title,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Hero(
                              tag: 'playerArtist',
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
                    // Play/pause button with enhanced styling
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (audioPlayerService.isPlaying) {
                          audioPlayerService.pause();
                        } else {
                          audioPlayerService.resume();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          audioPlayerService.isPlaying 
                              ? Icons.pause_rounded 
                              : Icons.play_arrow_rounded,
                          color: textColor,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

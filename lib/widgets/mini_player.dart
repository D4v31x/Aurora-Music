import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/performance/performance_manager.dart';
import '../services/expandable_player_controller.dart';

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
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();
  Color? dominantColor;
  final double _minHeight = 60.0;

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

    // Background colors are now automatically updated by AudioPlayerService
    // Previously updated background manager colors here:
    // if (mounted) {
    //   final backgroundManager = Provider.of<BackgroundManagerService>(context, listen: false);
    //   await backgroundManager.updateColorsFromSong(widget.currentSong);
    // }

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
            0.114 * backgroundColor.blue) /
        255;

    // Pokud je pozadí světlé, vrátíme černou, jinak bílou
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayerService, child) {
        return RepaintBoundary(
          child: GestureDetector(
            onTap: () =>
                Provider.of<ExpandablePlayerController>(context, listen: false)
                    .expand(),
            child: Container(
              margin: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: bottomPadding + 16.0,
              ),
              height: _minHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: _minHeight,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.centerLeft,
                        radius: 1.5,
                        colors: dominantColor != null
                            ? [
                                dominantColor!.withOpacity(0.85),
                                dominantColor!.withOpacity(0.3),
                              ]
                            : [
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.1),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(32.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Artwork with enhanced Hero animation
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Hero(
                            tag: 'songArtwork',
                            createRectTween: (begin, end) {
                              return MaterialRectCenterArcTween(
                                  begin: begin, end: end);
                            },
                            flightShuttleBuilder: (
                              BuildContext flightContext,
                              Animation<double> animation,
                              HeroFlightDirection flightDirection,
                              BuildContext fromHeroContext,
                              BuildContext toHeroContext,
                            ) {
                              final Hero toHero = toHeroContext.widget as Hero;
                              return Material(
                                color: Colors.transparent,
                                child: AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    final curvedValue = Curves.easeOutCubic
                                        .transform(animation.value);
                                    final borderRadius = BorderRadius.circular(
                                      27 + (8 - 27) * curvedValue,
                                    );
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: borderRadius,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                                0.4 * (1 - curvedValue)),
                                            blurRadius:
                                                12.0 * (1 - curvedValue),
                                            spreadRadius: 0.0,
                                            offset: Offset(
                                                0, 4 * (1 - curvedValue)),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: borderRadius,
                                        child: toHero.child,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(27),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 12.0,
                                      spreadRadius: 0.0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.0,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(27),
                                  child: _artworkService.buildCachedArtwork(
                                    widget.currentSong.id,
                                    size: 54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Song information with enhanced Hero animations
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Hero(
                                  tag: 'songTitle',
                                  flightShuttleBuilder: (
                                    BuildContext flightContext,
                                    Animation<double> animation,
                                    HeroFlightDirection flightDirection,
                                    BuildContext fromHeroContext,
                                    BuildContext toHeroContext,
                                  ) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: DefaultTextStyle.merge(
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        child: (toHeroContext.widget as Hero)
                                            .child,
                                      ),
                                    );
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      widget.currentSong.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Hero(
                                  tag: 'songArtist',
                                  flightShuttleBuilder: (
                                    BuildContext flightContext,
                                    Animation<double> animation,
                                    HeroFlightDirection flightDirection,
                                    BuildContext fromHeroContext,
                                    BuildContext toHeroContext,
                                  ) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: DefaultTextStyle.merge(
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                        ),
                                        child: (toHeroContext.widget as Hero)
                                            .child,
                                      ),
                                    );
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      widget.currentSong.artist ??
                                          'Unknown Artist',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
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
                        // Enhanced play/pause button
                        Padding(
                          padding: const EdgeInsets.only(right: 14.0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (audioPlayerService.isPlaying) {
                                audioPlayerService.pause();
                              } else {
                                audioPlayerService.resume();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                      scale: animation, child: child);
                                },
                                child: Icon(
                                  audioPlayerService.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey(audioPlayerService.isPlaying),
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

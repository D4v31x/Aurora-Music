/// Listening Recap Screen — a period-scoped (7 or 30 day) summary of the
/// user's listening activity. Distinct from ListeningInsightsScreen (all-time);
/// this one focuses on a specific window and is accessed via the aurora banner.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/insights_promo_service.dart';
import '../../../shared/services/smart_suggestions_service.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../l10n/generated/app_localizations.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────

Color _darken(Color c, [double amount = 0.25]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color _ensureDeep(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness(hsl.lightness.clamp(0.05, 0.38))
      .withSaturation(hsl.saturation.clamp(0.5, 1.0))
      .toColor();
}

// ── Data model ────────────────────────────────────────────────────────────────

class _RecapData {
  final int periodDays;
  final int totalListens;
  final int uniqueTracks;
  final int estimatedMinutes;
  final int? mostActiveHour;
  final int? mostActiveWeekday;
  final List<MapEntry<String, int>> topTracks;
  final List<MapEntry<String, int>> topArtists;
  final List<MapEntry<String, int>> topGenres;
  final Map<String, String> trackTitles;      // trackId → "Title — Artist"
  final Map<String, int> trackSongIds;         // trackId → int song ID
  final Map<String, Uint8List?> trackArtworks; // trackId → artwork bytes
  final List<Color> topTrackPalette;           // gradient from #1 track art
  final List<Color> topArtistPalette;          // gradient from top artist art
  final Uint8List? topArtistArtwork;           // art for top artist slide
  final Map<String, Uint8List?> artistArtworks; // artistName → Spotify image bytes

  const _RecapData({
    required this.periodDays,
    required this.totalListens,
    required this.uniqueTracks,
    required this.estimatedMinutes,
    required this.mostActiveHour,
    required this.mostActiveWeekday,
    required this.topTracks,
    required this.topArtists,
    required this.topGenres,
    required this.trackTitles,
    required this.trackSongIds,
    required this.trackArtworks,
    required this.topTrackPalette,
    required this.topArtistPalette,
    required this.topArtistArtwork,
    required this.artistArtworks,
  });
}

// ── Page spec ─────────────────────────────────────────────────────────────────

/// Pairs a full-screen gradient with the slide widget builder for that page.
class _PageSpec {
  final Gradient gradient;
  final Widget Function(BuildContext ctx, bool isLast, bool isActive) builder;
  const _PageSpec({required this.gradient, required this.builder});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ListeningRecapScreen extends StatefulWidget {
  const ListeningRecapScreen({super.key});

  @override
  State<ListeningRecapScreen> createState() => _ListeningRecapScreenState();
}

class _ListeningRecapScreenState extends State<ListeningRecapScreen> {
  _RecapData? _data;
  bool _loading = true;
  int _periodDays = InsightsPromoService.defaultPeriodDays;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // weekdays are now localized — see _buildPageSpecs

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChange);
    _loadRecap();
  }

  void _onPageChange() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage && mounted) setState(() => _currentPage = page);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChange);
    _pageController.dispose();
    super.dispose();
  }

  /// Extract a [dark, light] palette pair from raw artwork bytes.
  Future<List<Color>?> _extractPalette(Uint8List bytes) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        size: const Size(150, 150),
      );
      final c1 = palette.vibrantColor?.color ?? palette.dominantColor?.color;
      final c2 =
          palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color;
      if (c1 != null && c2 != null) {
        return [_ensureDeep(c1), _ensureDeep(c2)];
      }
      if (c1 != null) {
        return [_ensureDeep(c1), _darken(_ensureDeep(c1), 0.28)];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadRecap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _currentPage = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);

    final period = await InsightsPromoService.getRecapPeriodDays();
    if (!mounted) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final svc = SmartSuggestionsService();
    await svc.initialize();

    // Anchor the recap window to firstListenTime so data from day 0 is never
    // accidentally excluded by a "now − period" cutoff.
    // e.g. at day 8 with period=7: currentPeriodNum=1 → windowStart = firstListen + 0*7 = day 0.
    DateTime? windowStart;
    final firstListen = svc.firstListenTime;
    if (firstListen != null) {
      final daysSince = DateTime.now().difference(firstListen).inDays;
      final currentPeriodNum = daysSince ~/ period;
      if (currentPeriodNum > 0) {
        windowStart =
            firstListen.add(Duration(days: (currentPeriodNum - 1) * period));
      } else {
        windowStart = firstListen;
      }
    }

    final songById = {
      for (final s in audioService.songs) s.id.toString(): s,
    };

    final trackCounts =
        svc.trackPlayCountsForPeriod(period, fromDate: windowStart);
    final artistCounts =
        svc.artistPlayCountsForPeriod(period, fromDate: windowStart);
    final genreCounts =
        svc.genrePlayCountsForPeriod(period, fromDate: windowStart);

    List<MapEntry<String, int>> sorted(Map<String, int> m, int take) =>
        (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(take)
            .toList();

    final topTracks = sorted(trackCounts, 5);
    final topArtists = sorted(artistCounts, 5);
    final topGenres = sorted(genreCounts, 4);

    final trackTitles = <String, String>{};
    final trackSongIds = <String, int>{};
    for (final e in topTracks) {
      final song = songById[e.key];
      if (song != null) {
        final artist =
            (song.artist?.isNotEmpty == true) ? ' — ${song.artist}' : '';
        trackTitles[e.key] = '${song.title}$artist';
        trackSongIds[e.key] = song.id;
      }
    }

    // Load artwork for top tracks
    final artworkService = ArtworkCacheService();
    final trackArtworks = <String, Uint8List?>{};
    for (final e in topTracks) {
      final id = trackSongIds[e.key];
      if (id != null) {
        trackArtworks[e.key] = await artworkService.getArtwork(id);
      }
    }

    // Palette from #1 track artwork
    var topTrackPalette = <Color>[
      const Color(0xFF0D47A1),
      const Color(0xFF1A237E),
    ];
    if (topTracks.isNotEmpty) {
      final bytes = trackArtworks[topTracks.first.key];
      if (bytes != null && bytes.isNotEmpty) {
        topTrackPalette = await _extractPalette(bytes) ?? topTrackPalette;
      }
    }

    // Load Spotify artist images for all top artists
    final artistArtworks = <String, Uint8List?>{};
    for (final entry in topArtists) {
      final name = entry.key;
      try {
        final path = await artworkService.getArtistImageByName(name);
        if (path != null) {
          artistArtworks[name] = await File(path).readAsBytes();
        } else {
          artistArtworks[name] = null;
        }
      } catch (_) {
        artistArtworks[name] = null;
      }
    }

    // Artwork + palette for top artist (prefer Spotify image, fallback to song art)
    Uint8List? topArtistArtwork;
    var topArtistPalette = <Color>[
      const Color(0xFF1B5E20),
      const Color(0xFF004D40),
    ];
    if (topArtists.isNotEmpty) {
      final artistName = topArtists.first.key;
      // Use Spotify artist image if available
      topArtistArtwork = artistArtworks[artistName];
      // Fallback: use song artwork from a track by this artist
      if (topArtistArtwork == null || topArtistArtwork.isEmpty) {
        for (final e in topTracks) {
          final song = songById[e.key];
          if (song?.artist == artistName && trackArtworks[e.key] != null) {
            topArtistArtwork = trackArtworks[e.key];
            break;
          }
        }
      }
      // Second fallback: load from first song by this artist
      if (topArtistArtwork == null || topArtistArtwork.isEmpty) {
        final idx =
            audioService.songs.indexWhere((s) => s.artist == artistName);
        if (idx >= 0) {
          topArtistArtwork =
              await artworkService.getArtwork(audioService.songs[idx].id);
        }
      }
      if (topArtistArtwork != null && topArtistArtwork.isNotEmpty) {
        topArtistPalette =
            await _extractPalette(topArtistArtwork) ?? topArtistPalette;
      }
    }

    if (mounted) {
      setState(() {
        _periodDays = period;
        _data = _RecapData(
          periodDays: period,
          totalListens: trackCounts.values.fold(0, (a, b) => a + b),
          uniqueTracks: trackCounts.keys.length,
          estimatedMinutes:
              svc.estimatedMinutesForPeriod(period, fromDate: windowStart),
          mostActiveHour:
              svc.mostActiveHourForPeriod(period, fromDate: windowStart),
          mostActiveWeekday:
              svc.mostActiveWeekdayForPeriod(period, fromDate: windowStart),
          topTracks: topTracks,
          topArtists: topArtists,
          topGenres: topGenres,
          trackTitles: trackTitles,
          trackSongIds: trackSongIds,
          trackArtworks: trackArtworks,
          topTrackPalette: topTrackPalette,
          topArtistPalette: topArtistPalette,
          topArtistArtwork: topArtistArtwork,
          artistArtworks: artistArtworks,
        );
        _loading = false;
      });
    }
  }

  String _hourLabel(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$display $period';
  }

  // ── Build page specs ─────────────────────────────────────────────────────────

  List<_PageSpec> _buildPageSpecs(_RecapData data, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final specs = <_PageSpec>[];
    final pl = data.periodDays == 7 ? l10n.recapWeek : l10n.recapMonth;
    final plCap = data.periodDays == 7 ? l10n.recapPeriodWeek : l10n.recapPeriodMonth;
    final weekdays = [
      l10n.recapWeekdayMonday,
      l10n.recapWeekdayTuesday,
      l10n.recapWeekdayWednesday,
      l10n.recapWeekdayThursday,
      l10n.recapWeekdayFriday,
      l10n.recapWeekdaySaturday,
      l10n.recapWeekdaySunday,
    ];
    final tp = data.topTrackPalette;
    final ap = data.topArtistPalette;

    // 1 — Intro
    specs.add(_PageSpec(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D0060), Color(0xFF100830), Color(0xFF0A0B30)],
        stops: [0.0, 0.5, 1.0],
      ),
      builder: (_, isLast, isActive) =>
          _IntroSlide(periodDays: data.periodDays, isLast: isLast, isActive: isActive),
    ));

    // 2 — Total plays
    if (data.totalListens > 0) {
      specs.add(_PageSpec(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFD81B60), Color(0xFF7B1FA2)],
        ),
        builder: (_, isLast, isActive) => _BigStatSlide(
          eyebrow: l10n.recapPlayedEyebrow(pl),
          bigNumber: '${data.totalListens}',
          label: data.totalListens == 1 ? l10n.recapTimeSingular : l10n.recapTimePlural,
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 3 — Minutes listened
    if (data.estimatedMinutes > 0) {
      final h = data.estimatedMinutes ~/ 60;
      final m = data.estimatedMinutes % 60;
      final bigVal = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';
      specs.add(_PageSpec(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE65100), Color(0xFFAD1457)],
        ),
        builder: (_, isLast, isActive) => _BigStatSlide(
          eyebrow: l10n.recapListenedForEyebrow,
          bigNumber: bigVal,
          label: l10n.recapListenedForLabel,
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 4 — #1 Track (palette-driven gradient)
    if (data.topTracks.isNotEmpty) {
      final top = data.topTracks.first;
      specs.add(_PageSpec(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tp[0], tp[1]],
        ),
        builder: (_, isLast, isActive) => _NameSlide(
          eyebrow: l10n.recapTopTrackEyebrow,
          name: data.trackTitles[top.key] ?? top.key,
          count: top.value,
          unit: l10n.recapPlays,
          artwork: data.trackArtworks[top.key],
          paletteColor: tp[0],
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 5 — Top tracks list (slightly darker variant of track palette)
    if (data.topTracks.length > 1) {
      specs.add(_PageSpec(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darken(tp[0], 0.07), _darken(tp[1], 0.05)],
        ),
        builder: (_, isLast, isActive) => _ListSlide(
          title: l10n.recapTopTracksTitle,
          items: data.topTracks,
          labels: data.trackTitles,
          artworks: data.trackArtworks,
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 6 — #1 Artist (artist palette)
    if (data.topArtists.isNotEmpty) {
      final top = data.topArtists.first;
      specs.add(_PageSpec(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ap[0], ap[1]],
        ),
        builder: (_, isLast, isActive) => _NameSlide(
          eyebrow: l10n.recapTopArtistEyebrow,
          name: top.key,
          count: top.value,
          unit: l10n.recapPlays,
          artwork: data.artistArtworks[top.key] ?? data.topArtistArtwork,
          paletteColor: ap[0],
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 6b — Artist rankings list
    if (data.topArtists.length > 1) {
      specs.add(_PageSpec(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darken(ap[0], 0.07), _darken(ap[1], 0.05)],
        ),
        builder: (_, isLast, isActive) => _ArtistListSlide(
          title: l10n.recapTopArtistsTitle,
          artists: data.topArtists,
          artistArtworks: data.artistArtworks,
          isLast: isLast,
          isActive: isActive,
        ),
      ));
    }

    // 8 — Peak activity
    if (data.mostActiveHour != null || data.mostActiveWeekday != null) {
      specs.add(_PageSpec(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1A4A), Color(0xFF1A003A)],
        ),
        builder: (_, isLast, isActive) => _PeakSlide(
          data: data,
          hourLabel: _hourLabel,
          weekdays: weekdays,
          isLast: isLast,
          isActive: isActive,
          l10n: l10n,
        ),
      ));
    }

    // 9 — Summary (always last)
    specs.add(_PageSpec(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF080018),
          tp.isNotEmpty ? _darken(tp[0], 0.12) : const Color(0xFF0A0A28),
        ],
      ),
      builder: (_, isLast, isActive) => _SummarySlide(
        data: data,
        onClose: () => Navigator.pop(context),
        isActive: isActive,
        l10n: l10n,
        periodLabel: plCap,
      ),
    ));

    return specs;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final miniPad = ExpandingPlayer.getMiniPlayerPaddingHeight(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0020),
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF7B2FBE), strokeWidth: 2),
        ),
      );
    }

    final data = _data;
    if (data == null || data.totalListens == 0) {
      return _buildEmpty(context, miniPad);
    }

    final specs = _buildPageSpecs(data, context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen story pages ─────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: specs.length,
            itemBuilder: (ctx, i) {
              final isLast = i == specs.length - 1;
              final isActive = i == _currentPage;
              return DecoratedBox(
                decoration: BoxDecoration(gradient: specs[i].gradient),
                child: Stack(
                  children: [
                    const _AnimatedDecorBlobs(),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: miniPad),
                        child: specs[i].builder(ctx, isLast, isActive),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Top overlay: progress bar + back/period row ──────────────────
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _StoryProgressBar(
                    total: specs.length,
                    current: _currentPage,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _PeriodToggle(
                          currentDays: _periodDays,
                          onChanged: (days) async {
                            await InsightsPromoService.setRecapPeriodDays(days);
                            unawaited(_loadRecap());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, double miniPad) {
    final l10n = AppLocalizations.of(context);
    final period = _periodDays == 7 ? l10n.recapWeek : l10n.recapMonth;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0020),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D0060), Color(0xFF0A0B30)],
              ),
            ),
          ),
          const _AnimatedDecorBlobs(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    children: [
                      const Icon(Icons.headphones_rounded,
                          color: Colors.white30, size: 80),
                      const SizedBox(height: 24),
                      Text(
                        l10n.recapNothingToWrap,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: FontConstants.fontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.recapNothingToWrapBody(period),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _PeriodToggle(
                        currentDays: _periodDays,
                        onChanged: (days) async {
                          await InsightsPromoService.setRecapPeriodDays(days);
                          unawaited(_loadRecap());
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(height: miniPad + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Toggle ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final int currentDays;
  final ValueChanged<int> onChanged;

  const _PeriodToggle({required this.currentDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(context, AppLocalizations.of(context).recapPeriodWeek, 7),
          _pill(context, AppLocalizations.of(context).recapPeriodMonth, 30),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, int days) {
    final selected = currentDays == days;
    return GestureDetector(
      onTap: () => onChanged(days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.22) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Decorative background blobs (animated) ───────────────────────────────────

class _AnimatedDecorBlobs extends StatefulWidget {
  const _AnimatedDecorBlobs();

  @override
  State<_AnimatedDecorBlobs> createState() => _AnimatedDecorBlobsState();
}

class _AnimatedDecorBlobsState extends State<_AnimatedDecorBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) =>
                  CustomPaint(painter: _BlobPainter(progress: _ctrl.value)),
            ),
          ),
        ),
      );
}

class _BlobPainter extends CustomPainter {
  final double progress;
  const _BlobPainter({this.progress = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;
    final t = Curves.easeInOut.transform(progress);
    void blob(double cx, double cy, double baseR, Color color) {
      final r = baseR * (0.90 + 0.12 * t);
      paint.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.16 + 0.06 * t), Colors.transparent],
      ).createShader(Rect.fromCircle(
        center: Offset(cx * size.width, cy * size.height),
        radius: r * size.width,
      ));
      canvas.drawCircle(
          Offset(cx * size.width, cy * size.height), r * size.width, paint);
    }

    blob(0.1, 0.15, 0.65, Colors.white);
    blob(0.9, 0.85, 0.55, Colors.white);
    blob(0.5, 0.50, 0.40, Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) => old.progress != progress;
}

// ── Story-style progress bar ──────────────────────────────────────────────────

class _StoryProgressBar extends StatelessWidget {
  final int total;
  final int current;
  const _StoryProgressBar({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 3.0 : 0.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: filled ? 0.90 : 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Swipe hint (animated bounce) ─────────────────────────────────────────────

class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _offset = Tween<double>(begin: 0, end: -7)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _offset,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _offset.value),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.keyboard_arrow_up_rounded,
              color: Colors.white30, size: 28),
          Text(
            l10n.recapSwipeUp,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated entry wrapper ────────────────────────────────────────────────────

/// Fades and slides a child in when [isActive] becomes true.
/// Each call with a different [delay] creates a staggered entrance effect.
class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Duration delay;
  final Duration duration;
  final double slideDistance;

  const _AnimatedEntry({
    required this.child,
    required this.isActive,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
    this.slideDistance = 32,
  });

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.slideDistance, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.isActive) _scheduleForward();
  }

  @override
  void didUpdateWidget(_AnimatedEntry old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.reset();
      _scheduleForward();
    }
  }

  void _scheduleForward() {
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ── Count-up number text ──────────────────────────────────────────────────────────

/// Animates an integer from 0 to [targetValue] when [isActive] first becomes
/// true. Re-triggers the count-up if the slide is revisited.
class _CountUpText extends StatefulWidget {
  final int targetValue;
  final bool isActive;
  final TextStyle style;

  const _CountUpText({
    required this.targetValue,
    required this.isActive,
    required this.style,
  });

  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = IntTween(begin: 0, end: widget.targetValue)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.isActive) _startCountUp();
  }

  @override
  void didUpdateWidget(_CountUpText old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.reset();
      _startCountUp();
    }
  }

  void _startCountUp() {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text('${_anim.value}', style: widget.style),
    );
  }
}

// ── Intro slide ───────────────────────────────────────────────────────────────

class _IntroSlide extends StatelessWidget {
  final int periodDays;
  final bool isLast;
  final bool isActive;

  const _IntroSlide({
    required this.periodDays,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = periodDays == 7 ? l10n.recapWeekly : l10n.recapMonthly;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 3),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 80),
            child: Text(
              l10n.recapIntroAppName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 220),
            slideDistance: 48,
            duration: const Duration(milliseconds: 650),
            child: Text(
              l10n.recapIntroTitle(label),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 62,
                fontWeight: FontWeight.w900,
                height: 1.0,
                fontFamily: FontConstants.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 400),
            child: Text(
              l10n.recapIntroSubtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 17,
                height: 1.45,
              ),
            ),
          ),
          const Spacer(flex: 2),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Big stat slide ────────────────────────────────────────────────────────────

class _BigStatSlide extends StatelessWidget {
  final String eyebrow;
  final String bigNumber;
  final String label;
  final bool isLast;
  final bool isActive;

  const _BigStatSlide({
    required this.eyebrow,
    required this.bigNumber,
    required this.label,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 3),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 80),
            child: Text(
              eyebrow,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 220),
            slideDistance: 60,
            duration: const Duration(milliseconds: 700),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: int.tryParse(bigNumber) != null
                  ? _CountUpText(
                      targetValue: int.parse(bigNumber),
                      isActive: isActive,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 92,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    )
                  : Text(
                      bigNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 92,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 420),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Spacer(flex: 2),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Name slide (#1 track / #1 artist) ─────────────────────────────────────────

class _NameSlide extends StatelessWidget {
  final String eyebrow;
  final String name;
  final int count;
  final String unit;
  final Uint8List? artwork;
  final Color? paletteColor;
  final bool isLast;
  final bool isActive;

  const _NameSlide({
    required this.eyebrow,
    required this.name,
    required this.count,
    required this.unit,
    required this.isLast,
    required this.isActive,
    this.artwork,
    this.paletteColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = paletteColor ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          // Artwork
          if (artwork != null && artwork!.isNotEmpty)
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 60),
              slideDistance: 24,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.50),
                        blurRadius: 56,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.50),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(
                      artwork!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 160),
            child: Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 280),
            slideDistance: 48,
            duration: const Duration(milliseconds: 650),
            child: Text(
              name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1.05,
                fontFamily: FontConstants.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 420),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '$count $unit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── List slide (top 5 tracks) ─────────────────────────────────────────────────

class _ListSlide extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> items;
  final Map<String, String> labels;
  final Map<String, Uint8List?> artworks;
  final bool isLast;
  final bool isActive;

  const _ListSlide({
    required this.title,
    required this.items,
    required this.labels,
    required this.artworks,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 72),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 50),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(items.length, (i) {
            final name = labels[items[i].key] ?? items[i].key;
            final art = artworks[items[i].key];
            return _AnimatedEntry(
              isActive: isActive,
              delay: Duration(milliseconds: 120 + i * 90),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: i == 0 ? 20 : 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Artwork thumbnail
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: art != null && art.isNotEmpty
                          ? Image.memory(art, fit: BoxFit.cover)
                          : const Icon(Icons.music_note,
                              color: Colors.white30, size: 22),
                    ),
                    const SizedBox(width: 10),
                    // Track name
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.70),
                          fontSize: i == 0 ? 16 : 14,
                          fontWeight:
                              i == 0 ? FontWeight.w700 : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Play count
                    Text(
                      '${items[i].value}×',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: i == 0 ? 0.65 : 0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Artist list slide ─────────────────────────────────────────────────────────

class _ArtistListSlide extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> artists;
  final Map<String, Uint8List?> artistArtworks;
  final bool isLast;
  final bool isActive;

  const _ArtistListSlide({
    required this.title,
    required this.artists,
    required this.artistArtworks,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 72),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 50),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(artists.length, (i) {
            final name = artists[i].key;
            final art = artistArtworks[name];
            return _AnimatedEntry(
              isActive: isActive,
              delay: Duration(milliseconds: 120 + i * 90),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: i == 0 ? 20 : 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Artist picture (circular)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: art != null && art.isNotEmpty
                          ? Image.memory(art, fit: BoxFit.cover)
                          : const Icon(Icons.person,
                              color: Colors.white30, size: 26),
                    ),
                    const SizedBox(width: 10),
                    // Artist name
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.70),
                          fontSize: i == 0 ? 16 : 14,
                          fontWeight:
                              i == 0 ? FontWeight.w700 : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Play count
                    Text(
                      '${artists[i].value}×',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: i == 0 ? 0.65 : 0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Peak slide ────────────────────────────────────────────────────────────────

class _PeakSlide extends StatelessWidget {
  final _RecapData data;
  final String Function(int) hourLabel;
  final List<String> weekdays;
  final bool isLast;
  final bool isActive;
  final AppLocalizations l10n;

  const _PeakSlide({
    required this.data,
    required this.hourLabel,
    required this.weekdays,
    required this.isLast,
    required this.isActive,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final hasHour = data.mostActiveHour != null;
    final hasDay = data.mostActiveWeekday != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 60),
            child: Text(
              l10n.recapYouListenMost,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (hasDay)
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 200),
              slideDistance: 50,
              duration: const Duration(milliseconds: 700),
              child: Text(
                l10n.recapOnDay(weekdays[data.mostActiveWeekday!]),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
            ),
          if (hasDay && hasHour) const SizedBox(height: 8),
          if (hasHour)
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 360),
              slideDistance: 40,
              child: Text(
                l10n.recapAroundTime(hourLabel(data.mostActiveHour!)),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: hasDay ? 0.65 : 1.0),
                  fontSize: hasDay ? 34 : 54,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          const SizedBox(height: 24),
          _AnimatedEntry(
            isActive: isActive,
            delay: const Duration(milliseconds: 500),
            child: Text(
              l10n.recapVibesHitDifferent,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const Spacer(flex: 2),
          if (!isLast) const _SwipeHint(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Summary slide ─────────────────────────────────────────────────────────────

/// Final "That's a Wrap" slide that summarises all key stats for the period.
class _SummarySlide extends StatelessWidget {
  final _RecapData data;
  final VoidCallback onClose;
  final bool isActive;
  final AppLocalizations l10n;
  final String periodLabel;

  const _SummarySlide({
    required this.data,
    required this.onClose,
    required this.isActive,
    required this.l10n,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final topTrack = data.topTracks.isNotEmpty ? data.topTracks.first : null;
    final topArtist =
        data.topArtists.isNotEmpty ? data.topArtists.first.key : null;
    final topArt =
        topTrack != null ? data.trackArtworks[topTrack.key] : null;
    final h = data.estimatedMinutes ~/ 60;
    final m = data.estimatedMinutes % 60;
    final minuteLabel =
        h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 72),
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 60),
              child: Text(
                l10n.recapThatsAWrap,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 180),
              slideDistance: 40,
              duration: const Duration(milliseconds: 650),
              child: Text(
                l10n.recapInNumbers(periodLabel),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  fontFamily: FontConstants.fontFamily,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // #1 track artwork + name
            if (topArt != null && topArt.isNotEmpty) ...[
              _AnimatedEntry(
                isActive: isActive,
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        topArt,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.recapNumberOneTrack,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.trackTitles[topTrack!.key] ?? topTrack.key,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Stats grid
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 380),
              child: _StatsGrid(
                stats: [
                  _StatItem(
                      label: l10n.recapStatTotalPlays, value: '${data.totalListens}'),
                  _StatItem(label: l10n.recapStatTimeListened, value: minuteLabel),
                  _StatItem(
                      label: l10n.recapStatUniqueTracks, value: '${data.uniqueTracks}'),
                  if (topArtist != null)
                    _StatItem(label: l10n.recapStatTopArtist, value: topArtist),
                ],
              ),
            ),
            if (data.topGenres.isNotEmpty) ...[
              const SizedBox(height: 24),
              _AnimatedEntry(
                isActive: isActive,
                delay: const Duration(milliseconds: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.recapYourSoundLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.topGenres.map((e) => e.key).join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 44),
            // Done button
            _AnimatedEntry(
              isActive: isActive,
              delay: const Duration(milliseconds: 580),
              child: Center(
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 44, vertical: 17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Text(
                      l10n.recapDone,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 52),
          ],
        ),
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats.map((s) => _StatCard(item: s)).toList(),
      );
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 56 - 12) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

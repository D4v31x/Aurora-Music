/// Listening Insights screen — a Spotify-Wrapped-style view that surfaces
/// the rich listening-pattern data Aurora Music already collects but never
/// previously showed to the user.
///
/// Data sources:
///   • SmartSuggestionsService  — play counts, hourly/weekday patterns, genres
///   • AudioPlayerService.songs — song metadata for resolving track IDs
///   • ArtworkCacheService      — artwork thumbnails for Top Tracks
library;

import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/smart_suggestions_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/expanding_player.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _InsightsData {
  final int totalListens;
  final int uniqueTracksHeard;
  final int estimatedMinutes;
  final int? mostActiveHour;
  final int? mostActiveWeekday;
  final List<MapEntry<String, int>> topTracks; // trackId → count
  final List<MapEntry<String, int>> topArtists; // artist → count
  final List<MapEntry<String, int>> topGenres; // genre → count
  final Map<int, int> playsByHour; // 0–23
  final Map<int, int> playsByWeekday; // 0–6

  // Resolved track display names from AudioPlayerService
  final Map<String, String> trackTitles; // trackId → "Title – Artist"

  const _InsightsData({
    required this.totalListens,
    required this.uniqueTracksHeard,
    required this.estimatedMinutes,
    required this.mostActiveHour,
    required this.mostActiveWeekday,
    required this.topTracks,
    required this.topArtists,
    required this.topGenres,
    required this.playsByHour,
    required this.playsByWeekday,
    required this.trackTitles,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ListeningInsightsScreen extends StatefulWidget {
  const ListeningInsightsScreen({super.key});

  @override
  State<ListeningInsightsScreen> createState() =>
      _ListeningInsightsScreenState();
}

class _ListeningInsightsScreenState extends State<ListeningInsightsScreen> {
  _InsightsData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final suggestions = SmartSuggestionsService();
    await suggestions.initialize();

    // Build quick-lookup from song id → SongModel
    final songs = audioService.songs;
    final songById = <String, dynamic>{};
    for (final s in songs) {
      songById[s.id.toString()] = s;
    }

    // Resolve track titles
    final trackTitles = <String, String>{};
    for (final entry in suggestions.trackPlayCounts.entries) {
      final song = songById[entry.key];
      if (song != null) {
        final artist = (song.artist as String?)?.isNotEmpty == true
            ? song.artist as String
            : 'Unknown';
        trackTitles[entry.key] = '${song.title}\n$artist';
      }
    }

    // Sort top items
    final sortedTracks = suggestions.trackPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedArtists = suggestions.artistPlayCounts.entries
        .where((e) => e.key.toLowerCase() != 'unknown' && e.key.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedGenres = suggestions.genrePlayCounts.entries
        .where((e) => e.key.toLowerCase() != 'unknown' && e.key.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (!mounted) return;
    setState(() {
      _data = _InsightsData(
        totalListens: suggestions.totalListens,
        uniqueTracksHeard: suggestions.trackPlayCounts.length,
        estimatedMinutes: suggestions.estimatedListeningMinutes,
        mostActiveHour: suggestions.mostActiveHour,
        mostActiveWeekday: suggestions.mostActiveWeekday,
        topTracks: sortedTracks.take(5).toList(),
        topArtists: sortedArtists.take(5).toList(),
        topGenres: sortedGenres.take(6).toList(),
        playsByHour: suggestions.playsByHour,
        playsByWeekday: suggestions.playsByWeekday,
        trackTitles: trackTitles,
      );
      _loading = false;
    });
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────

  static String _hourFull(int h) {
    if (h == 0) return '12 midnight';
    if (h == 12) return '12 noon';
    if (h < 12) return '$h AM';
    return '${h - 12} PM';
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdaysFull = [
    'Mondays',
    'Tuesdays',
    'Wednesdays',
    'Thursdays',
    'Fridays',
    'Saturdays',
    'Sundays'
  ];

  static String _fmtMinutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Music Insights',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: FontConstants.fontFamily,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final data = _data!;
    const hPad = EdgeInsets.symmetric(horizontal: 16);

    return CustomScrollView(
      slivers: [
        // Top spacer for app-bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),

        // ── Quick Stats ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: _QuickStatsRow(data: data),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Activity by Hour ───────────────────────────────────────────────
        if (data.playsByHour.isNotEmpty) ...[
          _sectionHeader('Activity by Time of Day'),
          SliverToBoxAdapter(
            child: Padding(
              padding: hPad,
              child: _HourActivityCard(
                playsByHour: data.playsByHour,
                mostActiveHour: data.mostActiveHour,
                accentColor: theme.colorScheme.primary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Activity by Day ────────────────────────────────────────────────
        if (data.playsByWeekday.isNotEmpty) ...[
          _sectionHeader('Activity by Day'),
          SliverToBoxAdapter(
            child: Padding(
              padding: hPad,
              child: _WeekdayActivityCard(
                playsByWeekday: data.playsByWeekday,
                mostActiveWeekday: data.mostActiveWeekday,
                accentColor: theme.colorScheme.secondary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Top Tracks ─────────────────────────────────────────────────────
        if (data.topTracks.isNotEmpty) ...[
          _sectionHeader('Top Tracks'),
          SliverToBoxAdapter(
            child: Padding(
              padding: hPad,
              child: _TopItemsCard(
                items: data.topTracks,
                labels: data.trackTitles,
                accentColor: theme.colorScheme.primary,
                showArtwork: true,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Top Artists ────────────────────────────────────────────────────
        if (data.topArtists.isNotEmpty) ...[
          _sectionHeader('Top Artists'),
          SliverToBoxAdapter(
            child: Padding(
              padding: hPad,
              child: _TopItemsCard(
                items: data.topArtists,
                accentColor: theme.colorScheme.tertiary,
                showArtwork: false,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Genre Breakdown ────────────────────────────────────────────────
        if (data.topGenres.isNotEmpty) ...[
          _sectionHeader('Genre Breakdown'),
          SliverToBoxAdapter(
            child: Padding(
              padding: hPad,
              child: _GenreCard(
                genres: data.topGenres,
                accentColor: theme.colorScheme.primary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Empty state ────────────────────────────────────────────────────
        if (data.totalListens == 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.music_note_rounded, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No listening data yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play some music to start\nbuilding your insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: SizedBox(
            height: ExpandingPlayer.getMiniPlayerPaddingHeight(context) + 16,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ),
    );
  }
}

// ── Quick Stats Row ───────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final _InsightsData data;
  const _QuickStatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final mins = data.estimatedMinutes;
    final timeLabel = _ListeningInsightsScreenState._fmtMinutes(mins);

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          _QuickStat(
            value: _fmt(data.totalListens),
            label: 'Total\nPlays',
            icon: Icons.play_circle_outline_rounded,
          ),
          _Divider(),
          _QuickStat(
            value: _fmt(data.uniqueTracksHeard),
            label: 'Tracks\nHeard',
            icon: Icons.music_note_rounded,
          ),
          _Divider(),
          _QuickStat(
            value: mins > 0 ? timeLabel : '—',
            label: 'Est.\nListening',
            icon: Icons.access_time_rounded,
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _QuickStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.3,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white12,
    );
  }
}

// ── 24-Hour Activity Card ─────────────────────────────────────────────────────

class _HourActivityCard extends StatelessWidget {
  final Map<int, int> playsByHour;
  final int? mostActiveHour;
  final Color accentColor;

  const _HourActivityCard({
    required this.playsByHour,
    required this.mostActiveHour,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = mostActiveHour != null
        ? 'Most active around ${_ListeningInsightsScreenState._hourFull(mostActiveHour!)}'
        : null;

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Row(
              children: [
                Icon(Icons.nightlight_round,
                    color: accentColor.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: _BarChartPainter(
                counts: List.generate(24, (i) => playsByHour[i] ?? 0),
                highlightIndex: mostActiveHour,
                accentColor: accentColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _AxisLabel('12a'),
              _AxisLabel('6a'),
              _AxisLabel('12p'),
              _AxisLabel('6p'),
              _AxisLabel('12a'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Weekday Activity Card ─────────────────────────────────────────────────────

class _WeekdayActivityCard extends StatelessWidget {
  final Map<int, int> playsByWeekday;
  final int? mostActiveWeekday;
  final Color accentColor;

  const _WeekdayActivityCard({
    required this.playsByWeekday,
    required this.mostActiveWeekday,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = mostActiveWeekday != null
        ? 'Most active on ${_ListeningInsightsScreenState._weekdaysFull[mostActiveWeekday!]}'
        : null;

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: accentColor.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _BarChartPainter(
                counts: List.generate(7, (i) => playsByWeekday[i] ?? 0),
                highlightIndex: mostActiveWeekday,
                accentColor: accentColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _ListeningInsightsScreenState._weekdays
                .map((d) => _AxisLabel(d))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  final String text;
  const _AxisLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontFamily: FontConstants.fontFamily,
      ),
    );
  }
}

// ── Bar Chart Painter ─────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<int> counts;
  final int? highlightIndex;
  final Color accentColor;

  const _BarChartPainter({
    required this.counts,
    required this.highlightIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;

    final maxVal = counts.reduce(max).toDouble();
    if (maxVal == 0) return;

    final barCount = counts.length;
    final totalGapWidth = size.width * 0.3;
    final barWidth = (size.width - totalGapWidth) / barCount;
    final gapWidth = totalGapWidth / max(barCount - 1, 1);
    const minBarHeight = 4.0;

    final normalPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gapWidth);
      final frac = counts[i] / maxVal;
      final barH = max(minBarHeight, frac * size.height);
      final top = size.height - barH;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barH),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, i == highlightIndex ? accentPaint : normalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.counts != counts || old.highlightIndex != highlightIndex;
}

// ── Top Items Card ────────────────────────────────────────────────────────────

class _TopItemsCard extends StatelessWidget {
  final List<MapEntry<String, int>> items;
  final Map<String, String>? labels; // id → display label (for tracks)
  final Color accentColor;
  final bool showArtwork;

  const _TopItemsCard({
    required this.items,
    this.labels,
    required this.accentColor,
    required this.showArtwork,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = items.isEmpty ? 1.0 : items.first.value.toDouble();

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _TopItemRow(
              rank: i + 1,
              id: items[i].key,
              count: items[i].value,
              maxCount: maxCount,
              label: labels?[items[i].key] ?? items[i].key,
              accentColor: accentColor,
              showArtwork: showArtwork,
            ),
            if (i < items.length - 1)
              Divider(
                  color: Colors.white.withValues(alpha: 0.08), height: 1),
          ],
        ],
      ),
    );
  }
}

class _TopItemRow extends StatefulWidget {
  final int rank;
  final String id;
  final int count;
  final double maxCount;
  final String label;
  final Color accentColor;
  final bool showArtwork;

  const _TopItemRow({
    required this.rank,
    required this.id,
    required this.count,
    required this.maxCount,
    required this.label,
    required this.accentColor,
    required this.showArtwork,
  });

  @override
  State<_TopItemRow> createState() => _TopItemRowState();
}

class _TopItemRowState extends State<_TopItemRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static final _artworkService = ArtworkCacheService();
  ImageProvider? _artwork;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());

    if (widget.showArtwork) _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    final id = int.tryParse(widget.id);
    if (id == null) return;
    final provider = await _artworkService.getCachedImageProvider(id);
    if (mounted) setState(() => _artwork = provider);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.label.split('\n');
    final title = parts.isNotEmpty ? parts[0] : widget.label;
    final subtitle = parts.length > 1 ? parts[1] : null;
    final frac = widget.count / widget.maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '${widget.rank}',
              style: TextStyle(
                color: widget.accentColor.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: FontConstants.fontFamily,
              ),
            ),
          ),
          // Artwork thumbnail (tracks only)
          if (widget.showArtwork) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 40,
                height: 40,
                color: Colors.white12,
                child: _artwork != null
                    ? Image(image: _artwork!, fit: BoxFit.cover)
                    : const Icon(Icons.music_note_rounded,
                        color: Colors.white38, size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Label + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: FontConstants.fontFamily,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: frac * _anim.value,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.count}',
              style: TextStyle(
                color: widget.accentColor.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: FontConstants.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Genre Card ────────────────────────────────────────────────────────────────

class _GenreCard extends StatelessWidget {
  final List<MapEntry<String, int>> genres;
  final Color accentColor;

  const _GenreCard({required this.genres, required this.accentColor});

  // Assign a distinct hue to each genre for visual variety
  static const _hues = [220.0, 280.0, 160.0, 40.0, 0.0, 340.0];

  @override
  Widget build(BuildContext context) {
    final maxCount = genres.isEmpty ? 1 : genres.first.value.toDouble();

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          for (int i = 0; i < genres.length; i++) ...[
            _GenreRow(
              name: genres[i].key,
              count: genres[i].value,
              fraction: genres[i].value / maxCount,
              color: HSLColor.fromAHSL(1, _hues[i % _hues.length], 0.7, 0.55)
                  .toColor(),
            ),
            if (i < genres.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GenreRow extends StatefulWidget {
  final String name;
  final int count;
  final double fraction;
  final Color color;

  const _GenreRow({
    required this.name,
    required this.count,
    required this.fraction,
    required this.color,
  });

  @override
  State<_GenreRow> createState() => _GenreRowState();
}

class _GenreRowState extends State<_GenreRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: widget.fraction * _anim.value,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.color.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(
            '${widget.count}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: widget.color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

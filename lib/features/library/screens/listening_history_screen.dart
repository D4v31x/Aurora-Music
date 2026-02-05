/// Listening history screen.
///
/// Displays timeline-based playback history with rewind views
/// and resume functionality.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/listening_history_service.dart';
import '../../../shared/widgets/glassmorphic_container.dart';

/// Screen displaying listening history.
class ListeningHistoryScreen extends StatefulWidget {
  const ListeningHistoryScreen({super.key});

  @override
  State<ListeningHistoryScreen> createState() => _ListeningHistoryScreenState();
}

class _ListeningHistoryScreenState extends State<ListeningHistoryScreen>
    with SingleTickerProviderStateMixin {
  late ListeningHistoryService _historyService;
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  late TabController _tabController;
  bool _serviceReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_serviceReady) {
      _historyService = Provider.of<ListeningHistoryService>(context, listen: false);
      setState(() => _serviceReady = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    // Listen to history changes
    final historyService = Provider.of<ListeningHistoryService>(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('listeningHistory'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.translate('rewindToday')),
            Tab(text: l10n.translate('rewindYesterday')),
            Tab(text: l10n.translate('rewindThisWeek')),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Resume section
                if (_historyService.hasLastSession)
                  _buildResumeCard(context, isDark, l10n),

                // History tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHistoryList(HistoryPeriod.today, isDark, l10n),
                      _buildHistoryList(HistoryPeriod.yesterday, isDark, l10n),
                      _buildHistoryList(HistoryPeriod.thisWeek, isDark, l10n),
                      _buildHistoryList(HistoryPeriod.all, isDark, l10n),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumeCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final session = _historyService.lastSession;
    if (session == null) return const SizedBox.shrink();

    final timeDiff = DateTime.now().difference(session.timestamp);
    String timeAgo;
    if (timeDiff.inMinutes < 60) {
      timeAgo = '${timeDiff.inMinutes} minutes ago';
    } else if (timeDiff.inHours < 24) {
      timeAgo = '${timeDiff.inHours} hours ago';
    } else {
      timeAgo = '${timeDiff.inDays} days ago';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassmorphicContainer(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _resumeSession(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('resumeSession'),
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.queueSongIds.length} tracks • $timeAgo',
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 14,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    HistoryPeriod period,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final history = _historyService.getHistoryForPeriod(period);

    if (history.isEmpty) {
      return _buildEmptyState(isDark, period, l10n);
    }

    // Group by date
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in history) {
      final date = _formatDate(entry.timestamp);
      grouped.putIfAbsent(date, () => []).add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final entries = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                date,
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Entries
            ...entries.map((entry) => _HistoryEntryTile(
                  entry: entry,
                  isDark: isDark,
                  artworkService: _artworkService,
                  onTap: () => _playFromHistory(context, entry),
                )),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    HistoryPeriod period,
    AppLocalizations l10n,
  ) {
    String message;
    switch (period) {
      case HistoryPeriod.today:
        message = 'No tracks played today';
        break;
      case HistoryPeriod.yesterday:
        message = 'No tracks played yesterday';
        break;
      case HistoryPeriod.thisWeek:
        message = 'No tracks played this week';
        break;
      default:
        message = 'No listening history';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 16,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _resumeSession(BuildContext context) async {
    final session = _historyService.lastSession;
    if (session == null) return;

    HapticFeedback.mediumImpact();

    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    final audioQuery = OnAudioQuery();

    // Get songs by IDs
    final songs = await audioQuery.querySongs();
    final sessionSongs = <SongModel>[];
    for (final id in session.queueSongIds) {
      final song = songs.where((s) => s.id == id).firstOrNull;
      if (song != null) {
        sessionSongs.add(song);
      }
    }

    if (sessionSongs.isNotEmpty) {
      await audioService.setPlaylist(
        sessionSongs,
        session.currentIndex.clamp(0, sessionSongs.length - 1),
      );
      // Seek to saved position
      await audioService.audioPlayer.seek(session.position);
    }
  }

  Future<void> _playFromHistory(BuildContext context, HistoryEntry entry) async {
    HapticFeedback.lightImpact();

    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    final audioQuery = OnAudioQuery();

    // Get the song by ID
    final songs = await audioQuery.querySongs();
    final song = songs.where((s) => s.id == entry.songId).firstOrNull;

    if (song != null) {
      await audioService.setPlaylist([song], 0);
      // Optionally seek to last position
      if (entry.lastPosition != null) {
        await audioService.audioPlayer.seek(entry.lastPosition!);
      }
    }
  }
}

/// Individual history entry tile
class _HistoryEntryTile extends StatelessWidget {
  final HistoryEntry entry;
  final bool isDark;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _HistoryEntryTile({
    required this.entry,
    required this.isDark,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Time
                      SizedBox(
                        width: 48,
                        child: Text(
                          time,
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.4),
                          ),
                        ),
                      ),
                      // Artwork
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: artworkService.buildCachedArtwork(
                          entry.songId,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (entry.artist != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                entry.artist!,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  fontSize: 12,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Play indicator
                      Icon(
                        Icons.play_arrow_rounded,
                        color:
                            (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

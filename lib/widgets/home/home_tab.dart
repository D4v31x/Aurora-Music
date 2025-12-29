import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../services/local_caching_service.dart';
import '../../services/home_layout_service.dart';
import '../expanding_player.dart';
import 'for_you_section.dart';
import 'suggested_artists_section.dart';
import 'recently_played_section.dart';
import 'most_played_section.dart';
import 'listening_history_card.dart';
import 'recently_added_section.dart';
import 'music_stats_card.dart';

class HomeTab extends StatefulWidget {
  final List<SongModel> randomSongs;
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;
  final SongModel? currentSong;
  final Future<void> Function() onRefresh;

  const HomeTab({
    super.key,
    required this.randomSongs,
    required this.randomArtists,
    required this.artistService,
    required this.currentSong,
    required this.onRefresh,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await widget.onRefresh();
    HapticFeedback.lightImpact();
  }

  Widget _buildSection(HomeSection section) {
    final l10n = AppLocalizations.of(context);

    switch (section) {
      case HomeSection.forYou:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('for_you')),
            const SizedBox(height: 12.0),
            RepaintBoundary(
              child: ForYouSection(
                key: const ValueKey('for_you_section'),
                randomSongs: widget.randomSongs,
                randomArtists: widget.randomArtists,
                artistService: widget.artistService,
              ),
            ),
            const SizedBox(height: 24.0),
          ],
        );
      case HomeSection.suggestedArtists:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('suggested_artists')),
            const SizedBox(height: 12.0),
            RepaintBoundary(
              child: SuggestedArtistsSection(
                key: const ValueKey('suggested_artists_section'),
                randomArtists: widget.randomArtists,
                artistService: widget.artistService,
              ),
            ),
            const SizedBox(height: 24.0),
          ],
        );
      case HomeSection.recentlyPlayed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('recently_played')),
            const SizedBox(height: 12.0),
            const RepaintBoundary(child: RecentlyPlayedSection()),
            const SizedBox(height: 24.0),
          ],
        );
      case HomeSection.mostPlayed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('most_played')),
            const SizedBox(height: 12.0),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: RepaintBoundary(child: MostPlayedSection()),
            ),
            const SizedBox(height: 24.0),
          ],
        );
      case HomeSection.listeningHistory:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(child: ListeningHistoryCard()),
            SizedBox(height: 24.0),
          ],
        );
      case HomeSection.recentlyAdded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('recently_added')),
            const SizedBox(height: 12.0),
            const RepaintBoundary(child: RecentlyAddedSection()),
            const SizedBox(height: 24.0),
          ],
        );
      case HomeSection.libraryStats:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(child: MusicStatsCard()),
            SizedBox(height: 24.0),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<HomeLayoutService>(
      builder: (context, layoutService, _) {
        final visibleSections = layoutService.visibleSections;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
          strokeWidth: 2.5,
          displacement: 40,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              top: 24.0,
              bottom: widget.currentSong != null
                  ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                  : 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in visibleSections) _buildSection(section),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Optimized section title widget that prevents unnecessary rebuilds
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'ProductSans',
            ),
      ),
    );
  }
}

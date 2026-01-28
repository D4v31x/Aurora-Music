import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../mixins/services/local_caching_service.dart';
import '../../mixins/services/home_layout_service.dart';
import '../../mixins/utils/responsive_utils.dart';
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

  const HomeTab({
    super.key,
    required this.randomSongs,
    required this.randomArtists,
    required this.artistService,
    required this.currentSong,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Widget _buildSection(HomeSection section, bool isTablet, double spacing) {
    final l10n = AppLocalizations.of(context);

    switch (section) {
      case HomeSection.forYou:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.translate('for_you'), isTablet: isTablet),
            SizedBox(height: isTablet ? 16.0 : 12.0),
            RepaintBoundary(
              child: ForYouSection(
                key: const ValueKey('for_you_section'),
                randomSongs: widget.randomSongs,
                randomArtists: widget.randomArtists,
                artistService: widget.artistService,
              ),
            ),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.suggestedArtists:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                title: l10n.translate('suggested_artists'), isTablet: isTablet),
            SizedBox(height: isTablet ? 16.0 : 12.0),
            RepaintBoundary(
              child: SuggestedArtistsSection(
                key: const ValueKey('suggested_artists_section'),
                randomArtists: widget.randomArtists,
                artistService: widget.artistService,
              ),
            ),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.recentlyPlayed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                title: l10n.translate('recently_played'), isTablet: isTablet),
            SizedBox(height: isTablet ? 16.0 : 12.0),
            const RepaintBoundary(child: RecentlyPlayedSection()),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.mostPlayed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                title: l10n.translate('most_played'), isTablet: isTablet),
            SizedBox(height: isTablet ? 16.0 : 12.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 16.0),
              child: const RepaintBoundary(child: MostPlayedSection()),
            ),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.listeningHistory:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RepaintBoundary(child: ListeningHistoryCard()),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.recentlyAdded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                title: l10n.translate('recently_added'), isTablet: isTablet),
            SizedBox(height: isTablet ? 16.0 : 12.0),
            const RepaintBoundary(child: RecentlyAddedSection()),
            SizedBox(height: spacing),
          ],
        );
      case HomeSection.libraryStats:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RepaintBoundary(child: MusicStatsCard()),
            SizedBox(height: spacing),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final layoutMode = ResponsiveUtils.getLayoutMode(context);
    final spacing = ResponsiveUtils.getSpacing(context, base: 24.0);

    return Consumer<HomeLayoutService>(
      builder: (context, layoutService, _) {
        final visibleSections = layoutService.visibleSections;

        // Removed RefreshIndicator - using custom pull-to-refresh in HomeScreen
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            top: isTablet ? 32.0 : 24.0,
            bottom: widget.currentSong != null
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : isTablet
                    ? 50.0
                    : 40.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.getContentMaxWidth(context),
              ),
              child: layoutMode == LayoutMode.twoColumn ||
                      layoutMode == LayoutMode.wideWithPanel
                  ? _buildTabletLayout(visibleSections, spacing)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final section in visibleSections)
                          _buildSection(section, isTablet, spacing),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  /// Build a two-column layout for tablets in landscape
  Widget _buildTabletLayout(List<HomeSection> visibleSections, double spacing) {
    const isTablet = true;

    // Split sections into two columns
    final leftSections = <HomeSection>[];
    final rightSections = <HomeSection>[];

    for (int i = 0; i < visibleSections.length; i++) {
      if (i % 2 == 0) {
        leftSections.add(visibleSections[i]);
      } else {
        rightSections.add(visibleSections[i]);
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getHorizontalPadding(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in leftSections)
                  _buildSection(section, isTablet, spacing),
              ],
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in rightSections)
                  _buildSection(section, isTablet, spacing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized section title widget that prevents unnecessary rebuilds
class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isTablet;

  const _SectionTitle({
    required this.title,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: FontConstants.fontFamily,
              fontSize: isTablet ? 26 : null,
            ),
      ),
    );
  }
}

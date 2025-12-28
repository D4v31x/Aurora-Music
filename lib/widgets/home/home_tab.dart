import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../localization/app_localizations.dart';
import '../../services/local_caching_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        child: AnimationLimiter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: w),
              ),
              children: [
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('for_you'),
                ),
                const SizedBox(height: 12.0),
                RepaintBoundary(
                  child: ForYouSection(
                    randomSongs: widget.randomSongs,
                    randomArtists: widget.randomArtists,
                    artistService: widget.artistService,
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('suggested_artists'),
                ),
                const SizedBox(height: 12.0),
                RepaintBoundary(
                  child: SuggestedArtistsSection(
                    randomArtists: widget.randomArtists,
                    artistService: widget.artistService,
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('recently_played'),
                ),
                const SizedBox(height: 12.0),
                const RepaintBoundary(
                  child: RecentlyPlayedSection(),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('most_played'),
                ),
                const SizedBox(height: 12.0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: RepaintBoundary(
                    child: MostPlayedSection(),
                  ),
                ),
                const SizedBox(height: 24.0),
                const RepaintBoundary(
                  child: ListeningHistoryCard(),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('recently_added'),
                ),
                const SizedBox(height: 12.0),
                const RepaintBoundary(
                  child: RecentlyAddedSection(),
                ),
                const SizedBox(height: 24.0),
                const RepaintBoundary(
                  child: MusicStatsCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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

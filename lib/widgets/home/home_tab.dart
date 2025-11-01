import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../localization/app_localizations.dart';
import '../../services/local_caching_service.dart';
import 'quick_access_section.dart';
import 'suggested_tracks_section.dart';
import 'suggested_artists_section.dart';

class HomeTab extends StatelessWidget {
  final List<SongModel> randomSongs;
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;
  final SongModel? currentSong;
  final VoidCallback onRefresh;

  const HomeTab({
    super.key,
    required this.randomSongs,
    required this.randomArtists,
    required this.artistService,
    required this.currentSong,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 24.0,
          bottom: currentSong != null ? 100.0 : 40.0,
        ),
        child: AnimationLimiter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('quick_access'),
                ),
                const SizedBox(height: 12.0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: RepaintBoundary(
                    child: QuickAccessSection(),
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('suggested_tracks'),
                ),
                const SizedBox(height: 12.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RepaintBoundary(
                    child: SuggestedTracksSection(randomSongs: randomSongs),
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(
                  context,
                  AppLocalizations.of(context).translate('suggested_artists'),
                ),
                const SizedBox(height: 12.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RepaintBoundary(
                    child: SuggestedArtistsSection(
                      randomArtists: randomArtists,
                      artistService: artistService,
                    ),
                  ),
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

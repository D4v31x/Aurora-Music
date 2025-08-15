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
          left: 20.0,
          right: 20.0,
          top: 20.0,
          bottom: currentSong != null ? 90.0 : 30.0,
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
                const SizedBox(height: 20.0),
                Text(
                  AppLocalizations.of(context).translate('quick_access'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineMedium?.color),
                ),
                const SizedBox(height: 10.0),
                const QuickAccessSection(),
                const SizedBox(height: 30.0),
                Text(
                  AppLocalizations.of(context).translate('suggested_tracks'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineMedium?.color),
                ),
                const SizedBox(height: 10.0),
                SuggestedTracksSection(randomSongs: randomSongs),
                const SizedBox(height: 30.0),
                Text(
                  AppLocalizations.of(context).translate('suggested_artists'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineMedium?.color),
                ),
                const SizedBox(height: 10.0),
                SuggestedArtistsSection(
                  randomArtists: randomArtists,
                  artistService: artistService,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
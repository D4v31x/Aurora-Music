import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../screens/Artist_screen.dart';
import '../../services/local_caching_service.dart';
import '../../services/artwork_cache_service.dart';
import '../glassmorphic_card.dart';

class SuggestedArtistsSection extends StatelessWidget {
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;

  const SuggestedArtistsSection({
    super.key,
    required this.randomArtists,
    required this.artistService,
  });

  static final _artworkService = ArtworkCacheService();

  @override
  Widget build(BuildContext context) {
    if (randomArtists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 180,
        child: AnimationLimiter(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: randomArtists.length,
            itemBuilder: (context, index) {
              final artist = randomArtists[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: GlassmorphicCard.artist(
                      key: ValueKey(artist),
                      artistName: artist,
                      artworkService: _artworkService,
                      circularArtwork: false,
                      onTap: () async {
                        final imagePath =
                            await _artworkService.getArtistImageByName(artist);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtistDetailsScreen(
                                artistName: artist,
                                artistImagePath: imagePath,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

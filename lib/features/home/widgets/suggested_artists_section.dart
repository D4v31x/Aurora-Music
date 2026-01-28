import 'package:flutter/material.dart';
import '../../library/screens/artist_detail_screen.dart';
import '../../../shared/services/local_caching_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/widgets/glassmorphic_card.dart';

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
        height: 190,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: randomArtists.length,
          itemBuilder: (context, index) {
            final artist = randomArtists[index];
            return RepaintBoundary(
              key: ValueKey('artist_card_$artist'),
              child: GlassmorphicCard.artist(
                key: ValueKey('artist_content_$artist'),
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
            );
          },
        ),
      ),
    );
  }
}

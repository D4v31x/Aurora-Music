import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../screens/Artist_screen.dart';
import '../../services/local_caching_service.dart';
import '../glassmorphic_container.dart';

class SuggestedArtistsSection extends StatelessWidget {
  final List<String> randomArtists;
  final LocalCachingArtistService artistService;

  const SuggestedArtistsSection({
    super.key,
    required this.randomArtists,
    required this.artistService,
  });

  @override
  Widget build(BuildContext context) {
    if (randomArtists.isEmpty) {
      return glassmorphicContainer(
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No data',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 150,
        child: AnimationLimiter(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: randomArtists.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final artist = randomArtists[index];

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _ArtistItem(
                      key: ValueKey(artist), // Add key for performance
                      artist: artist,
                      artistService: artistService,
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

class _ArtistItem extends StatefulWidget {
  final String artist;
  final LocalCachingArtistService artistService;

  const _ArtistItem({
    super.key,
    required this.artist,
    required this.artistService,
  });

  @override
  State<_ArtistItem> createState() => _ArtistItemState();
}

class _ArtistItemState extends State<_ArtistItem> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadArtistImage();
  }

  Future<void> _loadArtistImage() async {
    try {
      final imagePath =
          await widget.artistService.fetchArtistImage(widget.artist);
      if (mounted) {
        setState(() {
          _imagePath = imagePath;
        });
      }
    } catch (e) {
      // Image loading failed, will show default icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistDetailsScreen(
                artistName: widget.artist,
                artistImagePath: _imagePath,
              ),
            ),
          );
        },
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _imagePath != null
                        ? FileImage(File(_imagePath!))
                        : null,
                    child: _imagePath == null
                        ? const Icon(Icons.person,
                            size: 40, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.artist,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'ProductSans'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

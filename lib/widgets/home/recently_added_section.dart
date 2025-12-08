import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../glassmorphic_card.dart';

/// Horizontal scrollable glassmorphic section showing recently added songs
class RecentlyAddedSection extends StatefulWidget {
  const RecentlyAddedSection({super.key});

  @override
  State<RecentlyAddedSection> createState() => _RecentlyAddedSectionState();
}

class _RecentlyAddedSectionState extends State<RecentlyAddedSection> {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<SongModel>? _recentSongs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    // Get songs sorted by date added (most recent first)
    final allSongs = List<SongModel>.from(audioPlayerService.songs);
    allSongs.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    _recentSongs = allSongs.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recentSongs = _recentSongs ?? [];

    if (recentSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context).translate('No_data'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: AnimationLimiter(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: recentSongs.length,
          itemBuilder: (context, index) {
            final song = recentSongs[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: GlassmorphicCard.song(
                    key: ValueKey(song.id),
                    songId: song.id,
                    title: song.title,
                    artist: splitArtists(song.artist ?? '').first,
                    artworkService: _artworkService,
                    badge: const CardBadge(text: 'NEW'),
                    onTap: () {
                      final audioPlayerService =
                          Provider.of<AudioPlayerService>(context,
                              listen: false);
                      audioPlayerService.setPlaylist(recentSongs, index);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

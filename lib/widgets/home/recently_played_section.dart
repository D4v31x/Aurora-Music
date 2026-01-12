import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../constants/app_config.dart';
import '../../services/audio_player_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../localization/app_localizations.dart';
import '../../models/utils.dart';
import '../glassmorphic_card.dart';

class RecentlyPlayedSection extends StatefulWidget {
  const RecentlyPlayedSection({super.key});

  @override
  State<RecentlyPlayedSection> createState() => _RecentlyPlayedSectionState();
}

class _RecentlyPlayedSectionState extends State<RecentlyPlayedSection> {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<SongModel>? _recentSongs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final songs = await audioPlayerService.getRecentlyPlayed();
    if (mounted) {
      setState(() {
        _recentSongs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

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
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: recentSongs.length,
        // Performance: Pre-cache items beyond visible area for smoother scrolling
        cacheExtent: AppConfig.horizontalListCacheExtent,
        itemBuilder: (context, index) {
          final song = recentSongs[index];
          return RepaintBoundary(
            child: GlassmorphicCard.song(
              key: ValueKey(song.id),
              songId: song.id,
              title: song.title,
              artist: splitArtists(song.artist ?? '').first,
              artworkService: _artworkService,
              onTap: () {
                final audioPlayerService =
                    Provider.of<AudioPlayerService>(context, listen: false);
                audioPlayerService.setPlaylist(
                  recentSongs,
                  index,
                  source: const PlaybackSourceInfo(
                      source: PlaybackSource.recentlyPlayed),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

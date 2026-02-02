import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/widgets/glassmorphic_container.dart';

class MostPlayedSection extends StatefulWidget {
  const MostPlayedSection({super.key});

  @override
  State<MostPlayedSection> createState() => _MostPlayedSectionState();
}

class _MostPlayedSectionState extends State<MostPlayedSection> {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<SongModel>? _displaySongs; // Songs to display (top 3)
  List<SongModel>? _fullPlaylist; // Full playlist for playback
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    // Load display songs (top 10 for display, show top 3)
    final displaySongs = await audioPlayerService.getMostPlayedTracks();
    // Load full playlist for playback (all played songs sorted by play count)
    final fullPlaylist = await audioPlayerService.getAllMostPlayedTracks();
    if (mounted) {
      setState(() {
        _displaySongs = displaySongs;
        _fullPlaylist = fullPlaylist;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final mostPlayedSongs = _displaySongs ?? [];
    final fullPlaylist = _fullPlaylist ?? mostPlayedSongs;

    if (mostPlayedSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context).translate('No_data'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
      );
    }

    // Take top 3 most played songs for display
    final topSongs = mostPlayedSongs.take(3).toList();

    return Column(
      children: topSongs.asMap().entries.map((entry) {
        final index = entry.key;
        final song = entry.value;
        // Find the index in the full playlist
        final fullPlaylistIndex =
            fullPlaylist.indexWhere((s) => s.id == song.id);

        return RepaintBoundary(
          key: ValueKey(song.id),
          child: _MostPlayedTile(
            song: song,
            rank: index + 1,
            artworkService: _artworkService,
            onTap: () {
              final audioPlayerService =
                  Provider.of<AudioPlayerService>(context, listen: false);
              // Play from full playlist, starting at the correct index
              audioPlayerService.setPlaylist(
                fullPlaylist,
                fullPlaylistIndex >= 0 ? fullPlaylistIndex : index,
                source:
                    const PlaybackSourceInfo(source: PlaybackSource.mostPlayed),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class _MostPlayedTile extends StatelessWidget {
  final SongModel song;
  final int rank;
  final ArtworkCacheService artworkService;
  final VoidCallback onTap;

  const _MostPlayedTile({
    required this.song,
    required this.rank,
    required this.artworkService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: glassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Rank number
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                // Artwork
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: artworkService.buildCachedArtwork(
                      song.id,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: FontConstants.fontFamily,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        splitArtists(song.artist ?? '').join(', '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontFamily: FontConstants.fontFamily,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

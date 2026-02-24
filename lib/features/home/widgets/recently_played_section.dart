import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:aurora_music_v01/core/constants/app_config.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/widgets/glassmorphic_card.dart';

class RecentlyPlayedSection extends StatefulWidget {
  const RecentlyPlayedSection({super.key});

  @override
  State<RecentlyPlayedSection> createState() => _RecentlyPlayedSectionState();
}

class _RecentlyPlayedSectionState extends State<RecentlyPlayedSection> {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();
  List<SongModel>? _displaySongs; // Songs to display (limited)
  List<SongModel>? _fullPlaylist; // Full playlist for playback
  bool _isLoading = true;
  AudioPlayerService? _audioPlayerService;
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<AudioPlayerService>(context, listen: false);
    if (_audioPlayerService != service) {
      _audioPlayerService?.removeListener(_onServiceChanged);
      _audioPlayerService = service;
      _audioPlayerService!.addListener(_onServiceChanged);
    }
  }

  void _onServiceChanged() {
    if (!mounted) return;
    final currentId = _audioPlayerService?.currentSong?.id;
    // Only reload when the playing song actually changes, not on play/pause/seek.
    if (currentId != _lastSongId) {
      _lastSongId = currentId;
      if (!_isLoading) _loadData();
    }
  }

  @override
  void dispose() {
    _audioPlayerService?.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    // Load display songs (limited to 3 for UI)
    final displaySongs = await audioPlayerService.getRecentlyPlayed(count: 3);
    // Load full playlist for playback
    final fullPlaylist = await audioPlayerService.getAllRecentlyPlayed();
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
        height: 100,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final displaySongs = _displaySongs ?? [];
    final fullPlaylist = _fullPlaylist ?? displaySongs;

    if (displaySongs.isEmpty) {
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
        itemCount: displaySongs.length,
        // Performance: Pre-cache items beyond visible area for smoother scrolling
        cacheExtent: AppConfig.horizontalListCacheExtent,
        itemBuilder: (context, index) {
          final song = displaySongs[index];
          // Find the index in the full playlist
          final fullPlaylistIndex =
              fullPlaylist.indexWhere((s) => s.id == song.id);
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
                // Play from full playlist, starting at the correct index
                audioPlayerService.setPlaylist(
                  fullPlaylist,
                  fullPlaylistIndex >= 0 ? fullPlaylistIndex : index,
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

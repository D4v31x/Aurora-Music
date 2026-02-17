import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/background_manager_service.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Glassmorphic card showing current/last played song
/// Performance: Removed BackdropFilter - blur is expensive for always-visible elements
class ListeningHistoryCard extends StatelessWidget {
  static final ArtworkCacheService _artworkService = ArtworkCacheService();

  const ListeningHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when currentSong changes, not on play/pause
    return Selector<AudioPlayerService, SongModel?>(
      selector: (context, audioService) => audioService.currentSong,
      builder: (context, currentSong, child) {
        if (currentSong == null) {
          return _buildEmptyState(context);
        }

        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);
        return _buildNowPlayingCard(context, currentSong, audioPlayerService);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicContainer(
        borderRadius: BorderRadius.circular(16),
        blur: 15,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.headphones_rounded,
                size: 28,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to play',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a song to start listening',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingCard(
    BuildContext context,
    SongModel song,
    AudioPlayerService audioPlayerService,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicContainer(
        borderRadius: BorderRadius.circular(16),
        blur: 15,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Artwork
                  Hero(
                    tag: 'nowPlayingArtwork_home',
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _artworkService.buildCachedArtwork(
                          song.id,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: audioPlayerService.isPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return Text(
                              isPlaying ? 'Now Playing' : 'Paused',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontFamily: FontConstants.fontFamily,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: FontConstants.fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          splitArtists(song.artist ?? 'Unknown').join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: FontConstants.fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Play/Pause button
                  ValueListenableBuilder<bool>(
                    valueListenable: audioPlayerService.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            audioPlayerService.pause();
                          } else {
                            audioPlayerService.resume();
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Progress bar at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<Duration>(
                stream: audioPlayerService.audioPlayer.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration =
                      audioPlayerService.audioPlayer.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;

                  // Get light vibrant color from artwork
                  final backgroundManager =
                      Provider.of<BackgroundManagerService>(context);
                  final progressColor =
                      backgroundManager.currentColors.length > 2
                          ? backgroundManager.currentColors[2]
                          : (backgroundManager.currentColors.isNotEmpty
                              ? backgroundManager.currentColors.first
                              : theme.colorScheme.primary);

                  return Container(
                    height: 3,
                    color: progressColor.withValues(alpha: 0.15),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        color: progressColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

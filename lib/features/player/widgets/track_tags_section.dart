/// Widget shown on the Now Playing screen (between the playback controls
/// and the lyrics section) for tagging/jumping between named parts of a
/// single long track — e.g. marking where each song starts within a DJ mix.
///
/// - If the current track already has tags, renders a scrollable list of
///   them (time + name); tapping a tag seeks the player to that position.
/// - If the track has no tags yet but is longer than [_setThreshold], shows
///   a lightweight suggestion bar inviting the user to tag it.
/// - Otherwise renders nothing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/track_tag_model.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/track_tag_service.dart';
import '../../../shared/utils/formatters/duration_formatter.dart';
import '../../../shared/widgets/optimized_tiles.dart' show NowPlayingBars;
import '../screens/track_tag_editor_screen.dart';

/// Tracks longer than this are considered candidates for a "is this a set?"
/// tagging suggestion.
const Duration _setThreshold = Duration(minutes: 30);

/// Index of the tag currently playing — the last tag whose position is at
/// or before [position] — or -1 if [position] precedes every tag.
int _activeTagIndex(List<TrackTag> tags, Duration position) {
  var active = -1;
  for (var i = 0; i < tags.length; i++) {
    if (tags[i].position <= position) {
      active = i;
    } else {
      break;
    }
  }
  return active;
}

class TrackTagsSection extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final bool isTablet;

  const TrackTagsSection({
    super.key,
    required this.audioPlayerService,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final song = audioPlayerService.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Consumer<TrackTagService>(
      builder: (context, trackTagService, _) {
        if (!trackTagService.loaded) return const SizedBox.shrink();

        final tags = trackTagService.tagsFor(song.id);
        if (tags.isNotEmpty) {
          return _TagsListCard(
            tags: tags,
            audioPlayerService: audioPlayerService,
            isTablet: isTablet,
          );
        }

        final duration = Duration(milliseconds: song.duration ?? 0);
        if (duration >= _setThreshold) {
          return _TagSuggestionBar(audioPlayerService: audioPlayerService);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _TagsListCard extends StatelessWidget {
  final List<TrackTag> tags;
  final AudioPlayerService audioPlayerService;
  final bool isTablet;

  const _TagsListCard({
    required this.tags,
    required this.audioPlayerService,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final song = audioPlayerService.currentSong!;

    return Column(
      children: [
        SizedBox(height: isTablet ? 40 : 30),
        SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                loc.trackTags,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 26 : 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: FontConstants.fontFamily,
                  letterSpacing: 0.5,
                ),
              ),
              Positioned(
                right: 16,
                child: IconButton(
                  tooltip: loc.editTrackTags,
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackTagEditorScreen(song: song),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 24 : 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: StreamBuilder<Duration>(
            stream: audioPlayerService.audioPlayer.positionStream,
            initialData: audioPlayerService.audioPlayer.position,
            builder: (context, snapshot) {
              final currentPosition = snapshot.data ?? Duration.zero;
              final activeIndex = _activeTagIndex(tags, currentPosition);

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final isActive = index == activeIndex;
                    return ColoredBox(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => audioPlayerService.audioPlayer
                            .seek(tag.position),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  formatDuration(tag.position),
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: isActive ? 0.9 : 0.55),
                                    fontFamily: FontConstants.fontFamily,
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tag.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: FontConstants.fontFamily,
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isActive)
                                NowPlayingBars(
                                  isPlaying: audioPlayerService.isPlaying,
                                  size: 16,
                                )
                              else
                                const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white38, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _TagSuggestionBar extends StatelessWidget {
  final AudioPlayerService audioPlayerService;

  const _TagSuggestionBar({required this.audioPlayerService});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final song = audioPlayerService.currentSong!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 18.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.query_stats_rounded,
                color: Colors.white70, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.isThisASet,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.tagPartsForEasySwitching,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: FontConstants.fontFamily,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackTagEditorScreen(song: song),
                ),
              ),
              child: Text(loc.tagThisTrack),
            ),
          ],
        ),
      ),
    );
  }
}


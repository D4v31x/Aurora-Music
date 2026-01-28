/// Playing From header widget for the Now Playing screen.
///
/// Displays the playback source (album, playlist, artist, etc.) in the app bar.
library;

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../mixins/services/audio_player_service.dart';

// MARK: - Constants

const _kHeaderFontSize = 12.0;
const _kSourceFontSize = 15.0;
const _kHeaderOpacity = 0.6;
const _kLetterSpacing = 0.5;

// MARK: - Playing From Header Widget

/// A widget that displays where the current playback originated from.
///
/// Shows "Playing from" label with the source name below it.
/// Source can be album, artist, playlist, folder, search, or library.
///
/// Usage:
/// ```dart
/// PlayingFromHeader(
///   audioPlayerService: audioService,
/// )
/// ```
class PlayingFromHeader extends StatelessWidget {
  /// The audio player service to get playback source from.
  final AudioPlayerService audioPlayerService;

  const PlayingFromHeader({
    super.key,
    required this.audioPlayerService,
  });

  @override
  Widget build(BuildContext context) {
    final sourceLabel = _getSourceLabel(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).translate('playing_from'),
          style: TextStyle(
            color: Colors.white.withOpacity(_kHeaderOpacity),
            fontSize: _kHeaderFontSize,
            fontWeight: FontWeight.w400,
            fontFamily: FontConstants.fontFamily,
            letterSpacing: _kLetterSpacing,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sourceLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _kSourceFontSize,
            fontWeight: FontWeight.w600,
            fontFamily: FontConstants.fontFamily,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Gets the localized label for the current playback source.
  String _getSourceLabel(BuildContext context) {
    final source = audioPlayerService.playbackSource;
    final l10n = AppLocalizations.of(context);

    switch (source.source) {
      case PlaybackSource.forYou:
        return l10n.translate('for_you');
      case PlaybackSource.recentlyPlayed:
        return l10n.translate('recently_played');
      case PlaybackSource.recentlyAdded:
        return l10n.translate('recently_added');
      case PlaybackSource.mostPlayed:
        return l10n.translate('most_played');
      case PlaybackSource.album:
        return source.name ?? l10n.translate('album');
      case PlaybackSource.artist:
        return source.name ?? l10n.translate('artist');
      case PlaybackSource.playlist:
        return source.name ?? l10n.translate('playlist');
      case PlaybackSource.folder:
        return source.name ?? l10n.translate('folder');
      case PlaybackSource.search:
        return l10n.translate('search');
      case PlaybackSource.library:
      case PlaybackSource.unknown:
        return l10n.translate('library');
    }
  }
}

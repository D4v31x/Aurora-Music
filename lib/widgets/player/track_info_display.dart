/// Track information display widget for the Now Playing screen.
///
/// Displays the song title and artist name with scrolling text for long titles
/// and hero animations for smooth transitions.
library;

import 'package:flutter/material.dart';
import '../../constants/font_constants.dart';
import '../../models/utils.dart';
import '../../services/audio_player_service.dart';
import '../common/scrolling_text.dart';

// MARK: - Constants

/// Default text style for track title
const _kTitleFontSizePhone = 18.0;
const _kTitleFontSizeTablet = 22.0;
const _kArtistFontSizePhone = 14.0;
const _kArtistFontSizeTablet = 16.0;
const _kDefaultArtistOpacity = 0.7;

// MARK: - Track Info Display Widget

/// A widget that displays the current track's title and artist.
///
/// Features:
/// - Auto-scrolling text for long song titles
/// - Hero animations for smooth screen transitions
/// - Responsive sizing for phones and tablets
///
/// Usage:
/// ```dart
/// TrackInfoDisplay(
///   audioPlayerService: audioService,
///   isTablet: false,
/// )
/// ```
class TrackInfoDisplay extends StatelessWidget {
  /// The audio player service to get current song info from.
  final AudioPlayerService audioPlayerService;

  /// Whether to use tablet-sized fonts.
  final bool isTablet;

  /// Optional padding around the content.
  final EdgeInsetsGeometry? padding;

  const TrackInfoDisplay({
    super.key,
    required this.audioPlayerService,
    this.isTablet = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final currentSong = audioPlayerService.currentSong;
    final titleFontSize = isTablet ? _kTitleFontSizeTablet : _kTitleFontSizePhone;
    final artistFontSize = isTablet ? _kArtistFontSizeTablet : _kArtistFontSizePhone;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSongTitle(currentSong?.title, titleFontSize),
          const SizedBox(height: 4),
          _buildArtistName(currentSong?.artist, artistFontSize),
        ],
      ),
    );
  }

  /// Builds the song title with hero animation and scrolling text.
  Widget _buildSongTitle(String? title, double fontSize) {
    return Hero(
      tag: 'songTitle',
      flightShuttleBuilder: _titleFlightShuttleBuilder,
      child: Material(
        color: Colors.transparent,
        child: ScrollingText(
          text: title ?? 'No song playing',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ),
    );
  }

  /// Builds the artist name with hero animation.
  Widget _buildArtistName(String? artist, double fontSize) {
    final displayArtist = artist != null
        ? splitArtists(artist).join(', ')
        : 'Unknown artist';

    return Hero(
      tag: 'songArtist',
      flightShuttleBuilder: _artistFlightShuttleBuilder,
      child: Material(
        color: Colors.transparent,
        child: Text(
          displayArtist,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.white.withOpacity(_kDefaultArtistOpacity),
            fontFamily: FontConstants.fontFamily,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Flight shuttle builder for title hero animation.
  Widget _titleFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: FontConstants.fontFamily,
        ),
        child: (toHeroContext.widget as Hero).child,
      ),
    );
  }

  /// Flight shuttle builder for artist hero animation.
  Widget _artistFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return Material(
      color: Colors.transparent,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: Colors.white.withOpacity(_kDefaultArtistOpacity),
          fontFamily: FontConstants.fontFamily,
        ),
        child: (toHeroContext.widget as Hero).child,
      ),
    );
  }
}

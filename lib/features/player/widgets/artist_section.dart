/// Artist section widget for the Now Playing screen.
///
/// Displays information about the current song's artist with
/// an artist card and navigation to artist details.
library;

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/artist_separator_service.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../library/screens/artist_detail_screen.dart';

// MARK: - Constants

const _kSectionTitleFontSize = 20.0;
const _kHorizontalMargin = 20.0;
const _kBottomPadding = 12.0;

// MARK: - Artist Section Widget

/// A widget that displays the current song's artist information.
///
/// Shows the "About Artist" header with an artist card that can be tapped
/// to navigate to the artist details screen.
///
/// Usage:
/// ```dart
/// ArtistSection(
///   audioPlayerService: audioService,
/// )
/// ```
class ArtistSection extends StatelessWidget {
  /// The audio player service to get current song from.
  final AudioPlayerService audioPlayerService;

  const ArtistSection({
    super.key,
    required this.audioPlayerService,
  });

  @override
  Widget build(BuildContext context) {
    final artistString = audioPlayerService.currentSong?.artist;

    // Return empty widget if no artist info
    if (artistString == null || artistString.isEmpty) {
      return const SizedBox.shrink();
    }

    final mainArtist = ArtistSeparatorService().getPrimaryArtist(artistString);

    return Column(
      children: [
        _buildSectionTitle(context),
        _buildArtistCard(context, mainArtist),
      ],
    );
  }

  /// Builds the section title.
  Widget _buildSectionTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kBottomPadding),
      child: Text(
        AppLocalizations.of(context).translate('about_artist'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: _kSectionTitleFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: FontConstants.fontFamily,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the artist card with navigation.
  Widget _buildArtistCard(BuildContext context, String artistName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _kHorizontalMargin),
      child: ArtistCard(
        artistName: artistName,
        onTap: () => _navigateToArtistDetails(context, artistName),
      ),
    );
  }

  /// Navigates to the artist details screen.
  void _navigateToArtistDetails(BuildContext context, String artistName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(artistName: artistName),
      ),
    );
  }
}

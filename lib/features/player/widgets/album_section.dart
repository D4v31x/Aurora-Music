/// Album section widget for the Now Playing screen.
///
/// Displays information about the current song's album with
/// an album card and navigation to album details.
library;

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../mixins/services/audio_player_service.dart';
import '../album_card.dart';
import '../../features/library/screens/album_detail_screen.dart';

// MARK: - Constants

const _kSectionTitleFontSize = 20.0;
const _kHorizontalMargin = 20.0;
const _kBottomPadding = 12.0;

// MARK: - Album Section Widget

/// A widget that displays the current song's album information.
///
/// Shows the "Album" header with an album card that can be tapped
/// to navigate to the album details screen.
///
/// Usage:
/// ```dart
/// AlbumSection(
///   audioPlayerService: audioService,
/// )
/// ```
class AlbumSection extends StatelessWidget {
  /// The audio player service to get current song from.
  final AudioPlayerService audioPlayerService;

  const AlbumSection({
    super.key,
    required this.audioPlayerService,
  });

  @override
  Widget build(BuildContext context) {
    final currentSong = audioPlayerService.currentSong;
    final albumName = currentSong?.album;

    // Return empty widget if no album info
    if (currentSong == null || albumName == null || albumName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSectionTitle(context),
        _buildAlbumCard(context, currentSong),
      ],
    );
  }

  /// Builds the section title.
  Widget _buildSectionTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kBottomPadding),
      child: Text(
        AppLocalizations.of(context).translate('album'),
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

  /// Builds the album card with navigation.
  Widget _buildAlbumCard(BuildContext context, SongModel currentSong) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _kHorizontalMargin),
      child: AlbumCard(
        albumName: currentSong.album!,
        artistName: currentSong.artist,
        albumId: currentSong.albumId,
        onTap: () => _navigateToAlbumDetails(context, currentSong.album!),
      ),
    );
  }

  /// Navigates to the album details screen.
  void _navigateToAlbumDetails(BuildContext context, String albumName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(albumName: albumName),
      ),
    );
  }
}

/// Lyrics section widget for the Now Playing screen.
///
/// Displays synchronized lyrics with animated highlighting for the current line.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/timed_lyrics.dart';
import '../screens/fullscreen_lyrics.dart';
import '../../../shared/services/audio_player_service.dart';

// MARK: - Constants

const _kLyricsSectionHeight = 250.0;
const _kLyricsContainerOpacity = 0.1;
const _kExpandButtonOpacity = 0.1;
const _kExpandButtonBorderOpacity = 0.2;
const _kBorderRadius = 16.0;

const _kCurrentLyricFontSize = 17.0;
const _kOtherLyricFontSize = 14.0;
const _kCurrentLyricPadding = 10.0;
const _kOtherLyricPadding = 6.0;
const _kHorizontalLyricPadding = 4.0;

const _kLyricAnimationDuration = Duration(milliseconds: 350);
const _kNoLyricsAnimationDuration = Duration(milliseconds: 500);
const _kMinLyricOpacity = 0.3;
const _kOpacityDecayPerLine = 0.25;
const _kScaleDecayPerLine = 0.05;

// MARK: - Lyrics Section Widget

/// A widget that displays synchronized lyrics for the current song.
///
/// Features:
/// - Animated highlighting of current lyric
/// - Opacity and scale transitions for surrounding lyrics
/// - Tap to expand to fullscreen lyrics view
/// - Placeholder when no lyrics are available
///
/// Usage:
/// ```dart
/// LyricsSection(
///   timedLyrics: lyrics,
///   currentLyricIndex: currentIndex,
///   audioPlayerService: audioService,
/// )
/// ```
class LyricsSection extends StatelessWidget {
  /// The list of timed lyrics for the song.
  final List<TimedLyric>? timedLyrics;

  /// The current lyric index (from ValueNotifier).
  final int currentLyricIndex;

  /// The audio player service.
  final AudioPlayerService audioPlayerService;

  const LyricsSection({
    super.key,
    required this.timedLyrics,
    required this.currentLyricIndex,
    required this.audioPlayerService,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hasLyrics = timedLyrics != null && timedLyrics!.isNotEmpty;

    return Column(
      children: [
        _buildLyricsContainer(context, hasLyrics, screenWidth),
      ],
    );
  }

  /// Builds the main lyrics container.
  Widget _buildLyricsContainer(
    BuildContext context,
    bool hasLyrics,
    double screenWidth,
  ) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: _kLyricsSectionHeight,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_kLyricsContainerOpacity),
            borderRadius: BorderRadius.circular(_kBorderRadius),
          ),
          child: hasLyrics
              ? _buildLyricsContent(context, screenWidth)
              : _buildNoLyricsPlaceholder(context),
        ),
        if (hasLyrics) _buildExpandButton(context),
      ],
    );
  }

  /// Builds the lyrics content with animated lines.
  Widget _buildLyricsContent(BuildContext context, double screenWidth) {
    return Center(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildAnimatedLyricLines(context, screenWidth),
          ),
        ),
      ),
    );
  }

  /// Builds the animated lyric lines around the current index.
  List<Widget> _buildAnimatedLyricLines(
    BuildContext context,
    double screenWidth,
  ) {
    if (timedLyrics == null || timedLyrics!.isEmpty) return [];

    // Show 2 lines before and after the current line
    final startIndex = max(0, currentLyricIndex - 2);
    final endIndex = min(timedLyrics!.length - 1, currentLyricIndex + 2);

    return timedLyrics!
        .sublist(startIndex, endIndex + 1)
        .asMap()
        .entries
        .map((entry) {
      final index = entry.key + startIndex;
      final lyric = entry.value;
      final isCurrent = index == currentLyricIndex;

      final distanceFromCenter = (index - currentLyricIndex).abs();
      final opacity = 1.0 - (distanceFromCenter * _kOpacityDecayPerLine);
      final scale = 1.0 - (distanceFromCenter * _kScaleDecayPerLine);

      final effectiveOpacity = opacity.clamp(_kMinLyricOpacity, 1.0);

      return _buildLyricLine(
        context,
        lyric,
        isCurrent,
        effectiveOpacity,
        scale,
        screenWidth,
      );
    }).toList();
  }

  /// Builds a single lyric line with animation.
  Widget _buildLyricLine(
    BuildContext context,
    TimedLyric lyric,
    bool isCurrent,
    double opacity,
    double scale,
    double screenWidth,
  ) {
    return AnimatedContainer(
      duration: _kLyricAnimationDuration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        vertical: isCurrent ? _kCurrentLyricPadding : _kOtherLyricPadding,
        horizontal: _kHorizontalLyricPadding,
      ),
      child: AnimatedScale(
        duration: _kLyricAnimationDuration,
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedDefaultTextStyle(
          duration: _kLyricAnimationDuration,
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: (isCurrent ? Colors.white : Colors.white60)
                .withValues(alpha: opacity),
            fontSize: isCurrent ? _kCurrentLyricFontSize : _kOtherLyricFontSize,
            fontFamily: FontConstants.fontFamily,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            height: 1.3,
            letterSpacing: isCurrent ? 0.2 : 0.0,
          ),
          child: SizedBox(
            width: screenWidth - 80,
            child: Text(
              lyric.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the placeholder when no lyrics are available.
  Widget _buildNoLyricsPlaceholder(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: _kNoLyricsAnimationDuration,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Text(
              AppLocalizations.of(context).translate('no_lyrics'),
              style: TextStyle(
                color: Colors.white70.withValues(alpha: value),
                fontSize: 16,
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  /// Builds the expand button overlay.
  Widget _buildExpandButton(BuildContext context) {
    return Positioned(
      bottom: 28,
      right: 24,
      child: GestureDetector(
        onTap: () => _openFullscreenLyrics(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_kExpandButtonOpacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(_kExpandButtonBorderOpacity),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => _openFullscreenLyrics(context),
              tooltip: AppLocalizations.of(context).translate('expand_lyrics'),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the fullscreen lyrics screen.
  void _openFullscreenLyrics(BuildContext context) {
    if (audioPlayerService.currentSong == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FullscreenLyricsScreen(),
      ),
    );
  }
}

/// Lyric line widget.
///
/// Displays a single line of lyrics with animation and tap handling.
library;

import 'package:flutter/material.dart';
import 'lyrics_constants.dart';

// MARK: - Lyric Line Widget

/// A widget that displays a single line of lyrics.
///
/// Features:
/// - Animated styling for current line
/// - Tap to seek functionality
/// - Configurable font size
class LyricLineWidget extends StatelessWidget {
  /// The lyric text to display.
  final String text;

  /// Whether this is the current active line.
  final bool isCurrent;

  /// Font size multiplier.
  final double fontSize;

  /// Callback when the line is tapped.
  final VoidCallback? onTap;

  /// Optional global key for scroll targeting.
  final GlobalKey? lineKey;

  const LyricLineWidget({
    super.key,
    required this.text,
    required this.isCurrent,
    this.fontSize = 1.0,
    this.onTap,
    this.lineKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kLyricsHorizontalPadding,
        vertical: kLyricsLineSpacing / 2,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedDefaultTextStyle(
          duration: kLyricsScrollDuration,
          style: isCurrent
              ? lyricsCurrentLineStyle(sizeFactor: fontSize)
              : lyricsOtherLineStyle(sizeFactor: fontSize),
          child: Text(
            text,
            key: lineKey,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Lyrics screen constants.
///
/// Contains styling constants for the fullscreen lyrics screen.
library;

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';

// MARK: - Colors

const Color kLyricsDialogBgColor = Colors.white24;
const double kLyricsDialogBlur = 10.0;
const double kLyricsBackgroundBlur = 50.0;

// MARK: - Sizes

const double kLyricsFontSizeSmall = 0.8;
const double kLyricsFontSizeNormal = 1.0;
const double kLyricsFontSizeLarge = 1.2;
const double kLyricsFontSizeExtraLarge = 1.4;

const double kLyricsCurrentFontSize = 26.0;
const double kLyricsOtherFontSize = 20.0;

// MARK: - Durations

const Duration kLyricsFadeDuration = Duration(milliseconds: 400);
const Duration kLyricsScrollDuration = Duration(milliseconds: 300);
const Duration kLyricsAnimationDuration = Duration(milliseconds: 500);

// MARK: - Spacing

const double kLyricsLineSpacing = 20.0;
const double kLyricsHorizontalPadding = 24.0;
const double kLyricsVerticalPadding = 100.0;

// MARK: - Text Styles

TextStyle lyricsCurrentLineStyle({double sizeFactor = 1.0}) => TextStyle(
      fontSize: kLyricsCurrentFontSize * sizeFactor,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFamily: FontConstants.fontFamily,
      height: 1.5,
    );

TextStyle lyricsOtherLineStyle({double sizeFactor = 1.0}) => TextStyle(
      fontSize: kLyricsOtherFontSize * sizeFactor,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.5),
      fontFamily: FontConstants.fontFamily,
      height: 1.5,
    );

TextStyle lyricsDialogTitleStyle() => const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFamily: FontConstants.fontFamily,
    );

TextStyle lyricsDialogTextStyle() => TextStyle(
      fontSize: 14,
      color: Colors.white.withOpacity(0.7),
      fontFamily: FontConstants.fontFamily,
    );

// MARK: - Decorations

BoxDecoration lyricsDialogDecoration() => BoxDecoration(
      color: Colors.grey[900]?.withOpacity(0.95),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    );

// MARK: - Settings Keys

const String kLyricsFontSizeKey = 'lyrics_font_size';
const String kLyricsSyncOffsetKey = 'lyrics_sync_offset';

// MARK: - API URLs

const String kLyricsSearchApiUrl = 'https://lrclib.net/api/search';

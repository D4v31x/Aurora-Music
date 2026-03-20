/// Lyrics section widget for the Now Playing screen.
///
/// Displays synchronized lyrics with animated highlighting for the current line,
/// and an optional translation powered by the MyMemory API.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:provider/provider.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../screens/fullscreen_lyrics.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/lyrics_translation_service.dart';

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

// MARK: - Translation state

enum _TranslationState { idle, loading, done, error }

// MARK: - Lyrics Section Widget

/// A widget that displays synchronized lyrics for the current song.
///
/// Features:
/// - Animated highlighting of current lyric
/// - Opacity and scale transitions for surrounding lyrics
/// - Tap to expand to fullscreen lyrics view
/// - Translate button: fetches translation via MyMemory, shows translated line
///   as main text with the original in smaller italic beneath — all animated
/// - Placeholder when no lyrics are available
class LyricsSection extends StatefulWidget {
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
  State<LyricsSection> createState() => _LyricsSectionState();
}

class _LyricsSectionState extends State<LyricsSection>
    with SingleTickerProviderStateMixin {
  _TranslationState _translationState = _TranslationState.idle;
  List<String?> _translatedLines = [];
  bool _showTranslated = false;

  /// Controls the pulsing opacity of the translate button while fetching.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LyricsSection old) {
    super.didUpdateWidget(old);
    // Reset when a new song is loaded (lyrics list reference changes).
    if (!identical(old.timedLyrics, widget.timedLyrics)) {
      _reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _translationState = _TranslationState.idle;
      _translatedLines = [];
      _showTranslated = false;
    });
    _pulseController
      ..stop()
      ..reset();
  }

  Future<void> _handleTranslateButton() async {
    final lyrics = widget.timedLyrics;
    if (lyrics == null || lyrics.isEmpty) return;

    // Already translated — just toggle visibility.
    if (_translationState == _TranslationState.done) {
      setState(() => _showTranslated = !_showTranslated);
      return;
    }

    // Ignore taps while a request is in flight.
    if (_translationState == _TranslationState.loading) return;

    setState(() => _translationState = _TranslationState.loading);
    _pulseController.repeat(reverse: true);

    try {
      final targetLang = Localizations.localeOf(context).languageCode;
      final song = widget.audioPlayerService.currentSong;
      final lyricsTexts = lyrics.map((l) => l.text).toList();
      final lyricsFingerprint = lyricsTexts.join().hashCode;
      final cacheKey = '${song?.artist ?? ""}|${song?.title ?? ""}|$lyricsFingerprint';

      final translated = await LyricsTranslationService.translateLines(
        texts: lyricsTexts,
        targetLang: targetLang,
        cacheKey: cacheKey,
      );

      if (!mounted) return;
      setState(() {
        _translatedLines = translated;
        _translationState = _TranslationState.done;
        _showTranslated = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _translationState = _TranslationState.error);
      // Auto-reset to idle after a delay so the user can retry.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _translationState == _TranslationState.error) {
          setState(() => _translationState = _TranslationState.idle);
        }
      });
    } finally {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hasLyrics =
        widget.timedLyrics != null && widget.timedLyrics!.isNotEmpty;

    return Column(
      children: [_buildLyricsContainer(context, hasLyrics, screenWidth)],
    );
  }

  Widget _buildLyricsContainer(
    BuildContext context,
    bool hasLyrics,
    double screenWidth,
  ) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: _kLyricsSectionHeight,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isLowEnd
                ? colorScheme.surfaceContainerHigh
                : Colors.white.withValues(alpha: _kLyricsContainerOpacity),
            borderRadius: BorderRadius.circular(_kBorderRadius),
            border: Border.all(
              color: isLowEnd
                  ? colorScheme.outlineVariant
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: hasLyrics
              ? _buildLyricsContent(context, screenWidth)
              : _buildNoLyricsPlaceholder(context),
        ),
        if (hasLyrics) ...[
          _buildExpandButton(context),
          _buildTranslateButton(context),
        ],
      ],
    );
  }

  Widget _buildLyricsContent(BuildContext context, double screenWidth) {
    // Dim the whole lyrics area while fetching — clear visual loading feedback.
    return AnimatedOpacity(
      opacity: _translationState == _TranslationState.loading ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.2, 0.8, 1.0],
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
      ),
    );
  }

  List<Widget> _buildAnimatedLyricLines(
    BuildContext context,
    double screenWidth,
  ) {
    final lyrics = widget.timedLyrics;
    if (lyrics == null || lyrics.isEmpty) return [];

    final startIndex = max(0, widget.currentLyricIndex - 2);
    final endIndex = min(lyrics.length - 1, widget.currentLyricIndex + 2);

    final lines = lyrics
        .sublist(startIndex, endIndex + 1)
        .asMap()
        .entries
        .map((entry) {
      final index = entry.key + startIndex;
      final lyric = entry.value;
      final isCurrent = index == widget.currentLyricIndex;
      final dist = (index - widget.currentLyricIndex).abs();
      final opacity =
          (1.0 - dist * _kOpacityDecayPerLine).clamp(_kMinLyricOpacity, 1.0);
      final scale = 1.0 - dist * _kScaleDecayPerLine;

      final translatedText =
          (_showTranslated && index < _translatedLines.length)
              ? _translatedLines[index]
              : null;

      return _buildLyricLine(
        context: context,
        lyric: lyric,
        isCurrent: isCurrent,
        opacity: opacity,
        scale: scale,
        screenWidth: screenWidth,
        translatedText: translatedText,
      );
    }).toList();

    if (_showTranslated) {
      lines.insert(
        0,
        Padding(
          key: const ValueKey('ai-disclaimer'),
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 10, color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                'AI translated \u00b7 accuracy may vary',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return lines;
  }

  Widget _buildLyricLine({
    required BuildContext context,
    required TimedLyric lyric,
    required bool isCurrent,
    required double opacity,
    required double scale,
    required double screenWidth,
    String? translatedText,
  }) {
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
        child: SizedBox(
          width: screenWidth - 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main text: translated if available, otherwise original ────
              AnimatedDefaultTextStyle(
                duration: _kLyricAnimationDuration,
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: (isCurrent ? Colors.white : Colors.white60)
                      .withValues(alpha: opacity),
                  fontSize: isCurrent
                      ? _kCurrentLyricFontSize
                      : _kOtherLyricFontSize,
                  fontFamily: FontConstants.fontFamily,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  height: 1.3,
                  letterSpacing: isCurrent ? 0.2 : 0.0,
                ),
                child: Text(
                  translatedText ?? lyric.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),

              // ── Original subtitle — animated in/out under the translation ─
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: translatedText != null
                      ? Padding(
                          key: const ValueKey('original'),
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: Text(
                              lyric.text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: (isCurrent
                                        ? Colors.white
                                        : Colors.white60)
                                    .withValues(alpha: opacity * 0.5),
                                fontSize: 11,
                                fontFamily: FontConstants.fontFamily,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLyricsPlaceholder(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: _kNoLyricsAnimationDuration,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Text(
              AppLocalizations.of(context).noLyrics,
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

  // MARK: - Overlay buttons

  Widget _buildExpandButton(BuildContext context) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 28,
      right: 24,
      child: _buttonShell(
        isLowEnd: isLowEnd,
        colorScheme: colorScheme,
        isActive: false,
        child: IconButton(
          icon: const Iconoir.Expand(
            color: Colors.white,
            width: 20,
            height: 20,
          ),
          onPressed: () => _openFullscreenLyrics(context),
          tooltip: AppLocalizations.of(context).expandLyrics,
        ),
      ),
    );
  }

  Widget _buildTranslateButton(BuildContext context) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;

    final isActive =
        _translationState == _TranslationState.done && _showTranslated;
    final isError = _translationState == _TranslationState.error;
    final isLoading = _translationState == _TranslationState.loading;

    final String tooltip;
    if (isError) {
      tooltip = 'Translation failed — tap to retry';
    } else if (isActive) {
      tooltip = 'Show original lyrics';
    } else if (_translationState == _TranslationState.done) {
      tooltip = 'Show translation';
    } else {
      tooltip = 'Translate lyrics';
    }

    return Positioned(
      bottom: 28,
      left: 24,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Opacity(
          opacity: isLoading ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: _buttonShell(
          isLowEnd: isLowEnd,
          colorScheme: colorScheme,
          isActive: isActive,
          isError: isError,
          child: isLoading
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: isError
                      ? const Iconoir.WarningTriangle(
                          color: Colors.orangeAccent,
                          width: 20,
                          height: 20,
                        )
                      : Iconoir.Language(
                          color: isActive
                              ? colorScheme.primary
                              : Colors.white,
                          width: 20,
                          height: 20,
                        ),
                  onPressed: _handleTranslateButton,
                  tooltip: tooltip,
                ),
        ),
      ),
    );
  }

  /// Shared animated shell used by both overlay buttons.
  Widget _buttonShell({
    required bool isLowEnd,
    required ColorScheme colorScheme,
    required bool isActive,
    bool isError = false,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary.withValues(alpha: 0.22)
            : isLowEnd
                ? colorScheme.surfaceContainerHigh
                : Colors.white.withValues(alpha: _kExpandButtonOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.55)
              : isError
                  ? Colors.orangeAccent.withValues(alpha: 0.5)
                  : isLowEnd
                      ? colorScheme.outlineVariant
                      : Colors.white
                          .withValues(alpha: _kExpandButtonBorderOpacity),
        ),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  void _openFullscreenLyrics(BuildContext context) {
    if (widget.audioPlayerService.currentSong == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FullscreenLyricsScreen(),
      ),
    );
  }
}

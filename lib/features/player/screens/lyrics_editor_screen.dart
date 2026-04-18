import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/lyrics_service.dart';
import '../../../shared/widgets/app_background.dart';

/// Full-screen editor for creating and timing synchronized lyrics.
///
/// Flow:
///   1. Paste raw (unsynced) lyrics via the Paste button.
///   2. Play the song and tap [TAP TO STAMP] at the moment each line starts.
///   3. Tap Save — LRC content is written to disk and the lyrics screen reloads.
class LyricsEditorScreen extends StatefulWidget {
  /// Called after lyrics are successfully saved so the caller can reload.
  final VoidCallback onSaved;

  const LyricsEditorScreen({super.key, required this.onSaved});

  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen> {
  List<String> _lines = [];
  List<Duration?> _timestamps = [];

  /// Index of the next line that will receive a timestamp when the user taps.
  int _nextStampIndex = 0;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  StreamSubscription<Duration>? _positionSub;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService =
          Provider.of<AudioPlayerService>(context, listen: false);
      _positionSub =
          audioService.audioPlayer.positionStream.listen((pos) {
        if (mounted) setState(() => _currentPosition = pos);
      });
      // Pre-populate with existing cached lyrics if available
      _tryLoadExistingLyrics(audioService);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ──────────────────────────────── helpers ────────────────────────────────

  String _formatTimestamp(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _applyLines(List<String> lines) {
    setState(() {
      _lines = lines;
      _timestamps = List.filled(lines.length, null);
      _nextStampIndex = 0;
      _lineKeys.clear();
      for (int i = 0; i < lines.length; i++) {
        _lineKeys[i] = GlobalKey();
      }
    });
  }

  // ──────────────────────────────── data loading ───────────────────────────

  Future<void> _tryLoadExistingLyrics(AudioPlayerService audioService) async {
    final song = audioService.currentSong;
    if (song == null) return;

    final artistRaw = song.artist ?? '';
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title = song.title.trim().isEmpty ? 'Unknown' : song.title.trim();

    final service = TimedLyricsService();
    final existing = await service.loadLyricsFromFile(artist, title);
    if (!mounted || existing == null || existing.isEmpty) return;

    // Pre-fill lines with existing text; user can re-stamp from scratch
    final lines = existing.map((l) => l.text).toList();
    _applyLines(lines);
  }

  // ──────────────────────────────── stamping ───────────────────────────────

  void _stampCurrentLine() {
    if (_nextStampIndex >= _lines.length) return;
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final position = audioService.audioPlayer.position;

    setState(() {
      _timestamps[_nextStampIndex] = position;
      _nextStampIndex++;
    });

    // Scroll the next line into view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nextStampIndex < _lines.length) {
        final key = _lineKeys[_nextStampIndex];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.35,
          );
        }
      }
    });
  }

  // ──────────────────────────────── dialogs ────────────────────────────────

  void _showPasteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Paste Lyrics',
          style: TextStyle(
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: FontConstants.fontFamily,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Paste unsynced lyrics here…\n\nOne line per verse line.',
              hintStyle: const TextStyle(
                  color: Colors.white30,
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.white54,
                  fontFamily: FontConstants.fontFamily),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _parsePastedText(controller.text);
            },
            child: const Text(
              'Use Lyrics',
              style: TextStyle(
                color: Colors.white,
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _parsePastedText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        // Strip existing LRC timestamp tags if the user pasted an LRC file
        .map((l) => l.replaceAll(RegExp(r'^\[[\d:\.]+\]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return;
    _applyLines(lines);
  }

  // ──────────────────────────────── saving ─────────────────────────────────

  Future<void> _save() async {
    final stampedIndices = <int>[];
    for (int i = 0; i < _lines.length; i++) {
      if (_timestamps[i] != null) stampedIndices.add(i);
    }

    if (stampedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No timestamps yet — tap the stamp button while the song plays.',
          ),
        ),
      );
      return;
    }

    // Build LRC format string
    final buffer = StringBuffer();
    for (final i in stampedIndices) {
      final t = _timestamps[i]!;
      final m =
          t.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s =
          t.inSeconds.remainder(60).toString().padLeft(2, '0');
      final cs =
          (t.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
      buffer.writeln('[$m:$s.$cs]${_lines[i]}');
    }

    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final song = audioService.currentSong;
    if (song == null) return;

    final artistRaw = song.artist ?? '';
    final artist = artistRaw.trim().isEmpty ? 'Unknown' : artistRaw.trim();
    final title =
        song.title.trim().isEmpty ? 'Unknown' : song.title.trim();

    final service = TimedLyricsService();
    await service.saveLyricsToCache(artist, title, buffer.toString());

    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
  }

  // ──────────────────────────────── build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final song = audioService.currentSong;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(song?.title ?? '', song?.artist ?? ''),
              _buildPlaybackBar(audioService),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: _buildLinesList()),
              _buildStampButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── header ─────────────────────────────────────

  Widget _buildHeader(String title, String artist) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title.isNotEmpty ? title : 'Unknown',
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showPasteDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Paste',
              style: TextStyle(
                color: Colors.white60,
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── playback bar ───────────────────────────────────

  Widget _buildPlaybackBar(AudioPlayerService audioService) {
    return StreamBuilder<Duration?>(
      stream: audioService.audioPlayer.durationStream,
      builder: (context, snap) {
        final total = snap.data ?? Duration.zero;
        final progress = total.inMilliseconds > 0
            ? (_currentPosition.inMilliseconds / total.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            children: [
              LayoutBuilder(builder: (ctx, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) {
                    final pct = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    audioService.audioPlayer.seek(total * pct);
                  },
                  child: SizedBox(
                    height: 20,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            height: 3,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 3,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_5_rounded,
                            color: Colors.white70, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        onPressed: () => audioService.audioPlayer.seek(
                          Duration(
                            milliseconds: (_currentPosition.inMilliseconds - 5000)
                                .clamp(0, total.inMilliseconds),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          audioService.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                        onPressed: () {
                          if (audioService.isPlaying) {
                            audioService.pause();
                          } else {
                            audioService.resume();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_5_rounded,
                            color: Colors.white70, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        onPressed: () => audioService.audioPlayer.seek(
                          Duration(
                            milliseconds: (_currentPosition.inMilliseconds + 5000)
                                .clamp(0, total.inMilliseconds),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDuration(total),
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────── lines list ─────────────────────────────────────

  Widget _buildLinesList() {
    if (_lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 56, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: 16),
            const Text(
              'No lyrics yet',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showPasteDialog,
              icon: const Icon(Icons.paste_rounded,
                  color: Colors.white60, size: 20),
              label: const Text(
                'Paste lyrics to get started',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _lines.length,
      itemBuilder: (context, index) => _buildLineItem(index),
    );
  }

  Widget _buildLineItem(int index) {
    final isStamped = _timestamps[index] != null;
    final isNext = index == _nextStampIndex;
    // A stamped line that is currently under the cursor — about to be re-stamped
    final isReStamping = isStamped && isNext;
    final isPast = index < _nextStampIndex;

    return GestureDetector(
      key: _lineKeys[index],
      onTap: () {
        // Move cursor to this line (whether stamped or not) and seek audio so
        // the user can hear the context and tap stamp to update the timestamp.
        final audioService =
            Provider.of<AudioPlayerService>(context, listen: false);
        if (isStamped) {
          // Seek 1.5 s before the existing timestamp so the user hears lead-in
          final seekTo = Duration(
            milliseconds:
                (_timestamps[index]!.inMilliseconds - 1500).clamp(0, 9999999),
          );
          audioService.audioPlayer.seek(seekTo);
        }
        setState(() => _nextStampIndex = index);
        // Scroll line into view
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _lineKeys[index];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.35,
            );
          }
        });
      },
      onLongPress: () {
        // Clear the timestamp on this line and move the cursor back
        setState(() {
          _timestamps[index] = null;
          if (_nextStampIndex > index) _nextStampIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isNext
              ? (isReStamping
                  ? Colors.orange.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isNext
              ? Border.all(
                  color: isReStamping
                      ? Colors.orangeAccent.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.18))
              : null,
        ),
        child: Row(
          children: [
            // Timestamp chip
            SizedBox(
              width: 76,
              child: Text(
                isStamped
                    ? _formatTimestamp(_timestamps[index]!)
                    : '--:--.--',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 12,
                  color: isStamped
                      ? (isNext ? Colors.white : Colors.white54)
                      : Colors.white24,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Status icon
            Icon(
              isReStamping
                  ? Icons.edit_rounded
                  : isStamped
                      ? Icons.check_circle_rounded
                      : isNext
                          ? Icons.arrow_right_rounded
                          : Icons.radio_button_unchecked,
              size: isNext ? 20 : 14,
              color: isReStamping
                  ? Colors.orangeAccent
                  : isStamped
                      ? Colors.white38
                      : isNext
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(width: 8),
            // Lyric text
            Expanded(
              child: Text(
                _lines[index],
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: isNext ? 15 : 14,
                  fontWeight:
                      isNext ? FontWeight.w600 : FontWeight.normal,
                  color: isPast
                      ? Colors.white60
                      : isNext
                          ? Colors.white
                          : Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── stamp button ───────────────────────────────────

  Widget _buildStampButton() {
    final hasLines = _lines.isNotEmpty;
    final allStamped =
        hasLines && _nextStampIndex >= _lines.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLines && !allStamped)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Next: "${_lines[_nextStampIndex]}"',
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white54,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          if (allStamped)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'All lines stamped — tap Save to finish.',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          GestureDetector(
            onTap: (hasLines && !allStamped) ? _stampCurrentLine : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: (hasLines && !allStamped)
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (hasLines && !allStamped)
                      ? Colors.white30
                      : Colors.white12,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  allStamped
                      ? '✓  All lines stamped'
                      : !hasLines
                          ? 'Paste lyrics first'
                          : '⏱  TAP TO STAMP LINE ${_nextStampIndex + 1} / ${_lines.length}',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: (hasLines && !allStamped)
                        ? Colors.white
                        : Colors.white30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

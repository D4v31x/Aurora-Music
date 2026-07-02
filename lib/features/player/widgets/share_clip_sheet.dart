/// Bottom sheet for generating and sharing a short vertical video "clip" of
/// the current song (artwork card + trimmed audio) to social apps.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:file_picker/file_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/share_clip_service.dart';

/// Shows the "Share as clip" bottom sheet for [song].
///
/// [initialPosition] seeds the start-offset slider (e.g. the current
/// playback position when invoked from the Now Playing screen); pass
/// [Duration.zero] when there is no meaningful current position (e.g. from a
/// library context menu on a song that isn't currently playing).
Future<void> showShareClipSheet(
  BuildContext context, {
  required SongModel song,
  Duration initialPosition = Duration.zero,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => _ShareClipSheet(song: song, initialPosition: initialPosition),
  );
}

const List<int> _kDurationPresetsSeconds = [15, 30, 60];

class _ShareClipSheet extends StatefulWidget {
  final SongModel song;
  final Duration initialPosition;

  const _ShareClipSheet({required this.song, required this.initialPosition});

  @override
  State<_ShareClipSheet> createState() => _ShareClipSheetState();
}

class _ShareClipSheetState extends State<_ShareClipSheet> {
  static final _artworkService = ArtworkCacheService();
  final _clipService = ShareClipService();

  late int _durationSeconds;
  late double _startSeconds;
  bool _generating = false;
  double _progress = 0;
  String? _error;

  double get _songDurationSeconds =>
      (widget.song.duration ?? 0) / 1000.0;

  double get _maxStartSeconds =>
      (_songDurationSeconds - _durationSeconds).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    final songDur = _songDurationSeconds;
    _durationSeconds = _kDurationPresetsSeconds
        .firstWhere((d) => d <= songDur, orElse: () => 15)
        .clamp(0, songDur > 0 ? songDur.floor() : 15)
        .toInt();
    if (_durationSeconds <= 0) _durationSeconds = 15;

    final initial = widget.initialPosition.inMilliseconds / 1000.0;
    _startSeconds = initial.clamp(0, _maxStartSeconds);
  }

  void _selectDuration(int seconds) {
    setState(() {
      _durationSeconds = seconds;
      _startSeconds = _startSeconds.clamp(0, _maxStartSeconds);
    });
  }

  Future<void> _generateAndSave() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _progress = 0;
      _error = null;
    });

    Directory? workDir;
    try {
      final file = await _clipService.generateClip(
        song: widget.song,
        start: Duration(milliseconds: (_startSeconds * 1000).round()),
        clipDuration: Duration(seconds: _durationSeconds),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      workDir = file.parent;

      if (!mounted) return;
      final safeTitle = widget.song.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final savedPath = await FilePicker.saveFile(
        fileName: '${safeTitle.isEmpty ? 'clip' : safeTitle}.mp4',
        type: FileType.video,
        bytes: await file.readAsBytes(),
      );

      if (!mounted) return;
      if (savedPath != null) {
        NotificationManager.showMessage(
            context, AppLocalizations.of(context).clipSavedToDevice);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ShareClipException
              ? e.message
              : AppLocalizations.of(context).clipSaveFailed;
        });
      }
    } finally {
      // Clean up the generated file's working directory either way.
      if (workDir != null && workDir.existsSync()) {
        unawaited(workDir.delete(recursive: true));
      }
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxStart = _maxStartSeconds;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withValues(alpha: 0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _artworkService.buildCachedArtwork(
                            widget.song.id,
                            size: 48),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: FontConstants.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              widget.song.artist ?? l10n.unknownArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontFamily: FontConstants.fontFamily,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.clipDuration,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _kDurationPresetsSeconds.map((seconds) {
                      final available = seconds <= _songDurationSeconds ||
                          _songDurationSeconds <= 0;
                      final selected = _durationSeconds == seconds;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${seconds}s'),
                          selected: selected,
                          onSelected: available && !_generating
                              ? (_) => _selectDuration(seconds)
                              : null,
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                          ),
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.clipStartOffset,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  Slider(
                    value: _startSeconds.clamp(0, maxStart > 0 ? maxStart : 0),
                    max: maxStart > 0 ? maxStart : 1,
                    onChanged: (maxStart > 0 && !_generating)
                        ? (v) => setState(() => _startSeconds = v)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatSeconds(_startSeconds),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(_formatSeconds(_startSeconds + _durationSeconds),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  if (_generating)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generating ? null : _generateAndSave,
                      icon: _generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const iconoir.Download(color: Colors.black),
                      label: Text(_generating
                          ? l10n.generatingClip
                          : l10n.saveClip),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

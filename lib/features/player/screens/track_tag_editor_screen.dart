/// Screen for creating, renaming, and deleting [TrackTag] markers on a
/// single (typically long / DJ-set style) track, so the user can jump
/// straight to any tagged part from the Now Playing screen.
///
/// Design mirrors `LyricsEditorScreen`: an [AppBackground] behind a
/// transparent [Scaffold] with a custom header (no default AppBar), styled
/// dialogs, and a bottom-docked action button.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/track_tag_model.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/track_tag_service.dart';
import '../../../shared/utils/formatters/duration_formatter.dart';
import '../../../shared/widgets/app_background.dart';

/// Matches lines like "0:00 Intro", "00:00 - Song Name", "[1:23:45] Song",
/// as commonly found in YouTube video descriptions/setlists.
final RegExp _setlistLineRegex = RegExp(
  r'^\(?\[?\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s*\]?\)?\s*[-–—:]?\s*(.+)$',
);

class TrackTagEditorScreen extends StatefulWidget {
  final SongModel song;

  const TrackTagEditorScreen({super.key, required this.song});

  @override
  State<TrackTagEditorScreen> createState() => _TrackTagEditorScreenState();
}

class _TrackTagEditorScreenState extends State<TrackTagEditorScreen> {
  StreamSubscription<Duration>? _positionSubscription;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioPlayerService>();
    _currentPosition = audio.audioPlayer.position;
    _positionSubscription = audio.audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Duration get _trackDuration =>
      Duration(milliseconds: widget.song.duration ?? 0);

  Future<void> _openTagDialog({TrackTag? existing}) async {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController(text: existing?.name ?? '');
    var position = existing?.position ?? _currentPosition;
    final maxMs = _trackDuration.inMilliseconds > 0
        ? _trackDuration.inMilliseconds
        : (position.inMilliseconds + 1);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(
                existing == null ? loc.addTrackTag : loc.editTrackTags,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: FontConstants.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: loc.trackTagNameHint,
                      hintStyle: const TextStyle(
                          color: Colors.white30,
                          fontFamily: FontConstants.fontFamily),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${loc.trackTagPosition}: ${formatDuration(position)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(
                            () => position = _currentPosition),
                        child: Text(
                          loc.useCurrentPosition,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontFamily: FontConstants.fontFamily),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    max: maxMs.toDouble(),
                    onChanged: (value) => setDialogState(
                        () => position = Duration(milliseconds: value.round())),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    loc.cancel,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: FontConstants.fontFamily),
                  ),
                ),
                TextButton(
                  onPressed: nameController.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: Text(
                    loc.save,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: FontConstants.fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final trackTagService = context.read<TrackTagService>();
    if (existing == null) {
      await trackTagService.addTag(
        widget.song.id,
        TrackTag(
          id: 'tag_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          position: position,
        ),
      );
    } else {
      await trackTagService.updateTag(
        widget.song.id,
        existing.copyWith(name: name, position: position),
      );
    }
  }

  Future<void> _deleteTag(TrackTag tag) async {
    await context.read<TrackTagService>().deleteTag(widget.song.id, tag.id);
  }

  // ──────────────────────────── paste setlist ──────────────────────────────

  List<TrackTag> _parseSetlist(String text) {
    final tags = <TrackTag>[];
    var counter = 0;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = _setlistLineRegex.firstMatch(line);
      if (match == null) continue;

      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
      final name = match.group(4)?.trim() ?? '';
      if (name.isEmpty) continue;

      tags.add(TrackTag(
        id: 'tag_${DateTime.now().microsecondsSinceEpoch}_${counter++}',
        name: name,
        position:
            Duration(hours: hours, minutes: minutes, seconds: seconds),
      ));
    }
    tags.sort((a, b) => a.position.compareTo(b.position));
    return tags;
  }

  void _showPasteSetlistDialog() {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.pasteSetlistDialogTitle,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
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
              hintText: loc.pasteSetlistHint,
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
            child: Text(
              loc.cancel,
              style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: FontConstants.fontFamily),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _importSetlist(controller.text);
            },
            child: Text(
              loc.importAction,
              style: const TextStyle(
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

  Future<void> _importSetlist(String text) async {
    final loc = AppLocalizations.of(context);
    final parsed = _parseSetlist(text);

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.noTagsFoundInPaste)),
      );
      return;
    }

    await context.read<TrackTagService>().addTags(widget.song.id, parsed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.tagsImportedMessage(parsed.length))),
    );
  }

  // ──────────────────────────────── build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final audio = context.watch<AudioPlayerService>();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(loc),
              _buildPlaybackBar(audio),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: Consumer<TrackTagService>(
                  builder: (context, trackTagService, _) {
                    final tags = trackTagService.tagsFor(widget.song.id);
                    return tags.isEmpty
                        ? _buildEmptyState(loc)
                        : _buildTagsList(tags);
                  },
                ),
              ),
              _buildAddTagButton(loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations loc) {
    final song = widget.song;
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
                  loc.trackTags,
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
                Text(
                  song.title,
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
          TextButton.icon(
            onPressed: _showPasteSetlistDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.paste_rounded,
                color: Colors.white60, size: 18),
            label: Text(
              loc.pasteSetlist,
              style: const TextStyle(
                color: Colors.white60,
                fontFamily: FontConstants.fontFamily,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackBar(AudioPlayerService audio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text(
            formatDuration(_currentPosition),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontFamily: FontConstants.fontFamily,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatDuration(_trackDuration),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontFamily: FontConstants.fontFamily,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              audio.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            onPressed: () => audio.isPlaying
                ? audio.audioPlayer.pause()
                : audio.audioPlayer.play(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 56, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              loc.noTrackTagsYet,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white54,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _showPasteSetlistDialog,
            icon: const Icon(Icons.paste_rounded,
                color: Colors.white60, size: 20),
            label: Text(
              loc.pasteSetlist,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsList(List<TrackTag> tags) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: tags.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final tag = tags[index];
        return Dismissible(
          key: ValueKey(tag.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _deleteTag(tag),
          child: ListTile(
            onTap: () => _openTagDialog(existing: tag),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: SizedBox(
              width: 56,
              child: Text(
                formatDuration(tag.position),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            title: Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38),
              onPressed: () => _deleteTag(tag),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddTagButton(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: () => _openTagDialog(),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30, width: 1.2),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  loc.addTrackTag,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


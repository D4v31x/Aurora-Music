import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/widgets/unified_detail_screen.dart';
import '../../../l10n/app_localizations.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderPath;

  const FolderDetailScreen({super.key, required this.folderPath});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  List<SongModel> _allSongs = [];
  Duration _totalDuration = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final allSongs = audioPlayerService.songs;

    final folderSongs = allSongs.where((song) {
      final songFile = File(song.data);
      return songFile.parent.path == widget.folderPath;
    }).toList();

    Duration totalDuration = Duration.zero;
    for (final song in folderSongs) {
      totalDuration += Duration(milliseconds: song.duration ?? 0);
    }

    setState(() {
      _allSongs = folderSongs;
      _totalDuration = totalDuration;
      _isLoading = false;
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;

    return UnifiedDetailScreen(
      config: DetailScreenConfig(
        type: DetailScreenType.folder,
        title: folderName,
        subtitle: widget.folderPath,
        playbackSource: PlaybackSourceInfo(
          source: PlaybackSource.folder,
          name: folderName,
        ),
        heroTag: 'folder_icon_${widget.folderPath}',
        headerIcon: Icons.folder_rounded,
        accentColor: Colors.blueGrey,
        stats: [
          DetailStat(
            icon: Icons.music_note_rounded,
            value: '${_allSongs.length}',
            label: localizations.translate('songs'),
          ),
          DetailStat(
            icon: Icons.timer_outlined,
            value: _formatDuration(_totalDuration),
            label: localizations.translate('total'),
          ),
        ],
      ),
      songs: _allSongs,
      isLoading: _isLoading,
    );
  }
}

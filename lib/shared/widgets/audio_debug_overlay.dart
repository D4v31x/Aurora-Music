/// Audio debug overlay widget.
///
/// Displays technical playback information like bitrate, codec,
/// and sample rate for power users.
library;

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';

/// Displays debug information about the currently playing track.
class AudioDebugOverlay extends StatelessWidget {
  final bool isVisible;

  const AudioDebugOverlay({
    super.key,
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Consumer<AudioPlayerService>(
      builder: (context, audioService, _) {
        final song = audioService.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 140,
          left: 16,
          right: 16,
          child: _DebugInfoCard(
            song: song,
            audioPlayer: audioService.audioPlayer,
          ),
        );
      },
    );
  }
}

class _DebugInfoCard extends StatelessWidget {
  final SongModel song;
  final AudioPlayer audioPlayer;

  const _DebugInfoCard({
    required this.song,
    required this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.bug_report_rounded,
                color: Colors.green.shade400,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Audio Debug Info',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Info rows
          _InfoRow(
            label: 'Format',
            value: song.fileExtension.toUpperCase(),
          ),
          _InfoRow(
            label: 'Bitrate',
            value: _formatBitrate(song),
          ),
          _InfoRow(
            label: 'Sample Rate',
            value: _formatSampleRate(),
          ),
          _InfoRow(
            label: 'Duration',
            value: _formatDuration(song.duration),
          ),
          StreamBuilder<Duration>(
            stream: audioPlayer.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return _InfoRow(
                label: 'Position',
                value: _formatDuration(position.inMilliseconds),
              );
            },
          ),
          StreamBuilder<double>(
            stream: audioPlayer.speedStream,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? 1.0;
              return _InfoRow(
                label: 'Speed',
                value: '${speed}x',
              );
            },
          ),
          StreamBuilder<LoopMode>(
            stream: audioPlayer.loopModeStream,
            builder: (context, snapshot) {
              final mode = snapshot.data ?? LoopMode.off;
              return _InfoRow(
                label: 'Loop',
                value: _loopModeToString(mode),
              );
            },
          ),
          StreamBuilder<bool>(
            stream: audioPlayer.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final shuffle = snapshot.data ?? false;
              return _InfoRow(
                label: 'Shuffle',
                value: shuffle ? 'On' : 'Off',
              );
            },
          ),
          _InfoRow(
            label: 'File',
            value: _truncatePath(song.data),
          ),
        ],
      ),
    );
  }

  String _formatBitrate(SongModel song) {
    // Estimate bitrate from file size and duration
    // This is an approximation since bitrate isn't directly available
    if (song.duration == null || song.duration! <= 0) {
      return 'Unknown';
    }

    // Use the extension to estimate typical bitrates
    switch (song.fileExtension.toLowerCase()) {
      case 'flac':
        return '~900-1400 kbps (Lossless)';
      case 'wav':
        return '~1411 kbps (Lossless)';
      case 'mp3':
        return '128-320 kbps';
      case 'm4a':
      case 'aac':
        return '128-256 kbps';
      case 'ogg':
        return '96-320 kbps';
      case 'opus':
        return '64-256 kbps';
      default:
        return 'Unknown';
    }
  }

  String _formatSampleRate() {
    // Common sample rates based on format
    switch (song.fileExtension.toLowerCase()) {
      case 'flac':
      case 'wav':
        return '44.1-96 kHz';
      case 'mp3':
      case 'm4a':
      case 'aac':
        return '44.1 kHz';
      case 'ogg':
      case 'opus':
        return '48 kHz';
      default:
        return 'Unknown';
    }
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return 'Unknown';
    final duration = Duration(milliseconds: durationMs);
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$mins:$secs.$ms';
  }

  String _loopModeToString(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return 'Off';
      case LoopMode.one:
        return 'One';
      case LoopMode.all:
        return 'All';
    }
  }

  String _truncatePath(String path) {
    if (path.length <= 40) return path;
    return '...${path.substring(path.length - 37)}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating debug button that can be added to Now Playing screen
class DebugInfoButton extends StatefulWidget {
  const DebugInfoButton({super.key});

  @override
  State<DebugInfoButton> createState() => _DebugInfoButtonState();
}

class _DebugInfoButtonState extends State<DebugInfoButton> {
  bool _showDebugInfo = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_showDebugInfo)
          AudioDebugOverlay(isVisible: _showDebugInfo),
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'debug_fab',
            backgroundColor: _showDebugInfo
                ? Colors.green.shade700
                : Colors.black.withOpacity(0.5),
            onPressed: () {
              setState(() => _showDebugInfo = !_showDebugInfo);
            },
            child: Icon(
              Icons.bug_report_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline debug info widget for track detail sheet
class InlineAudioInfo extends StatelessWidget {
  final SongModel song;

  const InlineAudioInfo({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTile(
          context,
          isDark,
          Icons.audio_file_rounded,
          'Format',
          song.fileExtension.toUpperCase(),
        ),
        _buildInfoTile(
          context,
          isDark,
          Icons.speed_rounded,
          'Bitrate',
          _formatBitrate(song),
        ),
        _buildInfoTile(
          context,
          isDark,
          Icons.graphic_eq_rounded,
          'Sample Rate',
          _formatSampleRate(song),
        ),
        _buildInfoTile(
          context,
          isDark,
          Icons.timer_outlined,
          'Duration',
          _formatDuration(song.duration),
        ),
        _buildInfoTile(
          context,
          isDark,
          Icons.storage_rounded,
          'Size',
          _formatFileSize(song.size),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBitrate(SongModel song) {
    switch (song.fileExtension.toLowerCase()) {
      case 'flac':
        return 'Lossless';
      case 'wav':
        return 'Lossless (PCM)';
      case 'mp3':
        return '~320 kbps';
      case 'm4a':
      case 'aac':
        return '~256 kbps';
      case 'ogg':
        return '~192 kbps';
      case 'opus':
        return '~128 kbps';
      default:
        return 'Unknown';
    }
  }

  String _formatSampleRate(SongModel song) {
    switch (song.fileExtension.toLowerCase()) {
      case 'flac':
      case 'wav':
        return '44.1-96 kHz';
      default:
        return '44.1 kHz';
    }
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return 'Unknown';
    final duration = Duration(milliseconds: durationMs);
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

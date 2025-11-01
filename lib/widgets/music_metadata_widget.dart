import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Widget to display music file metadata (format, bitrate, sample rate, etc.)
class MusicMetadataWidget extends StatelessWidget {
  final SongModel song;

  const MusicMetadataWidget({
    super.key,
    required this.song,
  });

  String _getFileFormat() {
    if (song.data.endsWith('.mp3')) return 'MP3';
    if (song.data.endsWith('.m4a')) return 'M4A';
    if (song.data.endsWith('.flac')) return 'FLAC';
    if (song.data.endsWith('.wav')) return 'WAV';
    if (song.data.endsWith('.ogg')) return 'OGG';
    if (song.data.endsWith('.opus')) return 'OPUS';
    if (song.data.endsWith('.aac')) return 'AAC';
    return 'UNKNOWN';
  }

  String _getFileSizeFormatted() {
    final sizeBytes = song.size;
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _estimateBitrate() {
    // Estimate bitrate based on file size and duration
    if (song.duration == null || song.duration! <= 0) return 'Unknown';

    final durationSeconds = song.duration! / 1000;
    final sizeKB = song.size / 1024;
    final bitrateKbps = (sizeKB * 8) / durationSeconds;

    if (bitrateKbps >= 320) return '320+ kbps';
    if (bitrateKbps >= 256) return '256 kbps';
    if (bitrateKbps >= 192) return '192 kbps';
    if (bitrateKbps >= 128) return '128 kbps';
    return '${bitrateKbps.toStringAsFixed(0)} kbps';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'File Information',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetadataChip(
                icon: Icons.audiotrack,
                label: _getFileFormat(),
                color: const Color(0xFF3B82F6),
              ),
              _buildMetadataChip(
                icon: Icons.speed,
                label: _estimateBitrate(),
                color: const Color(0xFF10B981),
              ),
              _buildMetadataChip(
                icon: Icons.storage,
                label: _getFileSizeFormatted(),
                color: const Color(0xFFF59E0B),
              ),
              if (song.duration != null)
                _buildMetadataChip(
                  icon: Icons.timer,
                  label: _formatDuration(song.duration!),
                  color: const Color(0xFF8B5CF6),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

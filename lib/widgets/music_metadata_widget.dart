import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../localization/app_localizations.dart';
import '../screens/settings/metadata_detail_screen.dart';

/// Compact glassmorphic widget to display music file metadata overview
class MusicMetadataWidget extends StatelessWidget {
  final SongModel song;

  const MusicMetadataWidget({
    super.key,
    required this.song,
  });

  String _getFileFormat() {
    final path = song.data.toLowerCase();
    if (path.endsWith('.mp3')) return 'MP3';
    if (path.endsWith('.m4a')) return 'M4A';
    if (path.endsWith('.flac')) return 'FLAC';
    if (path.endsWith('.wav')) return 'WAV';
    if (path.endsWith('.ogg')) return 'OGG';
    if (path.endsWith('.opus')) return 'OPUS';
    if (path.endsWith('.aac')) return 'AAC';
    if (path.endsWith('.wma')) return 'WMA';
    if (path.endsWith('.alac')) return 'ALAC';
    return 'AUDIO';
  }

  String _getFileSizeFormatted() {
    final sizeBytes = song.size;
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int _estimateBitrateValue() {
    if (song.duration == null || song.duration! <= 0) return 0;
    final durationSeconds = song.duration! / 1000;
    final sizeKB = song.size / 1024;
    return ((sizeKB * 8) / durationSeconds).round();
  }

  String _getQualityLabel(AppLocalizations loc) {
    final format = _getFileFormat();
    final bitrate = _estimateBitrateValue();

    if (format == 'FLAC' || format == 'WAV' || format == 'ALAC') {
      return loc.translate('lossless');
    }
    if (bitrate >= 256) return loc.translate('high_quality');
    if (bitrate >= 192) return loc.translate('good_quality');
    if (bitrate >= 128) return loc.translate('standard_quality');
    return loc.translate('low_quality');
  }

  String _formatDuration() {
    if (song.duration == null) return '—';
    final duration = Duration(milliseconds: song.duration!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getQualityIcon(AppLocalizations loc) {
    final label = _getQualityLabel(loc);
    if (label == loc.translate('lossless')) return Icons.diamond_outlined;
    if (label == loc.translate('high_quality')) return Icons.stars_outlined;
    if (label == loc.translate('good_quality')) return Icons.thumb_up_outlined;
    if (label == loc.translate('standard_quality')) {
      return Icons.check_circle_outline;
    }
    return Icons.warning_amber_outlined;
  }

  Color _getQualityColor(AppLocalizations loc) {
    final label = _getQualityLabel(loc);
    if (label == loc.translate('lossless')) return const Color(0xFF8B5CF6);
    if (label == loc.translate('high_quality')) return const Color(0xFF10B981);
    if (label == loc.translate('good_quality')) return const Color(0xFF3B82F6);
    if (label == loc.translate('standard_quality')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            loc.translate('metadata'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'ProductSans',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Compact metadata card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MetadataDetailScreen(song: song),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quality badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getQualityColor(loc).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getQualityColor(loc).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getQualityIcon(loc),
                              color: _getQualityColor(loc),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getQualityLabel(loc),
                              style: TextStyle(
                                color: _getQualityColor(loc),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                              _getFileFormat(), loc.translate('format')),
                          _buildDivider(),
                          _buildStatItem('${_estimateBitrateValue()} kbps',
                              loc.translate('bitrate')),
                          _buildDivider(),
                          _buildStatItem(
                              _getFileSizeFormatted(), loc.translate('size')),
                          _buildDivider(),
                          _buildStatItem(
                              _formatDuration(), loc.translate('duration')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // "View more" hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            loc.translate('view_details'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

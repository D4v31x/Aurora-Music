/// Track detail bottom sheet.
///
/// Displays detailed track information and allows editing
/// per-track settings like skip intro/outro, volume, etc.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/artist_utils.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/track_settings_service.dart';
import '../../../shared/services/crossfade_service.dart';
import '../../library/screens/album_detail_screen.dart';
import '../../library/screens/artist_detail_screen.dart';

/// Shows a bottom sheet with track details and actions.
void showTrackDetailSheet(BuildContext context, SongModel song) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TrackDetailSheet(song: song),
  );
}

/// Bottom sheet for track details and actions.
class TrackDetailSheet extends StatefulWidget {
  final SongModel song;

  const TrackDetailSheet({super.key, required this.song});

  @override
  State<TrackDetailSheet> createState() => _TrackDetailSheetState();
}

class _TrackDetailSheetState extends State<TrackDetailSheet> {
  static final _artworkService = ArtworkCacheService();
  final TrackSettingsService _trackSettingsService = TrackSettingsService();
  final CrossfadeService _crossfadeService = CrossfadeService();

  late TrackPlaybackSettings _currentSettings;
  TrackCrossfadeSettings? _crossfadeSettings;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _trackSettingsService.initialize();
    await _crossfadeService.initialize();

    if (mounted) {
      setState(() {
        _currentSettings =
            _trackSettingsService.getTrackSettings(widget.song.id.toString());
        _crossfadeSettings =
            _crossfadeService.getTrackSettings(widget.song.id.toString());
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Track header
            _buildTrackHeader(context, isDark, l10n),

            const SizedBox(height: 16),

            // Quick actions
            _buildQuickActions(context, isDark, l10n, audioService),

            const Divider(height: 32),

            // Playback settings
            if (_initialized)
              _buildPlaybackSettings(context, isDark, l10n),

            const Divider(height: 32),

            // Track info
            _buildTrackInfo(context, isDark, l10n),

            // Navigation actions
            _buildNavigationActions(context, isDark, l10n),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Artwork
          Hero(
            tag: 'track_art_${widget.song.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _artworkService.buildCachedArtwork(
                widget.song.id,
                size: 80,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  splitArtists(widget.song.artist ?? 'Unknown Artist').join(', '),
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.song.album != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.song.album!,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    AudioPlayerService audioService,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: Icons.play_arrow_rounded,
            label: l10n.translate('playAll'),
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              audioService.setPlaylist([widget.song], 0);
            },
          ),
          _QuickActionButton(
            icon: Icons.queue_play_next_rounded,
            label: l10n.translate('playNext'),
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              audioService.playNext(widget.song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added to play next'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.add_to_queue_rounded,
            label: l10n.translate('addToQueue'),
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              audioService.addToQueue(widget.song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added to queue'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: audioService.isLiked(widget.song)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: audioService.isLiked(widget.song) ? 'Liked' : 'Like',
            isDark: isDark,
            isActive: audioService.isLiked(widget.song),
            onTap: () {
              HapticFeedback.lightImpact();
              audioService.toggleLike(widget.song);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackSettings(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.translate('trackSettings'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Skip intro
        _SettingsTile(
          icon: Icons.skip_next_rounded,
          title: l10n.translate('skipIntro'),
          subtitle: _currentSettings.skipIntroSeconds > 0
              ? '${_currentSettings.skipIntroSeconds} ${l10n.translate('seconds')}'
              : 'Off',
          isDark: isDark,
          onTap: () => _showSkipIntroDialog(context, isDark, l10n),
        ),

        // Skip outro
        _SettingsTile(
          icon: Icons.skip_previous_rounded,
          title: l10n.translate('skipOutro'),
          subtitle: _currentSettings.skipOutroSeconds > 0
              ? '${_currentSettings.skipOutroSeconds} ${l10n.translate('seconds')}'
              : 'Off',
          isDark: isDark,
          onTap: () => _showSkipOutroDialog(context, isDark, l10n),
        ),

        // Exclude from suggestions
        SwitchListTile(
          secondary: Icon(
            Icons.lightbulb_outline_rounded,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
          title: Text(
            l10n.translate('excludeFromSuggestions'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          value: _currentSettings.excludeFromSuggestions,
          onChanged: (value) async {
            await _trackSettingsService.updateTrackSetting(
              widget.song.id.toString(),
              excludeFromSuggestions: value,
            );
            setState(() {
              _currentSettings = _trackSettingsService
                  .getTrackSettings(widget.song.id.toString());
            });
          },
        ),

        // Exclude from stats
        SwitchListTile(
          secondary: Icon(
            Icons.bar_chart_rounded,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
          title: Text(
            l10n.translate('excludeFromStats'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          value: _currentSettings.excludeFromStats,
          onChanged: (value) async {
            await _trackSettingsService.updateTrackSetting(
              widget.song.id.toString(),
              excludeFromStats: value,
            );
            setState(() {
              _currentSettings = _trackSettingsService
                  .getTrackSettings(widget.song.id.toString());
            });
          },
        ),

        // Crossfade override (if crossfade is enabled globally)
        if (_crossfadeService.isEnabled)
          _buildCrossfadeOverride(context, isDark, l10n),
      ],
    );
  }

  Widget _buildCrossfadeOverride(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final isLive = _crossfadeSettings?.isLive ?? false;
    final isDJMix = _crossfadeSettings?.isDJMix ?? false;
    final isContinuous = _crossfadeSettings?.isContinuous ?? false;

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.mic_rounded,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
          title: Text(
            'Mark as live recording',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Text(
            'Disable crossfade for this track',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 12,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          value: isLive,
          onChanged: (value) async {
            await _crossfadeService.setTrackSettings(
              widget.song.id.toString(),
              TrackCrossfadeSettings(
                isLive: value,
                isDJMix: isDJMix,
                isContinuous: isContinuous,
              ),
            );
            setState(() {
              _crossfadeSettings =
                  _crossfadeService.getTrackSettings(widget.song.id.toString());
            });
          },
        ),
      ],
    );
  }

  Widget _buildTrackInfo(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final duration = Duration(milliseconds: widget.song.duration ?? 0);
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.translate('trackInfo'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: l10n.translate('duration'),
          value: '$mins:$secs',
          isDark: isDark,
        ),
        if (widget.song.album != null)
          _InfoRow(
            label: l10n.translate('album'),
            value: widget.song.album!,
            isDark: isDark,
          ),
        if (widget.song.genre != null)
          _InfoRow(
            label: l10n.translate('genre'),
            value: widget.song.genre!,
            isDark: isDark,
          ),
        _InfoRow(
          label: l10n.translate('format'),
          value: widget.song.fileExtension.toUpperCase(),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildNavigationActions(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        const Divider(height: 32),
        // Go to artist
        if (widget.song.artist != null)
          ListTile(
            leading: Icon(
              Icons.person_rounded,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
            ),
            title: Text(
              l10n.translate('viewArtist'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              widget.song.artist!,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistDetailsScreen(
                    artistName: splitArtists(widget.song.artist!).first,
                  ),
                ),
              );
            },
          ),
        // Go to album
        if (widget.song.album != null && widget.song.albumId != null)
          ListTile(
            leading: Icon(
              Icons.album_rounded,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
            ),
            title: Text(
              l10n.translate('album'),
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              widget.song.album!,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(
                    albumId: widget.song.albumId!,
                    albumName: widget.song.album!,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showSkipIntroDialog(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    int seconds = _currentSettings.skipIntroSeconds;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.translate('skipIntro'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds ${l10n.translate('seconds')}',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Slider(
                value: seconds.toDouble(),
                min: 0,
                max: 60,
                divisions: 60,
                onChanged: (value) {
                  setDialogState(() {
                    seconds = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await _trackSettingsService.updateTrackSetting(
                  widget.song.id.toString(),
                  skipIntroSeconds: seconds,
                );
                if (mounted) {
                  setState(() {
                    _currentSettings = _trackSettingsService
                        .getTrackSettings(widget.song.id.toString());
                  });
                }
                Navigator.pop(context);
              },
              child: Text(l10n.translate('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showSkipOutroDialog(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    int seconds = _currentSettings.skipOutroSeconds;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.translate('skipOutro'),
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds ${l10n.translate('seconds')}',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Slider(
                value: seconds.toDouble(),
                min: 0,
                max: 60,
                divisions: 60,
                onChanged: (value) {
                  setDialogState(() {
                    seconds = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await _trackSettingsService.updateTrackSetting(
                  widget.song.id.toString(),
                  skipOutroSeconds: seconds,
                );
                if (mounted) {
                  setState(() {
                    _currentSettings = _trackSettingsService
                        .getTrackSettings(widget.song.id.toString());
                  });
                }
                Navigator.pop(context);
              },
              child: Text(l10n.translate('save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button for the track detail sheet
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 11,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings tile for the track detail sheet
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontSize: 12,
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
      ),
      onTap: onTap,
    );
  }
}

/// Info row for track details
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontSize: 14,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

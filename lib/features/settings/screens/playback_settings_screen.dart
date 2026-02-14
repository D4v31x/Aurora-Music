/// Playback settings screen.
///
/// Contains crossfade, audio tools, and other playback-related settings.
library;

import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/crossfade_service.dart';
import '../../../shared/services/audio_tools_service.dart';
import '../../../shared/services/offline_mode_service.dart';

/// Settings screen for playback configuration.
class PlaybackSettingsScreen extends StatefulWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  State<PlaybackSettingsScreen> createState() => _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState extends State<PlaybackSettingsScreen> {
  late CrossfadeService _crossfadeService;
  late AudioToolsService _audioToolsService;
  late OfflineModeService _offlineModeService;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _crossfadeService = Provider.of<CrossfadeService>(context, listen: false);
      _audioToolsService =
          Provider.of<AudioToolsService>(context, listen: false);
      _offlineModeService =
          Provider.of<OfflineModeService>(context, listen: false);
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final audioService = Provider.of<AudioPlayerService>(context);

    // Listen to service changes to rebuild UI when they notify
    // ignore: unused_local_variable
    final crossfadeService = Provider.of<CrossfadeService>(context);
    // ignore: unused_local_variable
    final audioToolsService = Provider.of<AudioToolsService>(context);
    // ignore: unused_local_variable
    final offlineModeService = Provider.of<OfflineModeService>(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('settingsPlayback'),
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Basic playback settings
                _buildSectionHeader(
                  l10n.translate('settingsPlayback'),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  // Gapless playback
                  SwitchListTile(
                    title: Text(
                      l10n.translate('settingsGapless'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('settingsGaplessDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: audioService.gaplessPlayback,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      audioService.setGaplessPlayback(value);
                    },
                  ),
                  const Divider(height: 1),
                  // Volume normalization
                  SwitchListTile(
                    title: Text(
                      l10n.translate('settingsNormalization'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('settingsNormalizationDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: audioService.volumeNormalization,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      audioService.setVolumeNormalization(value);
                    },
                  ),
                  const Divider(height: 1),
                  // Playback speed
                  ListTile(
                    title: Text(
                      l10n.translate('playbackSpeed'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      '${audioService.playbackSpeed}x',
                      style: _subtitleStyle(isDark),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.3),
                    ),
                    onTap: () => _showPlaybackSpeedDialog(
                        context, isDark, l10n, audioService),
                  ),
                ]),

                const SizedBox(height: 24),

                // Crossfade settings
                _buildSectionHeader(l10n.translate('crossfade'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  SwitchListTile(
                    title: Text(
                      l10n.translate('crossfade'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('crossfadeDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: _crossfadeService.isEnabled,
                    onChanged: (value) async {
                      HapticFeedback.lightImpact();
                      await _crossfadeService.setEnabled(value);
                      setState(() {});
                    },
                  ),
                  if (_crossfadeService.isEnabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.translate('crossfadeDuration'),
                        style: _titleStyle(isDark),
                      ),
                      subtitle: Slider(
                        value: _crossfadeService.durationSeconds.toDouble(),
                        min: 2,
                        max: 5,
                        divisions: 3,
                        label:
                            '${_crossfadeService.durationSeconds} ${l10n.translate('seconds')}',
                        onChanged: (value) async {
                          await _crossfadeService.setDuration(value.round());
                          setState(() {});
                        },
                      ),
                      trailing: Text(
                        '${_crossfadeService.durationSeconds}s',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        l10n.translate('crossfadeSmartDetection'),
                        style: _titleStyle(isDark),
                      ),
                      subtitle: Text(
                        l10n.translate('crossfadeSmartDetectionDesc'),
                        style: _subtitleStyle(isDark),
                      ),
                      value: _crossfadeService.config.smartDetection,
                      onChanged: (value) async {
                        HapticFeedback.lightImpact();
                        await _crossfadeService.setSmartDetection(value);
                        setState(() {});
                      },
                    ),
                  ],
                ]),

                const SizedBox(height: 24),

                // Audio tools (normalization only)
                _buildSectionHeader(
                  l10n.translate('loudnessNormalization'),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.volume_up_rounded,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.7),
                    ),
                    title: Text(
                      l10n.translate('loudnessNormalization'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('loudnessNormalizationDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: _audioToolsService.isLoudnessNormalizationEnabled,
                    onChanged: (value) async {
                      HapticFeedback.lightImpact();
                      await _audioToolsService.setLoudnessNormalization(value);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.tune_rounded,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.7),
                    ),
                    title: Text(
                      l10n.translate('replayGain'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('replayGainDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: _audioToolsService.isReplayGainEnabled,
                    onChanged: (value) async {
                      HapticFeedback.lightImpact();
                      await _audioToolsService.setReplayGainEnabled(value);
                      setState(() {});
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                // Offline mode
                _buildSectionHeader(l10n.translate('offlineMode'), isDark),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.cloud_off_rounded,
                      color: _offlineModeService.isOfflineMode
                          ? Colors.orange
                          : (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.7),
                    ),
                    title: Text(
                      l10n.translate('offlineMode'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      l10n.translate('offlineModeDesc'),
                      style: _subtitleStyle(isDark),
                    ),
                    value: _offlineModeService.isOfflineMode,
                    onChanged: (value) async {
                      HapticFeedback.lightImpact();
                      await _offlineModeService.setOfflineMode(value);
                      setState(() {});
                    },
                  ),
                  if (!_offlineModeService.isOfflineMode) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.wifi_rounded,
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.7),
                      ),
                      title: Text(
                        l10n.translate('downloadOnWifiOnly'),
                        style: _titleStyle(isDark),
                      ),
                      value: _offlineModeService.downloadOnWifiOnly,
                      onChanged: (value) async {
                        HapticFeedback.lightImpact();
                        await _offlineModeService.setDownloadOnWifiOnly(value);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.battery_charging_full_rounded,
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.7),
                      ),
                      title: Text(
                        l10n.translate('downloadWhileCharging'),
                        style: _titleStyle(isDark),
                      ),
                      value: _offlineModeService.downloadWhileChargingOnly,
                      onChanged: (value) async {
                        HapticFeedback.lightImpact();
                        await _offlineModeService
                            .setDownloadWhileChargingOnly(value);
                        setState(() {});
                      },
                    ),
                  ],
                ]),

                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  TextStyle _titleStyle(bool isDark) => TextStyle(
        fontFamily: FontConstants.fontFamily,
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black,
      );

  TextStyle _subtitleStyle(bool isDark) => TextStyle(
        fontFamily: FontConstants.fontFamily,
        fontSize: 13,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
      );

  void _showPlaybackSpeedDialog(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    AudioPlayerService audioService,
  ) {
    double currentSpeed = audioService.playbackSpeed;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.translate('playbackSpeed'),
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                // Current speed display
                Text(
                  '${currentSpeed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Speed slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '0.5x',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.5),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: currentSpeed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 30, // 0.05 increments
                          onChanged: (value) {
                            // Round to 2 decimal places for clean display
                            final rounded = (value * 20).round() / 20;
                            setSheetState(() => currentSpeed = rounded);
                            // Update playback speed in real-time as user drags
                            audioService.setPlaybackSpeed(rounded);
                          },
                        ),
                      ),
                      Text(
                        '2.0x',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Reset button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setSheetState(() => currentSpeed = 1.0);
                      audioService.setPlaybackSpeed(1.0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Reset to 1.0x',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
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

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
  final CrossfadeService _crossfadeService = CrossfadeService();
  final AudioToolsService _audioToolsService = AudioToolsService();
  final OfflineModeService _offlineModeService = OfflineModeService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await Future.wait([
      _crossfadeService.initialize(),
      _audioToolsService.initialize(),
      _offlineModeService.initialize(),
    ]);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final audioService = Provider.of<AudioPlayerService>(context);

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

                // Audio tools
                _buildSectionHeader(
                  l10n.translate('equalizerPresets'),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildSettingsCard(isDark, [
                  ListTile(
                    leading: Icon(
                      Icons.equalizer_rounded,
                      color: _audioToolsService.isEqualizerEnabled
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.7),
                    ),
                    title: Text(
                      l10n.translate('equalizerPresets'),
                      style: _titleStyle(isDark),
                    ),
                    subtitle: Text(
                      _audioToolsService
                          .getPresetName(_audioToolsService.currentPreset),
                      style: _subtitleStyle(isDark),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.3),
                    ),
                    onTap: () =>
                        _showEqualizerPresetSheet(context, isDark, l10n),
                  ),
                  const Divider(height: 1),
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
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              ...speeds.map((speed) => ListTile(
                    title: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: audioService.playbackSpeed == speed
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: audioService.playbackSpeed == speed
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioService.setPlaybackSpeed(speed);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEqualizerPresetSheet(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
                  l10n.translate('equalizerPresets'),
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _audioToolsService.availablePresets.length,
                  itemBuilder: (context, index) {
                    final preset = _audioToolsService.availablePresets[index];
                    final isSelected =
                        _audioToolsService.currentPreset == preset;

                    return ListTile(
                      title: Text(
                        _audioToolsService.getPresetName(preset),
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await _audioToolsService.setEqualizerPreset(preset);
                        setState(() {});
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

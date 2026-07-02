/// Playback settings sub-screen — speed, gapless, normalization, pitch & more.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../screens/artist_separator_settings.dart';
import '../screens/equalizer_screen.dart';
import '../widgets/settings_tile_builders.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return AppBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: iconoir.NavArrowLeft(
            color: isDark ? Colors.white : Colors.black,
            width: 28,
            height: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsPlayback,
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Selector<AudioPlayerService, bool>(
        selector: (_, s) => s.currentSong != null,
        builder: (context, hasCurrentSong, _) => ListView(
          padding: EdgeInsets.only(
            top: 10,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            // ── AUDIO ─────────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsAudio),
            Consumer<AudioPlayerService>(
              builder: (context, audioService, _) =>
                  SettingsTiles.buildGlassmorphicCard(context, children: [
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.GitFork(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.settingsGapless,
                  subtitle: l10n.settingsGaplessDesc,
                  value: audioService.gaplessPlayback,
                  onChanged: audioService.setGaplessPlayback,
                  isFirst: true,
                ),
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.SoundHigh(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.settingsCrossfade,
                  subtitle: l10n.settingsCrossfadeDesc,
                  value: audioService.crossfadeEnabled,
                  onChanged: (v) => audioService.setCrossfadeEnabled(v),
                ),
                if (audioService.crossfadeEnabled)
                  SettingsTiles.buildSliderTile(
                    context,
                    icon: iconoir.Timer(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.crossfadeDuration,
                    subtitle: l10n.crossfadeDurationDesc,
                    value: (audioService.crossfadeDurationMs / 1000.0)
                        .clamp(1.0, 12.0),
                    min: 1.0,
                    max: 12.0,
                    defaultValue: 6.0,
                    valueFormatter: (v) => '${v.toStringAsFixed(1)}s',
                    showArrows: true,
                    arrowStep: 0.5,
                    onChanged: (v) => audioService
                        .setCrossfadeDurationMs((v * 1000).round()),
                    onChangeEnd: (v) => audioService
                        .setCrossfadeDurationMs((v * 1000).round()),
                  ),
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.SoundHigh(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.settingsNormalization,
                  subtitle: l10n.settingsNormalizationDesc,
                  value: audioService.volumeNormalization,
                  onChanged: audioService.setVolumeNormalization,
                ),
              ]),
            ),

            // ── PLAYBACK ──────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsPlayback),
            Consumer<AudioPlayerService>(
              builder: (context, audioService, _) =>
                  SettingsTiles.buildGlassmorphicCard(context, children: [
                SettingsTiles.buildSliderTile(
                  context,
                  icon: iconoir.DashboardSpeed(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.playbackSpeed,
                  subtitle: l10n.playbackSpeedDesc,
                  value: audioService.playbackSpeed.clamp(0.25, 2.0),
                  min: 0.25,
                  max: 2.0,
                  defaultValue: 1.0,
                  valueFormatter: (v) => '${v.toStringAsFixed(2)}x',
                  showArrows: true,
                  onChanged: audioService.setPlaybackSpeed,
                  onChangeEnd: (v) {
                    final rounded = (v * 20).round() / 20;
                    audioService.setPlaybackSpeed(rounded);
                  },
                  isFirst: true,
                ),
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.MusicNote(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.adjustPitchWithSpeed,
                  subtitle: l10n.adjustPitchWithSpeedDesc,
                  value: audioService.pitchWithSpeed,
                  onChanged: audioService.setPitchWithSpeed,
                ),
              ]),
            ),

            // ── TOOLS ─────────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsTools),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.Group(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.artistSeparation,
                subtitle: l10n.artistSeparationDesc,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ArtistSeparatorSettingsScreen(),
                  ),
                ),
                isFirst: true,
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.SoundHigh(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.eqTitle,
                subtitle: l10n.eqSettingsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EqualizerScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
    );
  }
}

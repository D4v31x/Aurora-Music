/// Appearance settings sub-screen — Themes, colors, language & home layout.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/supported_languages.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/device_performance_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../screens/home_layout_settings.dart';
import '../widgets/settings_tile_builders.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

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
          l10n.settingsAppearance,
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
            // ── THEME ────────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsTheme),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) =>
                  SettingsTiles.buildGlassmorphicCard(context, children: [
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.Palette(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.settingsMaterialYou,
                  subtitle: l10n.settingsMaterialYouDesc,
                  value: themeProvider.useDynamicColor,
                  onChanged: (_) => themeProvider.toggleDynamicColor(),
                  isFirst: true,
                ),
                SettingsTiles.buildAnimatedTile(
                  visible: !themeProvider.useDynamicColor,
                  child: SettingsTiles.buildActionTile(
                    context,
                    icon: iconoir.ColorPicker(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.settingsAccentColor,
                    subtitle: _selectedPresetName(themeProvider),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: themeProvider.customSeedColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        iconoir.NavArrowRight(
                          color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.5) ??
                              Colors.white54,
                          width: 16,
                          height: 16,
                        ),
                      ],
                    ),
                    onTap: () =>
                        _showColorPickerDialog(context, themeProvider),
                  ),
                ),
              ]),
            ),

            // ── BACKGROUND ───────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsBackground),
            Consumer2<ThemeProvider, PerformanceModeProvider>(
              builder: (context, themeProvider, perfProvider, _) =>
                  SettingsTiles.buildGlassmorphicCard(context, children: [
                // High-end UI toggle
                SettingsTiles.buildSwitchTile(
                  context,
                  icon: iconoir.DashboardSpeed(
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      height: 20),
                  title: l10n.settingsHighendUi,
                  subtitle: l10n.settingsHighendUiDesc,
                  value: perfProvider.currentMode == PerformanceLevel.high,
                  onChanged: (value) => _showRestartDialog(context, value),
                  isFirst: true,
                ),
                // Low-end background style
                if (perfProvider.isLowEndDevice)
                  SettingsTiles.buildSegmentedChoiceTile(
                    context,
                    icon: iconoir.MultiWindow(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.backgroundLowEndStyle,
                    subtitle: l10n.backgroundLowEndStyleDesc,
                    options: [l10n.backgroundBlobs, l10n.backgroundSolid],
                    selectedIndex:
                        themeProvider.lowEndBackground == LowEndBackground.blobs
                            ? 0
                            : 1,
                    onChanged: (i) => themeProvider.setLowEndBackground(
                        i == 0
                            ? LowEndBackground.blobs
                            : LowEndBackground.solid),
                  ),
                // High-end background style
                if (perfProvider.shouldEnableBlur)
                  SettingsTiles.buildSegmentedChoiceTile(
                    context,
                    icon: iconoir.MediaImage(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.backgroundHighEndStyle,
                    subtitle: l10n.backgroundHighEndStyleDesc,
                    options: [
                      l10n.backgroundBlurredArtwork,
                      l10n.backgroundSolid,
                    ],
                    selectedIndex: themeProvider.highEndBackground ==
                            HighEndBackground.blurredArtwork
                        ? 0
                        : 1,
                    onChanged: (i) => themeProvider.setHighEndBackground(
                        i == 0
                            ? HighEndBackground.blurredArtwork
                            : HighEndBackground.solid),
                  ),
                // Blur intensity
                SettingsTiles.buildAnimatedTile(
                  visible: perfProvider.shouldEnableBlur &&
                      themeProvider.highEndBackground !=
                          HighEndBackground.solid,
                  child: SettingsTiles.buildSliderTile(
                    context,
                    icon: iconoir.Fog(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.backgroundBlur,
                    subtitle: l10n.backgroundBlurDesc,
                    value: themeProvider.blurIntensity,
                    min: 5.0,
                    max: 40.0,
                    defaultValue: 25.0,
                    valueFormatter: (v) => v.toStringAsFixed(0),
                    onChanged: themeProvider.updateBlurIntensity,
                    onChangeEnd: themeProvider.setBlurIntensity,
                  ),
                ),
                // Overlay darkness
                SettingsTiles.buildAnimatedTile(
                  visible: !perfProvider.isLowEndDevice &&
                      themeProvider.highEndBackground !=
                          HighEndBackground.solid,
                  child: SettingsTiles.buildSliderTile(
                    context,
                    icon: iconoir.Brightness(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.backgroundDarkness,
                    subtitle: l10n.backgroundDarknessDesc,
                    value: themeProvider.overlayOpacity,
                    min: 0.0,
                    max: 0.8,
                    defaultValue: 0.3,
                    valueFormatter: (v) =>
                        '${(v * 100).toStringAsFixed(0)}%',
                    onChanged: themeProvider.updateOverlayOpacity,
                    onChangeEnd: themeProvider.setOverlayOpacity,
                  ),
                ),
              ]),
            ),

            // ── LAYOUT ───────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsLayout),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.Dashboard(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.homeLayout,
                subtitle: l10n.homeLayoutDesc,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeLayoutSettingsScreen(),
                  ),
                ),
                isFirst: true,
              ),
            ]),

            // ── LANGUAGE ─────────────────────────────────────────────────
            SettingsTiles.buildSectionHeader(context, l10n.settingsLanguage),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              _LanguageTile(isFirst: true),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _selectedPresetName(ThemeProvider themeProvider) {
  final idx = themeProvider.selectedPresetIndex;
  if (idx < 0 || idx >= AppThemePreset.presets.length) return 'Custom color';
  return AppThemePreset.presets[idx].name;
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

void _showRestartDialog(BuildContext context, bool newIsHighEnd) {
  final l10n = AppLocalizations.of(context);
  final perfProvider =
      Provider.of<PerformanceModeProvider>(context, listen: false);
  final shouldBlur = perfProvider.shouldEnableBlur;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor:
          Colors.grey[900]?.withValues(alpha: shouldBlur ? 0.9 : 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: shouldBlur
              ? Colors.white.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      title: Text(l10n.restartRequired,
          style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold)),
      content: Text(l10n.restartRequiredDesc,
          style: const TextStyle(
              fontFamily: FontConstants.fontFamily, color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel,
              style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white70)),
        ),
        TextButton(
          onPressed: () async {
            await perfProvider.setPerformanceMode(
              newIsHighEnd ? PerformanceLevel.high : PerformanceLevel.low,
            );
            if (!context.mounted) return;
            final audio =
                Provider.of<AudioPlayerService>(context, listen: false);
            await audio.stop();
            audio.dispose();
            if (Platform.isAndroid) {
              await SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          },
          child: Text(l10n.restartNow,
              style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showColorPickerDialog(
    BuildContext context, ThemeProvider themeProvider) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      final presets = AppThemePreset.presets;
      return AlertDialog(
        backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text('Color Theme',
            style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: presets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (_, i) {
              final preset = presets[i];
              final isSelected = !themeProvider.useDynamicColor &&
                  themeProvider.selectedPresetIndex == i;
              return GestureDetector(
                onTap: () {
                  themeProvider.setPreset(i);
                  Navigator.pop(dialogContext);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.seedColor.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? preset.seedColor
                          : Colors.white.withValues(alpha: 0.12),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: preset.seedColor,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: preset.seedColor
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const iconoir.Check(
                                color: Colors.white, width: 16, height: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                              isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Colors.white70)),
          ),
        ],
      );
    },
  );
}
// ── Language tile (stateless, self-contained) ─────────────────────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({this.isFirst = false});

  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = LocaleProvider.of(context)!.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        if (!isFirst)
          Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.22)),
            ),
            child: iconoir.Language(
                color: primary, width: 20, height: 20),
          ),
          title: Text(l10n.settingsLanguage,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: FontConstants.fontFamily)),
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: currentLocale,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w500,
                  fontFamily: FontConstants.fontFamily),
              items: SupportedLanguages.all
                  .map((lang) => DropdownMenuItem(
                        value: lang.code,
                        child: Text(lang.nativeName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  LocaleProvider.of(context)!.setLocale(Locale(value));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

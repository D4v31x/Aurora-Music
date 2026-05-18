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
import '../../../shared/widgets/expanding_player.dart';
import '../screens/home_layout_settings.dart';
import '../widgets/settings_tile_builders.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
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
            SettingsTiles.buildSectionHeader(context, l10n.settingsAppearance),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) =>
                  SettingsTiles.buildGlassmorphicCard(context, children: [
                // Material You
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
                // Accent color (hidden when Material You is on)
                SettingsTiles.buildAnimatedTile(
                  visible: !themeProvider.useDynamicColor,
                  child: SettingsTiles.buildActionTile(
                    context,
                    icon: iconoir.ColorPicker(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: 'Accent Color',
                    subtitle: 'Choose the app accent color',
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
                // Low-end background style
                Consumer<PerformanceModeProvider>(
                  builder: (context, perfProvider, _) {
                    if (!perfProvider.isLowEndDevice) {
                      return const SizedBox.shrink();
                    }
                    return SettingsTiles.buildSegmentedChoiceTile(
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
                    );
                  },
                ),
                // High-end background style
                Consumer<PerformanceModeProvider>(
                  builder: (context, perfProvider, _) {
                    if (!perfProvider.shouldEnableBlur) {
                      return const SizedBox.shrink();
                    }
                    return SettingsTiles.buildSegmentedChoiceTile(
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
                    );
                  },
                ),
                // High-end UI toggle
                Consumer<PerformanceModeProvider>(
                  builder: (context, perfProvider, _) =>
                      SettingsTiles.buildSwitchTile(
                    context,
                    icon: iconoir.DashboardSpeed(
                        color: Theme.of(context).colorScheme.primary,
                        width: 20,
                        height: 20),
                    title: l10n.settingsHighendUi,
                    subtitle: l10n.settingsHighendUiDesc,
                    value:
                        perfProvider.currentMode == PerformanceLevel.high,
                    onChanged: (value) =>
                        _showRestartDialog(context, value),
                  ),
                ),
                // Blur intensity
                Consumer<PerformanceModeProvider>(
                  builder: (context, perfProvider, _) =>
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
                ),
                // Overlay darkness
                Consumer<PerformanceModeProvider>(
                  builder: (context, perfProvider, _) =>
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
                ),
                // Language
                _LanguageTile(),
                // Home layout
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
                ),
              ]),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
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
  const presetColors = [
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
  ];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      title: const Text('Accent Color',
          style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold)),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: presetColors.map((color) {
          final isSelected =
              color.toARGB32() == themeProvider.customSeedColor.toARGB32();
          return GestureDetector(
            onTap: () {
              themeProvider.setCustomSeedColor(color);
              Navigator.pop(dialogContext);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: isSelected
                  ? const iconoir.Check(
                      color: Colors.white, width: 22, height: 22)
                  : null,
            ),
          );
        }).toList(),
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
    ),
  );
}

// ── Language tile (stateless, self-contained) ─────────────────────────────────

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = LocaleProvider.of(context)!.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
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

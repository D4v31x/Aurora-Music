import 'package:aurora_music_v01/shared/widgets/about_dialog.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:aurora_music_v01/shared/widgets/changelog_dialog.dart';
import 'package:aurora_music_v01/shared/widgets/feedback_reminder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/locale_provider.dart';
import '../../../l10n/supported_languages.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/device_performance_service.dart';
import '../../../shared/services/version_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/cache_manager.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/donation_service.dart';
import '../screens/artist_separator_settings.dart';
import '../screens/home_layout_settings.dart';
import '../../../shared/utils/responsive_utils.dart';
import '../../../shared/widgets/expanding_player.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:url_launcher/url_launcher.dart';

/// A glassmorphic settings tab with translations.
class SettingsTab extends StatefulWidget {
  final VoidCallback? onUpdateCheck;
  final NotificationManager notificationManager;
  final VoidCallback? onResetSetup;

  const SettingsTab({
    super.key,
    this.onUpdateCheck,
    required this.notificationManager,
    this.onResetSetup,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final version = await VersionService.getCurrentVersion();
    if (mounted) {
      setState(() => _currentVersion = version);
    }
  }

  // Section Header — left accent bar + title-case label
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontFamily: FontConstants.fontFamily,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Glassmorphic Card Container
  Widget _buildGlassmorphicCard({required List<Widget> children}) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final colorScheme = Theme.of(context).colorScheme;
    final Color bgColor = isLowEnd
        ? colorScheme.surfaceContainerHigh
        : Colors.white.withValues(alpha: 0.08);
    final Color borderColor = isLowEnd
        ? colorScheme.outlineVariant
        : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          // Subtle depth shadow on capable devices so the card lifts off the background
          boxShadow: isLowEnd
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  // Switch Tile
  Widget _buildSwitchTile({
    required Widget icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
  }) {
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
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              // Subtle ring echoes the icon accent colour
              border: Border.all(
                color: primary.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: icon,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: FontConstants.fontFamily,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : null,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Action Tile
  Widget _buildActionTile({
    required Widget icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.primary;
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
              color: effectiveIconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: effectiveIconColor.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: icon,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: FontConstants.fontFamily,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : null,
          // Chevron wrapped in a faint circle for a more premium look
          trailing: trailing ??
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Iconoir.NavArrowRight(
                    color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.45) ??
                        Colors.white38,
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
          onTap: onTap,
        ),
      ],
    );
  }

  // Glassmorphic Slider Tile using classic Flutter Slider
  Widget _buildSliderTile({
    required Widget icon,
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String Function(double)? valueFormatter,
    bool isFirst = false,
    double? defaultValue,
    bool showArrows = false,
    double arrowStep = 0.05,
  }) {
    // _draft[0] tracks the live drag value so the label updates while dragging.
    final draft = <double?>[null];

    return StatefulBuilder(
      builder: (context, setLocal) {
        return _buildSliderTileContent(
          icon: icon,
          title: title,
          subtitle: subtitle,
          value: value,
          draft: draft[0],
          min: min,
          max: max,
          onChanged: (v) {
            setLocal(() => draft[0] = v);
            onChanged(v);
          },
          onChangeEnd: (v) {
            setLocal(() => draft[0] = null); // revert to committed value
            onChangeEnd?.call(v);
          },
          valueFormatter: valueFormatter,
          isFirst: isFirst,
          defaultValue: defaultValue,
          showArrows: showArrows,
          arrowStep: arrowStep,
        );
      },
    );
  }

  Widget _buildSliderTileContent({
    required Widget icon,
    required String title,
    String? subtitle,
    required double value,
    double? draft,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String Function(double)? valueFormatter,
    bool isFirst = false,
    double? defaultValue,
    bool showArrows = false,
    double arrowStep = 0.05,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue =
        valueFormatter?.call(draft ?? value) ?? (draft ?? value).toStringAsFixed(1);

    // Snap threshold: 2.5 % of the total range
    final snapThreshold =
        defaultValue != null ? (max - min) * 0.025 : 0.0;

    ValueChanged<double> wrappedOnChanged = onChanged;
    ValueChanged<double>? wrappedOnChangeEnd = onChangeEnd;
    if (defaultValue != null) {
      wrappedOnChanged = (v) {
        final snapped =
            (v - defaultValue).abs() <= snapThreshold ? defaultValue : v;
        onChanged(snapped);
      };
      if (onChangeEnd != null) {
        wrappedOnChangeEnd = (v) {
          final snapped =
              (v - defaultValue).abs() <= snapThreshold ? defaultValue : v;
          onChangeEnd(snapped);
        };
      }
    }

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                        // Pill badge makes the live value visually distinct
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            displayValue,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: FontConstants.fontFamily,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: FontConstants.fontFamily,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        overlayColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: () {
                        // Build the core slider widget (with optional default-value marker)
                        Widget sliderWidget = defaultValue != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  // Flutter's Slider pads the thumb by the overlay radius
                                  // (default RoundSliderOverlayShape = 24 px), NOT the
                                  // thumb radius. Using 24 keeps the marker exactly
                                  // aligned with the thumb position.
                                  const double thumbPadding = 24.0;
                                  final trackWidth =
                                      constraints.maxWidth - thumbPadding * 2;
                                  final fraction =
                                      (defaultValue - min) / (max - min);
                                  final markerLeft =
                                      thumbPadding + fraction * trackWidth;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Slider(
                                        value: (draft ?? value).clamp(min, max),
                                        min: min,
                                        max: max,
                                        onChanged: wrappedOnChanged,
                                        onChangeEnd: wrappedOnChangeEnd,
                                      ),
                                      Positioned(
                                        left: markerLeft - 1,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Container(
                                            width: 2,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.5),
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : Slider(
                                value: (draft ?? value).clamp(min, max),
                                min: min,
                                max: max,
                                onChanged: wrappedOnChanged,
                                onChangeEnd: wrappedOnChangeEnd,
                              );

                        if (!showArrows) return sliderWidget;

                        // Wrap slider with Iconoir arrow step buttons
                        final arrowColor =
                            Theme.of(context).colorScheme.primary;
                        return Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final cur =
                                    (draft ?? value).clamp(min, max);
                                final newVal =
                                    (cur - arrowStep).clamp(min, max);
                                wrappedOnChanged(newVal);
                                wrappedOnChangeEnd?.call(newVal);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Iconoir.NavArrowLeft(
                                  color: arrowColor,
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                            ),
                            Expanded(child: sliderWidget),
                            GestureDetector(
                              onTap: () {
                                final cur =
                                    (draft ?? value).clamp(min, max);
                                final newVal =
                                    (cur + arrowStep).clamp(min, max);
                                wrappedOnChanged(newVal);
                                wrappedOnChangeEnd?.call(newVal);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Iconoir.NavArrowRight(
                                  color: arrowColor,
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Segmented Choice Tile — animated sliding-pill selector
  Widget _buildSegmentedChoiceTile({
    required Widget icon,
    required String title,
    required String subtitle,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    bool isFirst = false,
  }) {
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: FontConstants.fontFamily,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Custom animated pill selector — the indicator slides smoothly
              // to the selected segment instead of Flutter's generic
              // SegmentedButton, giving the settings a more polished feel.
              LayoutBuilder(
                builder: (context, constraints) {
                  final segmentWidth =
                      constraints.maxWidth / options.length;
                  return Container(
                    height: 38,
                    // Clip so the sliding indicator stays within rounded corners
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Sliding accent indicator
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          left: selectedIndex * segmentWidth + 2,
                          top: 2,
                          bottom: 2,
                          width: segmentWidth - 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tappable label overlay
                        Row(
                          children: options.asMap().entries.map((entry) {
                            final isSelected = entry.key == selectedIndex;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onChanged(entry.key),
                                child: Center(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontFamily: FontConstants.fontFamily,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.55)
                                              : Colors.black
                                                  .withValues(alpha: 0.5)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Animates a tile's height and opacity when [visible] changes.
  Widget _buildAnimatedTile({required bool visible, required Widget child}) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }

  // Cache Management
  Future<void> _clearAllCaches() async {
    try {
      final cacheManager = CacheManager();
      cacheManager.initialize();
      cacheManager.clearAllCaches();

      final artworkCache = ArtworkCacheService();
      artworkCache.clearCache();

      final directory = await getApplicationDocumentsDirectory();

      final cacheDirs = [
        Directory('${directory.path}/lyrics'),
        Directory('${directory.path}/artwork_cache'),
        Directory('${directory.path}/cache'),
      ];

      for (final dir in cacheDirs) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create();
        }
      }
    } catch (e) {
      debugPrint('Error clearing all caches: $e');
    }
  }

  void _showClearCacheDialog() {
    final l10n = AppLocalizations.of(context);
    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for lowend devices
    final Color backgroundColor;
    if (shouldBlur) {
      backgroundColor = Colors.grey[900]!.withValues(alpha: 0.9);
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    final dialogContent = AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      title: Text(
        l10n.settingsClearCacheTitle,
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        l10n.settingsClearCacheMessage,
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancel,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white70,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _clearAllCaches();
            if (mounted) {
              widget.notificationManager.showNotification(
                l10n.settingsCacheCleared,
                duration: const Duration(seconds: 2),
              );
            }
          },
          child: Text(
            l10n.delete,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (context) => dialogContent,
    );
  }

  void _showCacheInfo() async {
    final l10n = AppLocalizations.of(context);
    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for lowend devices
    final Color backgroundColor;
    if (shouldBlur) {
      backgroundColor = Colors.grey[900]!.withValues(alpha: 0.9);
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();

      int lyricsSize = 0;
      int artworkSize = 0;

      final lyricsDir = Directory('${directory.path}/lyrics');
      if (await lyricsDir.exists()) {
        await for (final file in lyricsDir.list(recursive: true)) {
          if (file is File) {
            lyricsSize += await file.length();
          }
        }
      }

      final artworkDir = Directory('${directory.path}/artwork_cache');
      if (await artworkDir.exists()) {
        await for (final file in artworkDir.list(recursive: true)) {
          if (file is File) {
            artworkSize += await file.length();
          }
        }
      }

      final totalSize = lyricsSize + artworkSize;

      final cacheManager = CacheManager();
      cacheManager.initialize();
      final cacheSizes = cacheManager.getCacheSizes();

      if (!mounted) return;

      final dialogContent = AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: shouldBlur
                ? Colors.white.withValues(alpha: 0.1)
                : colorScheme.outlineVariant,
          ),
        ),
        title: Text(
          l10n.settingsCacheInfo,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.settingsStorage,
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(l10n.lyrics, _formatBytes(lyricsSize)),
              _buildInfoRow(l10n.onboardingAlbumArtwork,
                  _formatBytes(artworkSize)),
              Divider(color: Colors.white.withValues(alpha: 0.2)),
              _buildInfoRow('Total', _formatBytes(totalSize), bold: true),
              const SizedBox(height: 16),
              const Text(
                'Memory Cache',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                  l10n.lyrics, '${cacheSizes['lyrics']} items'),
              _buildInfoRow(l10n.onboardingAlbumArtwork,
                  '${cacheSizes['artwork']} items'),
              _buildInfoRow(l10n.metadata,
                  '${cacheSizes['metadata']} items'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );

      await showDialog(
        context: context,
        builder: (context) => dialogContent,
      );
    } catch (e) {
      debugPrint('Error getting cache info: $e');
    }
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Show restart dialog after UI mode change
  /// Only applies the change after user confirms and restarts
  void _showRestartDialog(bool newIsHighEnd) {
    final l10n = AppLocalizations.of(context);
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;

    final dialogContent = AlertDialog(
      backgroundColor: Colors.grey[900]?.withValues(alpha: shouldBlur ? 0.9 : 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: shouldBlur
              ? Colors.white.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      title: Text(
        l10n.restartRequired,
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        l10n.restartRequiredDesc,
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancel,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white70,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            // Apply the mode change only now, right before restart
            await performanceProvider.setPerformanceMode(
              newIsHighEnd ? PerformanceLevel.high : PerformanceLevel.low,
            );

            // Stop audio and exit the app
            if (!mounted) return;
            final audioService =
                Provider.of<AudioPlayerService>(context, listen: false);
            await audioService.stop();
            audioService.dispose();

            // Exit the app
            if (Platform.isAndroid) {
              await SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          },
          child: Text(
            l10n.restartNow,
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (context) => dialogContent,
    );
  }

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    const codename = String.fromEnvironment('CODE_NAME', defaultValue: 'Unknown');

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AuroraAboutDialog(
        version: packageInfo.version,
        codename: codename,
      ),
    );
  }

  void _showChangelogDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => ChangelogDialog(
        currentVersion: _currentVersion,
      ),
    );
  }

  void _showFeedbackDialog() {
    if (!mounted) return;
    FeedbackReminderDialog.show(context);
  }

  void _showColorPickerDialog(ThemeProvider themeProvider) {
    const presetColors = [
      Color(0xFF673AB7), // Deep Purple (default)
      Color(0xFF3F51B5), // Indigo
      Color(0xFF2196F3), // Blue
      Color(0xFF009688), // Teal
      Color(0xFF4CAF50), // Green
      Color(0xFFFFC107), // Amber
      Color(0xFFFF9800), // Orange
      Color(0xFFF44336), // Red
      Color(0xFFE91E63), // Pink
      Color(0xFF00BCD4), // Cyan
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text(
          'Accent Color',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                          color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.6), blurRadius: 12)
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Iconoir.Check(color: Colors.white, width: 22, height: 22)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateAvailableDialog(dynamic latestVersion) {
    final l10n = AppLocalizations.of(context);
    // Check if blur should be enabled based on performance mode
    final performanceProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final shouldBlur = performanceProvider.shouldEnableBlur;
    final colorScheme = Theme.of(context).colorScheme;

    // Use solid surface colors for lowend devices
    final Color backgroundColor;
    if (shouldBlur) {
      backgroundColor = Colors.grey[900]!.withValues(alpha: 0.9);
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
    }

    final dialogContent = AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: shouldBlur
              ? Colors.white.withValues(alpha: 0.1)
              : colorScheme.outlineVariant,
        ),
      ),
      title: Text(
        l10n.updateAvailable,
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        '${l10n.updateMessage}: $latestVersion',
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.later,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white70,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (widget.onUpdateCheck != null) {
              widget.onUpdateCheck!();
            }
          },
          child: Text(
            l10n.updateNow,
            style: const TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (context) => dialogContent,
    );
  }

  // Language Selection Tile
  Widget _buildLanguageTile() {
    final l10n = AppLocalizations.of(context);
    final currentLocale = LocaleProvider.of(context)!.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Iconoir.Language(
              color: Theme.of(context).colorScheme.primary,
              width: 20,
              height: 20,
            ),
          ),
          title: Text(
            l10n.settingsLanguage,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: FontConstants.fontFamily,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: currentLocale,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontFamily: FontConstants.fontFamily,
              ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);

    return Selector<AudioPlayerService, bool>(
      selector: (_, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);

        final sections = _buildSectionWidgets(
          l10n: l10n,
          audioPlayerService: audioPlayerService,
        );

        return ListView.builder(
          padding: EdgeInsets.only(
            top: isTablet ? 20.0 : 10.0,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 24.0,
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final item = sections[index];
            if (isTablet) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: item,
                ),
              );
            }
            return item;
          },
        );
      },
    );
  }

  List<Widget> _buildSectionWidgets({
    required AppLocalizations l10n,
    required AudioPlayerService audioPlayerService,
  }) {
    return [
      _buildSectionHeader(l10n.settingsAppearance),
      RepaintBoundary(child: _buildAppearanceCard(l10n: l10n)),
      _buildSectionHeader(l10n.settingsPlayback),
      Consumer<AudioPlayerService>(
        builder: (context, svc, _) => RepaintBoundary(
          child: _buildPlaybackCard(
            l10n: l10n,
            audioPlayerService: svc,
          ),
        ),
      ),
      _buildSectionHeader(l10n.settingsStorage),
      RepaintBoundary(child: _buildStorageCard(l10n: l10n)),
      _buildSectionHeader(l10n.settingsAbout),
      RepaintBoundary(child: _buildAboutCard(l10n: l10n)),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildAppearanceCard({required AppLocalizations l10n}) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => _buildGlassmorphicCard(
        children: [
          _buildSwitchTile(
            icon: Iconoir.Palette(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
            title: l10n.settingsMaterialYou,
            subtitle: l10n.settingsMaterialYouDesc,
            value: themeProvider.useDynamicColor,
            onChanged: (value) => themeProvider.toggleDynamicColor(),
            isFirst: true,
          ),
          _buildAnimatedTile(
            visible: !themeProvider.useDynamicColor,
            child: _buildActionTile(
              icon: Iconoir.ColorPicker(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
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
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Iconoir.NavArrowRight(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5) ?? Colors.white54,
                    width: 16,
                    height: 16,
                  ),
                ],
              ),
              onTap: () => _showColorPickerDialog(themeProvider),
            ),
          ),
          Consumer<PerformanceModeProvider>(
            builder: (context, performanceProvider, _) {
              if (!performanceProvider.isLowEndDevice) {
                return const SizedBox.shrink();
              }
              return _buildSegmentedChoiceTile(
                icon: Iconoir.MultiWindow(
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
                onChanged: (index) {
                  themeProvider.setLowEndBackground(
                    index == 0 ? LowEndBackground.blobs : LowEndBackground.solid,
                  );
                },
              );
            },
          ),
          Consumer<PerformanceModeProvider>(
            builder: (context, performanceProvider, _) {
              if (!performanceProvider.shouldEnableBlur) {
                return const SizedBox.shrink();
              }
              return _buildSegmentedChoiceTile(
                icon: Iconoir.MediaImage(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.backgroundHighEndStyle,
                subtitle: l10n.backgroundHighEndStyleDesc,
                options: [l10n.backgroundBlurredArtwork, l10n.backgroundSolid],
                selectedIndex: themeProvider.highEndBackground ==
                        HighEndBackground.blurredArtwork
                    ? 0
                    : 1,
                onChanged: (index) {
                  themeProvider.setHighEndBackground(
                    index == 0
                        ? HighEndBackground.blurredArtwork
                        : HighEndBackground.solid,
                  );
                },
              );
            },
          ),
          Consumer<PerformanceModeProvider>(
            builder: (context, performanceProvider, _) {
              final isHighEnd =
                  performanceProvider.currentMode == PerformanceLevel.high;
              return _buildSwitchTile(
                icon: Iconoir.DashboardSpeed(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
                title: l10n.settingsHighendUi,
                subtitle: l10n.settingsHighendUiDesc,
                value: isHighEnd,
                onChanged: (value) => _showRestartDialog(value),
              );
            },
          ),
          Consumer<PerformanceModeProvider>(
            builder: (context, performanceProvider, _) {
              final showBlur = performanceProvider.shouldEnableBlur &&
                  themeProvider.highEndBackground != HighEndBackground.solid;
              return _buildAnimatedTile(
                visible: showBlur,
                child: _buildSliderTile(
                  icon: Iconoir.Fog(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
                  title: l10n.backgroundBlur,
                  subtitle: l10n.backgroundBlurDesc,
                  value: themeProvider.blurIntensity,
                  min: 5.0,
                  max: 40.0,
                  defaultValue: 25.0,
                  valueFormatter: (v) => v.toStringAsFixed(0),
                  onChanged: (value) => themeProvider.updateBlurIntensity(value),
                  onChangeEnd: (value) => themeProvider.setBlurIntensity(value),
                ),
              );
            },
          ),
          Consumer<PerformanceModeProvider>(
            builder: (context, performanceProvider, _) {
              final showDarkness = !performanceProvider.isLowEndDevice &&
                  themeProvider.highEndBackground != HighEndBackground.solid;
              return _buildAnimatedTile(
                visible: showDarkness,
                child: _buildSliderTile(
                  icon: Iconoir.Brightness(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
                  title: l10n.backgroundDarkness,
                  subtitle: l10n.backgroundDarknessDesc,
                  value: themeProvider.overlayOpacity,
                  min: 0.0,
                  max: 0.8,
                  defaultValue: 0.3,
                  valueFormatter: (v) => '${(v * 100).toStringAsFixed(0)}%',
                  onChanged: (value) => themeProvider.updateOverlayOpacity(value),
                  onChangeEnd: (value) => themeProvider.setOverlayOpacity(value),
                ),
              );
            },
          ),
          _buildLanguageTile(),
          _buildActionTile(
            icon: Iconoir.Dashboard(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
            title: l10n.homeLayout,
            subtitle: l10n.homeLayoutDesc,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeLayoutSettingsScreen(),
                ),
              );
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackCard({
    required AppLocalizations l10n,
    required AudioPlayerService audioPlayerService,
  }) {
    return _buildGlassmorphicCard(
      children: [
        _buildSwitchTile(
          icon: Iconoir.GitFork(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsGapless,
          subtitle: l10n.settingsGaplessDesc,
          value: audioPlayerService.gaplessPlayback,
          onChanged: (value) => audioPlayerService.setGaplessPlayback(value),
          isFirst: true,
        ),
        _buildSwitchTile(
          icon: Iconoir.SoundHigh(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsNormalization,
          subtitle: l10n.settingsNormalizationDesc,
          value: audioPlayerService.volumeNormalization,
          onChanged: (value) => audioPlayerService.setVolumeNormalization(value),
        ),
        _buildSliderTile(
          icon: Iconoir.DashboardSpeed(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.playbackSpeed,
          subtitle: l10n.playbackSpeedDesc,
          value: audioPlayerService.playbackSpeed.clamp(0.25, 2.0),
          min: 0.25,
          max: 2.0,
          defaultValue: 1.0,
          valueFormatter: (v) => '${v.toStringAsFixed(2)}x',
          showArrows: true,
          arrowStep: 0.05,
          onChanged: (value) => audioPlayerService.setPlaybackSpeed(value),
          onChangeEnd: (value) {
            final rounded = (value * 20).round() / 20;
            audioPlayerService.setPlaybackSpeed(rounded);
          },
        ),
        _buildSwitchTile(
          icon: Iconoir.MusicNote(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.adjustPitchWithSpeed,
          subtitle: l10n.adjustPitchWithSpeedDesc,
          value: audioPlayerService.pitchWithSpeed,
          onChanged: (value) => audioPlayerService.setPitchWithSpeed(value),
        ),
        _buildActionTile(
          icon: Iconoir.Group(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.artistSeparation,
          subtitle: l10n.artistSeparationDesc,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ArtistSeparatorSettingsScreen(),
              ),
            );
          },
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildStorageCard({required AppLocalizations l10n}) {
    return _buildGlassmorphicCard(
      children: [
        _buildActionTile(
          icon: Iconoir.Database(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsCacheInfo,
          subtitle: l10n.settingsCacheInfoDesc,
          onTap: _showCacheInfo,
          isFirst: true,
        ),
        _buildActionTile(
          icon: Iconoir.Trash(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsClearCache,
          subtitle: l10n.settingsClearCacheDesc,
          onTap: _showClearCacheDialog,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildAboutCard({required AppLocalizations l10n}) {
    return _buildGlassmorphicCard(
      children: [
        _buildActionTile(
          icon: Iconoir.InfoCircle(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsAboutApp,
          subtitle: '${l10n.settingsVersion} $_currentVersion',
          onTap: _showAboutDialog,
          isFirst: true,
        ),
        _buildActionTile(
          icon: Iconoir.Bell(color: Colors.blue, width: 20, height: 20),
          title: l10n.whatsNew,
          subtitle: l10n.view_changelog,
          onTap: _showChangelogDialog,
          iconColor: Colors.blue,
        ),
        _buildActionTile(
          icon: Iconoir.HeartSolid(color: Colors.pink, width: 20, height: 20),
          title: l10n.supportAurora,
          subtitle: l10n.supportAuroraDescShort,
          onTap: () => DonationService.showDonationDialog(context),
          iconColor: Colors.pink,
        ),
        _buildActionTile(
          icon: Iconoir.ChatBubble(color: Colors.green, width: 20, height: 20),
          title: l10n.send_feedback,
          subtitle: l10n.send_feedback_desc,
          onTap: () => _showFeedbackDialog(),
          iconColor: Colors.green,
        ),
        _buildActionTile(
          icon: Iconoir.Language(color: Colors.purple, width: 20, height: 20),
          title: l10n.contributeTranslations,
          subtitle: l10n.contributeTranslationsDesc,
          onTap: () => launchUrl(
            Uri.parse('https://crowdin.com/project/aurora-music'),
            mode: LaunchMode.externalApplication,
          ),
          iconColor: Colors.purple,
        ),
        _buildActionTile(
          icon: Iconoir.Refresh(color: Theme.of(context).colorScheme.primary, width: 20, height: 20),
          title: l10n.settingsCheckUpdates,
          subtitle: l10n.settingsCheckUpdatesDesc,
          onTap: () async {
            widget.notificationManager.showNotification(
              l10n.settingsCheckingUpdates,
              duration: const Duration(seconds: 2),
            );

            final result = await VersionService.checkForNewVersion();

            if (result.isUpdateAvailable && result.latestVersion != null) {
              widget.notificationManager.showNotification(
                l10n.settingsUpdateAvailable,
                duration: const Duration(seconds: 2),
                onComplete: () {
                  _showUpdateAvailableDialog(result.latestVersion!);
                  widget.notificationManager.showDefaultTitle();
                },
              );
            } else {
              widget.notificationManager.showNotification(
                l10n.settingsUpToDate,
                duration: const Duration(seconds: 2),
                onComplete: () => widget.notificationManager.showDefaultTitle(),
              );
            }
          },
          isLast: true,
        ),
      ],
    );
  }
}

import 'package:aurora_music_v01/shared/widgets/about_dialog.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:aurora_music_v01/shared/widgets/changelog_dialog.dart';
import 'package:aurora_music_v01/shared/widgets/feedback_reminder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../shared/services/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/performance_mode_provider.dart';
import '../../../shared/services/device_performance_service.dart';
import '../../../shared/services/version_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/services/cache_manager.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/donation_service.dart';
import '../screens/artist_separator_settings.dart';
import '../screens/home_layout_settings.dart';
import '../../../shared/utils/responsive_utils.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/expanding_player.dart';

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

  // Glassmorphic Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          fontFamily: FontConstants.fontFamily,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Glassmorphic Card Container
  Widget _buildGlassmorphicCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  // Glassmorphic Switch Tile
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (!isFirst)
          Divider(
            height: 1,
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
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

  // Glassmorphic Action Tile
  Widget _buildActionTile({
    required IconData icon,
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
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: effectiveIconColor,
            ),
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
          trailing: trailing ??
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.5),
              ),
          onTap: onTap,
        ),
      ],
    );
  }

  // Glassmorphic Slider Tile using classic Flutter Slider
  Widget _buildSliderTile({
    required IconData icon,
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
        );
      },
    );
  }

  Widget _buildSliderTileContent({
    required IconData icon,
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
            indent: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                        Text(
                          displayValue,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: FontConstants.fontFamily,
                            color: Theme.of(context).colorScheme.primary,
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
                      child: defaultValue != null
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                // Thumb travel range: 8 px padding on each side
                                // (matches Flutter's default thumb overlay radius)
                                const double thumbRadius = 8.0;
                                final trackWidth =
                                    constraints.maxWidth - thumbRadius * 2;
                                final fraction =
                                    (defaultValue - min) / (max - min);
                                final markerLeft =
                                    thumbRadius + fraction * trackWidth;
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
                            ),
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
        l10n.translate('settings_clear_cache_title'),
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        l10n.translate('settings_clear_cache_message'),
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.translate('cancel'),
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
                l10n.translate('settings_cache_cleared'),
                duration: const Duration(seconds: 2),
              );
            }
          },
          child: Text(
            l10n.translate('delete'),
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
          l10n.translate('settings_cache_info'),
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
                l10n.translate('settings_storage'),
                style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(l10n.translate('lyrics'), _formatBytes(lyricsSize)),
              _buildInfoRow(l10n.translate('onboarding_album_artwork'),
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
                  l10n.translate('lyrics'), '${cacheSizes['lyrics']} items'),
              _buildInfoRow(l10n.translate('onboarding_album_artwork'),
                  '${cacheSizes['artwork']} items'),
              _buildInfoRow(l10n.translate('metadata'),
                  '${cacheSizes['metadata']} items'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.translate('cancel'),
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
        l10n.translate('restart_required'),
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        l10n.translate('restart_required_desc'),
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
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
            l10n.translate('restart_now'),
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
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (context) => PopScope(
        canPop: false, // Cannot dismiss with back button
        child: dialogContent,
      ),
    );
  }

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final codename = dotenv.env['CODE_NAME'] ?? 'Unknown';

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

    showDialog(
      context: context,
      builder: (context) => const FeedbackReminderDialog(),
    );
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
                    ? const Icon(Icons.check, color: Colors.white, size: 22)
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
        l10n.translate('update_available'),
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        '${l10n.translate('update_message')}: $latestVersion',
        style: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.translate('later'),
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
            l10n.translate('update_now'),
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
          indent: 56,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.language_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            l10n.translate('settings_language'),
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
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'cs', child: Text('Čeština')),
              ],
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);

    return Selector<AudioPlayerService, bool>(
      selector: (_, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);

        final settingsContent = _buildSettingsContent(
          l10n: l10n,
          themeProvider: themeProvider,
          audioPlayerService: audioPlayerService,
          hasCurrentSong: hasCurrentSong,
          isTablet: isTablet,
        );

        return ListView(
          padding: EdgeInsets.only(
            top: isTablet ? 20.0 : 10.0,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : MediaQuery.of(context).padding.bottom + 24.0,
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 800 : double.infinity,
                ),
                child: settingsContent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsContent({
    required AppLocalizations l10n,
    required ThemeProvider themeProvider,
    required AudioPlayerService audioPlayerService,
    required bool hasCurrentSong,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // APPEARANCE
        _buildSectionHeader(l10n.translate('settings_appearance')),
        _buildGlassmorphicCard(
          children: [
            _buildSwitchTile(
              icon: Icons.palette_rounded,
              title: l10n.translate('settings_material_you'),
              subtitle: l10n.translate('settings_material_you_desc'),
              value: themeProvider.useDynamicColor,
              onChanged: (value) => themeProvider.toggleDynamicColor(),
              isFirst: true,
            ),
            if (!themeProvider.useDynamicColor)
              _buildActionTile(
                icon: Icons.color_lens_rounded,
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
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                onTap: () => _showColorPickerDialog(themeProvider),
              ),
            Consumer<PerformanceModeProvider>(
              builder: (context, performanceProvider, _) {
                final isHighEnd =
                    performanceProvider.currentMode == PerformanceLevel.high;
                return _buildSwitchTile(
                  icon: Icons.speed_rounded,
                  title: l10n.translate('settings_highend_ui'),
                  subtitle: l10n.translate('settings_highend_ui_desc'),
                  value: isHighEnd,
                  onChanged: (value) {
                    // Don't change mode here - show dialog first
                    // Mode will only change when user confirms restart
                    _showRestartDialog(value);
                  },
                );
              },
            ),
            Consumer<PerformanceModeProvider>(
              builder: (context, performanceProvider, _) {
                if (!performanceProvider.shouldEnableBlur) {
                  return const SizedBox.shrink();
                }
                return _buildSliderTile(
                  icon: Icons.blur_on_rounded,
                  title: 'Background Blur',
                  subtitle: 'Artwork blur intensity',
                  value: themeProvider.blurIntensity,
                  min: 5.0,
                  max: 40.0,
                  defaultValue: 25.0,
                  valueFormatter: (v) => v.toStringAsFixed(0),
                  onChanged: (value) => themeProvider.updateBlurIntensity(value),
                  onChangeEnd: (value) => themeProvider.setBlurIntensity(value),
                );
              },
            ),
            _buildSliderTile(
              icon: Icons.brightness_4_rounded,
              title: 'Background Darkness',
              subtitle: 'Overlay opacity on artwork',
              value: themeProvider.overlayOpacity,
              min: 0.0,
              max: 0.8,
              defaultValue: 0.3,
              valueFormatter: (v) => '${(v * 100).toStringAsFixed(0)}%',
              onChanged: (value) => themeProvider.updateOverlayOpacity(value),
              onChangeEnd: (value) => themeProvider.setOverlayOpacity(value),
            ),
            _buildLanguageTile(),
            _buildActionTile(
              icon: Icons.dashboard_rounded,
              title: l10n.translate('homeLayout'),
              subtitle: l10n.translate('homeLayoutDesc'),
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

        // PLAYBACK
        _buildSectionHeader(l10n.translate('settings_playback')),
        _buildGlassmorphicCard(
          children: [
            _buildSwitchTile(
              icon: Icons.call_split_rounded,
              title: l10n.translate('settings_gapless'),
              subtitle: l10n.translate('settings_gapless_desc'),
              value: audioPlayerService.gaplessPlayback,
              onChanged: (value) =>
                  audioPlayerService.setGaplessPlayback(value),
              isFirst: true,
            ),
            _buildSwitchTile(
              icon: Icons.volume_up_rounded,
              title: l10n.translate('settings_normalization'),
              subtitle: l10n.translate('settings_normalization_desc'),
              value: audioPlayerService.volumeNormalization,
              onChanged: (value) =>
                  audioPlayerService.setVolumeNormalization(value),
            ),
            _buildSliderTile(
              icon: Icons.speed_rounded,
              title: l10n.translate('playback_speed'),
              subtitle: l10n.translate('playback_speed_desc'),
              value: audioPlayerService.playbackSpeed,
              min: 0.25,
              max: 5.0,
              defaultValue: 1.0,
              valueFormatter: (v) => '${v.toStringAsFixed(2)}x',
              onChanged: (value) {
                audioPlayerService.setPlaybackSpeed(value);
              },
              onChangeEnd: (value) {
                final rounded = (value * 20).round() / 20;
                audioPlayerService.setPlaybackSpeed(rounded);
              },
            ),
            _buildSwitchTile(
              icon: Icons.music_note_rounded,
              title: 'Adjust pitch with speed',
              subtitle: 'When off, tempo changes without pitch shift',
              value: audioPlayerService.pitchWithSpeed,
              onChanged: (value) =>
                  audioPlayerService.setPitchWithSpeed(value),
            ),
            _buildActionTile(
              icon: Icons.people_rounded,
              title: l10n.translate('artist_separation'),
              subtitle: l10n.translate('artist_separation_desc'),
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
        ),

        // STORAGE
        _buildSectionHeader(l10n.translate('settings_storage')),
        _buildGlassmorphicCard(
          children: [
            _buildActionTile(
              icon: Icons.storage_rounded,
              title: l10n.translate('settings_cache_info'),
              subtitle: l10n.translate('settings_cache_info_desc'),
              onTap: _showCacheInfo,
              isFirst: true,
            ),
            _buildActionTile(
              icon: Icons.delete_rounded,
              title: l10n.translate('settings_clear_cache'),
              subtitle: l10n.translate('settings_clear_cache_desc'),
              onTap: _showClearCacheDialog,
              isLast: true,
            ),
          ],
        ),

        // ABOUT
        _buildSectionHeader(l10n.translate('settings_about')),
        _buildGlassmorphicCard(
          children: [
            _buildActionTile(
              icon: Icons.info_rounded,
              title: l10n.translate('settings_about_app'),
              subtitle:
                  '${l10n.translate('settings_version')} $_currentVersion',
              onTap: _showAboutDialog,
              isFirst: true,
            ),
            _buildActionTile(
              icon: Icons.notifications_rounded,
              title: l10n.translate('whats_new'),
              subtitle: l10n.translate('view_changelog'),
              onTap: _showChangelogDialog,
              iconColor: Colors.blue,
            ),
            _buildActionTile(
              icon: Icons.favorite_rounded,
              title: l10n.translate('support_aurora'),
              subtitle: l10n.translate('support_aurora_desc'),
              onTap: () => DonationService.showDonationDialog(context),
              iconColor: Colors.pink,
            ),
            _buildActionTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.translate('send_feedback'),
              subtitle: l10n.translate('send_feedback_desc'),
              onTap: () => _showFeedbackDialog(),
              iconColor: Colors.green,
            ),
            _buildActionTile(
              icon: Icons.restart_alt_rounded,
              title: l10n.translate('settings_check_updates'),
              subtitle: l10n.translate('settings_check_updates_desc'),
              onTap: () async {
                widget.notificationManager.showNotification(
                  l10n.translate('settings_checking_updates'),
                  duration: const Duration(seconds: 2),
                );

                final result = await VersionService.checkForNewVersion();

                if (result.isUpdateAvailable && result.latestVersion != null) {
                  widget.notificationManager.showNotification(
                    l10n.translate('settings_update_available'),
                    duration: const Duration(seconds: 2),
                    onComplete: () {
                      _showUpdateAvailableDialog(result.latestVersion!);
                      widget.notificationManager.showDefaultTitle();
                    },
                  );
                } else {
                  widget.notificationManager.showNotification(
                    l10n.translate('settings_up_to_date'),
                    duration: const Duration(seconds: 2),
                    onComplete: () =>
                        widget.notificationManager.showDefaultTitle(),
                  );
                }
              },
              isLast: true,
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/performance_mode_provider.dart';
import '../../../shared/services/version_service.dart';
import '../../../shared/services/notification_manager.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/folder_filter_settings_screen.dart';
import '../screens/playback_settings_screen.dart';
import '../screens/storage_settings_screen.dart';
import '../screens/about_settings_screen.dart';
import '../screens/insights_settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: _buildSectionWidgets(),
      ),
    );
  }

  Widget _buildSectionWidgets() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildCategoryCard(
          icon: Icons.palette_outlined,
          title: l10n.settingsAppearance,
          subtitle: l10n.settingsAppearanceSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AppearanceSettingsScreen(),
            ),
          ),
          isFirst: true,
        ),
        _buildCategoryCard(
          icon: Icons.play_circle_outline,
          title: l10n.settingsPlayback,
          subtitle: l10n.settingsPlaybackSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaybackSettingsScreen(),
            ),
          ),
        ),
        _buildCategoryCard(
          icon: Icons.insights_outlined,
          title: l10n.settingsInsights,
          subtitle: l10n.settingsInsightsSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const InsightsSettingsScreen(),
            ),
          ),
        ),
        _buildCategoryCard(
          icon: Icons.storage_outlined,
          title: l10n.settingsStorage,
          subtitle: l10n.settingsStorageSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StorageSettingsScreen(
                notificationManager: widget.notificationManager,
              ),
            ),
          ),
        ),
        _buildCategoryCard(
          icon: Icons.folder_outlined,
          title: l10n.settingsLibraryFolders,
          subtitle: l10n.settingsLibraryFoldersSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FolderFilterSettingsScreen(),
            ),
          ),
        ),
        _buildCategoryCard(
          icon: Icons.info_outline,
          title: l10n.settingsAbout,
          subtitle: l10n.settingsAboutSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AboutSettingsScreen(
                currentVersion: _currentVersion,
                notificationManager: widget.notificationManager,
              ),
            ),
          ),
          isLast: true,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isLowEnd
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = isLowEnd
        ? Theme.of(context).colorScheme.outlineVariant
        : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 0 : 0,
        bottom: isLast ? 0 : 0,
      ),
      child: Column(
        children: [
          if (isFirst)
            DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: borderColor),
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                ),
              ),
              child: _categoryRow(
                  icon, title, subtitle, onTap, isDark, isFirst,
                  isLast: false),
            )
          else if (isLast)
            DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: borderColor),
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                ),
              ),
              child: _categoryRow(
                  icon, title, subtitle, onTap, isDark, isFirst,
                  isLast: true),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                ),
              ),
              child: _categoryRow(
                  icon, title, subtitle, onTap, isDark, isFirst,
                  isLast: false),
            ),
        ],
      ),
    );
  }

  Widget _categoryRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    bool isDark,
    bool isFirst, {
    required bool isLast,
  }) {
    return Column(
      children: [
        if (!isFirst)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 0,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.black.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: FontConstants.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: FontConstants.fontFamily,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

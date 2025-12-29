import 'package:aurora_music_v01/widgets/about_dialog.dart';
import 'package:aurora_music_v01/widgets/changelog_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/audio_player_service.dart';
import '../../localization/app_localizations.dart';
import '../../localization/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/version_service.dart';
import '../../services/notification_manager.dart';
import '../../services/cache_manager.dart';
import '../../services/artwork_cache_service.dart';
import '../../services/donation_service.dart';
import '../../screens/artist_separator_settings.dart';
import '../../screens/home_layout_settings.dart';
import '../glassmorphic_container.dart';
import '../expanding_player.dart';

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
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Glassmorphic Card Container
  Widget _buildGlassmorphicCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicContainer(
        borderRadius: BorderRadius.circular(20),
        blur: 15,
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
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.7),
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
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveIconColor.withOpacity(0.15),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.7),
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
                    ?.withOpacity(0.5),
              ),
          onTap: onTap,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('settings_clear_cache_title')),
        content: Text(l10n.translate('settings_clear_cache_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showCacheInfo() async {
    final l10n = AppLocalizations.of(context);
    try {
      final directory = await getApplicationDocumentsDirectory();

      int lyricsSize = 0;
      int artworkSize = 0;

      final lyricsDir = Directory('${directory.path}/lyrics');
      if (await lyricsDir.exists()) {
        await for (var file in lyricsDir.list(recursive: true)) {
          if (file is File) {
            lyricsSize += await file.length();
          }
        }
      }

      final artworkDir = Directory('${directory.path}/artwork_cache');
      if (await artworkDir.exists()) {
        await for (var file in artworkDir.list(recursive: true)) {
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

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translate('settings_cache_info')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('settings_storage'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                    l10n.translate('lyrics'), _formatBytes(lyricsSize)),
                _buildInfoRow(l10n.translate('onboarding_album_artwork'),
                    _formatBytes(artworkSize)),
                const Divider(),
                _buildInfoRow('Total', _formatBytes(totalSize), bold: true),
                const SizedBox(height: 16),
                Text(
                  'Memory Cache',
                  style: Theme.of(context).textTheme.titleSmall,
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
              child: Text(l10n.translate('cancel')),
            ),
          ],
        ),
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
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
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

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final codename = dotenv.env['CODE_NAME'] ?? 'Unknown';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AuroraAboutDialog(
        version: packageInfo.version,
        codename: codename,
      ),
    );
  }

  void _showChangelogDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ChangelogDialog(
        currentVersion: _currentVersion,
      ),
    );
  }

  void _showUpdateAvailableDialog(dynamic latestVersion) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('update_available')),
        content: Text('${l10n.translate('update_message')}: $latestVersion'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('later')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onUpdateCheck != null) {
                widget.onUpdateCheck!();
              }
            },
            child: Text(l10n.translate('update_now')),
          ),
        ],
      ),
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
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: currentLocale,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
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

    return Selector<AudioPlayerService, bool>(
      selector: (_, service) => service.currentSong != null,
      builder: (context, hasCurrentSong, child) {
        final audioPlayerService =
            Provider.of<AudioPlayerService>(context, listen: false);
        return ListView(
          padding: EdgeInsets.only(
            top: 10.0,
            bottom: hasCurrentSong
                ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                : 24.0,
          ),
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
                _buildLanguageTile(),
                _buildActionTile(
                  icon: Icons.dashboard_customize_rounded,
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
                  icon: Icons.swap_horiz_rounded,
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
                _buildActionTile(
                  icon: Icons.people_outline_rounded,
                  title: l10n.translate('artist_separation'),
                  subtitle: l10n.translate('artist_separation_desc'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ArtistSeparatorSettingsScreen(),
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
                  icon: Icons.delete_outline_rounded,
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
                  icon: Icons.info_outline_rounded,
                  title: l10n.translate('settings_about_app'),
                  subtitle:
                      '${l10n.translate('settings_version')} $_currentVersion',
                  onTap: _showAboutDialog,
                  isFirst: true,
                ),
                _buildActionTile(
                  icon: Icons.new_releases_outlined,
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
                  icon: Icons.system_update_rounded,
                  title: l10n.translate('settings_check_updates'),
                  subtitle: l10n.translate('settings_check_updates_desc'),
                  onTap: () async {
                    widget.notificationManager.showNotification(
                      l10n.translate('settings_checking_updates'),
                      duration: const Duration(seconds: 2),
                    );

                    final result = await VersionService.checkForNewVersion();

                    if (result.isUpdateAvailable &&
                        result.latestVersion != null) {
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
      },
    );
  }
}

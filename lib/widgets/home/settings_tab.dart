import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/Audio_Player_Service.dart';
import '../../localization/app_localizations.dart';
import '../../localization/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/version_service.dart';
import '../../services/notification_manager.dart';
import '../glassmorphic_container.dart';
import '../about_dialog.dart';

class SettingsTab extends StatefulWidget {
  final VoidCallback? onUpdateCheck;
  final NotificationManager notificationManager;

  const SettingsTab({
    super.key,
    this.onUpdateCheck,
    required this.notificationManager,
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
      setState(() {
        _currentVersion = version;
      });
    }
  }

  Widget buildSettingsCategory({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 10.0),
        ...children,
        const SizedBox(height: 20.0),
      ],
    );
  }

  Widget buildThemeSwitcher() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListTile(
      leading: Icon(
        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).iconTheme.color,
      ),
      title: Text(
        'Theme',
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (value) => themeProvider.toggleTheme(),
      ),
      subtitle: Text(
        themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
      ),
    );
  }

  Widget buildManualUpdateCheck() {
    return glassmorphicContainer(
      child: ListTile(
        title: Text(
          AppLocalizations.of(context).translate('check_for_updates'),
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.system_update, color: Colors.white),
        onTap: () async {
          widget.notificationManager.showNotification(
            AppLocalizations.of(context).translate('checking_for_updates'),
            duration: const Duration(seconds: 2),
          );

          VersionCheckResult result = await VersionService.checkForNewVersion();

          if (result.isUpdateAvailable && result.latestVersion != null) {
            widget.notificationManager.showNotification(
              AppLocalizations.of(context).translate('update_found'),
              duration: const Duration(seconds: 3),
              onComplete: () {
                _showUpdateAvailableDialog(result.latestVersion!);
                widget.notificationManager.showDefaultTitle();
              },
            );
          } else {
            widget.notificationManager.showNotification(
              AppLocalizations.of(context).translate('no_update_found'),
              duration: const Duration(seconds: 3),
              onComplete: () => widget.notificationManager.showDefaultTitle(),
            );
          }
        },
      ),
    );
  }

  Widget buildLanguageSelector() {
    return glassmorphicContainer(
      child: ListTile(
        title: Text(
          AppLocalizations.of(context).translate('language'),
          style: const TextStyle(color: Colors.white),
        ),
        trailing: DropdownButton<String>(
          value: LocaleProvider.of(context)!.locale.languageCode,
          dropdownColor: Colors.black.withOpacity(0.8),
          style: const TextStyle(color: Colors.white),
          onChanged: (String? newValue) {
            if (newValue != null) {
              LocaleProvider.of(context)!.setLocale(Locale(newValue));
            }
          },
          items: <String>['en', 'cs'].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value == 'en' ? 'English' : 'Čeština',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showUpdateAvailableDialog(dynamic latestVersion) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('update_available'),
          ),
          content: Text(
            AppLocalizations.of(context)
                .translate('update_message')
                .replaceFirst('%s', latestVersion.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).translate('later')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Note: URL launching should be handled by parent or injected as dependency
                if (widget.onUpdateCheck != null) {
                  widget.onUpdateCheck!();
                }
              },
              child: Text(AppLocalizations.of(context).translate('update_now')),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final currentSong = audioPlayerService.currentSong;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0)
          .copyWith(bottom: currentSong != null ? 90.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildThemeSwitcher(),
          // Playback Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('playback'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Gapless Playback
                    ListTile(
                      leading: Icon(Icons.play_circle_outline, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Gapless Playback',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.gaplessPlayback,
                        onChanged: (value) => audioPlayerService.setGaplessPlayback(value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                    Divider(color: Theme.of(context).dividerColor),

                    // Volume Normalization
                    ListTile(
                      leading: Icon(Icons.volume_up_outlined, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Volume Normalization',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.volumeNormalization,
                        onChanged: (value) => audioPlayerService.setVolumeNormalization(value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                    Divider(color: Theme.of(context).dividerColor),

                    // Playback Speed
                    ListTile(
                      leading: Icon(Icons.speed, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Playback Speed',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: DropdownButton<double>(
                        dropdownColor: Theme.of(context).cardColor,
                        value: audioPlayerService.playbackSpeed,
                        items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          return DropdownMenuItem<double>(
                            value: speed,
                            child: Text(
                              '${speed}x',
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setPlaybackSpeed(value);
                          }
                        },
                        underline: Container(),
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Library Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('library'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Default Sort Order
                    ListTile(
                      leading: Icon(Icons.sort, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Default Sort Order',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: DropdownButton<String>(
                        dropdownColor: Theme.of(context).cardColor,
                        value: audioPlayerService.defaultSortOrder,
                        items: ['title', 'artist', 'album', 'date_added'].map((sort) {
                          return DropdownMenuItem<String>(
                            value: sort,
                            child: Text(
                              sort.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setDefaultSortOrder(value);
                          }
                        },
                        underline: Container(),
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color),
                      ),
                    ),
                    Divider(color: Theme.of(context).dividerColor),

                    // Auto Playlists
                    ListTile(
                      leading: Icon(Icons.playlist_add_check, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Auto Playlists',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.autoPlaylists,
                        onChanged: (value) => audioPlayerService.setAutoPlaylists(value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Advanced Settings
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('advanced'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    // Cache Size
                    ListTile(
                      leading: Icon(Icons.memory, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Cache Size',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: DropdownButton<int>(
                        dropdownColor: Theme.of(context).cardColor,
                        value: audioPlayerService.cacheSize,
                        items: [100, 250, 500, 1000, 2000].map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text(
                              '${size}MB',
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            audioPlayerService.setCacheSize(value);
                          }
                        },
                        underline: Container(),
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color),
                      ),
                    ),
                    Divider(color: Theme.of(context).dividerColor),

                    // Media Controls
                    ListTile(
                      leading: Icon(Icons.notifications, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'Media Controls',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: Switch(
                        value: audioPlayerService.mediaControls,
                        onChanged: (value) => audioPlayerService.setMediaControls(value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // About Section
          buildSettingsCategory(
            title: AppLocalizations.of(context).translate('about'),
            children: [
              glassmorphicContainer(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: Text(
                        AppLocalizations.of(context).translate('about_aurora'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: () => _showAboutDialog(),
                    ),
                    const Divider(color: Colors.white24),
                    ListTile(
                      leading: const Icon(Icons.system_update, color: Colors.white),
                      title: Text(
                        AppLocalizations.of(context).translate('check_updates'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Version $_currentVersion',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      onTap: () async {
                        final result = await VersionService.checkForNewVersion();
                        // Handle result as needed
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
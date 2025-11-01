import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/audio_player_service.dart';
import '../../localization/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/version_service.dart';
import '../../services/notification_manager.dart';
import '../../services/cache_manager.dart';
import '../../services/artwork_cache_service.dart';
import '../about_dialog.dart';

/// A simplified settings tab.
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

  // Simplified Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Simplified Switch Tile
  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  // Simplified Dropdown Tile
  Widget _buildDropdownTile<T>({
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Simplified Action Tile
  Widget _buildActionTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
    );
  }

  // Cache Management
  Future<void> _clearLyricsCache() async {
    try {
      final cacheManager = CacheManager();
      cacheManager.initialize();
      cacheManager.clearLyricsCache();

      final directory = await getApplicationDocumentsDirectory();
      final lyricsDir = Directory('${directory.path}/lyrics');

      if (await lyricsDir.exists()) {
        await lyricsDir.delete(recursive: true);
        await lyricsDir.create();
      }
    } catch (e) {
      debugPrint('Error clearing lyrics cache: $e');
    }
  }

  Future<void> _clearArtworkCache() async {
    try {
      final cacheManager = CacheManager();
      cacheManager.initialize();
      cacheManager.clearArtworkCache();

      final artworkCache = ArtworkCacheService();
      artworkCache.clearCache();

      final directory = await getApplicationDocumentsDirectory();
      final artworkDir = Directory('${directory.path}/artwork_cache');

      if (await artworkDir.exists()) {
        await artworkDir.delete(recursive: true);
        await artworkDir.create();
      }
    } catch (e) {
      debugPrint('Error clearing artwork cache: $e');
    }
  }

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

  void _showClearCacheDialog(
      String cacheName, String message, Future<void> Function() clearFunction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $cacheName?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await clearFunction();
              if (mounted) {
                widget.notificationManager.showNotification(
                  '$cacheName cleared',
                  duration: const Duration(seconds: 2),
                );
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showCacheInfo() async {
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
          title: const Text('Cache Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Disk Usage',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Lyrics', _formatBytes(lyricsSize)),
                _buildInfoRow('Artwork', _formatBytes(artworkSize)),
                const Divider(),
                _buildInfoRow('Total', _formatBytes(totalSize), bold: true),
                const SizedBox(height: 16),
                Text(
                  'Memory Cache',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Lyrics', '${cacheSizes['lyrics']} items'),
                _buildInfoRow('Artwork', '${cacheSizes['artwork']} items'),
                _buildInfoRow('Metadata', '${cacheSizes['metadata']} items'),
                _buildInfoRow('Queries', '${cacheSizes['query']} items'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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

  void _showUpdateAvailableDialog(dynamic latestVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('Version $latestVersion is now available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onUpdateCheck != null) {
                widget.onUpdateCheck!();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentSong = audioPlayerService.currentSong;

    return ListView(
      padding: EdgeInsets.only(
        top: 10.0,
        bottom: currentSong != null ? 100.0 : 24.0,
      ),
      children: [
        // APPEARANCE
        _buildSectionHeader('Appearance'),
        _buildSwitchTile(
          title: 'Dark Mode',
          subtitle: themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
          value: themeProvider.isDarkMode,
          onChanged: (value) => themeProvider.toggleTheme(),
        ),
        _buildSwitchTile(
          title: 'Material You',
          subtitle: 'Dynamic colors from wallpaper',
          value: themeProvider.useDynamicColor,
          onChanged: (value) => themeProvider.toggleDynamicColor(),
        ),
        _buildDropdownTile<String>(
          title: 'Language',
          value: LocaleProvider.of(context)!.locale.languageCode,
          items: const ['en', 'cs'],
          itemLabel: (code) => code == 'en' ? 'English' : 'Čeština',
          onChanged: (value) {
            if (value != null) {
              LocaleProvider.of(context)!.setLocale(Locale(value));
            }
          },
        ),

        // PLAYBACK
        _buildSectionHeader('Playback'),
        _buildSwitchTile(
          title: 'Gapless Playback',
          subtitle: 'Seamless track transitions',
          value: audioPlayerService.gaplessPlayback,
          onChanged: (value) => audioPlayerService.setGaplessPlayback(value),
        ),
        _buildSwitchTile(
          title: 'Volume Normalization',
          subtitle: 'Consistent volume levels',
          value: audioPlayerService.volumeNormalization,
          onChanged: (value) =>
              audioPlayerService.setVolumeNormalization(value),
        ),
        _buildDropdownTile<double>(
          title: 'Playback Speed',
          value: audioPlayerService.playbackSpeed,
          items: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          itemLabel: (speed) => '${speed}x',
          onChanged: (value) {
            if (value != null) {
              audioPlayerService.setPlaybackSpeed(value);
            }
          },
        ),

        // LIBRARY
        _buildSectionHeader('Library'),
        _buildDropdownTile<String>(
          title: 'Default Sort Order',
          value: audioPlayerService.defaultSortOrder,
          items: const ['title', 'artist', 'album', 'date_added'],
          itemLabel: (sort) {
            switch (sort) {
              case 'title':
                return 'Title';
              case 'artist':
                return 'Artist';
              case 'album':
                return 'Album';
              case 'date_added':
                return 'Date Added';
              default:
                return sort;
            }
          },
          onChanged: (value) {
            if (value != null) {
              audioPlayerService.setDefaultSortOrder(value);
            }
          },
        ),
        _buildSwitchTile(
          title: 'Auto Playlists',
          subtitle: 'Automatic smart playlists',
          value: audioPlayerService.autoPlaylists,
          onChanged: (value) => audioPlayerService.setAutoPlaylists(value),
        ),

        // STORAGE & CACHE
        _buildSectionHeader('Storage & Cache'),
        _buildDropdownTile<int>(
          title: 'Cache Size Limit',
          value: audioPlayerService.cacheSize,
          items: const [100, 250, 500, 1000, 2000],
          itemLabel: (size) => '$size MB',
          onChanged: (value) {
            if (value != null) {
              audioPlayerService.setCacheSize(value);
            }
          },
        ),
        _buildActionTile(
          title: 'Cache Information',
          subtitle: 'View storage usage',
          onTap: _showCacheInfo,
        ),
        _buildActionTile(
          title: 'Clear Lyrics Cache',
          subtitle: 'Remove cached lyrics',
          onTap: () => _showClearCacheDialog(
            'Lyrics Cache',
            'Downloaded lyrics will be removed and re-downloaded when needed.',
            _clearLyricsCache,
          ),
        ),
        _buildActionTile(
          title: 'Clear Artwork Cache',
          subtitle: 'Remove cached album art',
          onTap: () => _showClearCacheDialog(
            'Artwork Cache',
            'Album artwork will be reloaded from your music files.',
            _clearArtworkCache,
          ),
        ),
        _buildActionTile(
          title: 'Clear All Caches',
          subtitle: 'Remove all temporary data',
          onTap: () => _showClearCacheDialog(
            'All Caches',
            'All cached data will be deleted and rebuilt as needed.',
            _clearAllCaches,
          ),
        ),

        // SYSTEM
        _buildSectionHeader('System'),
        _buildSwitchTile(
          title: 'Media Controls',
          subtitle: 'Notification playback controls',
          value: audioPlayerService.mediaControls,
          onChanged: (value) => audioPlayerService.setMediaControls(value),
        ),

        // ADVANCED
        _buildSectionHeader('Advanced'),
        _buildActionTile(
          title: 'Run Setup Wizard',
          subtitle: 'Re-run the initial permission and library setup',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Run Setup Wizard?'),
                content: const Text(
                    'This will guide you through the initial setup process again. Are you sure?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResetSetup?.call();
                    },
                    child: Text(
                      'Run',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ABOUT
        _buildSectionHeader('About'),
        _buildActionTile(
          title: 'About Aurora Music',
          subtitle: 'Version $_currentVersion',
          onTap: _showAboutDialog,
        ),
        _buildActionTile(
          title: 'Check for Updates',
          subtitle: 'Get latest version',
          onTap: () async {
            widget.notificationManager.showNotification(
              'Checking for updates...',
              duration: const Duration(seconds: 2),
            );

            final result = await VersionService.checkForNewVersion();

            if (result.isUpdateAvailable && result.latestVersion != null) {
              widget.notificationManager.showNotification(
                'Update available!',
                duration: const Duration(seconds: 2),
                onComplete: () {
                  _showUpdateAvailableDialog(result.latestVersion!);
                  widget.notificationManager.showDefaultTitle();
                },
              );
            } else {
              widget.notificationManager.showNotification(
                'You\'re up to date',
                duration: const Duration(seconds: 2),
                onComplete: () => widget.notificationManager.showDefaultTitle(),
              );
            }
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Storage settings sub-screen — cache info & cache management.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/cache_manager.dart';
import '../../../shared/services/notification_manager.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../widgets/settings_tile_builders.dart';

class StorageSettingsScreen extends StatefulWidget {
  final NotificationManager notificationManager;

  const StorageSettingsScreen({
    super.key,
    required this.notificationManager,
  });

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  Future<void> _clearAllCaches() async {
    try {
      final cacheManager = CacheManager()..initialize();
      cacheManager.clearAllCaches();
      ArtworkCacheService().clearCache();
      final dir = await getApplicationDocumentsDirectory();
      for (final path in ['lyrics', 'artwork_cache', 'cache']) {
        final d = Directory('${dir.path}/$path');
        if (await d.exists()) {
          await d.delete(recursive: true);
          await d.create();
        }
      }
    } catch (e) {
      debugPrint('StorageSettings: error clearing caches: $e');
    }
  }

  void _showClearCacheDialog() {
    final l10n = AppLocalizations.of(context);
    final perfProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final cs = Theme.of(context).colorScheme;
    final bg = perfProvider.shouldEnableBlur
        ? Colors.grey[900]!.withValues(alpha: 0.9)
        : cs.surfaceContainerHigh;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(l10n.settingsClearCacheTitle,
            style: const TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        content: Text(l10n.settingsClearCacheMessage,
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
              Navigator.pop(context);
              await _clearAllCaches();
              if (mounted) {
                widget.notificationManager.showNotification(
                  l10n.settingsCacheCleared,
                  duration: const Duration(seconds: 2),
                );
              }
            },
            child: Text(l10n.delete,
                style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCacheInfo() async {
    final l10n = AppLocalizations.of(context);
    final perfProvider =
        Provider.of<PerformanceModeProvider>(context, listen: false);
    final cs = Theme.of(context).colorScheme;
    final shouldBlur = perfProvider.shouldEnableBlur;
    final bg =
        shouldBlur ? Colors.grey[900]!.withValues(alpha: 0.9) : cs.surfaceContainerHigh;

    try {
      final dir = await getApplicationDocumentsDirectory();
      int lyricsSize = 0;
      int artworkSize = 0;

      final lyricsDir = Directory('${dir.path}/lyrics');
      if (await lyricsDir.exists()) {
        await for (final f in lyricsDir.list(recursive: true)) {
          if (f is File) lyricsSize += await f.length();
        }
      }
      final artworkDir = Directory('${dir.path}/artwork_cache');
      if (await artworkDir.exists()) {
        await for (final f in artworkDir.list(recursive: true)) {
          if (f is File) artworkSize += await f.length();
        }
      }

      final cacheManager = CacheManager()..initialize();
      final cacheSizes = cacheManager.getCacheSizes();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: shouldBlur
                  ? Colors.white.withValues(alpha: 0.1)
                  : cs.outlineVariant,
            ),
          ),
          title: Text(l10n.settingsCacheInfo,
              style: const TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.settingsStorage,
                    style: const TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _infoRow(l10n.lyrics, _fmt(lyricsSize)),
                _infoRow(l10n.onboardingAlbumArtwork, _fmt(artworkSize)),
                Divider(color: Colors.white.withValues(alpha: 0.2)),
                _infoRow('Total', _fmt(lyricsSize + artworkSize), bold: true),
                const SizedBox(height: 16),
                Text(l10n.settingsMemoryCache,
                    style: const TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _infoRow(l10n.lyrics, l10n.settingsCacheItems('${cacheSizes['lyrics']}')),
                _infoRow(l10n.onboardingAlbumArtwork,
                    l10n.settingsCacheItems('${cacheSizes['artwork']}')),
                _infoRow(l10n.metadata, l10n.settingsCacheItems('${cacheSizes['metadata']}')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel,
                  style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: Colors.white70)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('StorageSettings: error getting cache info: $e');
    }
  }

  Widget _infoRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      );

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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
          l10n.settingsStorage,
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
            SettingsTiles.buildSectionHeader(context, l10n.settingsStorage),
            SettingsTiles.buildGlassmorphicCard(context, children: [
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.Database(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.settingsCacheInfo,
                subtitle: l10n.settingsCacheInfoDesc,
                onTap: _showCacheInfo,
                isFirst: true,
              ),
              SettingsTiles.buildActionTile(
                context,
                icon: iconoir.Trash(
                    color: Theme.of(context).colorScheme.primary,
                    width: 20,
                    height: 20),
                title: l10n.settingsClearCache,
                subtitle: l10n.settingsClearCacheDesc,
                onTap: _showClearCacheDialog,
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

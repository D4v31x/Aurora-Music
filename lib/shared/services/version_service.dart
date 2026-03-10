import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionCheckResult {
  final bool isUpdateAvailable;
  final String? latestVersion;

  VersionCheckResult({required this.isUpdateAvailable, this.latestVersion});
}

class VersionService {
  static Future<VersionCheckResult> checkForNewVersion() async {
    debugPrint('[VersionService] Starting version check via Play Core API...');
    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint('[VersionService] updateAvailability: ${info.updateAvailability}');
      debugPrint('[VersionService] availableVersionCode: ${info.availableVersionCode}');

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final versionCode = info.availableVersionCode?.toString();
        debugPrint('[VersionService] Update available! Version code: $versionCode');
        return VersionCheckResult(isUpdateAvailable: true, latestVersion: versionCode);
      }
    } catch (e) {
      debugPrint('[VersionService] Play Core check error: $e');
    }
    debugPrint('[VersionService] No update available.');
    return VersionCheckResult(isUpdateAvailable: false);
  }

  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<bool> shouldShowChangelog() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString('last_version') ?? '';
    final currentVersion = await getCurrentVersion();

    if (lastVersion != currentVersion) {
      await prefs.setString('last_version', currentVersion);
      return true;
    }
    return false;
  }

  // Force reset the changelog to show again (useful for testing)
  static Future<void> resetChangelog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_version');
  }
}

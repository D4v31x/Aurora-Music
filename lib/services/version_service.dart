import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionCheckResult {
  final bool isUpdateAvailable;
  final Version? latestVersion;

  VersionCheckResult({required this.isUpdateAvailable, this.latestVersion});
}

class VersionService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/D4v31x/Aurora-Music/releases/latest';
  static const String _currentVersionString = '0.0.9';

  static Future<VersionCheckResult> checkForNewVersion() async {
    try {
      final response = await http.get(Uri.parse(_githubApiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final versionString = data['tag_name'];

        final regex = RegExp(r'^v?(\d+\.\d+\.\d+(-[a-zA-Z0-9.\-]+)?)$');
        final match = regex.firstMatch(versionString);
        if (match != null && match.groupCount > 0) {
          final latestVersionString = match.group(1)!;
          final latestVersion = Version.parse(latestVersionString);

          final currentVersion = Version.parse(_currentVersionString);

          if (latestVersion > currentVersion) {
            return VersionCheckResult(
              isUpdateAvailable: true,
              latestVersion: latestVersion,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Version check error: $e');
    }
    return VersionCheckResult(isUpdateAvailable: false, latestVersion: null);
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
}

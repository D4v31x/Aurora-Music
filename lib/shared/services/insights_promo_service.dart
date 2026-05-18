import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages when to surface the Listening Insights promotional popups.
///
/// Two popup types:
/// 1. New-feature banner – shown once per app version (e.g. after an upgrade
///    that first ships the Insights screen).
/// 2. Periodic recap reminder – shown every [_kRecapIntervalDays] days to
///    encourage users to revisit their stats.
class InsightsPromoService {
  /// Drives the aurora recap banner on the home screen AppBar.
  /// Set to `true` to show the banner; `false` to dismiss it.
  static final ValueNotifier<bool> recapBannerNotifier = ValueNotifier(false);

  static const _kNewFeatureVersionKey = 'insights_feature_version';
  static const _kRecapLastShownKey = 'insights_recap_last_ms';
  static const int _kRecapIntervalDays = 14;

  // ── New-feature banner ────────────────────────────────────────────────────

  /// Returns true if the current app version has not yet shown the banner.
  static Future<bool> shouldShowNewFeatureBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final pkgInfo = await PackageInfo.fromPlatform();
    final storedVersion = prefs.getString(_kNewFeatureVersionKey) ?? '';
    return storedVersion != pkgInfo.version;
  }

  /// Call this immediately after showing the new-feature banner.
  static Future<void> markNewFeatureBannerShown() async {
    final prefs = await SharedPreferences.getInstance();
    final pkgInfo = await PackageInfo.fromPlatform();
    await prefs.setString(_kNewFeatureVersionKey, pkgInfo.version);
  }

  // ── Periodic recap reminder ───────────────────────────────────────────────

  /// Returns true if the reminder has never been shown, or was last shown
  /// more than [_kRecapIntervalDays] days ago.
  static Future<bool> shouldShowRecapReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kRecapLastShownKey) ?? 0;
    if (lastMs == 0) return true;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;
    return daysSince >= _kRecapIntervalDays;
  }

  /// Call this immediately after showing the recap reminder.
  static Future<void> markRecapReminderShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kRecapLastShownKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Recap period preference ───────────────────────────────────────────────

  static const _kRecapPeriodKey = 'insights_recap_period_days';
  static const int defaultPeriodDays = 7;

  /// Returns the saved recap period (7 or 30 days; defaults to 7).
  static Future<int> getRecapPeriodDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRecapPeriodKey) ?? defaultPeriodDays;
  }

  /// Saves the recap period preference.
  static Future<void> setRecapPeriodDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRecapPeriodKey, days);
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages when to surface the Listening Recap banner on the home screen.
///
/// Timeline:
/// - Weekly recap: shown once per calendar-week (weeks counted from the
///   user's very first play) after at least 7 days have elapsed.
/// - Monthly recap: shown once per calendar-month after at least 30 days.
///   Monthly takes precedence when both are due.
///
/// Tapping "Later" hides the banner for the current session only — it will
/// reappear on the next launch.  Tapping "Show" calls [markRecapViewed]
/// which records the current week/month so the banner stays hidden until
/// the next period begins.
class InsightsPromoService {
  // ── Public notifiers ──────────────────────────────────────────────────────

  /// Set to true when a recap banner should be visible.
  static final ValueNotifier<bool> recapBannerNotifier = ValueNotifier(false);

  /// The recap period (7 or 30 days) for the currently pending banner.
  static final ValueNotifier<int> recapBannerPeriodNotifier = ValueNotifier(7);

  // ── Persistence keys ──────────────────────────────────────────────────────

  static const _kWeeklyLastSeenWeek  = 'recap_weekly_last_seen_week';
  static const _kMonthlyLastSeenMonth = 'recap_monthly_last_seen_month';
  static const _kWeeklyEnabled       = 'recap_weekly_enabled';
  static const _kMonthlyEnabled      = 'recap_monthly_enabled';
  static const _kRecapPeriodKey      = 'insights_recap_period_days';

  static const int defaultPeriodDays = 7;

  // ── Banner trigger ────────────────────────────────────────────────────────

  /// Call once on each app launch after [SmartSuggestionsService] is
  /// initialised (so [firstListenTime] is available).
  ///
  /// Does nothing when [firstListenTime] is null (no plays recorded yet).
  static Future<void> checkAndTriggerBanner(DateTime? firstListenTime) async {
    if (firstListenTime == null) return;

    final prefs      = await SharedPreferences.getInstance();
    final daysSince  = DateTime.now().difference(firstListenTime).inDays;

    // Monthly recap takes precedence.
    final monthlyEnabled = prefs.getBool(_kMonthlyEnabled) ?? true;
    if (monthlyEnabled && daysSince >= 30) {
      final currentMonth  = daysSince ~/ 30;
      final lastSeenMonth = prefs.getInt(_kMonthlyLastSeenMonth) ?? 0;
      if (currentMonth > lastSeenMonth) {
        recapBannerPeriodNotifier.value = 30;
        recapBannerNotifier.value = true;
        return;
      }
    }

    // Weekly recap.
    final weeklyEnabled = prefs.getBool(_kWeeklyEnabled) ?? true;
    if (weeklyEnabled && daysSince >= 7) {
      final currentWeek  = daysSince ~/ 7;
      final lastSeenWeek = prefs.getInt(_kWeeklyLastSeenWeek) ?? 0;
      if (currentWeek > lastSeenWeek) {
        recapBannerPeriodNotifier.value = 7;
        recapBannerNotifier.value = true;
      }
    }
  }

  /// Call when the user taps "Show" and opens the recap screen.
  /// Records the current period so the banner won't reappear until next week/month.
  static Future<void> markRecapViewed(
    int periodDays,
    DateTime firstListenTime,
  ) async {
    final prefs     = await SharedPreferences.getInstance();
    final daysSince = DateTime.now().difference(firstListenTime).inDays;
    if (periodDays >= 30) {
      await prefs.setInt(_kMonthlyLastSeenMonth, daysSince ~/ 30);
    } else {
      await prefs.setInt(_kWeeklyLastSeenWeek, daysSince ~/ 7);
    }
  }

  // ── Per-period enable preferences ─────────────────────────────────────────

  static Future<bool> getWeeklyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kWeeklyEnabled) ?? true;
  }

  static Future<void> setWeeklyEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWeeklyEnabled, v);
  }

  static Future<bool> getMonthlyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMonthlyEnabled) ?? true;
  }

  static Future<void> setMonthlyEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMonthlyEnabled, v);
  }

  // ── Recap content period ──────────────────────────────────────────────────

  /// The period of data the recap screen shows (7 or 30 days).
  static Future<int> getRecapPeriodDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRecapPeriodKey) ?? defaultPeriodDays;
  }

  static Future<void> setRecapPeriodDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRecapPeriodKey, days);
  }
}

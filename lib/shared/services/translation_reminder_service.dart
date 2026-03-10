import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage the in-app translation contribution reminder.
/// Shows once per device for users whose system locale is not English.
class TranslationReminderService {
  static const String _shownKey = 'translation_reminder_shown';

  /// Returns true if the reminder should be displayed:
  /// - Device language is not English, AND
  /// - The prompt has not been shown/dismissed before.
  static Future<bool> shouldShowPrompt() async {
    final langCode = PlatformDispatcher.instance.locale.languageCode;
    if (langCode == 'en') return false;

    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_shownKey) ?? false);
  }

  /// Mark the prompt as shown so it does not appear again.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
  }
}

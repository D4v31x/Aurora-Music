import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage feedback reminder timing
class FeedbackReminderService {
  static const String _lastPromptKey = 'feedback_last_prompt';
  static const String _promptCountKey = 'feedback_prompt_count';
  static const String _dismissedPermanentlyKey =
      'feedback_dismissed_permanently';
  static const String _appOpenCountKey = 'app_open_count';

  /// Minimum days between feedback prompts
  static const int _minDaysBetweenPrompts = 7;

  /// Minimum app opens before first prompt
  static const int _minOpensBeforeFirstPrompt = 5;

  /// Record an app open and check if we should show feedback prompt
  static Future<bool> shouldShowFeedbackPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if permanently dismissed
    if (prefs.getBool(_dismissedPermanentlyKey) ?? false) {
      return false;
    }

    // Increment app open count
    int openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, openCount);

    // Don't show before minimum opens
    if (openCount < _minOpensBeforeFirstPrompt) {
      return false;
    }

    // Check last prompt time
    final lastPrompt = prefs.getInt(_lastPromptKey);
    if (lastPrompt != null) {
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPrompt);
      final daysSinceLastPrompt =
          DateTime.now().difference(lastPromptDate).inDays;

      if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
        return false;
      }
    }

    return true;
  }

  /// Record that the feedback prompt was shown
  static Future<void> recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);

    int count = (prefs.getInt(_promptCountKey) ?? 0) + 1;
    await prefs.setInt(_promptCountKey, count);
  }

  /// Permanently dismiss feedback prompts
  static Future<void> dismissPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedPermanentlyKey, true);
  }

  /// Reset the prompt (for testing or after major update)
  static Future<void> resetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPromptKey);
    await prefs.remove(_dismissedPermanentlyKey);
  }
}

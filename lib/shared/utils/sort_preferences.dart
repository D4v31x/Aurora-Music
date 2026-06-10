import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-screen sort settings (selected option + sort direction) so the
/// user's last choice is restored after the app is reopened.
///
/// Each library/playlist screen passes a unique [key] (e.g. `'tracks'`). The
/// selected sort option is stored as its enum index, paired with the ascending
/// flag.
class SortPreferences {
  const SortPreferences._();

  static String _optionKey(String key) => 'sort_${key}_option';
  static String _ascendingKey(String key) => 'sort_${key}_ascending';

  /// Loads the saved sort option index and ascending flag for [key].
  ///
  /// Returns `(index, ascending)`. When nothing is stored, [index] is `null`
  /// and [ascending] defaults to [defaultAscending].
  static Future<({int? index, bool ascending})> load(
    String key, {
    bool defaultAscending = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      index: prefs.getInt(_optionKey(key)),
      ascending: prefs.getBool(_ascendingKey(key)) ?? defaultAscending,
    );
  }

  /// Saves the current sort [optionIndex] and [ascending] flag for [key].
  static Future<void> save(
    String key, {
    required int optionIndex,
    required bool ascending,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_optionKey(key), optionIndex);
    await prefs.setBool(_ascendingKey(key), ascending);
  }
}

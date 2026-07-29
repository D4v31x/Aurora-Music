import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/supported_languages.dart';

/// Tracks which languages the user has already been notified about and
/// surfaces newly-added languages on subsequent app launches.
class NewLanguagesService {
  static const String _seenLanguagesKey = 'seen_language_codes';

  /// Returns language codes that are in [SupportedLanguages.all] but were
  /// not present the last time [markAllSeen] was called.
  /// Returns an empty list when no new languages have been added.
  static Future<List<SupportedLanguage>> getNewLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final seenRaw = prefs.getString(_seenLanguagesKey) ?? '';
    final seenCodes =
        seenRaw.isEmpty ? <String>{} : seenRaw.split(',').toSet();

    return SupportedLanguages.all
        .where((lang) => lang.code != 'en' && !seenCodes.contains(lang.code))
        .toList();
  }

  /// Records all currently registered languages so [getNewLanguages] returns
  /// an empty list on the next call.
  static Future<void> markAllSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final codes = SupportedLanguages.all.map((l) => l.code).join(',');
    await prefs.setString(_seenLanguagesKey, codes);
  }
}

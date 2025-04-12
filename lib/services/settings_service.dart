import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _crossfadeKey = 'crossfade_enabled';
  static const String _gaplessKey = 'gapless_enabled';
  static const String _languageKey = 'selected_language';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  bool get isCrossfadeEnabled => _prefs.getBool(_crossfadeKey) ?? false;
  bool get isGaplessEnabled => _prefs.getBool(_gaplessKey) ?? true;
  String get selectedLanguage => _prefs.getString(_languageKey) ?? 'en';

  Future<void> setCrossfade(bool value) async {
    await _prefs.setBool(_crossfadeKey, value);
  }

  Future<void> setGapless(bool value) async {
    await _prefs.setBool(_gaplessKey, value);
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(_languageKey, languageCode);
  }
} 
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _keyFirstTime = 'isFirstTime';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> isFirstTimeUser() async {
    final prefs = await _instance();
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  static Future<void> setFirstTimeUser(bool value) async {
    final prefs = await _instance();
    await prefs.setBool(_keyFirstTime, value);
  }
}

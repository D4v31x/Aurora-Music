import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _keyFirstTime = 'isFirstTime';

  static Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  static Future<void> setFirstTimeUser(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstTime, value);
  }
}
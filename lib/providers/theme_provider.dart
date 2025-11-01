import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _useDynamicColorKey = 'use_dynamic_color';

  bool _isDarkMode = true; // Dark mode is default
  bool _useDynamicColor = true;
  ColorScheme? _lightDynamicColorScheme;
  ColorScheme? _darkDynamicColorScheme;

  bool get isDarkMode => _isDarkMode;
  bool get useDynamicColor => _useDynamicColor;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ColorScheme? get lightDynamicColorScheme => _lightDynamicColorScheme;
  ColorScheme? get darkDynamicColorScheme => _darkDynamicColorScheme;

  // Gradient colors for light mode - Soft purple to blue
  List<Color> get lightGradientColors => const [
        Color(0xFFE8DEFF), // Soft lavender
        Color(0xFFD4E4FF), // Light sky blue
        Color(0xFFC4D7FF), // Periwinkle
        Color(0xFFDED4FF), // Pale purple
      ];

  // Gradient colors for dark mode - Deep purple to teal
  List<Color> get darkGradientColors => const [
        Color(0xFF1A0B2E), // Deep purple
        Color(0xFF2D1B4E), // Rich purple
        Color(0xFF16213E), // Dark blue
        Color(0xFF0F3460), // Deep teal blue
      ];

  // Get current gradient colors based on theme
  List<Color> get currentGradientColors =>
      _isDarkMode ? darkGradientColors : lightGradientColors;

  // Fallback color scheme when dynamic colors are not available
  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  );

  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );

  ThemeData get lightTheme {
    final colorScheme = _useDynamicColor && _lightDynamicColorScheme != null
        ? _lightDynamicColorScheme!
        : _defaultLightColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  ThemeData get darkTheme {
    final colorScheme = _useDynamicColor && _darkDynamicColorScheme != null
        ? _darkDynamicColorScheme!
        : _defaultDarkColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  ThemeProvider() {
    _loadThemePreference();
    _loadDynamicColors();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true; // Default to dark mode
    _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
    notifyListeners();
  }

  Future<void> _loadDynamicColors() async {
    // Dynamic colors will be loaded via DynamicColorBuilder in main.dart
    // This method is kept for manual refresh if needed
    notifyListeners();
  }

  void setDynamicColorSchemes(ColorScheme? light, ColorScheme? dark) {
    _lightDynamicColorScheme = light;
    _darkDynamicColorScheme = dark;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> toggleDynamicColor() async {
    _useDynamicColor = !_useDynamicColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorKey, _useDynamicColor);
    notifyListeners();
  }

  Future<void> refreshDynamicColors() async {
    await _loadDynamicColors();
  }
}

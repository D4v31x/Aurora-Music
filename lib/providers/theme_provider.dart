import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _useDynamicColorKey = 'use_dynamic_color';

  // App is dark mode only
  bool get isDarkMode => true;

  bool _useDynamicColor = true;
  ColorScheme? _darkDynamicColorScheme;

  bool get useDynamicColor => _useDynamicColor;
  ThemeMode get themeMode => ThemeMode.dark;

  ColorScheme? get darkDynamicColorScheme => _darkDynamicColorScheme;

  // Gradient colors for dark mode - Deep purple to teal
  List<Color> get darkGradientColors => const [
        Color(0xFF1A0B2E), // Deep purple
        Color(0xFF2D1B4E), // Rich purple
        Color(0xFF16213E), // Dark blue
        Color(0xFF0F3460), // Deep teal blue
      ];

  // Get current gradient colors (always dark)
  List<Color> get currentGradientColors => darkGradientColors;

  // Fallback color scheme when dynamic colors are not available
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  );

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
      // Glassmorphic popup menu theme
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.grey[900]?.withValues(alpha: 0.9),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        textStyle: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      // Glassmorphic dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 15,
        ),
      ),
      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.grey[900]?.withValues(alpha: 0.95),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        modalBarrierColor: Colors.black54,
      ),
    );
  }

  ThemeProvider() {
    _loadPreferences();
    _loadDynamicColors();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
    notifyListeners();
  }

  Future<void> _loadDynamicColors() async {
    // Dynamic colors will be loaded via DynamicColorBuilder in main.dart
    // This method is kept for manual refresh if needed
    notifyListeners();
  }

  void setDynamicColorSchemes(ColorScheme? light, ColorScheme? dark) {
    // Only store dark scheme since app is dark mode only
    _darkDynamicColorScheme = dark;
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

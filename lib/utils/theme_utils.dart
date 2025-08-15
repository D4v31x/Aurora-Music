import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Theme utilities for consistent styling throughout the app
class ThemeUtils {
  /// Primary color palette
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color primaryVariant = Color(0xFF5A52E8);
  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryVariant = Color(0xFFE85A5A);

  /// Background colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Text colors
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textSecondaryDark = Color(0xFFBDBDBD);

  /// Accent colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  /// Glass morphism colors
  static const Color glassMorphismLight = Color(0x1AFFFFFF);
  static const Color glassMorphismDark = Color(0x1A000000);

  /// Creates a light theme
  static ThemeData createLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondary,
        surface: surfaceLight,
        background: backgroundLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onBackground: textPrimaryLight,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'ProductSans',
        ),
        iconTheme: IconThemeData(color: textPrimaryLight),
      ),
      textTheme: _createTextTheme(textPrimaryLight, textSecondaryLight),
      // Using direct properties instead of CardTheme
      cardColor: surfaceLight,
      shadowColor: Colors.black26,
      cardTheme: null, // Explicitly set to null to avoid type issues
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: textSecondaryLight.withOpacity(0.3),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
      ),
    );
  }

  /// Creates a dark theme
  static ThemeData createDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondary,
        surface: surfaceDark,
        background: backgroundDark,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onBackground: textPrimaryDark,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'ProductSans',
        ),
        iconTheme: IconThemeData(color: textPrimaryDark),
      ),
      textTheme: _createTextTheme(textPrimaryDark, textSecondaryDark),
      // Using direct properties instead of CardTheme
      cardColor: surfaceDark,
      shadowColor: Colors.black54,
      cardTheme: null, // Explicitly set to null to avoid type issues
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: textSecondaryDark.withOpacity(0.3),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
      ),
    );
  }

  /// Creates a text theme with consistent styling
  static TextTheme _createTextTheme(Color primaryTextColor, Color secondaryTextColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
        fontFamily: 'ProductSans',
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondaryTextColor,
        fontFamily: 'Outfit',
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primaryTextColor,
        fontFamily: 'Outfit',
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        fontFamily: 'Outfit',
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        fontFamily: 'Outfit',
      ),
    );
  }

  /// Creates a MaterialColor from a single color
  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  /// Gets glassmorphism decoration
  static BoxDecoration getGlassmorphismDecoration({
    required bool isDark,
    double borderRadius = 12,
    double blurRadius = 10,
  }) {
    return BoxDecoration(
      color: isDark ? glassMorphismDark : glassMorphismLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark 
            ? Colors.white.withOpacity(0.1) 
            : Colors.black.withOpacity(0.1),
        width: 1,
      ),
    );
  }

  /// Gets card shadow
  static List<BoxShadow> getCardShadow({
    required bool isDark,
    double elevation = 4,
  }) {
    return [
      BoxShadow(
        color: isDark ? Colors.black54 : Colors.black26,
        blurRadius: elevation * 2,
        offset: Offset(0, elevation),
      ),
    ];
  }

  /// Gets text style for specific use cases
  static TextStyle getCustomTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    String? fontFamily,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? theme.textTheme.bodyMedium?.color,
      fontFamily: fontFamily ?? 'Outfit',
    );
  }

  /// Gets icon color based on theme
  static Color getIconColor(BuildContext context, {bool isActive = false}) {
    final theme = Theme.of(context);
    if (isActive) {
      return theme.primaryColor;
    }
    return theme.iconTheme.color ?? theme.textTheme.bodyMedium!.color!;
  }

  /// Gets appropriate text color for background
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Creates a gradient decoration
  static BoxDecoration createGradientDecoration({
    required List<Color> colors,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    double borderRadius = 0,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: begin,
        end: end,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}
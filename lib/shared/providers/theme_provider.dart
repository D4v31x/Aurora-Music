import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LowEndBackground { blobs, solid }
enum HighEndBackground { blurredArtwork, solid }

/// Fast, GPU-cheap page transition used app-wide for every
/// [MaterialPageRoute]. A short fade + subtle upward slide reads as snappy
/// while avoiding the default ZoomPageTransition's scrim/snapshot overhead,
/// keeping pushes and pops fluid even on low-end devices.
class _FastFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FastFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppThemePreset {
  const AppThemePreset({required this.name, required this.seedColor});
  final String name;
  final Color seedColor;

  static const List<AppThemePreset> presets = [
    AppThemePreset(name: 'Aurora', seedColor: Color(0xFF8B5CF6)),
    AppThemePreset(name: 'Midnight', seedColor: Color(0xFF304FFE)),
    AppThemePreset(name: 'Ocean', seedColor: Color(0xFF0091EA)),
    AppThemePreset(name: 'Teal', seedColor: Color(0xFF00B8D4)),
    AppThemePreset(name: 'Forest', seedColor: Color(0xFF00C853)),
    AppThemePreset(name: 'Neon', seedColor: Color(0xFF76FF03)),
    AppThemePreset(name: 'Gold', seedColor: Color(0xFFFFC107)),
    AppThemePreset(name: 'Ember', seedColor: Color(0xFFFF6D00)),
    AppThemePreset(name: 'Rose', seedColor: Color(0xFFD50000)),
    AppThemePreset(name: 'Sakura', seedColor: Color(0xFFFF4081)),
  ];
}

class ThemeProvider with ChangeNotifier {
  static const String _useDynamicColorKey = 'use_dynamic_color';
  static const String _customSeedColorKey = 'custom_seed_color';
  static const String _selectedPresetIndexKey = 'selected_preset_index';
  static const String _blurIntensityKey = 'blur_intensity';
  static const String _overlayOpacityKey = 'overlay_opacity';
  static const String _lowEndBackgroundKey = 'low_end_background';
  static const String _highEndBackgroundKey = 'high_end_background';

  // App is dark mode only
  bool get isDarkMode => true;

  bool _useDynamicColor = true;
  ColorScheme? _darkDynamicColorScheme;
  Color _customSeedColor = Colors.deepPurple;
  int _selectedPresetIndex = 0; // -1 = custom (no preset)
  double _blurIntensity = 25.0;
  double _overlayOpacity = 0.3;
  LowEndBackground _lowEndBackground = LowEndBackground.solid;
  HighEndBackground _highEndBackground = HighEndBackground.blurredArtwork;

  // Cached ThemeData — invalidated whenever theme-affecting properties change.
  ThemeData? _cachedDarkTheme;

  bool get useDynamicColor => _useDynamicColor;
  ThemeMode get themeMode => ThemeMode.dark;
  Color get customSeedColor => _customSeedColor;
  int get selectedPresetIndex => _selectedPresetIndex;
  double get blurIntensity => _blurIntensity;
  double get overlayOpacity => _overlayOpacity;
  LowEndBackground get lowEndBackground => _lowEndBackground;
  HighEndBackground get highEndBackground => _highEndBackground;

  ColorScheme? get darkDynamicColorScheme => _darkDynamicColorScheme;

  // Get current gradient colors derived from the active accent/Material You color
  List<Color> get currentGradientColors {
    final scheme = _useDynamicColor && _darkDynamicColorScheme != null
        ? _darkDynamicColorScheme!
        : _defaultDarkColorScheme;
    return [
      scheme.surfaceContainerLowest,
      scheme.primaryContainer,
      scheme.secondaryContainer,
    ];
  }

  // Fallback color scheme when dynamic colors are not available
  ColorScheme get _defaultDarkColorScheme => ColorScheme.fromSeed(
    seedColor: _customSeedColor,
    brightness: Brightness.dark,
  );

  ThemeData get darkTheme => _cachedDarkTheme ??= _buildDarkTheme();

  ThemeData _buildDarkTheme() {
    final colorScheme = _useDynamicColor && _darkDynamicColorScheme != null
        ? _darkDynamicColorScheme!
        : _defaultDarkColorScheme;


    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      fontFamily: FontConstants.fontFamily,
      scaffoldBackgroundColor: colorScheme.surface,
      // Fast, lightweight transitions for all MaterialPageRoutes.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FastFadePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          fontFamily: FontConstants.fontFamily,
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
    final savedColor = prefs.getInt(_customSeedColorKey);
    if (savedColor != null) {
      _customSeedColor = Color(savedColor);
    }
    _selectedPresetIndex = prefs.getInt(_selectedPresetIndexKey) ?? 0;
    _blurIntensity = (prefs.getDouble(_blurIntensityKey) ?? 25.0).clamp(5.0, 40.0);
    _overlayOpacity = prefs.getDouble(_overlayOpacityKey) ?? 0.3;
    final lowEndBgIndex = prefs.getInt(_lowEndBackgroundKey);
    if (lowEndBgIndex != null && lowEndBgIndex < LowEndBackground.values.length) {
      _lowEndBackground = LowEndBackground.values[lowEndBgIndex];
    }
    final highEndBgIndex = prefs.getInt(_highEndBackgroundKey);
    if (highEndBgIndex != null && highEndBgIndex < HighEndBackground.values.length) {
      _highEndBackground = HighEndBackground.values[highEndBgIndex];
    }
    _cachedDarkTheme = null;
    notifyListeners();
  }

  Future<void> _loadDynamicColors() async {
    // Dynamic colors will be loaded via DynamicColorBuilder in main.dart
    // This method is kept for manual refresh if needed.
    // Note: intentionally no notifyListeners() here — DynamicColorBuilder
    // will call setDynamicColorSchemes() which handles notification.
  }

  void setDynamicColorSchemes(ColorScheme? light, ColorScheme? dark) {
    // Only store dark scheme since app is dark mode only.
    // Guard: identical reference means same object from DynamicColorBuilder —
    // no actual change, so skip notifyListeners() to avoid a per-frame
    // rebuild loop (DynamicColorBuilder rebuilds → addPostFrameCallback →
    // setDynamicColorSchemes → notifyListeners → rebuild → …).
    if (identical(_darkDynamicColorScheme, dark)) return;
    _darkDynamicColorScheme = dark;
    _cachedDarkTheme = null;
    notifyListeners();
  }

  Future<void> toggleDynamicColor() async {
    _useDynamicColor = !_useDynamicColor;
    _cachedDarkTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorKey, _useDynamicColor);
    notifyListeners();
  }

  Future<void> setCustomSeedColor(Color color) async {
    _customSeedColor = color;
    _selectedPresetIndex = -1;
    _cachedDarkTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customSeedColorKey, color.toARGB32());
    await prefs.setInt(_selectedPresetIndexKey, -1);
    notifyListeners();
  }

  Future<void> setPreset(int index) async {
    assert(index >= 0 && index < AppThemePreset.presets.length);
    _selectedPresetIndex = index;
    _customSeedColor = AppThemePreset.presets[index].seedColor;
    _useDynamicColor = false;
    _cachedDarkTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedPresetIndexKey, index);
    await prefs.setInt(_customSeedColorKey, _customSeedColor.toARGB32());
    await prefs.setBool(_useDynamicColorKey, false);
    notifyListeners();
  }

  /// Updates blur intensity in memory immediately (no disk write).  
  /// Use in slider [onChanged] for real-time feedback; call [setBlurIntensity]
  /// in [onChangeEnd] to persist.
  void updateBlurIntensity(double value) {
    _blurIntensity = value.clamp(5.0, 40.0);
    notifyListeners();
  }

  Future<void> setBlurIntensity(double value) async {
    _blurIntensity = value.clamp(5.0, 40.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_blurIntensityKey, _blurIntensity);
    notifyListeners();
  }

  /// Updates overlay opacity in memory immediately (no disk write).
  /// Use in slider [onChanged] for real-time feedback; call [setOverlayOpacity]
  /// in [onChangeEnd] to persist.
  void updateOverlayOpacity(double value) {
    _overlayOpacity = value.clamp(0.0, 0.8);
    notifyListeners();
  }

  Future<void> setOverlayOpacity(double value) async {
    _overlayOpacity = value.clamp(0.0, 0.8);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_overlayOpacityKey, _overlayOpacity);
    notifyListeners();
  }

  Future<void> setLowEndBackground(LowEndBackground value) async {
    _lowEndBackground = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lowEndBackgroundKey, value.index);
    notifyListeners();
  }

  Future<void> setHighEndBackground(HighEndBackground value) async {
    _highEndBackground = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highEndBackgroundKey, value.index);
    notifyListeners();
  }

  Future<void> refreshDynamicColors() async {
    await _loadDynamicColors();
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing the different sections on the home tab
enum HomeSection {
  forYou,
  suggestedArtists,
  recentlyPlayed,
  mostPlayed,
  listeningHistory,
  recentlyAdded,
  libraryStats,
}

/// Extension to get display name and translation key for HomeSection
extension HomeSectionExtension on HomeSection {
  String get translationKey {
    switch (this) {
      case HomeSection.forYou:
        return 'for_you';
      case HomeSection.suggestedArtists:
        return 'suggested_artists';
      case HomeSection.recentlyPlayed:
        return 'recently_played';
      case HomeSection.mostPlayed:
        return 'most_played';
      case HomeSection.listeningHistory:
        return 'listening_history';
      case HomeSection.recentlyAdded:
        return 'recently_added';
      case HomeSection.libraryStats:
        return 'library_stats';
    }
  }

  String get id => name;
}

/// Service for managing the order and visibility of home tab sections
class HomeLayoutService extends ChangeNotifier {
  static const String _orderKey = 'home_section_order';
  static const String _visibilityKey = 'home_section_visibility';

  static final HomeLayoutService _instance = HomeLayoutService._internal();
  factory HomeLayoutService() => _instance;
  HomeLayoutService._internal();

  List<HomeSection> _sectionOrder = HomeSection.values.toList();
  Map<HomeSection, bool> _sectionVisibility = {
    for (var section in HomeSection.values) section: true
  };

  bool _isInitialized = false;

  /// Default section order
  static List<HomeSection> get defaultOrder => HomeSection.values.toList();

  /// Get the current section order
  List<HomeSection> get sectionOrder => List.unmodifiable(_sectionOrder);

  /// Get visibility of a section
  bool isSectionVisible(HomeSection section) =>
      _sectionVisibility[section] ?? true;

  /// Get visible sections in order
  List<HomeSection> get visibleSections =>
      _sectionOrder.where((s) => isSectionVisible(s)).toList();

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load section order
    final orderString = prefs.getString(_orderKey);
    if (orderString != null && orderString.isNotEmpty) {
      final orderList = orderString.split(',');
      final loadedOrder = <HomeSection>[];
      for (final id in orderList) {
        try {
          final section = HomeSection.values.firstWhere((s) => s.id == id);
          loadedOrder.add(section);
        } catch (_) {
          // Section not found, skip
        }
      }
      // Add any missing sections at the end
      for (final section in HomeSection.values) {
        if (!loadedOrder.contains(section)) {
          loadedOrder.add(section);
        }
      }
      _sectionOrder = loadedOrder;
    }

    // Load visibility
    final visibilityString = prefs.getString(_visibilityKey);
    if (visibilityString != null && visibilityString.isNotEmpty) {
      final visibilityParts = visibilityString.split(',');
      for (final part in visibilityParts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          try {
            final section = HomeSection.values.firstWhere((s) => s.id == kv[0]);
            _sectionVisibility[section] = kv[1] == '1';
          } catch (_) {
            // Section not found, skip
          }
        }
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Save the current settings
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // Save order
    final orderString = _sectionOrder.map((s) => s.id).join(',');
    await prefs.setString(_orderKey, orderString);

    // Save visibility
    final visibilityString = _sectionVisibility.entries
        .map((e) => '${e.key.id}:${e.value ? '1' : '0'}')
        .join(',');
    await prefs.setString(_visibilityKey, visibilityString);
  }

  /// Reorder sections
  void reorderSections(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final section = _sectionOrder.removeAt(oldIndex);
    _sectionOrder.insert(newIndex, section);
    _save();
    notifyListeners();
  }

  /// Toggle section visibility
  void toggleSectionVisibility(HomeSection section) {
    _sectionVisibility[section] = !(_sectionVisibility[section] ?? true);
    _save();
    notifyListeners();
  }

  /// Set section visibility
  void setSectionVisibility(HomeSection section, bool visible) {
    _sectionVisibility[section] = visible;
    _save();
    notifyListeners();
  }

  /// Reset to default order and visibility
  Future<void> resetToDefault() async {
    _sectionOrder = HomeSection.values.toList();
    _sectionVisibility = {
      for (final section in HomeSection.values) section: true
    };
    await _save();
    notifyListeners();
  }

  /// Check if current layout differs from default
  bool get isCustomLayout {
    if (!listEquals(_sectionOrder, defaultOrder)) {
      return true;
    }
    for (final section in HomeSection.values) {
      if (!isSectionVisible(section)) {
        return true;
      }
    }
    return false;
  }
}

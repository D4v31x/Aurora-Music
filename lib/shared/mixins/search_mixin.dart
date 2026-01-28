import 'dart:async';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';

/// A mixin that provides common search functionality with debouncing.
///
/// This mixin handles:
/// - Debounced search queries
/// - Search state management
/// - Search text controller
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SearchMixin {
///   @override
///   void onSearchQuery(String query) {
///     setState(() {
///       _filteredItems = _allItems.where((item) =>
///         item.title.toLowerCase().contains(query.toLowerCase())
///       ).toList();
///     });
///   }
/// }
/// ```
mixin SearchMixin<T extends StatefulWidget> on State<T> {
  /// The text controller for the search field.
  late TextEditingController searchController;

  /// The current search query.
  String searchQuery = '';

  /// Debounce timer for search.
  Timer? _searchDebounce;

  /// The debounce duration in milliseconds.
  int get debounceMilliseconds => 300;

  /// Called when a search query is submitted. Must be implemented.
  void onSearchQuery(String query);

  /// Initialize search. Call this in initState().
  void initSearch() {
    searchController = TextEditingController();
  }

  /// Dispose search. Call this in dispose().
  void disposeSearch() {
    searchController.dispose();
    _searchDebounce?.cancel();
  }

  /// Handle search text changes with debouncing.
  void onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(Duration(milliseconds: debounceMilliseconds), () {
      searchQuery = query.toLowerCase().trim();
      onSearchQuery(searchQuery);
    });
  }

  /// Clear the search query.
  void clearSearch() {
    searchController.clear();
    searchQuery = '';
    onSearchQuery('');
  }

  /// Build a standard search text field.
  Widget buildSearchField({
    String? hintText,
    Color? backgroundColor,
    Color? textColor,
    Color? hintColor,
    double height = 50,
    double borderRadius = 25,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black),
          fontFamily: FontConstants.fontFamily,
        ),
        decoration: InputDecoration(
          hintText: hintText ?? 'Search...',
          hintStyle: TextStyle(
            color: hintColor ?? Colors.white.withOpacity(0.5),
            fontFamily: FontConstants.fontFamily,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: hintColor ?? Colors.white.withOpacity(0.5),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: hintColor ?? Colors.white.withOpacity(0.5),
                  ),
                  onPressed: clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

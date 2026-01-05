import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// A mixin that provides common lazy loading functionality for song lists.
/// 
/// This mixin handles:
/// - Pagination with configurable page size
/// - Scroll-based loading
/// - Loading state management
/// 
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LazyLoadingMixin {
///   @override
///   int get songsPerPage => 20;
///   
///   @override
///   List<SongModel> get allSongs => _allSongs;
///   
///   @override
///   void onSongsLoaded(List<SongModel> newSongs) {
///     setState(() => _displayedSongs.addAll(newSongs));
///   }
/// }
/// ```
mixin LazyLoadingMixin<T extends StatefulWidget> on State<T> {
  /// The scroll controller for detecting when to load more items
  late ScrollController lazyLoadingScrollController;
  
  /// Current page for pagination
  int currentPage = 0;
  
  /// Whether we're currently loading more items
  bool isLoadingMore = false;
  
  /// Whether there are more items to load
  bool hasMoreItems = true;
  
  /// The number of songs to load per page. Override to customize.
  int get songsPerPage => 20;
  
  /// The list of all songs available for loading. Must be implemented.
  List<SongModel> get allSongs;
  
  /// Called when new songs are loaded. Must be implemented.
  void onSongsLoaded(List<SongModel> newSongs);
  
  /// The threshold in pixels before the end of the list to trigger loading.
  double get loadingThreshold => 200;

  /// Initialize lazy loading. Call this in initState().
  void initLazyLoading() {
    lazyLoadingScrollController = ScrollController()
      ..addListener(_onScroll);
  }
  
  /// Dispose lazy loading. Call this in dispose().
  void disposeLazyLoading() {
    lazyLoadingScrollController.removeListener(_onScroll);
    lazyLoadingScrollController.dispose();
  }
  
  void _onScroll() {
    if (lazyLoadingScrollController.position.extentAfter < loadingThreshold &&
        !isLoadingMore &&
        hasMoreItems) {
      loadMoreSongs();
    }
  }
  
  /// Reset pagination to initial state. Call when refreshing data.
  void resetPagination() {
    currentPage = 0;
    hasMoreItems = true;
    isLoadingMore = false;
  }
  
  /// Load the next page of songs.
  void loadMoreSongs() {
    if (isLoadingMore) return;
    
    setState(() {
      isLoadingMore = true;
    });
    
    final int startIndex = currentPage * songsPerPage;
    final int endIndex = (startIndex + songsPerPage).clamp(0, allSongs.length);
    
    if (startIndex < allSongs.length) {
      final newSongs = allSongs.sublist(startIndex, endIndex);
      
      onSongsLoaded(newSongs);
      
      setState(() {
        currentPage++;
        isLoadingMore = false;
        hasMoreItems = endIndex < allSongs.length;
      });
    } else {
      setState(() {
        isLoadingMore = false;
        hasMoreItems = false;
      });
    }
  }
  
  /// Build a loading indicator widget for the bottom of lists.
  Widget buildLoadingIndicator() {
    if (!isLoadingMore) return const SizedBox.shrink();
    
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white54,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

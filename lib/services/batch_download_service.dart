import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'lyrics_service.dart';
import 'artwork_cache_service.dart';

enum DownloadAction { lyrics, artwork }

class DownloadItem {
  final String id;
  final String title;
  final List<DownloadAction> actions;
  bool isCompleted;
  bool hasFailed;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.title,
    required this.actions,
    this.isCompleted = false,
    this.hasFailed = false,
    this.errorMessage,
  });
}

class DownloadProgress {
  final int total;
  final int completed;
  final int failed;
  final int inProgress;
  final bool isDownloading;
  final DownloadItem? currentItem;
  final String? currentStatus;

  DownloadProgress({
    required this.total,
    required this.completed,
    required this.failed,
    required this.inProgress,
    required this.isDownloading,
    this.currentItem,
    this.currentStatus,
  });

  double get percentage => total > 0 ? ((completed + failed) / total) : 0.0;
  bool get isComplete => !isDownloading && (completed + failed >= total);
}

class BatchDownloadService {
  static final BatchDownloadService _instance =
      BatchDownloadService._internal();
  factory BatchDownloadService() => _instance;
  BatchDownloadService._internal();

  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  final TimedLyricsService _lyricsService = TimedLyricsService();
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  final List<DownloadItem> _downloadQueue = [];
  int _completedCount = 0;
  int _failedCount = 0;
  int _inProgressCount = 0;

  Future<void> startBatchDownload({
    required bool downloadLyrics,
    required bool downloadArtwork,
  }) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadQueue.clear();
    _completedCount = 0;
    _failedCount = 0;
    _inProgressCount = 0;

    // Don't emit progress until we have the full queue
    // _emitProgress('Initializing...');

    try {
      // Check permissions first
      final hasPermission = await _audioQuery.permissionsStatus();

      if (!hasPermission) {
        debugPrint('Missing audio library permissions');
        _isDownloading = false;
        _emitProgress('Skipped - permissions required');
        return;
      }

      // Get all songs from library
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      if (songs.isEmpty) {
        _isDownloading = false;
        _emitProgress('No songs found in library');
        return;
      }

      // Build download queue
      for (final song in songs) {
        final actions = <DownloadAction>[];
        if (downloadLyrics) {
          actions.add(DownloadAction.lyrics);
        }
        if (downloadArtwork) {
          actions.add(DownloadAction.artwork);
        }

        if (actions.isNotEmpty) {
          _downloadQueue.add(DownloadItem(
            id: song.id.toString(),
            title: song.title,
            actions: actions,
          ));
        }
      }

      // Now that we have the queue, we can start emitting progress
      debugPrint('=== BATCH DOWNLOAD STARTING ===');
      debugPrint('Total songs in library: ${songs.length}');
      debugPrint('Total download items in queue: ${_downloadQueue.length}');
      debugPrint(
          'Download lyrics: $downloadLyrics, Download artwork: $downloadArtwork');
      _emitProgress('Starting download...');

      // Process queue with controlled concurrency
      if (_downloadQueue.isNotEmpty) {
        await _processQueue(songs);
      }

      // Don't emit here - let the finally block handle it
    } catch (e) {
      debugPrint('Error in batch download: $e');
      _emitProgress('Download failed: $e');
    } finally {
      _isDownloading = false;
      // Emit final "complete" status
      if (!_progressController.isClosed) {
        _emitProgress('Download complete!');
      }
    }
  }

  Future<void> _processQueue(List<SongModel> songs) async {
    const int maxConcurrent = 10; // Process 10 items at a time
    final List<Future<void>> activeTasks = [];

    for (int i = 0; i < _downloadQueue.length; i++) {
      final item = _downloadQueue[i];

      // Find the corresponding song
      final song = songs.firstWhere(
        (s) => s.id.toString() == item.id,
        orElse: () => songs.first,
      );

      // Increment in-progress BEFORE starting the task
      _inProgressCount++;

      // Add task to active tasks
      final task = _downloadItem(item, song);
      activeTasks.add(task);

      // If we hit max concurrent or end of queue, wait for completion
      if (activeTasks.length >= maxConcurrent ||
          i == _downloadQueue.length - 1) {
        await Future.wait(activeTasks);
        activeTasks.clear();
      }
    }
  }

  Future<void> _downloadItem(DownloadItem item, SongModel song) async {
    bool allSucceeded = true;

    try {
      _emitProgress('Downloading...', currentItem: item);

      if (item.actions.contains(DownloadAction.lyrics)) {
        final success = await _downloadLyrics(song);
        if (!success) {
          allSucceeded = false;
        }
      }
      if (item.actions.contains(DownloadAction.artwork)) {
        // Assuming this can't fail in a way we need to track for this issue
        await _downloadArtwork(song);
      }

      if (allSucceeded) {
        item.isCompleted = true;
        _completedCount++;
        debugPrint(
            'Completed: ${item.title} ($_completedCount/${_downloadQueue.length})');
      } else {
        item.hasFailed = true;
        item.errorMessage = 'Lyrics not found';
        _failedCount++;
        debugPrint('Failed: ${item.title} ($_failedCount failed)');
      }
    } catch (e) {
      item.hasFailed = true;
      item.errorMessage = e.toString();
      _failedCount++;
      debugPrint('Failed to download ${item.title}: $e');
    } finally {
      _inProgressCount--;
      _emitProgress('Processing...');
    }
  }

  Future<bool> _downloadLyrics(SongModel song) async {
    final artist = song.artist ?? 'Unknown';
    final title = song.title;

    // Check if already cached
    final cached = await _lyricsService.loadLyricsFromFile(artist, title);
    if (cached != null && cached.isNotEmpty) {
      // Already cached, skip
      return true;
    }

    // Download and cache
    try {
      await _lyricsService.fetchTimedLyrics(
        artist,
        title,
        songDuration: Duration(milliseconds: song.duration ?? 0),
      );
      // After attempting to fetch, check if lyrics are now available.
      final newLyrics = await _lyricsService.loadLyricsFromFile(artist, title);
      if (newLyrics != null && newLyrics.isNotEmpty) {
        return true;
      }
      debugPrint('Lyrics not available for $title by $artist');
      return false;
    } catch (e) {
      // Lyrics might not be available, that's okay
      debugPrint('Lyrics not available for $title by $artist');
      return false;
    }
  }

  Future<void> _downloadArtwork(SongModel song) async {
    // The artwork cache service will handle caching automatically
    try {
      await _artworkService.getCachedImageProvider(song.id);
    } catch (e) {
      debugPrint('Failed to cache artwork for ${song.title}');
    }
  }

  void _emitProgress(String status, {DownloadItem? currentItem}) {
    if (!_progressController.isClosed) {
      final isComplete = !_isDownloading &&
          (_completedCount + _failedCount >= _downloadQueue.length);
      debugPrint(
          'Progress: completed=$_completedCount, failed=$_failedCount, inProgress=$_inProgressCount, total=${_downloadQueue.length}, isDownloading=$_isDownloading, isComplete=$isComplete');
      _progressController.add(DownloadProgress(
        total: _downloadQueue.length,
        completed: _completedCount,
        failed: _failedCount,
        inProgress: _inProgressCount,
        isDownloading: _isDownloading,
        currentItem: currentItem,
        currentStatus: status,
      ));
    }
  }

  void dispose() {
    _progressController.close();
  }

  // Get statistics about what's already cached
  Future<Map<String, int>> getCacheStatistics() async {
    try {
      final songs = await _audioQuery.querySongs();
      int cachedLyrics = 0;
      int cachedArtwork = 0;

      for (final song in songs.take(100)) {
        // Sample first 100 songs
        final artist = song.artist ?? 'Unknown';
        final title = song.title;

        // Check lyrics cache
        final lyrics = await _lyricsService.loadLyricsFromFile(artist, title);
        if (lyrics != null && lyrics.isNotEmpty) {
          cachedLyrics++;
        }

        // Note: Artwork is cached on-demand, hard to check without loading
      }

      return {
        'totalSongs': songs.length,
        'cachedLyrics': cachedLyrics,
        'cachedArtwork': cachedArtwork,
      };
    } catch (e) {
      return {'totalSongs': 0, 'cachedLyrics': 0, 'cachedArtwork': 0};
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/utils.dart';
import '../utils/performance_optimizations.dart';

/// Smart suggestion service that analyzes user listening patterns
/// to provide personalized track and artist recommendations
/// 
/// Performance optimizations:
/// - Memoized suggestions to avoid recomputation
/// - Cached score calculations
/// - Debounced data saving
class SmartSuggestionsService {
  static final SmartSuggestionsService _instance =
      SmartSuggestionsService._internal();
  factory SmartSuggestionsService() => _instance;
  SmartSuggestionsService._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Listening history with timestamps
  List<ListeningEvent> _listeningHistory = [];

  // Play counts by time of day (0-23 hours)
  Map<int, Map<String, int>> _hourlyTrackCounts = {};
  Map<int, Map<String, int>> _hourlyArtistCounts = {};
  Map<int, Map<String, int>> _hourlyGenreCounts = {};

  // Day of week patterns (0=Monday, 6=Sunday)
  Map<int, Map<String, int>> _weekdayTrackCounts = {};
  Map<int, Map<String, int>> _weekdayArtistCounts = {};

  // Overall play counts
  Map<String, int> _trackPlayCounts = {};
  Map<String, int> _artistPlayCounts = {};
  Map<String, int> _genrePlayCounts = {};

  // Skip patterns (tracks user tends to skip)
  Map<String, int> _trackSkipCounts = {};

  // Recently played tracking
  List<String> _recentlyPlayedTrackIds = [];
  List<String> _recentlyPlayedArtists = [];

  bool _isLoaded = false;

  // Performance optimizations
  final Memoizer<List<SongModel>> _suggestionsMemoizer = Memoizer<List<SongModel>>();
  final Memoizer<List<String>> _artistsMemoizer = Memoizer<List<String>>();
  final Debouncer _saveDebouncer = Debouncer(delay: const Duration(seconds: 5));
  DateTime? _lastSuggestionTime;
  
  // Cache suggestion results for 5 minutes
  static const _suggestionCacheDuration = Duration(minutes: 5);

  /// Initialize and load saved data
  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadData();
    _isLoaded = true;
  }

  /// Record a listening event
  Future<void> recordPlay(SongModel song,
      {bool wasSkipped = false, int listenDurationMs = 0}) async {
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday - 1; // Convert to 0-indexed
    final trackId = song.id.toString();
    final artists = splitArtists(song.artist ?? 'Unknown');
    final genre = song.genre ?? 'Unknown';

    // Record the event
    _listeningHistory.add(ListeningEvent(
      trackId: trackId,
      artists: artists,
      genre: genre,
      timestamp: now,
      wasSkipped: wasSkipped,
      listenDurationMs: listenDurationMs,
      totalDurationMs: song.duration ?? 0,
    ));

    // Keep only last 1000 events
    if (_listeningHistory.length > 1000) {
      _listeningHistory =
          _listeningHistory.sublist(_listeningHistory.length - 1000);
    }

    if (wasSkipped) {
      _trackSkipCounts[trackId] = (_trackSkipCounts[trackId] ?? 0) + 1;
    } else {
      // Update overall counts
      _trackPlayCounts[trackId] = (_trackPlayCounts[trackId] ?? 0) + 1;
      for (var artist in artists) {
        _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
      }
      _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;

      // Update hourly patterns
      _hourlyTrackCounts[hour] ??= {};
      _hourlyTrackCounts[hour]![trackId] =
          (_hourlyTrackCounts[hour]![trackId] ?? 0) + 1;

      _hourlyArtistCounts[hour] ??= {};
      for (var artist in artists) {
        _hourlyArtistCounts[hour]![artist] =
            (_hourlyArtistCounts[hour]![artist] ?? 0) + 1;
      }

      _hourlyGenreCounts[hour] ??= {};
      _hourlyGenreCounts[hour]![genre] =
          (_hourlyGenreCounts[hour]![genre] ?? 0) + 1;

      // Update weekday patterns
      _weekdayTrackCounts[weekday] ??= {};
      _weekdayTrackCounts[weekday]![trackId] =
          (_weekdayTrackCounts[weekday]![trackId] ?? 0) + 1;

      _weekdayArtistCounts[weekday] ??= {};
      for (var artist in artists) {
        _weekdayArtistCounts[weekday]![artist] =
            (_weekdayArtistCounts[weekday]![artist] ?? 0) + 1;
      }

      // Track recently played
      _recentlyPlayedTrackIds.remove(trackId);
      _recentlyPlayedTrackIds.insert(0, trackId);
      if (_recentlyPlayedTrackIds.length > 50) {
        _recentlyPlayedTrackIds = _recentlyPlayedTrackIds.sublist(0, 50);
      }

      for (var artist in artists) {
        _recentlyPlayedArtists.remove(artist);
        _recentlyPlayedArtists.insert(0, artist);
      }
      if (_recentlyPlayedArtists.length > 30) {
        _recentlyPlayedArtists = _recentlyPlayedArtists.sublist(0, 30);
      }
    }

    // Save periodically (debounced to reduce disk I/O)
    _saveDebouncer.call(() => _saveData());
  }

  /// Get suggested tracks based on current time and listening patterns
  Future<List<SongModel>> getSuggestedTracks({int count = 3}) async {
    final now = DateTime.now();
    final cacheKey = '${now.hour}_${now.weekday}_$count';
    
    // Check if we can use cached suggestions
    if (_lastSuggestionTime != null) {
      final timeSinceLastSuggestion = now.difference(_lastSuggestionTime!);
      if (timeSinceLastSuggestion < _suggestionCacheDuration) {
        return _suggestionsMemoizer.call(cacheKey, () => _computeSuggestedTracks(count));
      }
    }
    
    // Clear cache and recompute
    _suggestionsMemoizer.clear();
    _lastSuggestionTime = now;
    return _suggestionsMemoizer.call(cacheKey, () => _computeSuggestedTracks(count));
  }

  /// Internal method to compute suggestions (expensive operation)
  Future<List<SongModel>> _computeSuggestedTracks(int count) async {
    final allSongs = await _audioQuery.querySongs();
    if (allSongs.isEmpty) return [];

    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday - 1;

    // Calculate scores for each track
    final scores = <String, double>{};

    for (var song in allSongs) {
      final trackId = song.id.toString();
      double score = 0;

      // 1. Time-of-day relevance (weight: 3x)
      final hourlyData = _hourlyTrackCounts[hour];
      if (hourlyData != null && hourlyData.containsKey(trackId)) {
        score += (hourlyData[trackId]! * 3);
      }

      // Check adjacent hours too (weight: 1.5x)
      for (var adj in [(hour - 1) % 24, (hour + 1) % 24]) {
        final adjData = _hourlyTrackCounts[adj];
        if (adjData != null && adjData.containsKey(trackId)) {
          score += (adjData[trackId]! * 1.5);
        }
      }

      // 2. Day-of-week relevance (weight: 2x)
      final weekdayData = _weekdayTrackCounts[weekday];
      if (weekdayData != null && weekdayData.containsKey(trackId)) {
        score += (weekdayData[trackId]! * 2);
      }

      // 3. Overall play count (weight: 1x, but diminishing returns)
      final playCount = _trackPlayCounts[trackId] ?? 0;
      score += sqrt(playCount.toDouble());

      // 4. Genre matching current time preference (weight: 2x)
      final genre = song.genre ?? 'Unknown';
      final hourlyGenres = _hourlyGenreCounts[hour];
      if (hourlyGenres != null && hourlyGenres.containsKey(genre)) {
        score += (hourlyGenres[genre]! * 0.5);
      }

      // 5. Artist preference at this time (weight: 2x)
      final artists = splitArtists(song.artist ?? '');
      final hourlyArtists = _hourlyArtistCounts[hour];
      if (hourlyArtists != null) {
        for (var artist in artists) {
          if (hourlyArtists.containsKey(artist)) {
            score += (hourlyArtists[artist]! * 2);
          }
        }
      }

      // 6. Penalty for recently played (avoid repetition)
      final recentIndex = _recentlyPlayedTrackIds.indexOf(trackId);
      if (recentIndex >= 0 && recentIndex < 10) {
        score *= (0.3 +
            (recentIndex * 0.07)); // 30-100% of score based on how recent
      }

      // 7. Penalty for frequently skipped tracks
      final skipCount = _trackSkipCounts[trackId] ?? 0;
      if (skipCount > 0) {
        score *= max(0.2, 1.0 - (skipCount * 0.1));
      }

      // 8. Small random factor for variety (5%)
      score *= (0.95 + Random().nextDouble() * 0.1);

      scores[trackId] = score;
    }

    // If no listening history, use weighted random based on song metadata
    if (_listeningHistory.isEmpty) {
      return _getFallbackSuggestions(allSongs, count);
    }

    // Sort by score and get top tracks
    final sortedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final suggestedIds = sortedIds.take(count * 2).map((e) => e.key).toList();

    // Shuffle top results slightly for variety
    suggestedIds.shuffle();

    final result = <SongModel>[];
    for (var id in suggestedIds.take(count)) {
      final song = allSongs.firstWhere(
        (s) => s.id.toString() == id,
        orElse: () => allSongs.first,
      );
      result.add(song);
    }

    return result;
  }

  /// Get suggested artists based on current time and listening patterns
  Future<List<String>> getSuggestedArtists({int count = 3}) async {
    final allSongs = await _audioQuery.querySongs();
    if (allSongs.isEmpty) return [];

    // Get all unique artists
    final allArtists = <String>{};
    for (var song in allSongs) {
      allArtists.addAll(splitArtists(song.artist ?? ''));
    }

    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday - 1;

    // Calculate scores for each artist
    final scores = <String, double>{};

    for (var artist in allArtists) {
      if (artist.isEmpty || artist.toLowerCase() == 'unknown') continue;

      double score = 0;

      // 1. Time-of-day relevance (weight: 3x)
      final hourlyData = _hourlyArtistCounts[hour];
      if (hourlyData != null && hourlyData.containsKey(artist)) {
        score += (hourlyData[artist]! * 3);
      }

      // Check adjacent hours (weight: 1.5x)
      for (var adj in [(hour - 1) % 24, (hour + 1) % 24]) {
        final adjData = _hourlyArtistCounts[adj];
        if (adjData != null && adjData.containsKey(artist)) {
          score += (adjData[artist]! * 1.5);
        }
      }

      // 2. Day-of-week relevance (weight: 2x)
      final weekdayData = _weekdayArtistCounts[weekday];
      if (weekdayData != null && weekdayData.containsKey(artist)) {
        score += (weekdayData[artist]! * 2);
      }

      // 3. Overall play count (weight: 1x with diminishing returns)
      final playCount = _artistPlayCounts[artist] ?? 0;
      score += sqrt(playCount.toDouble());

      // 4. Penalty for very recently played artists
      final recentIndex = _recentlyPlayedArtists.indexOf(artist);
      if (recentIndex >= 0 && recentIndex < 5) {
        score *= (0.5 + (recentIndex * 0.1));
      }

      // 5. Small random factor for variety
      score *= (0.95 + Random().nextDouble() * 0.1);

      scores[artist] = score;
    }

    // If no listening history, return popular artists
    if (_listeningHistory.isEmpty) {
      final shuffled = allArtists.toList()..shuffle();
      return shuffled.take(count).toList();
    }

    // Sort by score and get top artists
    final sortedArtists = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take more than needed and shuffle for variety
    final topArtists = sortedArtists.take(count * 2).map((e) => e.key).toList();
    topArtists.shuffle();

    return topArtists.take(count).toList();
  }

  /// Fallback suggestions when no listening history exists
  List<SongModel> _getFallbackSuggestions(List<SongModel> allSongs, int count) {
    // Prefer songs with complete metadata
    final scored = allSongs.map((song) {
      double score = Random().nextDouble();
      if (song.artist != null && song.artist!.isNotEmpty) score += 0.3;
      if (song.album != null && song.album!.isNotEmpty) score += 0.2;
      if (song.genre != null && song.genre!.isNotEmpty) score += 0.1;
      return MapEntry(song, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(count).map((e) => e.key).toList();
  }

  /// Get time-based greeting and context
  String getTimeContext() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  /// Check if user has enough history for smart suggestions
  bool hasListeningHistory() => _listeningHistory.length >= 10;

  /// Save data to disk
  Future<void> _saveData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/smart_suggestions.json');

      final data = {
        'listeningHistory': _listeningHistory.map((e) => e.toJson()).toList(),
        'hourlyTrackCounts':
            _hourlyTrackCounts.map((k, v) => MapEntry(k.toString(), v)),
        'hourlyArtistCounts':
            _hourlyArtistCounts.map((k, v) => MapEntry(k.toString(), v)),
        'hourlyGenreCounts':
            _hourlyGenreCounts.map((k, v) => MapEntry(k.toString(), v)),
        'weekdayTrackCounts':
            _weekdayTrackCounts.map((k, v) => MapEntry(k.toString(), v)),
        'weekdayArtistCounts':
            _weekdayArtistCounts.map((k, v) => MapEntry(k.toString(), v)),
        'trackPlayCounts': _trackPlayCounts,
        'artistPlayCounts': _artistPlayCounts,
        'genrePlayCounts': _genrePlayCounts,
        'trackSkipCounts': _trackSkipCounts,
        'recentlyPlayedTrackIds': _recentlyPlayedTrackIds,
        'recentlyPlayedArtists': _recentlyPlayedArtists,
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving smart suggestions data: $e');
    }
  }

  /// Load data from disk
  Future<void> _loadData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/smart_suggestions.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;

        _listeningHistory = (data['listeningHistory'] as List?)
                ?.map((e) => ListeningEvent.fromJson(e))
                .toList() ??
            [];

        _hourlyTrackCounts =
            (data['hourlyTrackCounts'] as Map<String, dynamic>?)?.map((k, v) =>
                    MapEntry(int.parse(k), Map<String, int>.from(v))) ??
                {};

        _hourlyArtistCounts =
            (data['hourlyArtistCounts'] as Map<String, dynamic>?)?.map((k, v) =>
                    MapEntry(int.parse(k), Map<String, int>.from(v))) ??
                {};

        _hourlyGenreCounts =
            (data['hourlyGenreCounts'] as Map<String, dynamic>?)?.map((k, v) =>
                    MapEntry(int.parse(k), Map<String, int>.from(v))) ??
                {};

        _weekdayTrackCounts =
            (data['weekdayTrackCounts'] as Map<String, dynamic>?)?.map((k, v) =>
                    MapEntry(int.parse(k), Map<String, int>.from(v))) ??
                {};

        _weekdayArtistCounts =
            (data['weekdayArtistCounts'] as Map<String, dynamic>?)?.map(
                    (k, v) =>
                        MapEntry(int.parse(k), Map<String, int>.from(v))) ??
                {};

        _trackPlayCounts = Map<String, int>.from(data['trackPlayCounts'] ?? {});
        _artistPlayCounts =
            Map<String, int>.from(data['artistPlayCounts'] ?? {});
        _genrePlayCounts = Map<String, int>.from(data['genrePlayCounts'] ?? {});
        _trackSkipCounts = Map<String, int>.from(data['trackSkipCounts'] ?? {});
        _recentlyPlayedTrackIds =
            List<String>.from(data['recentlyPlayedTrackIds'] ?? []);
        _recentlyPlayedArtists =
            List<String>.from(data['recentlyPlayedArtists'] ?? []);
      }
    } catch (e) {
      debugPrint('Error loading smart suggestions data: $e');
    }
  }
}

/// Represents a single listening event
class ListeningEvent {
  final String trackId;
  final List<String> artists;
  final String genre;
  final DateTime timestamp;
  final bool wasSkipped;
  final int listenDurationMs;
  final int totalDurationMs;

  ListeningEvent({
    required this.trackId,
    required this.artists,
    required this.genre,
    required this.timestamp,
    this.wasSkipped = false,
    this.listenDurationMs = 0,
    this.totalDurationMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'artists': artists,
        'genre': genre,
        'timestamp': timestamp.toIso8601String(),
        'wasSkipped': wasSkipped,
        'listenDurationMs': listenDurationMs,
        'totalDurationMs': totalDurationMs,
      };

  factory ListeningEvent.fromJson(Map<String, dynamic> json) => ListeningEvent(
        trackId: json['trackId'],
        artists: List<String>.from(json['artists']),
        genre: json['genre'],
        timestamp: DateTime.parse(json['timestamp']),
        wasSkipped: json['wasSkipped'] ?? false,
        listenDurationMs: json['listenDurationMs'] ?? 0,
        totalDurationMs: json['totalDurationMs'] ?? 0,
      );
}

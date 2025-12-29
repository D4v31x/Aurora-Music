import 'package:on_audio_query/on_audio_query.dart';
import '../models/utils.dart';
import '../models/separated_artist.dart';

/// Improved search service with fuzzy matching and scoring
class MusicSearchService {
  /// Calculate Levenshtein distance for fuzzy matching
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    List<List<int>> d =
        List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  /// Calculate search score for a song (higher is better)
  static double _calculateScore(SongModel song, String query) {
    final title = song.title.toLowerCase();
    final rawArtist = (song.artist ?? '').toLowerCase();
    final album = (song.album ?? '').toLowerCase();
    final queryLower = query.toLowerCase();

    // Split artists for better matching
    final artists =
        splitArtists(song.artist ?? '').map((a) => a.toLowerCase()).toList();
    final artist = artists.join(' '); // Combined for contains checks

    double score = 0.0;

    // Exact match bonus
    if (title == queryLower) score += 100;
    if (rawArtist == queryLower) score += 80;
    if (album == queryLower) score += 60;

    // Check if query matches any individual artist exactly
    for (final a in artists) {
      if (a == queryLower) score += 85;
    }

    // Starts with bonus
    if (title.startsWith(queryLower)) score += 50;
    if (rawArtist.startsWith(queryLower)) score += 40;
    if (album.startsWith(queryLower)) score += 30;

    // Check if any individual artist starts with query
    for (final a in artists) {
      if (a.startsWith(queryLower)) score += 45;
    }

    // Contains bonus
    if (title.contains(queryLower)) score += 30;
    if (artist.contains(queryLower)) score += 25;
    if (album.contains(queryLower)) score += 20;

    // Word match bonus (matches whole words)
    final titleWords = title.split(' ');
    final artistWords = artist.split(' ');
    final queryWords = queryLower.split(' ');

    for (final queryWord in queryWords) {
      for (final titleWord in titleWords) {
        if (titleWord == queryWord) {
          score += 15;
        } else if (titleWord.startsWith(queryWord)) score += 10;
      }
      for (final artistWord in artistWords) {
        if (artistWord == queryWord) {
          score += 12;
        } else if (artistWord.startsWith(queryWord)) score += 8;
      }
    }

    // Fuzzy match using Levenshtein distance
    final titleDistance = _levenshteinDistance(title, queryLower);
    final artistDistance = _levenshteinDistance(artist, queryLower);

    // Normalize distance (smaller is better, convert to score where higher is better)
    final maxLength =
        title.length > queryLower.length ? title.length : queryLower.length;
    if (maxLength > 0 && titleDistance < maxLength / 2) {
      score += (1 - titleDistance / maxLength) * 25;
    }

    final maxArtistLength =
        artist.length > queryLower.length ? artist.length : queryLower.length;
    if (maxArtistLength > 0 && artistDistance < maxArtistLength / 2) {
      score += (1 - artistDistance / maxArtistLength) * 20;
    }

    return score;
  }

  /// Search songs with intelligent fuzzy matching
  static List<SongModel> searchSongs(
    List<SongModel> songs,
    String query, {
    int limit = 50,
    double minScore = 10.0,
  }) {
    if (query.isEmpty) return [];

    // Calculate scores for all songs
    final scoredSongs = songs
        .map((song) {
          final score = _calculateScore(song, query);
          return MapEntry(song, score);
        })
        .where((entry) => entry.value >= minScore)
        .toList();

    // Sort by score (descending)
    scoredSongs.sort((a, b) => b.value.compareTo(a.value));

    // Return top results
    return scoredSongs.take(limit).map((entry) => entry.key).toList();
  }

  /// Search artists (using ArtistModel from on_audio_query)
  /// Note: For separated artist search, use searchSeparatedArtists instead
  static List<ArtistModel> searchArtists(
    List<ArtistModel> artists,
    String query, {
    int limit = 30,
  }) {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();

    return artists
        .where((artist) {
          final name = artist.artist.toLowerCase();
          return name.contains(queryLower) || name.startsWith(queryLower);
        })
        .take(limit)
        .toList();
  }

  /// Search separated artists with proper individual artist matching
  static List<SeparatedArtist> searchSeparatedArtists(
    List<SeparatedArtist> artists,
    String query, {
    int limit = 30,
  }) {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();

    final results = artists.where((artist) {
      final name = artist.name.toLowerCase();
      return name.contains(queryLower);
    }).toList();

    // Sort by relevance (starts with > contains, then by track count)
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aStartsWith = aName.startsWith(queryLower);
      final bStartsWith = bName.startsWith(queryLower);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      // If same relevance, sort by track count (more tracks first)
      return b.numberOfTracks.compareTo(a.numberOfTracks);
    });

    return results.take(limit).toList();
  }

  /// Search albums
  static List<AlbumModel> searchAlbums(
    List<AlbumModel> albums,
    String query, {
    int limit = 30,
  }) {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();

    return albums
        .where((album) {
          final name = album.album.toLowerCase();
          final artist = (album.artist ?? '').toLowerCase();
          return name.contains(queryLower) || artist.contains(queryLower);
        })
        .take(limit)
        .toList();
  }
}

import 'package:on_audio_query/on_audio_query.dart';
import '../models/separated_artist.dart';
import 'artist_separator_service.dart';

/// Service that aggregates artists from all songs by properly splitting
/// combined artist names (e.g., "Artist1/Artist2") into individual artists.
class ArtistAggregatorService {
  static final ArtistAggregatorService _instance =
      ArtistAggregatorService._internal();
  factory ArtistAggregatorService() => _instance;
  ArtistAggregatorService._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ArtistSeparatorService _separatorService = ArtistSeparatorService();

  List<SeparatedArtist>? _cachedArtists;
  Map<String, SeparatedArtist>? _artistMap;
  Map<String, List<SongModel>>? _artistSongsMap;
  DateTime? _lastCacheTime;

  // Cache duration - 5 minutes
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Check if cache is still valid
  bool get _isCacheValid {
    if (_cachedArtists == null || _lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheDuration;
  }

  /// Clear the cache to force refresh
  void clearCache() {
    _cachedArtists = null;
    _artistMap = null;
    _artistSongsMap = null;
    _lastCacheTime = null;
  }

  /// Get all separated artists from the music library
  Future<List<SeparatedArtist>> getAllArtists(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid && _cachedArtists != null) {
      return _cachedArtists!;
    }

    await _separatorService.initialize();

    // Query all songs
    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Build artist map
    final Map<String, SeparatedArtist> artistMap = {};
    final Map<String, List<SongModel>> artistSongsMap = {};

    for (final song in songs) {
      final artistString = song.artist ?? 'Unknown Artist';
      final artists = _separatorService.splitArtists(artistString);

      for (final artistName in artists) {
        final normalizedName = _normalizeArtistName(artistName);
        if (normalizedName.isEmpty) continue;

        // Use the first occurrence's casing for display
        final displayName = artistMap.containsKey(normalizedName)
            ? artistMap[normalizedName]!.name
            : artistName.trim();

        if (artistMap.containsKey(normalizedName)) {
          artistMap[normalizedName] = artistMap[normalizedName]!.addSong(song);
        } else {
          artistMap[normalizedName] = SeparatedArtist(
            name: displayName,
          ).addSong(song);
        }

        // Also maintain a map of artist -> songs for quick lookup
        if (!artistSongsMap.containsKey(normalizedName)) {
          artistSongsMap[normalizedName] = [];
        }
        if (!artistSongsMap[normalizedName]!.any((s) => s.id == song.id)) {
          artistSongsMap[normalizedName]!.add(song);
        }
      }
    }

    // Convert to list and sort by name
    final artistList = artistMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Update cache
    _cachedArtists = artistList;
    _artistMap = artistMap;
    _artistSongsMap = artistSongsMap;
    _lastCacheTime = DateTime.now();

    return artistList;
  }

  /// Get songs by a specific artist
  Future<List<SongModel>> getSongsByArtist(String artistName) async {
    await getAllArtists(); // Ensure cache is populated

    final normalizedName = _normalizeArtistName(artistName);
    return _artistSongsMap?[normalizedName] ?? [];
  }

  /// Get a specific artist by name
  Future<SeparatedArtist?> getArtist(String artistName) async {
    await getAllArtists(); // Ensure cache is populated

    final normalizedName = _normalizeArtistName(artistName);
    return _artistMap?[normalizedName];
  }

  /// Search artists by name
  Future<List<SeparatedArtist>> searchArtists(String query,
      {int limit = 30}) async {
    if (query.isEmpty) return [];

    final artists = await getAllArtists();
    final queryLower = query.toLowerCase();

    final results = artists.where((artist) {
      final name = artist.name.toLowerCase();
      return name.contains(queryLower);
    }).toList();

    // Sort by relevance (starts with > contains)
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aStartsWith = aName.startsWith(queryLower);
      final bStartsWith = bName.startsWith(queryLower);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      return aName.compareTo(bName);
    });

    return results.take(limit).toList();
  }

  /// Get albums by a specific artist
  Future<List<AlbumModel>> getAlbumsByArtist(String artistName) async {
    final songs = await getSongsByArtist(artistName);
    if (songs.isEmpty) return [];

    // Get unique album IDs
    final albumIds =
        songs.where((s) => s.albumId != null).map((s) => s.albumId!).toSet();

    if (albumIds.isEmpty) return [];

    // Query all albums
    final allAlbums = await _audioQuery.queryAlbums();

    // Filter to only albums that contain songs by this artist
    return allAlbums.where((album) => albumIds.contains(album.id)).toList();
  }

  /// Normalize artist name for comparison (case-insensitive)
  String _normalizeArtistName(String name) {
    return name.trim().toLowerCase();
  }

  /// Get total count of unique artists
  Future<int> getArtistCount() async {
    final artists = await getAllArtists();
    return artists.length;
  }
}

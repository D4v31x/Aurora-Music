import 'package:on_audio_query/on_audio_query.dart';

/// Model representing an individual artist extracted from song metadata.
/// Unlike ArtistModel from on_audio_query, this properly handles artists
/// that were combined with separators like "/" or "feat."
class SeparatedArtist {
  /// The artist name
  final String name;

  /// List of song IDs associated with this artist
  final List<int> songIds;

  /// List of album names associated with this artist
  final Set<String> albumNames;

  /// Total number of songs by this artist
  int get numberOfTracks => songIds.length;

  /// Total number of albums by this artist
  int get numberOfAlbums => albumNames.length;

  SeparatedArtist({
    required this.name,
    List<int>? songIds,
    Set<String>? albumNames,
  })  : songIds = songIds ?? [],
        albumNames = albumNames ?? {};

  /// Create a copy with additional song
  SeparatedArtist addSong(SongModel song) {
    final newSongIds = List<int>.from(songIds);
    final newAlbumNames = Set<String>.from(albumNames);

    if (!newSongIds.contains(song.id)) {
      newSongIds.add(song.id);
    }
    if (song.album != null && song.album!.isNotEmpty) {
      newAlbumNames.add(song.album!);
    }

    return SeparatedArtist(
      name: name,
      songIds: newSongIds,
      albumNames: newAlbumNames,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeparatedArtist &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() =>
      'SeparatedArtist(name: $name, songs: $numberOfTracks, albums: $numberOfAlbums)';
}

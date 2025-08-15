import 'package:on_audio_query/on_audio_query.dart';

class Playlist {
  final String id;
  final String name;
  final List<SongModel> songs;

  Playlist({required this.id, required this.name, required this.songs});

  Playlist copyWith({String? id, String? name, List<SongModel>? songs}) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
    );
  }
  
  // Convert Playlist to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'albumId': song.albumId,
        'duration': song.duration,
        'uri': song.uri,
        'data': song.data,
      }).toList(),
    };
  }
  
  // Create Playlist from JSON
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      songs: (json['songs'] as List).map((songJson) {
        return SongModel({
          'id': songJson['id'],
          'title': songJson['title'],
          'artist': songJson['artist'],
          'album': songJson['album'],
          'album_id': songJson['albumId'],
          'duration': songJson['duration'],
          'uri': songJson['uri'],
          '_data': songJson['data'],
        });
      }).toList(),
    );
  }
}
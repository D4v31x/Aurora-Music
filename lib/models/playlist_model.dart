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
}
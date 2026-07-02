/// A single named marker at a specific position within a long track (e.g. a
/// DJ mix or set), used so users can jump straight to that point.
library;

class TrackTag {
  final String id;
  final String name;
  final Duration position;

  const TrackTag({
    required this.id,
    required this.name,
    required this.position,
  });

  TrackTag copyWith({String? name, Duration? position}) => TrackTag(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'positionMs': position.inMilliseconds,
      };

  factory TrackTag.fromJson(Map<String, dynamic> json) => TrackTag(
        id: json['id'] as String,
        name: json['name'] as String,
        position: Duration(milliseconds: json['positionMs'] as int),
      );
}

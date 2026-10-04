import 'package:on_audio_query/on_audio_query.dart';

/// Drops albums with no MediaStore album name.
///
/// `on_audio_query`'s [AlbumModel.album] getter throws a `TypeError` instead
/// of returning null when the underlying column is null, which crashes any
/// code that sorts/compares/displays `.album` for the whole list. Filter
/// those entries out right after querying, using [AlbumModel.getMap] which
/// doesn't trigger the throwing getter.
List<AlbumModel> sanitizeAlbums(List<AlbumModel> albums) =>
    albums.where((a) => a.getMap['album'] != null).toList();

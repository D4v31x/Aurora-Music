import '../services/artist_separator_service.dart';

/// Split artist string into individual artists using the ArtistSeparatorService.
/// This function uses user-configurable separators and exclusions.
List<String> splitArtists(String artists) {
  return ArtistSeparatorService().splitArtists(artists);
}

/// Get the primary (first) artist from an artist string
String getPrimaryArtist(String artists) {
  return ArtistSeparatorService().getPrimaryArtist(artists);
}

/// Check if an artist string contains multiple artists
bool hasMultipleArtists(String artists) {
  return ArtistSeparatorService().hasMultipleArtists(artists);
}

List<String> splitArtists(String artists) {
  // Split the string by '/' and '&' and trim any extra spaces
  return artists.split(RegExp(r'[/&,]')).map((artist) => artist.trim()).toList();
}
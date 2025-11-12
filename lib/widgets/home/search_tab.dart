import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../services/audio_player_service.dart';
import '../../services/expandable_player_controller.dart';
import '../../services/music_search_service.dart';
import '../../services/artwork_cache_service.dart';
import '../../screens/Artist_screen.dart';
import '../artist_card.dart';

class SearchTab extends StatefulWidget {
  final List<SongModel> songs;
  final List<ArtistModel> artists;
  final bool isInitialized;

  const SearchTab({
    super.key,
    required this.songs,
    required this.artists,
    required this.isInitialized,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  // Make artwork service static to prevent recreation
  static final _artworkService = ArtworkCacheService();
  List<SongModel> _filteredSongs = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search input to reduce rebuilds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final query = _searchController.text;

      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _filteredSongs = [];
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          // Use improved search service with fuzzy matching
          _filteredSongs = MusicSearchService.searchSongs(
            widget.songs,
            query,
            limit: 100,
            minScore: 10.0,
          );
        });
      }
    });
  }

  void _onSongTap(SongModel song) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final expandableController =
        Provider.of<ExpandablePlayerController>(context, listen: false);

    List<SongModel> playlist = _filteredSongs;
    int initialIndex = playlist.indexOf(song);

    audioPlayerService.setPlaylist(playlist, initialIndex);

    expandableController.show();
  }

  Widget buildSongListTile(SongModel song) {
    return RepaintBoundary(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _artworkService.buildCachedArtwork(song.id, size: 50),
        ),
        title: Text(
          song.title,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist ?? '',
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.favorite_border,
            color: Theme.of(context).iconTheme.color),
        onTap: () => _onSongTap(song),
      ),
    );
  }

  Widget buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).translate('Start_type'),
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7)),
        ),
      );
    }

    final query = _searchController.text.toLowerCase();
    final matchingArtists = widget.artists
        .where(
          (artist) => artist.artist.toLowerCase().contains(query),
        )
        .toList();

    final closestArtist =
        matchingArtists.isNotEmpty ? matchingArtists.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (closestArtist != null) ...[
          ArtistCard(
            artistName: closestArtist.artist,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistDetailsScreen(
                    artistName: closestArtist.artist,
                    artistImagePath: null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
        if (_filteredSongs.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context).translate('songs'),
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ..._filteredSongs.map(buildSongListTile),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: buildSearchResults(),
        ),
      ],
    );
  }
}

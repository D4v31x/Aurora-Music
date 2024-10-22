import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/playlist_model.dart';
import '../models/utils.dart';
import '../services/Audio_Player_Service.dart';
import '../localization/app_localizations.dart';
import '../widgets/glassmorphic_container.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';


class TracksScreen extends StatefulWidget {
  final bool isEditingPlaylist;
  final Playlist? playlist;

  const TracksScreen({
    super.key,
    this.isEditingPlaylist = false,
    this.playlist,
  });

  @override
  _TracksScreenState createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _allSongs = [];
  List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  final int _songsPerPage = 20;
  bool _isLoading = false;
  bool _hasMoreSongs = true;
  String _searchQuery = '';
  Timer? _debounce;
  String _errorMessage = '';
  final Set<SongModel> _selectedSongs = {};

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchAllSongs();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreSongs) {
        _loadMoreSongs();
      }
    }
  }

  Future<void> _fetchAllSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool permissionStatus = await _audioQuery.permissionsStatus();

      if (!permissionStatus) {
        permissionStatus = await _audioQuery.permissionsRequest();
      }

      if (permissionStatus) {
        _allSongs = await _audioQuery.querySongs(
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        if (_allSongs.isEmpty) {
          setState(() {
            _errorMessage = 'No songs found on the device.';
            _isLoading = false;
          });
        } else {
          _loadMoreSongs();
        }
      } else {
        setState(() {
          _errorMessage = 'Permission to access media library was denied.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching songs: $e';
        _isLoading = false;
      });
    }
  }

  void _loadMoreSongs() {
    if (_isLoading && _displayedSongs.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final int startIndex = _currentPage * _songsPerPage;
    final int endIndex = (startIndex + _songsPerPage).clamp(
        0, _allSongs.length);

    if (startIndex < _allSongs.length) {
      final newSongs = _allSongs.sublist(startIndex, endIndex);

      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoading = false;
        _hasMoreSongs = endIndex < _allSongs.length;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasMoreSongs = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase();
        _currentPage = 0;
        _displayedSongs.clear();
        _hasMoreSongs = true;
      });
      _searchSongs();
    });
  }

  void _searchSongs() {
    final filteredSongs = _allSongs.where((song) =>
    song.title.toLowerCase().contains(_searchQuery) ||
        splitArtists(song.artist ?? '').any((artist) => artist.toLowerCase().contains(_searchQuery))
    ).toList();

    final int endIndex = (_songsPerPage).clamp(0, filteredSongs.length);

    setState(() {
      _displayedSongs = filteredSongs.sublist(0, endIndex);
      _currentPage = 1;
      _hasMoreSongs = endIndex < filteredSongs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Hero(
      tag: 'tracks_screen',
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            buildBackground(audioPlayerService.currentSong),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: buildAppBar(),
              body: buildBody(audioPlayerService),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBackground(SongModel? currentSong) {
    return FutureBuilder<Uint8List?>(
      future: currentSong != null
          ? OnAudioQuery().queryArtwork(currentSong.id, ArtworkType.AUDIO)
          : null,
      builder: (context, snapshot) {
        ImageProvider backgroundImage;
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          backgroundImage = MemoryImage(snapshot.data!);
        } else {
          backgroundImage = AssetImage(
              MediaQuery
                  .of(context)
                  .platformBrightness == Brightness.dark
                  ? 'assets/images/background/dark_back.jpg'
                  : 'assets/images/background/light_back.jpg');
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 180,
      automaticallyImplyLeading: false,
      title: Stack(
        children: [
          Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(seconds: 1),
              child: Text(
                AppLocalizations.of(context).translate('tracks'),
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontStyle: FontStyle.normal,
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate(
                        'search_tracks'),
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.isEditingPlaylist)
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              final audioPlayerService = Provider.of<AudioPlayerService>(
                  context, listen: false);
              audioPlayerService.addSongsToPlaylist(
                  widget.playlist!.id, _selectedSongs.toList());
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  Widget buildBody(AudioPlayerService audioPlayerService) {
    if (_isLoading && _displayedSongs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      return Center(
          child: Text(_errorMessage, style: const TextStyle(color: Colors.white)));
    } else if (_displayedSongs.isEmpty) {
      return const Center(
          child: Text('No songs found', style: TextStyle(color: Colors.white)));
    } else {
      return AnimationLimiter(
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _displayedSongs.length) {
              return _hasMoreSongs
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink();
            }
            final song = _displayedSongs[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: _buildSongCard(song, audioPlayerService),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildSongCard(SongModel song, AudioPlayerService audioPlayerService) {
    return glassmorphicContainer(
      child: ListTile(
        leading: QueryArtworkWidget(
          id: song.id,
          type: ArtworkType.AUDIO,
          nullArtworkWidget: Container(
            width: 50,
            height: 50,
            color: Colors.grey[800],
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          splitArtists(song.artist ?? 'Unknown Artist').join(', '),
          style: TextStyle(color: Colors.grey[400]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: widget.isEditingPlaylist
            ? Checkbox(
          value: _selectedSongs.contains(song),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedSongs.add(song);
              } else {
                _selectedSongs.remove(song);
              }
            });
          },
          fillColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.blue;
            }
            return Colors.grey;
          }),
        )
            : IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            // Show options for the song (e.g., add to playlist, delete, etc.)
          },
        ),
        onTap: widget.isEditingPlaylist
            ? () {
          setState(() {
            if (_selectedSongs.contains(song)) {
              _selectedSongs.remove(song);
            } else {
              _selectedSongs.add(song);
            }
          });
        }
            : () {
          audioPlayerService.setPlaylist(
              _displayedSongs, _displayedSongs.indexOf(song));
          audioPlayerService.play();
        },
      ),
    );
  }
}

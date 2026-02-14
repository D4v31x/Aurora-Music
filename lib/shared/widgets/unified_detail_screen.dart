/// Unified detail screen for artists, albums, folders, and playlists.
///
/// Provides a consistent glassmorphic UI across all collection detail screens
/// with a blurred artwork header, type badge, search bar, and numbered song list.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import '../models/artist_utils.dart';
import '../services/audio_player_service.dart';
import '../services/artwork_cache_service.dart';
import 'app_background.dart';
import 'expanding_player.dart';

/// The type of detail screen being shown
enum DetailScreenType {
  artist,
  album,
  folder,
  playlist,
}

/// Configuration for the unified detail screen header
class DetailScreenConfig {
  /// Screen type
  final DetailScreenType type;

  /// Main title (artist name, album name, folder name, playlist name)
  final String title;

  /// Optional subtitle (artist name for album, path for folder, etc.)
  final String? subtitle;

  /// Optional year to display below subtitle
  final String? year;

  /// Playback source info for tracking
  final PlaybackSourceInfo playbackSource;

  /// Hero tag for artwork transition
  final String? heroTag;

  /// Whether to show add button (for user playlists)
  final bool showAddButton;

  /// Whether songs can be dismissed/removed
  final bool allowSongRemoval;

  /// Callback when add button is pressed
  final VoidCallback? onAddPressed;

  /// Callback when a song is removed
  final void Function(SongModel song)? onSongRemoved;

  /// Custom header icon for folders
  final IconData? headerIcon;

  /// Optional stats to show
  final List<DetailStat> stats;

  /// Optional extra widgets below songs (e.g., related albums)
  final List<Widget> extraSlivers;

  /// Tab labels for a segmented control above the content (e.g. ["Songs", "Albums"])
  /// When provided, shows a Material You segmented toggle above the songs list.
  final List<String> tabLabels;

  /// Content slivers for each tab (index-matched with tabLabels).
  /// The first tab always shows the songs list automatically.
  /// Additional tabs show the slivers at the corresponding index.
  final List<List<Widget>> tabSlivers;

  /// Accent color for the screen
  final Color accentColor;

  const DetailScreenConfig({
    required this.type,
    required this.title,
    this.subtitle,
    this.year,
    required this.playbackSource,
    this.heroTag,
    this.showAddButton = false,
    this.allowSongRemoval = false,
    this.onAddPressed,
    this.onSongRemoved,
    this.headerIcon,
    this.stats = const [],
    this.extraSlivers = const [],
    this.tabLabels = const [],
    this.tabSlivers = const [],
    this.accentColor = Colors.deepPurple,
  });
}

/// A stat item displayed in the stats bar
class DetailStat {
  final IconData icon;
  final String value;
  final String label;

  const DetailStat({
    required this.icon,
    required this.value,
    required this.label,
  });
}

/// Unified detail screen widget
class UnifiedDetailScreen extends StatefulWidget {
  final DetailScreenConfig config;
  final List<SongModel> songs;
  final Widget? headerArtwork;
  final bool isLoading;

  const UnifiedDetailScreen({
    super.key,
    required this.config,
    required this.songs,
    this.headerArtwork,
    this.isLoading = false,
  });

  @override
  State<UnifiedDetailScreen> createState() => _UnifiedDetailScreenState();
}

class _UnifiedDetailScreenState extends State<UnifiedDetailScreen> {
  late ScrollController _scrollController;
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  bool _isScrolled = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _selectedTab = 0;

  // Lazy loading
  final List<SongModel> _displayedSongs = [];
  int _currentPage = 0;
  static const int _songsPerPage = 30;
  bool _isLoadingMore = false;
  bool _hasMoreSongs = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _loadMoreSongs();
  }

  @override
  void didUpdateWidget(UnifiedDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs != widget.songs) {
      _displayedSongs.clear();
      _currentPage = 0;
      _hasMoreSongs = true;
      _loadMoreSongs();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isScrolled = _scrollController.offset > 200;
      if (isScrolled != _isScrolled) {
        setState(() => _isScrolled = isScrolled);
      }
    }
    if (_scrollController.position.extentAfter < 300 &&
        !_isLoadingMore &&
        _hasMoreSongs) {
      _loadMoreSongs();
    }
  }

  void _loadMoreSongs() {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final startIndex = _currentPage * _songsPerPage;
    final endIndex = (startIndex + _songsPerPage).clamp(0, widget.songs.length);

    if (startIndex < widget.songs.length) {
      final newSongs = widget.songs.sublist(startIndex, endIndex);
      setState(() {
        _displayedSongs.addAll(newSongs);
        _currentPage++;
        _isLoadingMore = false;
        _hasMoreSongs = endIndex < widget.songs.length;
      });
    } else {
      setState(() {
        _isLoadingMore = false;
        _hasMoreSongs = false;
      });
    }
  }

  /// Get the display label for the screen type
  String _getTypeLabel() {
    switch (widget.config.type) {
      case DetailScreenType.artist:
        return 'ARTIST';
      case DetailScreenType.album:
        return 'ALBUM';
      case DetailScreenType.folder:
        return 'FOLDER';
      case DetailScreenType.playlist:
        return 'PLAYLIST';
    }
  }

  /// Get filtered songs based on search query
  List<SongModel> get _filteredDisplayedSongs {
    if (_searchQuery.isEmpty) return _displayedSongs;
    final query = _searchQuery.toLowerCase();
    return _displayedSongs
        .where((song) =>
            song.title.toLowerCase().contains(query) ||
            (song.artist ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (widget.isLoading) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- HEADER ---
            _buildHeader(context, isDark, theme),

            // --- STATS BAR ---
            if (widget.config.stats.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildStatsBar(isDark),
              ),

            // --- PLAY / SEARCH / SHUFFLE ROW ---
            SliverToBoxAdapter(
              child: _buildActionRow(context, isDark, theme),
            ),

            // --- SEGMENTED TAB CONTROL ---
            if (widget.config.tabLabels.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSegmentedControl(isDark, theme),
              ),

            // --- TAB CONTENT ---
            if (widget.config.tabLabels.isEmpty || _selectedTab == 0) ...[
              // --- SONG COUNT ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    '${widget.songs.length} ${widget.songs.length == 1 ? 'track' : 'tracks'}',
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // --- SONGS LIST ---
              _buildSongsList(context, isDark, theme),
            ] else if (_selectedTab < widget.config.tabSlivers.length)
              ...widget.config.tabSlivers[_selectedTab],

            // --- EXTRA SLIVERS (related albums, etc.) ---
            ...widget.config.extraSlivers,

            // --- BOTTOM PADDING ---
            SliverToBoxAdapter(
              child: Selector<AudioPlayerService, bool>(
                selector: (_, service) => service.currentSong != null,
                builder: (context, hasCurrentSong, _) {
                  return SizedBox(
                    height: hasCurrentSong
                        ? ExpandingPlayer.getMiniPlayerPaddingHeight(context)
                        : 24,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, ThemeData theme) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 240,
      pinned: true,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
      title: _isScrolled
          ? Text(
              widget.config.title,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred artwork background (full header)
              _buildBlurredBackground(isDark),
              // Content overlay — centered
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Type badge
                    _buildTypeBadge(isDark),
                    const SizedBox(height: 12),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        widget.config.title,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Subtitle (artist name)
                    if (widget.config.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.config.subtitle!,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 6,
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Year
                    if (widget.config.year != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.config.year!,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 6,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Blurred artwork background for the header
  Widget _buildBlurredBackground(bool isDark) {
    Widget artworkImage;

    if (widget.headerArtwork != null) {
      artworkImage = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: widget.headerArtwork!,
        ),
      );
    } else {
      artworkImage = Container(
        color: widget.config.accentColor.withOpacity(0.6),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Artwork image
        artworkImage,
        // Heavy blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: const SizedBox.expand(),
        ),
        // Dark overlay for readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  /// Type badge pill (e.g., "ALBUM", "ARTIST")
  Widget _buildTypeBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Text(
        _getTypeLabel(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    final statColor = isDark ? Colors.white54 : Colors.black45;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.config.stats.asMap().entries.expand((entry) {
          final stat = entry.value;
          final isLast = entry.key == widget.config.stats.length - 1;
          return [
            Text(
              '${stat.value} ${stat.label}',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: statColor,
                fontSize: 13,
              ),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: statColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ];
        }).toList(),
      ),
    );
  }

  /// Material You segmented pill toggle for switching between tabs
  Widget _buildSegmentedControl(bool isDark, ThemeData theme) {
    final labels = widget.config.tabLabels;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / labels.length;
            return Stack(
              children: [
                // Animated sliding indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _selectedTab * tabWidth + 3,
                  top: 3,
                  bottom: 3,
                  width: tabWidth - 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab labels
                Row(
                  children: List.generate(labels.length, (index) {
                    final isSelected = _selectedTab == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedTab != index) {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedTab = index);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : (isDark ? Colors.white60 : Colors.black54),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(labels[index]),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark, ThemeData theme) {
    final audioService =
        Provider.of<AudioPlayerService>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Play button (circular)
          _buildCircleActionButton(
            icon: Icons.play_arrow_rounded,
            onTap: widget.songs.isEmpty
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    audioService.setPlaylist(
                      widget.songs,
                      0,
                      source: widget.config.playbackSource,
                    );
                  },
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          // Search bar
          Expanded(
            child: _buildSearchBar(isDark),
          ),
          const SizedBox(width: 10),
          // Shuffle button (circular)
          _buildCircleActionButton(
            icon: Icons.shuffle_rounded,
            onTap: widget.songs.isEmpty
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    final shuffled = List.of(widget.songs)..shuffle();
                    audioService.setPlaylist(
                      shuffled,
                      0,
                      source: widget.config.playbackSource,
                    );
                  },
            theme: theme,
            isDark: isDark,
          ),
          // Add button (for playlists)
          if (widget.config.showAddButton) ...[
            const SizedBox(width: 10),
            _buildCircleActionButton(
              icon: Icons.add_rounded,
              onTap: widget.config.onAddPressed ?? () {},
              theme: theme,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    VoidCallback? onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isDisabled = onTap == null;
    final buttonColor = theme.colorScheme.primary;
    final onButtonColor = theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled
              ? buttonColor.withOpacity(0.3)
              : buttonColor,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isDisabled ? onButtonColor.withOpacity(0.5) : onButtonColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search a song...',
                    hintStyle: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _isSearching = value.isNotEmpty;
                    });
                  },
                ),
              ),
              if (_isSearching)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isSearching = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 18,
                    ),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongsList(BuildContext context, bool isDark, ThemeData theme) {
    final songsToShow = _filteredDisplayedSongs;

    if (widget.songs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 56,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'No songs found',
                style: TextStyle(
                  fontFamily: FontConstants.fontFamily,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching && songsToShow.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No matching songs',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white38 : Colors.black26,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= songsToShow.length) {
            return _hasMoreSongs && !_isSearching
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final song = songsToShow[index];
          final duration = Duration(milliseconds: song.duration ?? 0);
          final durationString =
              '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

          // Get the original index for display numbering
          final originalIndex = _isSearching
              ? widget.songs.indexWhere((s) => s.id == song.id)
              : _displayedSongs.indexOf(song);

          // Use Selector to reactively listen for current song changes
          return Selector<AudioPlayerService, int?>(
            selector: (_, service) => service.currentSong?.id,
            builder: (context, currentSongId, _) {
              final audioService =
                  Provider.of<AudioPlayerService>(context, listen: false);
              final isPlaying = currentSongId == song.id;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 200),
                child: SlideAnimation(
                  verticalOffset: 20.0,
                  child: FadeInAnimation(
                    child: _buildSongTile(
                      context,
                      song,
                      originalIndex >= 0 ? originalIndex : index,
                      isPlaying,
                      isDark,
                      theme,
                      durationString,
                      audioService,
                    ),
                  ),
                ),
              );
            },
          );
        },
        childCount: songsToShow.length + (_hasMoreSongs && !_isSearching ? 1 : 0),
      ),
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    SongModel song,
    int index,
    bool isPlaying,
    bool isDark,
    ThemeData theme,
    String durationString,
    AudioPlayerService audioService,
  ) {
    final tile = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final songIndex = widget.songs.indexWhere((s) => s.id == song.id);
        if (songIndex >= 0) {
          audioService.setPlaylist(
            widget.songs,
            songIndex,
            source: widget.config.playbackSource,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isPlaying
                    ? theme.colorScheme.primary.withOpacity(0.15)
                    : (isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPlaying
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04)),
                ),
              ),
              child: Row(
                children: [
                  // Track number
                  SizedBox(
                    width: 28,
                    child: isPlaying
                        ? Icon(
                            Icons.equalizer_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Song title only (no artwork per mockup)
                  Expanded(
                    child: Text(
                      song.title,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isPlaying
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 14,
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration
                  Text(
                    durationString,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 3-dot menu
                  GestureDetector(
                    onTap: () =>
                        _showSongOptions(context, song, audioService, isDark),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white30 : Colors.black26,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with Dismissible if song removal is allowed
    if (widget.config.allowSongRemoval) {
      return Dismissible(
        key: ValueKey(song.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Icon(Icons.delete_rounded, color: Colors.red.withOpacity(0.8)),
        ),
        onDismissed: (_) {
          widget.config.onSongRemoved?.call(song);
        },
        child: tile,
      );
    }

    return tile;
  }

  void _showSongOptions(
    BuildContext context,
    SongModel song,
    AudioPlayerService audioService,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Song info
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: _artworkService.buildCachedArtwork(song.id,
                              size: 50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              splitArtists(song.artist ?? 'Unknown')
                                  .join(', '),
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color:
                                    isDark ? Colors.white54 : Colors.black45,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Options
                _buildOptionTile(
                  Icons.play_arrow_rounded,
                  'Play',
                  isDark,
                  () {
                    Navigator.pop(context);
                    final songIndex =
                        widget.songs.indexWhere((s) => s.id == song.id);
                    if (songIndex >= 0) {
                      audioService.setPlaylist(widget.songs, songIndex,
                          source: widget.config.playbackSource);
                    }
                  },
                ),
                _buildOptionTile(
                  Icons.playlist_play_rounded,
                  'Play Next',
                  isDark,
                  () async {
                    Navigator.pop(context);
                    await audioService.playNext(song);
                  },
                ),
                _buildOptionTile(
                  Icons.queue_music_rounded,
                  'Add to Queue',
                  isDark,
                  () async {
                    Navigator.pop(context);
                    await audioService.addToQueue(song);
                  },
                ),
                _buildOptionTile(
                  audioService.isLiked(song)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  audioService.isLiked(song) ? 'Unlike' : 'Like',
                  isDark,
                  () {
                    Navigator.pop(context);
                    audioService.toggleLike(song);
                  },
                  iconColor: audioService.isLiked(song) ? Colors.pink : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ??
                  (isDark ? Colors.white70 : Colors.black54),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../shared/widgets/glassmorphic_container.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../../../shared/widgets/library_screen_header.dart';
import 'folder_detail_screen.dart';

enum FolderSortOption { name, path }

/// Screen displaying all music folders on the device.
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _allFolders = [];
  List<String> _filteredFolders = [];
  List<String> _displayedFolders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  static const int _pageSize = 40;
  String? _error;
  String _searchQuery = '';
  FolderSortOption _sortOption = FolderSortOption.name;
  bool _isAscending = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadFolders();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || !_hasMore) return;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredFolders.length);
    if (start >= _filteredFolders.length) return;
    setState(() {
      _isLoadingMore = true;
      _displayedFolders.addAll(_filteredFolders.sublist(start, end));
      _currentPage++;
      _hasMore = end < _filteredFolders.length;
      _isLoadingMore = false;
    });
  }

  void _resetPaging() {
    final end = _pageSize.clamp(0, _filteredFolders.length);
    _displayedFolders = _filteredFolders.sublist(0, end);
    _currentPage = 1;
    _hasMore = end < _filteredFolders.length;
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await OnAudioQuery().queryAllPath();
      setState(() {
        _allFolders = folders;
        _filteredFolders = folders;
        _isLoading = false;
      });
      _applySorting();
      setState(() => _resetPaging());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterFolders(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFolders = List.from(_allFolders);
      } else {
        _filteredFolders = _allFolders.where((f) {
          final name = f.split('/').last.toLowerCase();
          return name.contains(query.toLowerCase()) ||
              f.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _applySorting();
      setState(() => _resetPaging());
    });
  }

  void _applySorting() {
    switch (_sortOption) {
      case FolderSortOption.name:
        _filteredFolders
            .sort((a, b) => a.split('/').last.compareTo(b.split('/').last));
        break;
      case FolderSortOption.path:
        _filteredFolders.sort((a, b) => a.compareTo(b));
        break;
    }
    if (!_isAscending) _filteredFolders = _filteredFolders.reversed.toList();
  }

  String _getSortLabel(FolderSortOption opt) {
    switch (opt) {
      case FolderSortOption.name:
        return 'Name';
      case FolderSortOption.path:
        return 'Path';
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _filteredFolders.length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            LibraryScreenHeader(
              badge: 'Library',
              title: 'Folders',
              subtitle: _isLoading
                  ? null
                  : '$count ${count == 1 ? 'folder' : 'folders'}',
              accentColor: Colors.orange,
              expandedHeight: 295,
              showBackButton: true,
              searchField: LibrarySearchField(
                controller: _searchController,
                hint: 'Search folders…',
                onChanged: _filterFolders,
                hasQuery: _searchQuery.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  _filterFolders('');
                },
              ),
              controlsRow: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<FolderSortOption>(
                      onSelected: (opt) {
                        setState(() => _sortOption = opt);
                        _applySorting();
                        setState(() => _resetPaging());
                      },
                      color: Colors.grey.shade900,
                      child: LibraryControlPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getSortLabel(_sortOption),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: Colors.white70),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        _sortItem(FolderSortOption.name, 'Name'),
                        _sortItem(FolderSortOption.path, 'Path'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  LibraryControlPill(
                    onTap: () {
                      setState(() => _isAscending = !_isAscending);
                      _applySorting();
                      setState(() => _resetPaging());
                    },
                    child: Icon(
                      _isAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            _buildBody(),
            SliverToBoxAdapter(
              child: SizedBox(
                height: ExpandingPlayer.getMiniPlayerPaddingHeight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_filteredFolders.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child:
              Text('No folders found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _displayedFolders.length) {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final folder = _displayedFolders[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 40.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 16.0),
                  child: glassmorphicContainer(
                    child: ListTile(
                      leading:
                          const Icon(Icons.folder_rounded, color: Colors.white),
                      title: Text(
                        folder.split('/').last,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        folder,
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FolderDetailScreen(folderPath: folder),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _displayedFolders.length + (_hasMore ? 1 : 0),
      ),
    );
  }

  PopupMenuItem<FolderSortOption> _sortItem(
      FolderSortOption opt, String label) {
    return PopupMenuItem(
      value: opt,
      child: Row(
        children: [
          if (_sortOption == opt)
            const Icon(Icons.check, color: Colors.white, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

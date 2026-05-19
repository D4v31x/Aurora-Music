/// Library folder filter — choose which folders are included in the music library.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/folder_filter_service.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/expanding_player.dart';
import '../widgets/settings_tile_builders.dart';

class FolderFilterSettingsScreen extends StatefulWidget {
  const FolderFilterSettingsScreen({super.key});

  @override
  State<FolderFilterSettingsScreen> createState() =>
      _FolderFilterSettingsScreenState();
}

class _FolderFilterSettingsScreenState
    extends State<FolderFilterSettingsScreen> {
  final _filterService = FolderFilterService();
  final _audioQuery = OnAudioQuery();
  final _searchController = TextEditingController();

  /// All folders discovered from the MediaStore query.
  List<String> _allFolders = [];

  /// Folders visible after applying the search filter.
  List<String> _visibleFolders = [];

  /// Song count per folder path (unfiltered total).
  Map<String, int> _songCounts = {};

  bool _isLoading = true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadFolders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadFolders() async {
    await _filterService.ensureInitialized();

    try {
      final songs = await _audioQuery.querySongs(
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final counts = <String, int>{};
      for (final song in songs) {
        final folder = File(song.data).parent.path;
        counts[folder] = (counts[folder] ?? 0) + 1;
      }

      final sorted = counts.keys.toList()..sort();

      if (mounted) {
        setState(() {
          _allFolders = sorted;
          _visibleFolders = sorted;
          _songCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('FolderFilter: error loading folders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _visibleFolders = q.isEmpty
          ? _allFolders
          : _allFolders.where((f) => f.toLowerCase().contains(q)).toList();
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggle(String folder, bool excluded) async {
    await _filterService.setExcluded(folder, excluded);
    if (mounted) setState(() {});
  }

  void _applyAndPop() => Navigator.pop(context);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns just the last path component as a display name.
  String _displayName(String path) =>
      path.split('/').where((p) => p.isNotEmpty).last;

  int get _excludedCount => _filterService.excludedFolders.length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _applyAndPop();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
                    icon: iconoir.NavArrowLeft(
                      color: isDark ? Colors.white : Colors.black,
                      width: 28,
                      height: 28,
                    ),
                    onPressed: _applyAndPop,
                  ),
            title: Text(
              'Folder Filter',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          body: Selector<AudioPlayerService, bool>(
            selector: (_, s) => s.currentSong != null,
            builder: (context, hasCurrentSong, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Search bar ─────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search folders…',
                      hintStyle: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45),
                              onPressed: () {
                                _searchController.clear();
                                _applySearch();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // ── Info header ────────────────────────────────────────────
                SettingsTiles.buildSectionHeader(
                  context,
                  _isLoading
                      ? 'Loading…'
                      : '${_allFolders.length} folder${_allFolders.length == 1 ? '' : 's'}'
                          '${_excludedCount > 0 ? ' · $_excludedCount excluded' : ''}',
                ),

                // ── Folder list ────────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _visibleFolders.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.builder(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: hasCurrentSong
                                    ? ExpandingPlayer
                                        .getMiniPlayerPaddingHeight(context)
                                    : MediaQuery.of(context).padding.bottom +
                                        24,
                              ),
                              itemCount: _visibleFolders.length,
                              itemBuilder: (context, i) => _FolderTile(
                                folder: _visibleFolders[i],
                                displayName:
                                    _displayName(_visibleFolders[i]),
                                songCount:
                                    _songCounts[_visibleFolders[i]] ?? 0,
                                isExcluded: _filterService
                                    .isExcluded(_visibleFolders[i]),
                                isDark: isDark,
                                onToggle: (v) =>
                                    _toggle(_visibleFolders[i], v),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_off_rounded,
            size: 52,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'No folders found',
            style: TextStyle(
              fontFamily: FontConstants.fontFamily,
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Folder tile ───────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final String folder;
  final String displayName;
  final int songCount;
  final bool isExcluded;
  final bool isDark;
  final ValueChanged<bool> onToggle;

  const _FolderTile({
    required this.folder,
    required this.displayName,
    required this.songCount,
    required this.isExcluded,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final included = !isExcluded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: included ? 0.08 : 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: included ? 0.15 : 0.06),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: included ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                included
                    ? Icons.folder_rounded
                    : Icons.folder_off_rounded,
                size: 20,
                color: included
                    ? cs.primary
                    : (isDark ? Colors.white38 : Colors.black26),
              ),
            ),
            title: Text(
              displayName,
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: included
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  folder,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 11,
                    color: isDark
                        ? Colors.white38
                        : Colors.black38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$songCount song${songCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 12,
                    color: isDark
                        ? Colors.white54
                        : Colors.black54,
                  ),
                ),
              ],
            ),
            trailing: Switch.adaptive(
              value: included,
              onChanged: (v) => onToggle(!v),
              activeTrackColor: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

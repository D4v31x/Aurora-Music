import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/font_constants.dart';
import '../services/artwork_cache_service.dart';

/// A card widget that displays album information with artwork
/// Similar to ArtistCard but for albums - with cached artwork to prevent flickering
class AlbumCard extends StatefulWidget {
  final String albumName;
  final String? artistName;
  final int? albumId;
  final Uint8List? artworkBytes;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.albumName,
    this.artistName,
    this.albumId,
    this.artworkBytes,
    required this.onTap,
  });

  // Static cache to prevent duplicate artwork loads
  static final Map<int, Uint8List?> _artworkCache = {};

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard>
    with AutomaticKeepAliveClientMixin {
  final ArtworkCacheService _artworkService = ArtworkCacheService();
  Uint8List? _cachedArtwork;
  bool _hasLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadArtworkFromCache();
  }

  @override
  void didUpdateWidget(AlbumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if album actually changed
    if (oldWidget.albumId != widget.albumId) {
      _hasLoaded = false;
      _loadArtworkFromCache();
    }
  }

  void _loadArtworkFromCache() {
    // If artwork bytes provided, use them directly
    if (widget.artworkBytes != null && widget.artworkBytes!.isNotEmpty) {
      _cachedArtwork = widget.artworkBytes;
      _hasLoaded = true;
      return;
    }

    // Check static cache first - synchronous, no setState needed during build
    if (widget.albumId != null &&
        AlbumCard._artworkCache.containsKey(widget.albumId)) {
      _cachedArtwork = AlbumCard._artworkCache[widget.albumId];
      _hasLoaded = true;
      return;
    }

    // Schedule async load only if not already loaded
    if (!_hasLoaded && widget.albumId != null) {
      _loadArtworkAsync();
    }
  }

  Future<void> _loadArtworkAsync() async {
    if (widget.albumId == null) return;

    // Double-check cache in case it was loaded while waiting
    if (AlbumCard._artworkCache.containsKey(widget.albumId)) {
      if (mounted) {
        setState(() {
          _cachedArtwork = AlbumCard._artworkCache[widget.albumId];
          _hasLoaded = true;
        });
      }
      return;
    }

    try {
      final artwork = await _artworkService.getAlbumArtwork(widget.albumId!);

      // Cache the result
      AlbumCard._artworkCache[widget.albumId!] = artwork;

      if (mounted) {
        setState(() {
          _cachedArtwork = artwork;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedArtwork = null;
          _hasLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Album artwork - matches ArtistCard size (80x80)
              RepaintBoundary(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildArtwork(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Album info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.albumName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.artistName ?? 'Unknown Artist',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: FontConstants.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.7),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    // Show artwork if available, otherwise show placeholder immediately
    // No loading indicator to prevent visual flickering
    if (_cachedArtwork != null && _cachedArtwork!.isNotEmpty) {
      return Image.memory(
        _cachedArtwork!,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        gaplessPlayback: true, // Prevents flickering on reload
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.white.withOpacity(0.1),
      child: Icon(
        Icons.album_rounded,
        color: Colors.white.withOpacity(0.3),
        size: 40,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

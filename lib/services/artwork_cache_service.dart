import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'local_caching_service.dart';

class ArtworkCacheService {
  static final ArtworkCacheService _instance = ArtworkCacheService._internal();
  factory ArtworkCacheService() => _instance;
  ArtworkCacheService._internal();

  // Cache size limits to prevent memory issues
  static const int _maxArtworkCacheSize = 100;
  static const int _maxArtistCacheSize = 50;

  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};
  final OnAudioQuery _audioQuery = OnAudioQuery();

  final Map<int, Uint8List?> _artistArtworkCache = {};
  final Map<int, ImageProvider<Object>?> _artistImageProviderCache = {};

  // Album artwork cache
  final Map<int, Uint8List?> _albumArtworkCache = {};
  final Map<int, ImageProvider<Object>?> _albumImageProviderCache = {};
  final List<int> _albumAccessOrder = [];

  // Name-based artist image cache (from Spotify API)
  final Map<String, String?> _artistNameImageCache = {};
  final Map<String, ImageProvider<Object>?> _artistNameProviderCache = {};
  final LocalCachingArtistService _localCachingService =
      LocalCachingArtistService();

  // LRU tracking for cache eviction
  final List<int> _artworkAccessOrder = [];
  final List<int> _artistAccessOrder = [];

  Future<void> initialize() async {
    await _initializeCache();
    await _localCachingService.initialize();
    await _preloadCommonArtwork();
  }

  Future<void> _initializeCache() async {
    // Clear existing cache and access tracking
    _artworkCache.clear();
    _imageProviderCache.clear();
    _artistArtworkCache.clear();
    _artistImageProviderCache.clear();
    _albumArtworkCache.clear();
    _albumImageProviderCache.clear();
    _artistNameImageCache.clear();
    _artistNameProviderCache.clear();
    _artworkAccessOrder.clear();
    _artistAccessOrder.clear();
    _albumAccessOrder.clear();
  }

  void _updateAccessOrder(int id, bool isArtist) {
    final accessOrder = isArtist ? _artistAccessOrder : _artworkAccessOrder;
    accessOrder.remove(id);
    accessOrder.add(id);
  }

  void _evictLRUIfNeeded(bool isArtist) {
    final cache = isArtist ? _artistArtworkCache : _artworkCache;
    final imageCache =
        isArtist ? _artistImageProviderCache : _imageProviderCache;
    final accessOrder = isArtist ? _artistAccessOrder : _artworkAccessOrder;
    final maxSize = isArtist ? _maxArtistCacheSize : _maxArtworkCacheSize;

    if (cache.length >= maxSize && accessOrder.isNotEmpty) {
      final lruId = accessOrder.removeAt(0);
      cache.remove(lruId);
      imageCache.remove(lruId);
    }
  }

  Future<void> _preloadCommonArtwork() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      );

      // Načteme prvních 30 skladeb
      final songsToPreload = songs.take(30).toList();

      // Načteme artwork paralelně, ale s omezením na 5 současných požadavků
      final chunks = <List<SongModel>>[];
      for (var i = 0; i < songsToPreload.length; i += 5) {
        chunks.add(songsToPreload.skip(i).take(5).toList());
      }

      for (var chunk in chunks) {
        await Future.wait(chunk.map((song) => _getArtwork(song.id)));
      }
    } catch (e) {}
  }

  Future<ImageProvider<Object>> getCachedImageProvider(int id) async {
    try {
      // Synchronous check - if in cache, return immediately
      if (_imageProviderCache.containsKey(id)) {
        _updateAccessOrder(id, false);
        final cachedProvider = _imageProviderCache[id];
        if (cachedProvider != null) {
          return cachedProvider;
        }
      }

      _evictLRUIfNeeded(false);
      final artwork = await _getArtwork(id);
      final ImageProvider<Object> provider = artwork != null
          ? MemoryImage(artwork)
          : const AssetImage('assets/images/logo/default_art.png')
              as ImageProvider<Object>;

      _imageProviderCache[id] = provider;
      _updateAccessOrder(id, false);
      return provider;
    } catch (e) {
      return const AssetImage('assets/images/logo/default_art.png');
    }
  }

  /// Get cached artwork synchronously if available, null otherwise
  ImageProvider<Object>? getCachedImageProviderSync(int id) {
    if (_imageProviderCache.containsKey(id)) {
      _updateAccessOrder(id, false);
      return _imageProviderCache[id];
    }
    return null;
  }

  Future<Uint8List?> _getArtwork(int id) async {
    // Only return cached value if it's not null
    if (_artworkCache.containsKey(id) && _artworkCache[id] != null) {
      return _artworkCache[id];
    }

    try {
      final artwork = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 500,
      );

      // Only cache if we got valid artwork
      if (artwork != null && artwork.isNotEmpty) {
        _artworkCache[id] = artwork;
        _updateAccessOrder(id, false);
      }
      return artwork;
    } catch (e) {
      return null;
    }
  }

  Widget buildCachedArtwork(int id, {double size = 50}) {
    // Use a unique key based on song ID to prevent unnecessary rebuilds
    return RepaintBoundary(
      key: ValueKey('artwork_$id'),
      child: _ArtworkWidget(
        id: id,
        size: size,
        artworkService: this,
      ),
    );
  }

  Widget buildCachedArtistArtwork(int id,
      {double size = 50, bool circular = false}) {
    return RepaintBoundary(
      key: ValueKey('artist_artwork_$id'),
      child: _ArtistArtworkWidget(
        id: id,
        size: size,
        circular: circular,
        artworkService: this,
      ),
    );
  }

  /// Build widget for album artwork by album ID
  Widget buildCachedAlbumArtwork(int albumId, {double size = 50}) {
    return RepaintBoundary(
      key: ValueKey('album_artwork_$albumId'),
      child: _AlbumArtworkWidget(
        albumId: albumId,
        size: size,
        artworkService: this,
      ),
    );
  }

  /// Get album artwork by album ID
  Future<Uint8List?> getAlbumArtwork(int albumId) async {
    if (_albumArtworkCache.containsKey(albumId) &&
        _albumArtworkCache[albumId] != null) {
      return _albumArtworkCache[albumId];
    }

    try {
      final artwork = await _audioQuery.queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        quality: 100,
        size: 500,
      );

      if (artwork != null && artwork.isNotEmpty) {
        _albumArtworkCache[albumId] = artwork;
        _updateAlbumAccessOrder(albumId);
      }
      return artwork;
    } catch (e) {
      return null;
    }
  }

  /// Get album image provider
  Future<ImageProvider<Object>> getAlbumImageProvider(int albumId) async {
    try {
      if (_albumImageProviderCache.containsKey(albumId)) {
        _updateAlbumAccessOrder(albumId);
        return _albumImageProviderCache[albumId] ??
            const AssetImage('assets/images/logo/default_art.png');
      }

      _evictAlbumLRUIfNeeded();
      final artwork = await getAlbumArtwork(albumId);
      final ImageProvider<Object> provider = artwork != null
          ? MemoryImage(artwork)
          : const AssetImage('assets/images/logo/default_art.png')
              as ImageProvider<Object>;

      _albumImageProviderCache[albumId] = provider;
      _updateAlbumAccessOrder(albumId);
      return provider;
    } catch (e) {
      return const AssetImage('assets/images/logo/default_art.png');
    }
  }

  /// Get cached album image provider synchronously
  ImageProvider<Object>? getCachedAlbumImageProviderSync(int albumId) {
    if (_albumImageProviderCache.containsKey(albumId)) {
      _updateAlbumAccessOrder(albumId);
      return _albumImageProviderCache[albumId];
    }
    return null;
  }

  void _updateAlbumAccessOrder(int id) {
    _albumAccessOrder.remove(id);
    _albumAccessOrder.add(id);
  }

  void _evictAlbumLRUIfNeeded() {
    if (_albumArtworkCache.length >= _maxArtworkCacheSize &&
        _albumAccessOrder.isNotEmpty) {
      final lruId = _albumAccessOrder.removeAt(0);
      _albumArtworkCache.remove(lruId);
      _albumImageProviderCache.remove(lruId);
    }
  }

  Future<Uint8List?> getArtistArtwork(int id) async {
    if (_artistArtworkCache.containsKey(id) &&
        _artistArtworkCache[id] != null) {
      return _artistArtworkCache[id];
    }

    try {
      final artwork = await _audioQuery.queryArtwork(
        id,
        ArtworkType.ARTIST,
        quality: 100,
        size: 500,
      );

      if (artwork != null && artwork.isNotEmpty) {
        _artistArtworkCache[id] = artwork;
        _updateAccessOrder(id, true);
      }
      return artwork;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> getArtwork(int id) async {
    return _getArtwork(id);
  }

  Future<void> preloadArtwork(int id) async {
    try {
      if (_artworkCache.containsKey(id)) {
        _updateAccessOrder(id, false);
        return;
      }

      _evictLRUIfNeeded(false);
      final artwork = await _audioQuery
          .queryArtwork(
            id,
            ArtworkType.AUDIO,
            quality: 100,
            size: 500,
          )
          .timeout(
            const Duration(
                seconds: 3), // Reduced timeout for better performance
            onTimeout: () => null,
          );

      if (artwork != null) {
        _artworkCache[id] = artwork;
        _imageProviderCache[id] = MemoryImage(artwork);
        _updateAccessOrder(id, false);
      }
    } catch (e) {}
  }

  Future<void> preloadArtistArtwork(int id) async {
    try {
      if (_artistArtworkCache.containsKey(id)) {
        _updateAccessOrder(id, true);
        return;
      }

      _evictLRUIfNeeded(true);
      final artwork = await _audioQuery
          .queryArtwork(
            id,
            ArtworkType.ARTIST,
            quality: 100,
            size: 500,
          )
          .timeout(
            const Duration(
                seconds: 3), // Reduced timeout for better performance
            onTimeout: () => null,
          );

      if (artwork != null) {
        _artistArtworkCache[id] = artwork;
        _artistImageProviderCache[id] = MemoryImage(artwork);
        _updateAccessOrder(id, true);
      }
    } catch (e) {}
  }

  Future<ImageProvider<Object>> getArtistImageProvider(int id) async {
    try {
      if (_artistImageProviderCache.containsKey(id)) {
        _updateAccessOrder(id, true);
        return _artistImageProviderCache[id] ??
            const AssetImage('assets/images/logo/default_art.png');
      }

      await preloadArtistArtwork(id);
      return _artistImageProviderCache[id] ??
          const AssetImage('assets/images/logo/default_art.png');
    } catch (e) {
      return const AssetImage('assets/images/logo/default_art.png');
    }
  }

  /// Get artist image by name from Spotify API cache
  Future<String?> getArtistImageByName(String artistName) async {
    // Check memory cache first
    if (_artistNameImageCache.containsKey(artistName)) {
      return _artistNameImageCache[artistName];
    }

    // Fetch from local caching service (which handles file cache and API)
    final imagePath = await _localCachingService.fetchArtistImage(artistName);
    _artistNameImageCache[artistName] = imagePath;

    if (imagePath != null) {
      _artistNameProviderCache[artistName] = FileImage(File(imagePath));
    }

    return imagePath;
  }

  /// Get cached artist image provider by name
  Future<ImageProvider<Object>?> getArtistImageProviderByName(
      String artistName) async {
    // Check provider cache first
    if (_artistNameProviderCache.containsKey(artistName)) {
      return _artistNameProviderCache[artistName];
    }

    final imagePath = await getArtistImageByName(artistName);
    if (imagePath != null) {
      final provider = FileImage(File(imagePath));
      _artistNameProviderCache[artistName] = provider;
      return provider;
    }

    return null;
  }

  /// Check if artist image is already cached (sync check)
  String? getCachedArtistImageByNameSync(String artistName) {
    return _artistNameImageCache[artistName];
  }

  /// Build widget for artist image by name (from Spotify API)
  Widget buildArtistImageByName(String artistName,
      {double size = 50, bool circular = false}) {
    return RepaintBoundary(
      key: ValueKey('artist_name_$artistName'),
      child: _ArtistNameImageWidget(
        artistName: artistName,
        size: size,
        circular: circular,
        artworkService: this,
      ),
    );
  }

  void clearCache() {
    _artworkCache.clear();
    _imageProviderCache.clear();
    _artistArtworkCache.clear();
    _artistImageProviderCache.clear();
    _albumArtworkCache.clear();
    _albumImageProviderCache.clear();
    _artistNameImageCache.clear();
    _artistNameProviderCache.clear();
    _artworkAccessOrder.clear();
    _artistAccessOrder.clear();
    _albumAccessOrder.clear();
  }
}

/// Stateful widget for displaying album artwork by album ID
class _AlbumArtworkWidget extends StatefulWidget {
  final int albumId;
  final double size;
  final ArtworkCacheService artworkService;

  const _AlbumArtworkWidget({
    required this.albumId,
    required this.size,
    required this.artworkService,
  });

  @override
  State<_AlbumArtworkWidget> createState() => _AlbumArtworkWidgetState();
}

class _AlbumArtworkWidgetState extends State<_AlbumArtworkWidget> {
  ImageProvider<Object>? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(_AlbumArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    // Check sync cache first
    final cachedProvider =
        widget.artworkService.getCachedAlbumImageProviderSync(widget.albumId);

    if (cachedProvider != null) {
      if (mounted) {
        setState(() {
          _imageProvider = cachedProvider;
          _isLoading = false;
        });
      }
      return;
    }

    // Load asynchronously
    final provider =
        await widget.artworkService.getAlbumImageProvider(widget.albumId);
    if (mounted) {
      setState(() {
        _imageProvider = provider;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageProvider != null && !_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: _imageProvider!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.album, color: Colors.white),
    );
  }
}

/// Stateful widget for displaying artwork - prevents rebuilds in parent
class _ArtworkWidget extends StatefulWidget {
  final int id;
  final double size;
  final ArtworkCacheService artworkService;

  const _ArtworkWidget({
    required this.id,
    required this.size,
    required this.artworkService,
  });

  @override
  State<_ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<_ArtworkWidget> {
  ImageProvider<Object>? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(_ArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    // Check sync cache first
    final cachedProvider =
        widget.artworkService.getCachedImageProviderSync(widget.id);

    if (cachedProvider != null) {
      if (mounted) {
        setState(() {
          _imageProvider = cachedProvider;
          _isLoading = false;
        });
      }
      return;
    }

    // Load asynchronously
    final provider =
        await widget.artworkService.getCachedImageProvider(widget.id);
    if (mounted) {
      setState(() {
        _imageProvider = provider;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageProvider != null && !_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: _imageProvider!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.white),
    );
  }
}

/// Stateful widget for displaying artist artwork
class _ArtistArtworkWidget extends StatefulWidget {
  final int id;
  final double size;
  final bool circular;
  final ArtworkCacheService artworkService;

  const _ArtistArtworkWidget({
    required this.id,
    required this.size,
    required this.artworkService,
    this.circular = false,
  });

  @override
  State<_ArtistArtworkWidget> createState() => _ArtistArtworkWidgetState();
}

class _ArtistArtworkWidgetState extends State<_ArtistArtworkWidget> {
  ImageProvider<Object>? _imageProvider;
  bool _isLoading = true;
  bool _hasArtwork = false;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(_ArtistArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    try {
      final provider =
          await widget.artworkService.getArtistImageProvider(widget.id);
      final artwork = await widget.artworkService.getArtistArtwork(widget.id);

      if (mounted) {
        setState(() {
          _imageProvider = provider;
          _hasArtwork = artwork != null && artwork.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasArtwork = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.circular
        ? BorderRadius.circular(widget.size / 2)
        : BorderRadius.circular(8);

    if (_hasArtwork && _imageProvider != null && !_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(
            image: _imageProvider!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback to person icon
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.6),
        size: widget.size * 0.5,
      ),
    );
  }
}

/// Widget for displaying artist image by name (from Spotify API)
class _ArtistNameImageWidget extends StatefulWidget {
  final String artistName;
  final double size;
  final bool circular;
  final ArtworkCacheService artworkService;

  const _ArtistNameImageWidget({
    required this.artistName,
    required this.size,
    required this.artworkService,
    this.circular = false,
  });

  @override
  State<_ArtistNameImageWidget> createState() => _ArtistNameImageWidgetState();
}

class _ArtistNameImageWidgetState extends State<_ArtistNameImageWidget> {
  ImageProvider<Object>? _imageProvider;
  bool _isLoading = true;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_ArtistNameImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check sync cache first
      final cachedPath = widget.artworkService
          .getCachedArtistImageByNameSync(widget.artistName);
      if (cachedPath != null) {
        if (mounted) {
          setState(() {
            _imageProvider = FileImage(File(cachedPath));
            _hasImage = true;
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch from API/cache
      final provider = await widget.artworkService
          .getArtistImageProviderByName(widget.artistName);
      if (mounted) {
        setState(() {
          _imageProvider = provider;
          _hasImage = provider != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.circular
        ? BorderRadius.circular(widget.size / 2)
        : BorderRadius.circular(8);

    if (_hasImage && _imageProvider != null && !_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: DecorationImage(
            image: _imageProvider!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback to person icon
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.6),
        size: widget.size * 0.5,
      ),
    );
  }
}

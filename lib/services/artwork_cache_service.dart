import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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

  // LRU tracking for cache eviction
  final List<int> _artworkAccessOrder = [];
  final List<int> _artistAccessOrder = [];

  Future<void> initialize() async {
    await _initializeCache();
    await _preloadCommonArtwork();
  }

  Future<void> _initializeCache() async {
    // Clear existing cache and access tracking
    _artworkCache.clear();
    _imageProviderCache.clear();
    _artistArtworkCache.clear();
    _artistImageProviderCache.clear();
    _artworkAccessOrder.clear();
    _artistAccessOrder.clear();
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
    if (_artworkCache.containsKey(id)) {
      return _artworkCache[id];
    }

    try {
      final artwork = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 500,
      );
      _artworkCache[id] = artwork;
      return artwork;
    } catch (e) {
      return null;
    }
  }

  Widget buildCachedArtwork(int id, {double size = 50}) {
    // Check if already in cache for instant display
    final cachedProvider = getCachedImageProviderSync(id);

    if (cachedProvider != null) {
      // Display cached artwork immediately with no loading state
      return RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: cachedProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // Not in cache, load asynchronously
    return RepaintBoundary(
      child: FutureBuilder<ImageProvider<Object>>(
        future: getCachedImageProvider(id),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: snapshot.data!,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note, color: Colors.white),
          );
        },
      ),
    );
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

  void clearCache() {
    _artworkCache.clear();
    _imageProviderCache.clear();
    _artistArtworkCache.clear();
    _artistImageProviderCache.clear();
    _artworkAccessOrder.clear();
    _artistAccessOrder.clear();
  }
}

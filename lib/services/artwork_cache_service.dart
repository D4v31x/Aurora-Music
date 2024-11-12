import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class ArtworkCacheService {
  static final ArtworkCacheService _instance = ArtworkCacheService._internal();
  factory ArtworkCacheService() => _instance;
  ArtworkCacheService._internal();

  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};
  final OnAudioQuery _audioQuery = OnAudioQuery();

  final Map<int, Uint8List?> _artistArtworkCache = {};
  final Map<int, ImageProvider<Object>?> _artistImageProviderCache = {};

  Future<void> initialize() async {
    await _initializeCache();
    await _preloadCommonArtwork();
  }

  Future<void> _initializeCache() async {
    // Vyčistíme existující cache při inicializaci
    _artworkCache.clear();
    _imageProviderCache.clear();
    _artistArtworkCache.clear();
    _artistImageProviderCache.clear();
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
        chunks.add(
          songsToPreload.skip(i).take(5).toList()
        );
      }

      for (var chunk in chunks) {
        await Future.wait(
          chunk.map((song) => _getArtwork(song.id))
        );
      }
    } catch (e) {
      
    }
  }

  Future<ImageProvider<Object>> getCachedImageProvider(int id) async {
    try {
      if (_imageProviderCache.containsKey(id)) {
        return _imageProviderCache[id] ?? 
               const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
      }

      final artwork = await _getArtwork(id);
      final ImageProvider<Object> provider = artwork != null 
          ? MemoryImage(artwork) 
          : const AssetImage('assets/images/logo/default_art.png') as ImageProvider<Object>;
      
      _imageProviderCache[id] = provider;
      return provider;
    } catch (e) {
      
      return const AssetImage('assets/images/logo/default_art.png');
    }
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
        size: 1000,
      );
      _artworkCache[id] = artwork;
      return artwork;
    } catch (e) {
      
      return null;
    }
  }

  Widget buildCachedArtwork(int id, {double size = 50}) {
    return FutureBuilder<ImageProvider<Object>>(
      future: getCachedImageProvider(id),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.music_note, color: Colors.white),
        );
      },
    );
  }

  Future<Uint8List?> getArtwork(int id) async {
    return _getArtwork(id);
  }

  Future<void> preloadArtwork(int id) async {
    try {
      if (_artworkCache.containsKey(id)) return;

      final artwork = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 1000,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (artwork != null) {
        _artworkCache[id] = artwork;
        _imageProviderCache[id] = MemoryImage(artwork);
      }
    } catch (e) {
      
    }
  }

  Future<void> preloadArtistArtwork(int id) async {
    try {
      if (_artistArtworkCache.containsKey(id)) return;

      final artwork = await _audioQuery.queryArtwork(
        id,
        ArtworkType.ARTIST,
        quality: 100,
        size: 1000,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (artwork != null) {
        _artistArtworkCache[id] = artwork;
        _artistImageProviderCache[id] = MemoryImage(artwork);
      }
    } catch (e) {
      
    }
  }

  Future<ImageProvider<Object>> getArtistImageProvider(int id) async {
    try {
      if (_artistImageProviderCache.containsKey(id)) {
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
  }
} 
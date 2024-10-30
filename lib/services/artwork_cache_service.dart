import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class ArtworkCacheService {
  static final ArtworkCacheService _instance = ArtworkCacheService._internal();
  factory ArtworkCacheService() => _instance;
  ArtworkCacheService._internal();

  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, ImageProvider<Object>?> _imageProviderCache = {};

  Future<ImageProvider<Object>> getCachedImageProvider(int id) async {
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
  }

  Future<Uint8List?> _getArtwork(int id) async {
    if (_artworkCache.containsKey(id)) {
      return _artworkCache[id];
    }
    
    try {
      final artwork = await OnAudioQuery().queryArtwork(
        id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 1000,
      );
      _artworkCache[id] = artwork;
      return artwork;
    } catch (e) {
      print('Error loading artwork: $e');
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
} 
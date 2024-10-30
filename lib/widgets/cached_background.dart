import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:typed_data';

class ImageCacheManager {
  static final Map<int, Uint8List?> _artworkCache = {};
  static final Map<int, ImageProvider> _imageProviderCache = {};

  static Future<ImageProvider> getArtworkProvider(int songId, OnAudioQuery audioQuery) async {
    if (_imageProviderCache.containsKey(songId)) {
      return _imageProviderCache[songId]!;
    }

    final artwork = await _getArtwork(songId, audioQuery);
    final provider = artwork != null
        ? MemoryImage(artwork)
        : const AssetImage('assets/images/logo/default_art.png') as ImageProvider;

    _imageProviderCache[songId] = provider;
    return provider;
  }

  static Future<Uint8List?> _getArtwork(int songId, OnAudioQuery audioQuery) async {
    if (_artworkCache.containsKey(songId)) {
      return _artworkCache[songId];
    }

    final artwork = await audioQuery.queryArtwork(songId, ArtworkType.AUDIO);
    _artworkCache[songId] = artwork;
    return artwork;
  }

  static void clearCache() {
    _artworkCache.clear();
    _imageProviderCache.clear();
  }
}

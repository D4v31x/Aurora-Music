/// Resolves an [ImageElement]'s [ImageSource] to a decoded `ui.Image` once
/// (per song-change for [CurrentArtworkSource], once ever for
/// [AssetImageSource]) and caches it — the painter only ever reads an
/// already-decoded image, never decodes/allocates during paint (spec
/// section 14: no expensive work in the render loop).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../shared/services/artwork_cache_service.dart';
import '../../../shared/services/audio_player_service.dart';
import '../model/visualizer_element.dart';

class ImageElementResolver {
  final AudioPlayerService audioService;
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  final Map<String, ui.Image> _resolvedByElementId = {};
  final Map<String, ImageStreamListener> _listenersByElementId = {};
  final Map<String, ImageStream> _streamsByElementId = {};
  List<ImageElement> _trackedElements = const [];
  int? _lastArtworkSongId;

  ImageElementResolver(this.audioService) {
    audioService.currentSongNotifier.addListener(_onSongChanged);
  }

  ui.Image? imageFor(String elementId) => _resolvedByElementId[elementId];

  /// Call once per template load with the template's [ImageElement]s so
  /// their sources get resolved (and re-resolved automatically on song
  /// change for [CurrentArtworkSource] elements).
  void resolveAll(Iterable<ImageElement> elements) {
    _trackedElements = elements.toList(growable: false);
    for (final element in _trackedElements) {
      _resolve(element);
    }
  }

  void _onSongChanged() {
    final songId = audioService.currentSong?.id;
    if (songId == _lastArtworkSongId) return;
    _lastArtworkSongId = songId;
    for (final element in _trackedElements) {
      if (element.source is CurrentArtworkSource) _resolve(element);
    }
  }

  void _resolve(ImageElement element) {
    final source = element.source;
    if (source is AssetImageSource) {
      if (_resolvedByElementId.containsKey(element.id)) return; // static, resolve once
      _listen(element.id, AssetImage(source.path));
    } else if (source is CurrentArtworkSource) {
      final songId = audioService.currentSong?.id;
      if (songId == null) return;
      unawaited(_resolveCurrentArtwork(element.id, songId));
    }
  }

  Future<void> _resolveCurrentArtwork(String elementId, int songId) async {
    try {
      final provider = await _artworkService.getCachedImageProvider(songId);
      _listen(elementId, provider);
    } catch (_) {
      // No artwork available — leave any previously-resolved image in
      // place rather than clearing it, avoiding a visible flash.
    }
  }

  void _listen(String elementId, ImageProvider provider) {
    _detach(elementId);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) => _resolvedByElementId[elementId] = info.image,
      onError: (_, __) {},
    );
    stream.addListener(listener);
    _streamsByElementId[elementId] = stream;
    _listenersByElementId[elementId] = listener;
  }

  void _detach(String elementId) {
    final stream = _streamsByElementId.remove(elementId);
    final listener = _listenersByElementId.remove(elementId);
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  void dispose() {
    audioService.currentSongNotifier.removeListener(_onSongChanged);
    for (final elementId in List<String>.from(_streamsByElementId.keys)) {
      _detach(elementId);
    }
  }
}


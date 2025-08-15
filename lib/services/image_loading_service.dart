import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/cache_manager.dart';
import '../services/logging_service.dart';
import '../constants/animation_constants.dart';

/// Optimized image loading service with caching and error handling
class ImageLoadingService {
  static final ImageLoadingService _instance = ImageLoadingService._internal();
  factory ImageLoadingService() => _instance;
  ImageLoadingService._internal();

  final CacheManager _cacheManager = CacheManager();

  /// Loads artwork with caching and optimization
  Future<Uint8List?> loadArtwork(
    int songId, {
    int size = 200,
    int quality = 70,
    bool useCache = true,
  }) async {
    final cacheKey = 'artwork_${songId}_${size}_$quality';

    // Check cache first
    if (useCache) {
      final cachedArtwork = _cacheManager.getArtwork(cacheKey);
      if (cachedArtwork != null) {
        return cachedArtwork;
      }
    }

    try {
      // Load artwork from audio query
      final artwork = await OnAudioQuery().queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: size,
        quality: quality,
      );

      // Cache the result if valid
      if (artwork != null && useCache) {
        _cacheManager.putArtwork(cacheKey, artwork);
      }

      return artwork;
    } catch (e) {
      LoggingService.error('Failed to load artwork for song $songId', 'ImageLoadingService', e);
      return null;
    }
  }

  /// Loads artwork for albums
  Future<Uint8List?> loadAlbumArtwork(
    int albumId, {
    int size = 200,
    int quality = 70,
    bool useCache = true,
  }) async {
    final cacheKey = 'album_artwork_${albumId}_${size}_$quality';

    if (useCache) {
      final cachedArtwork = _cacheManager.getArtwork(cacheKey);
      if (cachedArtwork != null) {
        return cachedArtwork;
      }
    }

    try {
      final artwork = await OnAudioQuery().queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        size: size,
        quality: quality,
      );

      if (artwork != null && useCache) {
        _cacheManager.putArtwork(cacheKey, artwork);
      }

      return artwork;
    } catch (e) {
      LoggingService.error('Failed to load album artwork for $albumId', 'ImageLoadingService', e);
      return null;
    }
  }

  /// Loads artwork for artists
  Future<Uint8List?> loadArtistArtwork(
    int artistId, {
    int size = 200,
    int quality = 70,
    bool useCache = true,
  }) async {
    final cacheKey = 'artist_artwork_${artistId}_${size}_$quality';

    if (useCache) {
      final cachedArtwork = _cacheManager.getArtwork(cacheKey);
      if (cachedArtwork != null) {
        return cachedArtwork;
      }
    }

    try {
      final artwork = await OnAudioQuery().queryArtwork(
        artistId,
        ArtworkType.ARTIST,
        size: size,
        quality: quality,
      );

      if (artwork != null && useCache) {
        _cacheManager.putArtwork(cacheKey, artwork);
      }

      return artwork;
    } catch (e) {
      LoggingService.error('Failed to load artist artwork for $artistId', 'ImageLoadingService', e);
      return null;
    }
  }

  /// Preloads artwork for better performance
  Future<void> preloadArtwork(List<int> songIds) async {
    try {
      final futures = songIds.map((id) => loadArtwork(id, size: 100, quality: 50));
      await Future.wait(futures);
      LoggingService.debug('Preloaded artwork for ${songIds.length} songs', 'ImageLoadingService');
    } catch (e) {
      LoggingService.error('Failed to preload artwork', 'ImageLoadingService', e);
    }
  }

  /// Creates an optimized image provider
  ImageProvider? createImageProvider(Uint8List? imageData) {
    if (imageData == null) return null;
    return MemoryImage(imageData);
  }

  /// Creates a placeholder widget
  Widget createPlaceholder({
    double size = 200,
    Color? backgroundColor,
    Color? iconColor,
    IconData icon = Icons.music_note,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: size * 0.3,
        color: iconColor ?? Colors.grey[600],
      ),
    );
  }

  /// Creates an error widget
  Widget createErrorWidget({
    double size = 200,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.error_outline,
        size: size * 0.3,
        color: iconColor ?? Colors.red[600],
      ),
    );
  }

  /// Optimizes image for display
  Future<ui.Image?> optimizeImage(Uint8List imageData, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      LoggingService.error('Failed to optimize image', 'ImageLoadingService', e);
      return null;
    }
  }

  /// Clears image cache
  void clearCache() {
    _cacheManager.clearArtworkCache();
    LoggingService.info('Image cache cleared', 'ImageLoadingService');
  }

  /// Gets cache statistics
  Map<String, dynamic> getCacheStats() {
    final sizes = _cacheManager.getCacheSizes();
    final hitRates = _cacheManager.getCacheHitRates();
    
    return {
      'artwork_cache_size': sizes['artwork'] ?? 0,
      'artwork_hit_rate': hitRates['artwork'] ?? 0.0,
      'estimated_memory': _cacheManager.getEstimatedMemoryUsage(),
    };
  }
}

/// Widget for optimized image loading with fade animation
class OptimizedImage extends StatefulWidget {
  final int? songId;
  final int? albumId;
  final int? artistId;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableFadeAnimation;
  final int imageSize;
  final int imageQuality;

  const OptimizedImage({
    super.key,
    this.songId,
    this.albumId,
    this.artistId,
    required this.width,
    required this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableFadeAnimation = true,
    this.imageSize = 200,
    this.imageQuality = 70,
  }) : assert(songId != null || albumId != null || artistId != null,
         'At least one ID must be provided');

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final ImageLoadingService _imageService = ImageLoadingService();
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: AnimationConstants.fast,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: AnimationConstants.easeInOut,
    ));

    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.songId != widget.songId ||
        oldWidget.albumId != widget.albumId ||
        oldWidget.artistId != widget.artistId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      Uint8List? imageData;

      if (widget.songId != null) {
        imageData = await _imageService.loadArtwork(
          widget.songId!,
          size: widget.imageSize,
          quality: widget.imageQuality,
        );
      } else if (widget.albumId != null) {
        imageData = await _imageService.loadAlbumArtwork(
          widget.albumId!,
          size: widget.imageSize,
          quality: widget.imageQuality,
        );
      } else if (widget.artistId != null) {
        imageData = await _imageService.loadArtistArtwork(
          widget.artistId!,
          size: widget.imageSize,
          quality: widget.imageQuality,
        );
      }

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _isLoading = false;
          _hasError = imageData == null;
        });

        if (widget.enableFadeAnimation && imageData != null) {
          _fadeController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Widget _buildImageWidget() {
    if (_isLoading) {
      return widget.placeholder ?? _imageService.createPlaceholder(
        size: widget.width,
      );
    }

    if (_hasError || _imageData == null) {
      return widget.errorWidget ?? _imageService.createErrorWidget(
        size: widget.width,
      );
    }

    final imageWidget = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        image: DecorationImage(
          image: MemoryImage(_imageData!),
          fit: widget.fit,
        ),
      ),
    );

    if (widget.enableFadeAnimation) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: _buildImageWidget(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
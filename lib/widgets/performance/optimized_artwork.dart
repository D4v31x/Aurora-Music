import 'package:flutter/material.dart';
import '../../services/artwork_cache_service.dart';

/// Optimized artwork widget that automatically includes RepaintBoundary
/// and proper memory management for image loading
class OptimizedArtwork extends StatelessWidget {
  final int songId;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const OptimizedArtwork({
    super.key,
    required this.songId,
    this.size = 50,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final artworkService = ArtworkCacheService();
    
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: artworkService.buildCachedArtwork(
            songId,
            size: size,
          ),
        ),
      ),
    );
  }
}
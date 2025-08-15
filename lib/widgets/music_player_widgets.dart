import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../constants/animation_constants.dart';

/// Reusable artwork widget with caching and animations
/// Provides optimized artwork display for music players
class MusicArtworkWidget extends StatefulWidget {
  final SongModel? song;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final bool enableHeroAnimation;
  final String? heroTag;

  const MusicArtworkWidget({
    super.key,
    this.song,
    required this.size,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.enableHeroAnimation = false,
    this.heroTag,
  });

  @override
  State<MusicArtworkWidget> createState() => _MusicArtworkWidgetState();
}

class _MusicArtworkWidgetState extends State<MusicArtworkWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Uint8List? _artworkData;
  bool _isLoading = true;
  ImageProvider<Object>? _imageProvider;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AnimationConstants.normalDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: AnimationConstants.easeInOutCurve,
    ));

    _loadArtwork();
  }

  @override
  void didUpdateWidget(MusicArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    if (widget.song == null) {
      setState(() {
        _isLoading = false;
        _artworkData = null;
        _imageProvider = null;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final artworkData = await OnAudioQuery().queryArtwork(
        widget.song!.id,
        ArtworkType.AUDIO,
        size: widget.size.toInt(),
        quality: 100,
      );

      if (mounted) {
        setState(() {
          _artworkData = artworkData;
          _imageProvider = artworkData != null 
              ? MemoryImage(artworkData) 
              : null;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _artworkData = null;
          _imageProvider = null;
        });
      }
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: Icon(
        Icons.music_note,
        size: widget.size * 0.3,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildArtwork() {
    if (_isLoading) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: widget.borderRadius,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_imageProvider == null) {
      return _buildPlaceholder();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          image: DecorationImage(
            image: _imageProvider!,
            fit: widget.fit,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artworkWidget = RepaintBoundary(
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: _buildArtwork(),
      ),
    );

    if (widget.enableHeroAnimation && widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: artworkWidget,
      );
    }

    return artworkWidget;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}

/// Reusable progress bar widget for audio players
/// Provides consistent progress indication with customizable styling
class MusicProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;
  final bool showLabels;

  const MusicProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.onSeek,
    this.activeColor,
    this.inactiveColor,
    this.height = 4.0,
    this.showLabels = true,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: height,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: activeColor ?? theme.primaryColor,
            inactiveTrackColor: inactiveColor ?? theme.disabledColor,
            thumbColor: activeColor ?? theme.primaryColor,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: onSeek != null 
                ? (value) {
                    final newPosition = Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    );
                    onSeek!(newPosition);
                  }
                : null,
          ),
        ),
        if (showLabels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  _formatDuration(duration),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Reusable playback controls widget
/// Provides standard music player controls with customizable styling
class MusicPlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool isShuffle;
  final bool isRepeat;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final Color? iconColor;
  final double iconSize;

  const MusicPlaybackControls({
    super.key,
    required this.isPlaying,
    required this.isShuffle,
    required this.isRepeat,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onShuffle,
    this.onRepeat,
    this.iconColor,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.iconTheme.color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onShuffle,
          icon: Icon(
            isShuffle ? Icons.shuffle : Icons.shuffle,
            color: isShuffle ? theme.primaryColor : color,
            size: iconSize * 0.8,
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: Icon(
            Icons.skip_previous,
            color: color,
            size: iconSize,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.primaryColor,
          ),
          child: IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: iconSize * 1.2,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.skip_next,
            color: color,
            size: iconSize,
          ),
        ),
        IconButton(
          onPressed: onRepeat,
          icon: Icon(
            isRepeat ? Icons.repeat_one : Icons.repeat,
            color: isRepeat ? theme.primaryColor : color,
            size: iconSize * 0.8,
          ),
        ),
      ],
    );
  }
}
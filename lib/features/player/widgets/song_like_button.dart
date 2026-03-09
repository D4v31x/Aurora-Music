import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/services/audio_player_service.dart';

/// A like/favorite button for the current song.
///
/// Plays a scale-bounce + particle-burst animation when liking a song.
class SongLikeButton extends StatefulWidget {
  final AudioPlayerService audioPlayerService;
  final double size;
  final Color likedColor;
  final Color unlikedColor;

  const SongLikeButton({
    super.key,
    required this.audioPlayerService,
    this.size = 30,
    this.likedColor = Colors.red,
    this.unlikedColor = Colors.white,
  });

  @override
  State<SongLikeButton> createState() => _SongLikeButtonState();
}

class _SongLikeButtonState extends State<SongLikeButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _onTap(bool wasLiked) {
    widget.audioPlayerService.toggleLike(
      widget.audioPlayerService.currentSong!,
    );
    // Only animate when liking (not unliking)
    if (!wasLiked) {
      _scaleController.forward(from: 0.0);
      _particleController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.audioPlayerService.likedSongsNotifier,
      builder: (context, likedSongs, _) {
        final currentSong = widget.audioPlayerService.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final isLiked = likedSongs.contains(currentSong.id.toString());

        return GestureDetector(
          onTap: () => _onTap(isLiked),
          child: SizedBox(
            width: widget.size * 2.4,
            height: widget.size * 2.4,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scaleController, _particleController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    progress: _particleController.value,
                    color: widget.likedColor,
                    iconSize: widget.size,
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? widget.likedColor : widget.unlikedColor,
                        size: widget.size,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double iconSize;

  _ParticlePainter({
    required this.progress,
    required this.color,
    required this.iconSize,
  });

  static const int _count = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0 || progress == 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = iconSize * 1.1;
    // Particles appear after the icon has grown, then fly outward and fade
    final t = Curves.easeOut.transform(progress);
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final distance = maxRadius * t;
    final particleRadius = (iconSize * 0.08) * (1.0 - t * 0.5);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _count; i++) {
      final angle = (2 * math.pi / _count) * i - math.pi / 2;
      final pos = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(pos, particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

import 'package:flutter/material.dart';

class AnimatedProgressIndicator extends StatefulWidget {
  final Color color;
  final double height;
  final double width;

  const AnimatedProgressIndicator({
    super.key,
    this.color = Colors.blue,
    this.height = 4.0,
    this.width = 200.0,
  });

  @override
  _AnimatedProgressIndicatorState createState() => _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ProgressIndicatorPainter(
              progress: _controller.value,
              color: widget.color,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}

class _ProgressIndicatorPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressIndicatorPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dotRadius = size.height / 2;
    final maxWidth = size.width - dotRadius * 2;

    double left, right;

    if (progress < 0.5) {
      // Dot on left to pill in middle to dot on right
      if (progress < 0.25) {
        left = 0;
        right = lerp(dotRadius * 2, size.width / 2, progress * 4);
      } else {
        left = lerp(0, maxWidth, (progress - 0.25) * 4);
        right = size.width;
      }
    } else {
      // Dot on right to pill in middle to dot on left
      if (progress < 0.75) {
        left = lerp(maxWidth, size.width / 2, (progress - 0.5) * 4);
        right = size.width;
      } else {
        left = 0;
        right = lerp(size.width, dotRadius * 2, (progress - 0.75) * 4);
      }
    }

    final rect = RRect.fromLTRBR(
      left,
      0,
      right,
      size.height,
      Radius.circular(dotRadius),
    );
    canvas.drawRRect(rect, paint);
  }

  double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  bool shouldRepaint(_ProgressIndicatorPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
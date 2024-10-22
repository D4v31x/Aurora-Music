import 'package:flutter/material.dart';

class OutlineIndicator extends Decoration {
  const OutlineIndicator({
    this.color = Colors.white,
    this.strokeWidth = 2,
    required this.text,
    this.radius = const Radius.circular(24),
  });

  final Color color;
  final double strokeWidth;
  final String text;
  final Radius radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChange]) {
    return _OutlinePainter(
      color: color,
      strokeWidth: strokeWidth,
      text: text,
      radius: radius,
      onChange: onChange,
    );
  }
}

class _OutlinePainter extends BoxPainter {
  _OutlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.text,
    required this.radius,
    VoidCallback? onChange,
  })  : _paint = Paint()
    ..style = PaintingStyle.stroke
    ..color = color
    ..strokeWidth = strokeWidth,
        super(onChange);

  final Color color;
  final double strokeWidth;
  final String text;
  final Radius radius;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    const Radius radius = Radius.circular(24);
    final Rect rect = offset & configuration.size!;
    final RRect rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: radius,
    );
    canvas.drawRRect(rrect, _paint);
  }
}
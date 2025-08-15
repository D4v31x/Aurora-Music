import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';

/// An animated mesh gradient widget that can transition between different color schemes
class AnimatedMeshGradient extends StatefulWidget {
  final bool isDarkMode;
  final Duration duration;
  final Widget? child;
  final double width;
  final double height;

  const AnimatedMeshGradient({
    super.key,
    required this.isDarkMode,
    this.duration = const Duration(milliseconds: 400),
    this.child,
    this.width = 2,
    this.height = 2,
  });

  @override
  State<AnimatedMeshGradient> createState() => _AnimatedMeshGradientState();
}

class _AnimatedMeshGradientState extends State<AnimatedMeshGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedMeshGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return OMeshGradient(
          mesh: OMeshRect(
            width: widget.width.toInt(),
            height: widget.height.toInt(),
            fallbackColor: widget.isDarkMode 
                ? const Color(0xFF1A237E) 
                : const Color(0xFFE3F2FD),
            vertices: [
              // Top-left corner
              (0.0, 0.0).v.to(widget.isDarkMode 
                  ? const Color(0xFF1A237E) 
                  : const Color(0xFFE3F2FD)),
              // Top-right corner  
              (1.0, 0.0).v.to(widget.isDarkMode 
                  ? const Color(0xFF311B92) 
                  : const Color(0xFFBBDEFB)),
              // Bottom-left corner
              (0.0, 1.0).v.to(widget.isDarkMode 
                  ? const Color(0xFF512DA8) 
                  : const Color(0xFF90CAF9)),
              // Bottom-right corner
              (1.0, 1.0).v.to(widget.isDarkMode 
                  ? const Color(0xFF7B1FA2) 
                  : const Color(0xFF64B5F6)),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
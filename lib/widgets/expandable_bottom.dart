import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/expandable_player_controller.dart';

class ExpandableBottomSheet extends StatefulWidget {
  final Widget minChild;
  final Widget maxChild;
  final double minHeight;

  const ExpandableBottomSheet({
    super.key,
    required this.minChild,
    required this.maxChild,
    this.minHeight = 60.0,
  });

  @override
  _ExpandableBottomSheetState createState() => _ExpandableBottomSheetState();
}

class _ExpandableBottomSheetState extends State<ExpandableBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightFactor = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expandablePlayerController = Provider.of<ExpandablePlayerController>(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.minHeight + (MediaQuery.of(context).size.height - widget.minHeight) * _heightFactor.value,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              _controller.value -= details.primaryDelta! / (MediaQuery.of(context).size.height - widget.minHeight);
            },
            onVerticalDragEnd: (details) {
              if (_controller.isAnimating) return;

              final double flingVelocity = details.velocity.pixelsPerSecond.dy / (MediaQuery.of(context).size.height - widget.minHeight);
              if (flingVelocity.abs() > 2.0) {
                _controller.fling(velocity: -flingVelocity);
                expandablePlayerController.isExpanded ? expandablePlayerController.collapse() : expandablePlayerController.expand();
              } else if (_controller.value < 0.5) {
                _controller.animateTo(0.0);
                expandablePlayerController.collapse();
              } else {
                _controller.animateTo(1.0);
                expandablePlayerController.expand();
              }
            },
            onTap: () {
              if (_controller.value == 0.0) {
                _controller.animateTo(1.0);
                expandablePlayerController.expand();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: ReverseAnimation(_controller),
                      child: widget.minChild,
                    ),
                  ),
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _controller,
                      child: widget.maxChild,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
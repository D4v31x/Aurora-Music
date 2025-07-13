import 'package:flutter/material.dart';

/// Widget that optimizes animations by disabling them during scrolling
class OptimizedScrollView extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  
  const OptimizedScrollView({
    super.key,
    required this.child,
    this.controller,
  });
  
  @override
  State<OptimizedScrollView> createState() => _OptimizedScrollViewState();
}

class _OptimizedScrollViewState extends State<OptimizedScrollView> {
  late ScrollController _scrollController;
  bool _isScrolling = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
      });
      
      // Stop scrolling detection after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isScrolling = false;
          });
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: !_isScrolling, // Disable animations while scrolling
      child: widget.child,
    );
  }
}

/// Widget that uses Transform.translate for performant animations
class PerformantSlideTransition extends StatelessWidget {
  final Animation<Offset> position;
  final Widget child;
  
  const PerformantSlideTransition({
    super.key,
    required this.position,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        return Transform.translate(
          offset: position.value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Optimized AnimatedBuilder that only rebuilds when necessary
class OptimizedAnimatedBuilder extends StatelessWidget {
  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;
  
  const OptimizedAnimatedBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: builder,
      child: child,
    );
  }
}
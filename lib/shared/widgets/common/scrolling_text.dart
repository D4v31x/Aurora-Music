import 'dart:async';
import 'package:flutter/material.dart';

/// A text widget that automatically scrolls horizontally when the text
/// is too long to fit in the available space.
///
/// The text scrolls back and forth with pauses at each end.
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;
  final Duration scrollDuration;

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.scrollDuration = const Duration(seconds: 2),
  });

  @override
  ScrollingTextState createState() => ScrollingTextState();
}

class ScrollingTextState extends State<ScrollingText> {
  late ScrollController _scrollController;
  bool _showScrolling = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        setState(() {
          _showScrolling = _scrollController.position.maxScrollExtent > 0;
        });
        if (_showScrolling) {
          _startScrollingWithPause();
        }
      }
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Reset scroll position when text changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
          setState(() {
            _showScrolling = _scrollController.position.maxScrollExtent > 0;
          });
          if (_showScrolling && !_isScrolling) {
            _startScrollingWithPause();
          }
        }
      });
    }
  }

  Future<void> _startScrollingWithPause() async {
    if (!_showScrolling || _isScrolling) return;

    _isScrolling = true;
    while (_scrollController.hasClients && _showScrolling && mounted) {
      // Wait at start
      await Future.delayed(widget.pauseDuration);

      // Scroll to end
      if (_scrollController.hasClients && mounted) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.scrollDuration,
          curve: Curves.easeInOut,
        );
      }

      // Wait at end
      await Future.delayed(widget.pauseDuration);

      // Scroll back to start
      if (_scrollController.hasClients && mounted) {
        await _scrollController.animateTo(
          0.0,
          duration: widget.scrollDuration,
          curve: Curves.easeInOut,
        );
      }
    }
    _isScrolling = false;
  }

  @override
  void dispose() {
    _showScrolling = false; // Stop the animation loop
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

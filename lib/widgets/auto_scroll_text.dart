import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../constants/animation_constants.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Function(String) onMessageComplete;

  const AutoScrollText({
    Key? key,
    required this.text,
    required this.style,
    required this.onMessageComplete,
  }) : super(key: key);

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _displayedText = '';
  Timer? _messageTimer;
  Timer? _scrollTimer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _displayedText = widget.text;

    _fadeController = AnimationController(
      vsync: this,
      duration: AnimationConstants.normal,
    );

    _fadeAnimation = Tween<double>(
      begin: AnimationConstants.hiddenOpacity,
      end: AnimationConstants.visibleOpacity,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: AnimationConstants.easeInOut),
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMessageTimer();
      _startScrollIfNeeded();
    });
  }

  void _startScrollIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _startScrolling();
    });
  }

  void _startScrolling() {
    if (!mounted || _isAnimating || !_scrollController.hasClients) return;
    _isAnimating = true;

    const baseDuration = 2500; // Slightly faster for better responsiveness
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      maxScroll,
      duration: const Duration(milliseconds: baseDuration),
      curve: AnimationConstants.linear,
    ).then((_) {
      return Future.delayed(AnimationConstants.mediumDelay);
    }).then((_) {
      if (mounted && _scrollController.hasClients) {
        return _scrollController.animateTo(
          0,
          duration: AnimationConstants.slow,
          curve: Curves.easeOut,
        );
      }
    }).then((_) {
      if (!mounted) return;
      _isAnimating = false;
      _scrollTimer?.cancel();
      _scrollTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _startScrolling();
      });
    });
  }

  void _startMessageTimer() {
    if (!mounted) return;

    final bool isScanningMessage = _isScanningMessage();
    if (isScanningMessage) return;

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _fadeToNextMessage();
      }
    });
  }

  bool _isScanningMessage() {
    if (!mounted) return false;
    return widget.text.contains(
      AppLocalizations.of(context).translate('scanning_songs'),
    );
  }

  void _fadeToNextMessage() {
    if (!mounted) return;
    _fadeController.reverse().then((_) {
      if (mounted) {
        widget.onMessageComplete(
            AppLocalizations.of(context).translate('aurora_music')
        );
      }
    });
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      setState(() => _displayedText = widget.text);

      if (!_isScanningMessage()) {
        _fadeController.forward();
      }

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _isAnimating = false;
      _scrollTimer?.cancel();
      _startScrollIfNeeded();
      _startMessageTimer();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _displayedText,
              style: widget.style,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
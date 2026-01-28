import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../l10n/app_localizations.dart';
import '../../core/constants/animation_constants.dart';

class AutoScrollText extends HookWidget {
  final String text;
  final TextStyle style;
  final Function(String) onMessageComplete;

  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    required this.onMessageComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Get localization at build time (safe)
    final localizations = AppLocalizations.of(context);

    final scrollController = useScrollController();
    final fadeController = useAnimationController(
      duration: AnimationConstants.normal,
    );

    final fadeAnimation = useMemoized(
      () => Tween<double>(
        begin: AnimationConstants.hiddenOpacity,
        end: AnimationConstants.visibleOpacity,
      ).animate(
        CurvedAnimation(
            parent: fadeController, curve: AnimationConstants.easeInOut),
      ),
      [fadeController],
    );

    final displayedText = useState(text);
    final isAnimating = useState(false);
    final messageTimer = useRef<Timer?>(null);
    final scrollTimer = useRef<Timer?>(null);
    final isInitialized = useRef(false);
    final isMounted = useRef(true);

    // Set isMounted to false when widget is disposed
    useEffect(() {
      isMounted.value = true;
      return () {
        isMounted.value = false;
      };
    }, const []);

    // Check if scanning message - use captured localizations
    bool isScanningMessage() {
      return text.contains(localizations.translate('scanning_songs'));
    }

    // Fade to next message - use captured localizations
    void fadeToNextMessage() {
      if (!isMounted.value) return;
      fadeController.reverse().then((_) {
        if (isMounted.value) {
          onMessageComplete(localizations.translate('aurora_music'));
        }
      });
    }

    // Start message timer
    void startMessageTimer() {
      if (isScanningMessage()) return;

      messageTimer.value?.cancel();
      messageTimer.value = Timer(const Duration(seconds: 5), () {
        if (isMounted.value) {
          fadeToNextMessage();
        }
      });
    }

    // Start scrolling
    void startScrolling() {
      if (!isMounted.value || isAnimating.value || !scrollController.hasClients) {
        return;
      }
      isAnimating.value = true;

      const baseDuration = 2500;
      final maxScroll = scrollController.position.maxScrollExtent;

      scrollController
          .animateTo(
        maxScroll,
        duration: const Duration(milliseconds: baseDuration),
        curve: AnimationConstants.linear,
      )
          .then((_) {
        if (!isMounted.value) return Future<void>.value();
        return Future.delayed(AnimationConstants.mediumDelay);
      }).then((_) {
        if (!isMounted.value) return Future<void>.value();
        if (scrollController.hasClients) {
          return scrollController.animateTo(
            0,
            duration: AnimationConstants.slow,
            curve: Curves.easeOut,
          );
        }
        return Future<void>.value();
      }).then((_) {
        if (!isMounted.value) return;
        isAnimating.value = false;
        scrollTimer.value?.cancel();
        scrollTimer.value = Timer(const Duration(milliseconds: 1000), () {
          if (isMounted.value) {
            startScrolling();
          }
        });
      });
    }

    // Start scroll if needed
    void startScrollIfNeeded() {
      if (!isMounted.value || !scrollController.hasClients) return;

      final maxScroll = scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      scrollTimer.value?.cancel();
      scrollTimer.value = Timer(const Duration(milliseconds: 800), () {
        if (isMounted.value) {
          startScrolling();
        }
      });
    }

    // Initial setup - only runs once after first build
    useEffect(() {
      if (!isInitialized.value) {
        isInitialized.value = true;
        fadeController.forward();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          startMessageTimer();
          startScrollIfNeeded();
        });
      }

      return () {
        messageTimer.value?.cancel();
        scrollTimer.value?.cancel();
      };
    }, const []);

    // Handle text changes (replaces didUpdateWidget)
    // Skip the first run by checking isInitialized
    useEffect(() {
      if (!isInitialized.value) return null;

      displayedText.value = text;

      if (!isScanningMessage()) {
        fadeController.forward();
      }

      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      isAnimating.value = false;
      scrollTimer.value?.cancel();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        startScrollIfNeeded();
        startMessageTimer();
      });

      return null;
    }, [text]);

    return RepaintBoundary(
      child: FadeTransition(
        opacity: fadeAnimation,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              displayedText.value,
              style: style,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

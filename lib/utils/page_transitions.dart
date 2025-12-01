import 'package:flutter/material.dart';

/// Smooth page transitions for the app
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final bool slideFromBottom;

  SmoothPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 350),
    this.slideFromBottom = false,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            if (slideFromBottom) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                ),
              );
            }

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Shared axis transition (Material 3 style)
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisTransitionType transitionType;

  SharedAxisPageRoute({
    required this.page,
    this.transitionType = SharedAxisTransitionType.horizontal,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.fastOutSlowIn,
            );

            Offset beginOffset;
            switch (transitionType) {
              case SharedAxisTransitionType.horizontal:
                beginOffset = const Offset(0.3, 0);
                break;
              case SharedAxisTransitionType.vertical:
                beginOffset = const Offset(0, 0.3);
                break;
              case SharedAxisTransitionType.scaled:
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );
            }

            return SlideTransition(
              position: Tween<Offset>(
                begin: beginOffset,
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
          },
        );
}

enum SharedAxisTransitionType { horizontal, vertical, scaled }

/// Hero dialog route for smooth hero animation to dialogs/modals
class HeroDialogRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  
  HeroDialogRoute({required this.builder}) : super();

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }
}

/// Extension for easy navigation with transitions
extension NavigatorExtension on NavigatorState {
  Future<T?> pushSmooth<T>(Widget page, {bool slideFromBottom = false}) {
    return push(SmoothPageRoute<T>(page: page, slideFromBottom: slideFromBottom));
  }

  Future<T?> pushSharedAxis<T>(
    Widget page, {
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return push(SharedAxisPageRoute<T>(page: page, transitionType: type));
  }
}

/// Extension for easy navigation from BuildContext
extension ContextNavigatorExtension on BuildContext {
  Future<T?> pushSmooth<T>(Widget page, {bool slideFromBottom = false}) {
    return Navigator.of(this).pushSmooth<T>(page, slideFromBottom: slideFromBottom);
  }

  Future<T?> pushSharedAxis<T>(
    Widget page, {
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return Navigator.of(this).pushSharedAxis<T>(page, type: type);
  }
}

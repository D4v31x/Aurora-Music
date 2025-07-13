import 'package:flutter/material.dart';

/// A stateful widget that automatically keeps alive expensive content
/// to prevent rebuild when parent scrolls. Ideal for complex list items.
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  final bool keepAlive;
  
  const KeepAliveWrapper({
    super.key,
    required this.child,
    this.keepAlive = true,
  });

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return widget.child;
  }
}

/// Enhanced tab wrapper that provides better memory management for tab content
class TabContentWrapper extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final bool preloadWhenInactive;

  const TabContentWrapper({
    super.key,
    required this.child,
    this.isActive = true,
    this.preloadWhenInactive = false,
  });

  @override
  State<TabContentWrapper> createState() => _TabContentWrapperState();
}

class _TabContentWrapperState extends State<TabContentWrapper>
    with AutomaticKeepAliveClientMixin {
  
  bool _hasBeenBuilt = false;

  @override
  bool get wantKeepAlive => _hasBeenBuilt;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (!_hasBeenBuilt && (widget.isActive || widget.preloadWhenInactive)) {
      _hasBeenBuilt = true;
    }

    if (!_hasBeenBuilt) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: widget.child,
    );
  }
}
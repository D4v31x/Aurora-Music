import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Device type based on screen width
enum DeviceType {
  phone,
  tablet,
  largeTablet,
}

/// Orientation-aware layout mode
enum LayoutMode {
  /// Single column layout (phones, tablets in portrait)
  singleColumn,

  /// Two column layout (tablets in landscape)
  twoColumn,

  /// Wide layout with side panel (large tablets in landscape)
  wideWithPanel,
}

/// Responsive breakpoints and utilities for adapting UI to different screen sizes
class ResponsiveUtils {
  /// Screen width breakpoints
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 900;
  static const double largeTabletMaxWidth = 1200;

  /// Minimum width to show split view (two columns)
  static const double splitViewMinWidth = 720;

  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMaxWidth) {
      return DeviceType.phone;
    } else if (width < tabletMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.largeTablet;
    }
  }

  /// Check if the device is a tablet (or larger)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= phoneMaxWidth;
  }

  /// Check if the device is a large tablet
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMaxWidth;
  }

  /// Get the current layout mode based on screen size and orientation
  static LayoutMode getLayoutMode(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isLandscape = size.width > size.height;

    if (width < phoneMaxWidth) {
      return LayoutMode.singleColumn;
    } else if (width < splitViewMinWidth) {
      return LayoutMode.singleColumn;
    } else if (width < largeTabletMaxWidth) {
      return isLandscape ? LayoutMode.twoColumn : LayoutMode.singleColumn;
    } else {
      return isLandscape ? LayoutMode.wideWithPanel : LayoutMode.twoColumn;
    }
  }

  /// Get the optimal number of grid columns based on screen width
  static int getGridColumns(BuildContext context,
      {int minColumns = 2, int maxColumns = 6}) {
    final width = MediaQuery.of(context).size.width;
    // Aim for items around 150-200px wide
    final idealColumns = (width / 180).floor();
    return idealColumns.clamp(minColumns, maxColumns);
  }

  /// Get the optimal number of columns for a list of cards/tiles
  static int getCardColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMaxWidth) {
      return 1;
    } else if (width < tabletMaxWidth) {
      return 2;
    } else if (width < largeTabletMaxWidth) {
      return 3;
    } else {
      return 4;
    }
  }

  /// Get responsive horizontal padding
  static double getHorizontalPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 16.0;
      case DeviceType.tablet:
        return 24.0;
      case DeviceType.largeTablet:
        return 32.0;
    }
  }

  /// Get responsive content max width (for centering on large screens)
  static double getContentMaxWidth(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return double.infinity;
      case DeviceType.tablet:
        return 900.0;
      case DeviceType.largeTablet:
        return 1200.0;
    }
  }

  /// Get responsive font scale factor
  static double getFontScale(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 1.0;
      case DeviceType.tablet:
        return 1.1;
      case DeviceType.largeTablet:
        return 1.15;
    }
  }

  /// Get responsive icon size multiplier
  static double getIconScale(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 1.0;
      case DeviceType.tablet:
        return 1.2;
      case DeviceType.largeTablet:
        return 1.3;
    }
  }

  /// Get the width ratio for the main content in a two-column layout
  static double getMainContentRatio(BuildContext context) {
    final layoutMode = getLayoutMode(context);
    switch (layoutMode) {
      case LayoutMode.singleColumn:
        return 1.0;
      case LayoutMode.twoColumn:
        return 0.6;
      case LayoutMode.wideWithPanel:
        return 0.65;
    }
  }

  /// Get the width ratio for the detail panel in a two-column layout
  static double getDetailPanelRatio(BuildContext context) {
    return 1.0 - getMainContentRatio(context);
  }

  /// Calculate optimal item extent for grids
  static double getOptimalItemExtent(BuildContext context,
      {double aspectRatio = 1.0}) {
    final width = MediaQuery.of(context).size.width;
    final columns = getGridColumns(context);
    final padding = getHorizontalPadding(context);
    const spacing = 12.0;
    final itemWidth =
        (width - (padding * 2) - (spacing * (columns - 1))) / columns;
    return itemWidth / aspectRatio;
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, {double base = 16.0}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return base;
      case DeviceType.tablet:
        return base * 1.25;
      case DeviceType.largeTablet:
        return base * 1.5;
    }
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context, {double base = 12.0}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return base;
      case DeviceType.tablet:
        return base * 1.2;
      case DeviceType.largeTablet:
        return base * 1.4;
    }
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 56.0;
      case DeviceType.tablet:
        return 64.0;
      case DeviceType.largeTablet:
        return 72.0;
    }
  }

  /// Get responsive expanded app bar height
  static double getExpandedAppBarHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 250.0;
      case DeviceType.tablet:
        return 300.0;
      case DeviceType.largeTablet:
        return 350.0;
    }
  }

  /// Get optimal mini player height
  static double getMiniPlayerHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return 70.0;
      case DeviceType.tablet:
        return 80.0;
      case DeviceType.largeTablet:
        return 90.0;
    }
  }

  /// Get optimal now playing artwork size
  static double getNowPlayingArtworkSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = math.min(size.width, size.height);
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.phone:
        return shortestSide * 0.6; // Reduced from 0.7
      case DeviceType.tablet:
        return math.min(shortestSide * 0.45, 360.0); // Reduced from 0.5/400
      case DeviceType.largeTablet:
        return math.min(shortestSide * 0.4, 400.0); // Reduced from 0.45/450
    }
  }

  /// Check if should use drawer navigation (phones) or rail/tabs (tablets)
  static bool shouldUseBottomNav(BuildContext context) {
    return !isTablet(context);
  }

  /// Get number of items to show in a horizontal list
  static int getHorizontalListItemCount(BuildContext context,
      {int phoneCount = 3, int tabletCount = 5, int largeTabletCount = 7}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return phoneCount;
      case DeviceType.tablet:
        return tabletCount;
      case DeviceType.largeTablet:
        return largeTabletCount;
    }
  }

  /// Get item width for horizontal scrolling lists
  static double getHorizontalListItemWidth(BuildContext context,
      {double phoneWidth = 150.0}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.phone:
        return phoneWidth;
      case DeviceType.tablet:
        return phoneWidth * 1.2;
      case DeviceType.largeTablet:
        return phoneWidth * 1.4;
    }
  }
}

/// A widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for phone layout
  final Widget Function(BuildContext context) phone;

  /// Builder for tablet layout (optional, falls back to phone)
  final Widget Function(BuildContext context)? tablet;

  /// Builder for large tablet layout (optional, falls back to tablet or phone)
  final Widget Function(BuildContext context)? largeTablet;

  const ResponsiveBuilder({
    super.key,
    required this.phone,
    this.tablet,
    this.largeTablet,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.largeTablet:
        return (largeTablet ?? tablet ?? phone)(context);
      case DeviceType.tablet:
        return (tablet ?? phone)(context);
      case DeviceType.phone:
        return phone(context);
    }
  }
}

/// A widget that builds different layouts based on layout mode
class LayoutModeBuilder extends StatelessWidget {
  /// Builder for single column layout
  final Widget Function(BuildContext context) singleColumn;

  /// Builder for two column layout (optional, falls back to singleColumn)
  final Widget Function(BuildContext context)? twoColumn;

  /// Builder for wide layout with panel (optional, falls back to twoColumn or singleColumn)
  final Widget Function(BuildContext context)? wideWithPanel;

  const LayoutModeBuilder({
    super.key,
    required this.singleColumn,
    this.twoColumn,
    this.wideWithPanel,
  });

  @override
  Widget build(BuildContext context) {
    final layoutMode = ResponsiveUtils.getLayoutMode(context);

    switch (layoutMode) {
      case LayoutMode.wideWithPanel:
        return (wideWithPanel ?? twoColumn ?? singleColumn)(context);
      case LayoutMode.twoColumn:
        return (twoColumn ?? singleColumn)(context);
      case LayoutMode.singleColumn:
        return singleColumn(context);
    }
  }
}

/// A widget that constrains its child to a maximum width and centers it
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveUtils.getContentMaxWidth(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getHorizontalPadding(context),
        );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// Extension methods for BuildContext to easily access responsive utilities
extension ResponsiveContext on BuildContext {
  /// Get device type
  DeviceType get deviceType => ResponsiveUtils.getDeviceType(this);

  /// Check if device is tablet or larger
  bool get isTablet => ResponsiveUtils.isTablet(this);

  /// Check if device is large tablet
  bool get isLargeTablet => ResponsiveUtils.isLargeTablet(this);

  /// Get current layout mode
  LayoutMode get layoutMode => ResponsiveUtils.getLayoutMode(this);

  /// Get responsive horizontal padding
  double get horizontalPadding => ResponsiveUtils.getHorizontalPadding(this);

  /// Get number of grid columns
  int get gridColumns => ResponsiveUtils.getGridColumns(this);

  /// Get number of card columns
  int get cardColumns => ResponsiveUtils.getCardColumns(this);

  /// Get responsive spacing
  double responsiveSpacing([double base = 16.0]) =>
      ResponsiveUtils.getSpacing(this, base: base);

  /// Get font scale
  double get fontScale => ResponsiveUtils.getFontScale(this);

  /// Get icon scale
  double get iconScale => ResponsiveUtils.getIconScale(this);
}

/// A responsive grid that automatically adjusts column count
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? minColumns;
  final int? maxColumns;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
    this.minColumns,
    this.maxColumns,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getGridColumns(
      context,
      minColumns: minColumns ?? 2,
      maxColumns: maxColumns ?? 6,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getHorizontalPadding(context),
          ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A sliver grid delegate that calculates column count based on max item width
class SliverGridDelegateWithMaxCrossAxisExtent extends SliverGridDelegate {
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const SliverGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final crossAxisCount =
        (constraints.crossAxisExtent / maxCrossAxisExtent).ceil();
    final usableCrossAxisExtent =
        constraints.crossAxisExtent - (crossAxisSpacing * (crossAxisCount - 1));
    final childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final childMainAxisExtent = childCrossAxisExtent / childAspectRatio;

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithMaxCrossAxisExtent oldDelegate) {
    return oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio;
  }
}

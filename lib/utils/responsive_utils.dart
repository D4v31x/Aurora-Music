import 'package:flutter/material.dart';

/// Responsive design utilities for consistent layouts across screen sizes
class ResponsiveUtils {
  /// Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Gets the current screen type based on width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  /// Checks if the current screen is mobile
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }

  /// Checks if the current screen is tablet
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  /// Checks if the current screen is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }

  /// Gets responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(16);
      case ScreenType.tablet:
        return const EdgeInsets.all(24);
      case ScreenType.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Gets responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(8);
      case ScreenType.tablet:
        return const EdgeInsets.all(12);
      case ScreenType.desktop:
        return const EdgeInsets.all(16);
    }
  }

  /// Gets responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return 16;
      case ScreenType.tablet:
        return 24;
      case ScreenType.desktop:
        return 32;
    }
  }

  /// Gets responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return baseFontSize;
      case ScreenType.tablet:
        return baseFontSize * 1.1;
      case ScreenType.desktop:
        return baseFontSize * 1.2;
    }
  }

  /// Gets responsive icon size based on screen size
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return baseIconSize;
      case ScreenType.tablet:
        return baseIconSize * 1.2;
      case ScreenType.desktop:
        return baseIconSize * 1.4;
    }
  }

  /// Gets responsive grid column count
  static int getResponsiveGridColumns(BuildContext context, {
    int mobileColumns = 2,
    int tabletColumns = 3,
    int desktopColumns = 4,
  }) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return mobileColumns;
      case ScreenType.tablet:
        return tabletColumns;
      case ScreenType.desktop:
        return desktopColumns;
    }
  }

  /// Gets the optimal card width for the screen size
  static double getOptimalCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return (screenWidth - 48) / 2; // 2 columns with padding
      case ScreenType.tablet:
        return (screenWidth - 72) / 3; // 3 columns with padding
      case ScreenType.desktop:
        return (screenWidth - 96) / 4; // 4 columns with padding
    }
  }

  /// Gets responsive height for components
  static double getResponsiveHeight(BuildContext context, {
    double mobileHeight = 200,
    double tabletHeight = 250,
    double desktopHeight = 300,
  }) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return mobileHeight;
      case ScreenType.tablet:
        return tabletHeight;
      case ScreenType.desktop:
        return desktopHeight;
    }
  }

  /// Gets the safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Checks if the device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Checks if the device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Gets responsive border radius
  static BorderRadius getResponsiveBorderRadius(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return BorderRadius.circular(8);
      case ScreenType.tablet:
        return BorderRadius.circular(12);
      case ScreenType.desktop:
        return BorderRadius.circular(16);
    }
  }

  /// Gets responsive elevation
  static double getResponsiveElevation(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return 4;
      case ScreenType.tablet:
        return 6;
      case ScreenType.desktop:
        return 8;
    }
  }

  /// Responsive value based on screen width percentage
  static double getResponsiveValue(BuildContext context, double percentage) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * (percentage / 100);
  }

  /// Gets adaptive constraints for content
  static BoxConstraints getAdaptiveConstraints(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return const BoxConstraints(maxWidth: 600);
      case ScreenType.tablet:
        return const BoxConstraints(maxWidth: 800);
      case ScreenType.desktop:
        return const BoxConstraints(maxWidth: 1200);
    }
  }
}

/// Enum for different screen types
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// Extension on BuildContext for easier access to responsive utilities
extension ResponsiveContext on BuildContext {
  ScreenType get screenType => ResponsiveUtils.getScreenType(this);
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
  bool get isPortrait => ResponsiveUtils.isPortrait(this);
  
  EdgeInsets get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(this);
  double get responsiveSpacing => ResponsiveUtils.getResponsiveSpacing(this);
  BorderRadius get responsiveBorderRadius => ResponsiveUtils.getResponsiveBorderRadius(this);
  double get responsiveElevation => ResponsiveUtils.getResponsiveElevation(this);
  EdgeInsets get safeAreaPadding => ResponsiveUtils.getSafeAreaPadding(this);
  BoxConstraints get adaptiveConstraints => ResponsiveUtils.getAdaptiveConstraints(this);
}
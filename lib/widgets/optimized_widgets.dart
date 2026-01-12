import 'package:flutter/material.dart';
import 'package:aurora_music_v01/constants/font_constants.dart';

/// Optimized widgets for better performance in lists and grids
/// 
/// These widgets are designed to minimize rebuilds and improve
/// scroll performance by using const constructors, RepaintBoundary,
/// and careful state management.

/// A const divider for better performance
class ConstDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  const ConstDivider({
    super.key,
    this.height = 1.0,
    this.thickness = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color,
    );
  }
}

/// A const spacer for better performance
class ConstSpacer extends StatelessWidget {
  final double? width;
  final double? height;

  const ConstSpacer.horizontal(this.width, {super.key}) : height = null;
  const ConstSpacer.vertical(this.height, {super.key}) : width = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}

/// Optimized list item wrapper that reduces rebuilds
/// Wrap list items with this to isolate them from parent rebuilds
class OptimizedListItem extends StatelessWidget {
  final Widget child;
  final bool addRepaintBoundary;
  final bool addAutomaticKeepAlive;

  const OptimizedListItem({
    super.key,
    required this.child,
    this.addRepaintBoundary = true,
    this.addAutomaticKeepAlive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = child;

    if (addAutomaticKeepAlive) {
      result = _KeepAliveWrapper(child: result);
    }

    if (addRepaintBoundary) {
      result = RepaintBoundary(child: result);
    }

    return result;
  }
}

/// Internal widget to add AutomaticKeepAlive functionality
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super for AutomaticKeepAlive
    return widget.child;
  }
}

/// Optimized grid wrapper with RepaintBoundary
class OptimizedGrid extends StatelessWidget {
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const OptimizedGrid({
    super.key,
    required this.crossAxisCount,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children
            .map((child) => RepaintBoundary(child: child))
            .toList(growable: false),
      ),
    );
  }
}

/// Optimized horizontal list that reduces rebuilds
class OptimizedHorizontalList extends StatelessWidget {
  final List<Widget> children;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  const OptimizedHorizontalList({
    super.key,
    required this.children,
    required this.height,
    this.padding,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: children.length,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemBuilder: (context, index) =>
              RepaintBoundary(child: children[index]),
        ),
      ),
    );
  }
}

/// Optimized section header that doesn't rebuild unnecessarily
class OptimizedSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry padding;

  const OptimizedSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: FontConstants.fontFamily,
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

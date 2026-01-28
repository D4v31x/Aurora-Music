import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/responsive_utils.dart';

/// A responsive scaffold that adapts to tablet layouts by showing
/// a master-detail view or side navigation when appropriate.
class ResponsiveScaffold extends StatelessWidget {
  /// The main content (shown in single column, or as master in split view)
  final Widget body;

  /// Optional detail content for split view on tablets
  final Widget? detailBody;

  /// App bar for the main content
  final PreferredSizeWidget? appBar;

  /// App bar for the detail content
  final PreferredSizeWidget? detailAppBar;

  /// Background color
  final Color? backgroundColor;

  /// Whether the scaffold should resize for the keyboard
  final bool? resizeToAvoidBottomInset;

  /// Floating action button
  final Widget? floatingActionButton;

  /// Floating action button location
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Bottom navigation bar (only shown on phones)
  final Widget? bottomNavigationBar;

  /// Navigation rail for tablets (optional alternative to tabs)
  final NavigationRail? navigationRail;

  /// Whether to show the detail pane even if detailBody is null
  final bool showEmptyDetailPane;

  /// Placeholder widget for empty detail pane
  final Widget? emptyDetailPlaceholder;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.detailBody,
    this.appBar,
    this.detailAppBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.navigationRail,
    this.showEmptyDetailPane = false,
    this.emptyDetailPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutModeBuilder(
      singleColumn: (context) => _buildSingleColumn(context),
      twoColumn: (context) => _buildTwoColumn(context),
      wideWithPanel: (context) => _buildWideWithPanel(context),
    );
  }

  Widget _buildSingleColumn(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildTwoColumn(BuildContext context) {
    final mainRatio = ResponsiveUtils.getMainContentRatio(context);
    final hasDetail = detailBody != null || showEmptyDetailPane;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Row(
        children: [
          // Navigation rail if provided
          if (navigationRail != null) navigationRail!,

          // Main content
          Expanded(
            flex: hasDetail ? (mainRatio * 100).round() : 100,
            child: Column(
              children: [
                if (appBar != null) appBar!,
                Expanded(child: body),
              ],
            ),
          ),

          // Detail content
          if (hasDetail) ...[
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
            Expanded(
              flex: ((1 - mainRatio) * 100).round(),
              child: Column(
                children: [
                  if (detailAppBar != null) detailAppBar!,
                  Expanded(
                    child: detailBody ??
                        (emptyDetailPlaceholder ??
                            _buildDefaultPlaceholder(context)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  Widget _buildWideWithPanel(BuildContext context) {
    // Similar to two column but with more generous proportions
    return _buildTwoColumn(context);
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Select an item to view details',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}

/// A responsive list-detail layout for master-detail patterns
class ResponsiveListDetail extends StatefulWidget {
  /// Builder for the list view
  final Widget Function(
          BuildContext context, void Function(dynamic item) onItemSelected)
      listBuilder;

  /// Builder for the detail view
  final Widget Function(BuildContext context, dynamic selectedItem)?
      detailBuilder;

  /// App bar for the list
  final PreferredSizeWidget? listAppBar;

  /// App bar builder for the detail (receives selected item)
  final PreferredSizeWidget Function(
      BuildContext context, dynamic selectedItem)? detailAppBarBuilder;

  /// Callback when an item is selected (for phone navigation)
  final void Function(dynamic item)? onItemSelectedPhone;

  /// Initial selected item
  final dynamic initialItem;

  const ResponsiveListDetail({
    super.key,
    required this.listBuilder,
    this.detailBuilder,
    this.listAppBar,
    this.detailAppBarBuilder,
    this.onItemSelectedPhone,
    this.initialItem,
  });

  @override
  State<ResponsiveListDetail> createState() => _ResponsiveListDetailState();
}

class _ResponsiveListDetailState extends State<ResponsiveListDetail> {
  dynamic _selectedItem;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem;
  }

  void _selectItem(dynamic item) {
    if (ResponsiveUtils.isTablet(context)) {
      setState(() {
        _selectedItem = item;
      });
    } else {
      // On phones, navigate to detail screen
      widget.onItemSelectedPhone?.call(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);

    if (isTablet && widget.detailBuilder != null) {
      return ResponsiveScaffold(
        appBar: widget.listAppBar,
        body: widget.listBuilder(context, _selectItem),
        detailBody: _selectedItem != null
            ? widget.detailBuilder!(context, _selectedItem)
            : null,
        detailAppBar:
            _selectedItem != null && widget.detailAppBarBuilder != null
                ? widget.detailAppBarBuilder!(context, _selectedItem)
                : null,
        showEmptyDetailPane: true,
      );
    }

    return Scaffold(
      appBar: widget.listAppBar,
      body: widget.listBuilder(context, _selectItem),
    );
  }
}

/// A responsive card grid that adjusts columns based on screen size
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double childAspectRatio;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 12.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getCardColumns(context);
    final horizontalPadding = ResponsiveUtils.getHorizontalPadding(context);

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding ?? EdgeInsets.symmetric(horizontal: horizontalPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A responsive sliver grid delegate
class ResponsiveSliverGridDelegate extends SliverGridDelegate {
  final BuildContext context;
  final double spacing;
  final double childAspectRatio;
  final int? minColumns;
  final int? maxColumns;

  const ResponsiveSliverGridDelegate({
    required this.context,
    this.spacing = 12.0,
    this.childAspectRatio = 1.0,
    this.minColumns,
    this.maxColumns,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = ResponsiveUtils.getGridColumns(
      context,
      minColumns: minColumns ?? 2,
      maxColumns: maxColumns ?? 6,
    );

    final usableCrossAxisExtent =
        constraints.crossAxisExtent - (spacing * (columns - 1));
    final childCrossAxisExtent = usableCrossAxisExtent / columns;
    final childMainAxisExtent = childCrossAxisExtent / childAspectRatio;

    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: childMainAxisExtent + spacing,
      crossAxisStride: childCrossAxisExtent + spacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ResponsiveSliverGridDelegate oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.minColumns != minColumns ||
        oldDelegate.maxColumns != maxColumns;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../widgets/app_background.dart';
import '../widgets/expanding_player.dart';

class CommonScreenScaffold extends StatelessWidget {
  final String title;
  final Widget? searchBar;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final bool showBackButton;

  const CommonScreenScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.searchBar,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 110.0,
              pinned: true,
              stretch: true,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              actions: actions,
              flexibleSpace: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double top = constraints.biggest.height;
                      final double minHeight =
                          kToolbarHeight + MediaQuery.of(context).padding.top;
                      final double range = 110.0 - minHeight;
                      final double opacity = range > 0
                          ? ((110.0 - top) / range).clamp(0.0, 1.0)
                          : 1.0;

                      return Opacity(
                        opacity: opacity,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  FlexibleSpaceBar(
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 16),
                    title: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'ProductSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (searchBar != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: searchBar,
                ),
              ),
            ...slivers,
            // Add padding for mini player
            SliverToBoxAdapter(
              child: SizedBox(
                height: ExpandingPlayer.getMiniPlayerPaddingHeight(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

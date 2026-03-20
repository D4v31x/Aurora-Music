import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:aurora_music_v01/core/constants/font_constants.dart';


class LibraryScreenHeader extends StatelessWidget {
  final String badge;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget searchField;
  final Widget? controlsRow;
  final List<Widget>? actions;
  final bool showBackButton;
  final double expandedHeight;
  const LibraryScreenHeader({
    super.key,
    required this.badge,
    required this.title,
    this.subtitle,
    this.accentColor = Colors.deepPurple,
    required this.searchField,
    this.controlsRow,
    this.actions,
    this.showBackButton = false,
    this.expandedHeight = 310,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final collapsedHeight = kToolbarHeight + topPadding;

    return SliverAppBar(
      // Collapsed state is solid black; expanded state is drawn by flexibleSpace
      backgroundColor: Colors.black,
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      // Back button is always shown on every library screen
      leading: _buildBackButton(context),
      actions: actions,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentHeight = constraints.biggest.height;
            // 0 = fully expanded, 1 = fully collapsed
            final collapseProgress =
                ((expandedHeight + topPadding - currentHeight) /
                        (expandedHeight + topPadding - collapsedHeight))
                    .clamp(0.0, 1.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: _buildBackground(),
                ),
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: _buildOrbs(),
                ),
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Expanded content 
                Opacity(
                  opacity: (1.0 - collapseProgress * 2.0).clamp(0.0, 1.0),
                  child: ClipRect(
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Badge
                                _buildBadgePill(),
                                const SizedBox(height: 14),
                                // Title
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: FontConstants.fontFamily,
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Subtitle / count
                                if (subtitle != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle!,
                                    style: TextStyle(
                                      fontFamily: FontConstants.fontFamily,
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                // Search field
                                searchField,
                                if (controlsRow != null) ...[
                                  const SizedBox(height: 10),
                                  controlsRow!,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Collapsed toolbar title
                if (collapseProgress > 0.3)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: topPadding,
                    height: kToolbarHeight,
                    child: Opacity(
                      opacity: ((collapseProgress - 0.3) / 0.4).clamp(0.0, 1.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Helpers

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [
            accentColor.withValues(alpha: 0.35),
            const Color(0xFF080B14),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbs() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Left orb
        Positioned(
          left: -60,
          top: 20,
          child: _orb(accentColor.withValues(alpha: 0.18), 180),
        ),
        // Right orb
        Positioned(
          right: -40,
          top: 60,
          child: _orb(Colors.blue.withValues(alpha: 0.14), 150),
        ),
        // Bottom centre orb
        Positioned(
          left: 0,
          right: 0,
          bottom: -30,
          child: Center(
            child: _orb(accentColor.withValues(alpha: 0.10), 120),
          ),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildBadgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        badge.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: const Iconoir.NavArrowLeft(
            color: Colors.white,
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
  }
}

/// A frosted search field that matches the library header palette.
class LibrarySearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool hasQuery;
  final VoidCallback? onClear;

  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.hasQuery = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: FontConstants.fontFamily,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontFamily: FontConstants.fontFamily,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.55),
            size: 20,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: Colors.white.withValues(alpha: 0.55), size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

/// A single frosted pill button used for sort/filter controls in the header.
class LibraryControlPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const LibraryControlPill({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: child,
      ),
    );
  }
}

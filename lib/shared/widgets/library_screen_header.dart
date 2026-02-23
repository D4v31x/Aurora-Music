import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';

/// A rich [SliverAppBar] header for library list screens (Tracks, Albums,
/// Artists, Playlists, Folders).
///
/// Matches the visual language of [DetailHeader] — same blurred gradient
/// background, badge pill, large title and metadata — but without any artwork.
/// Instead it exposes a [searchField] and an optional [controlsRow] (sort /
/// filter / view-mode chips) that live beneath the title and smoothly collapse
/// as the user scrolls.
class LibraryScreenHeader extends StatelessWidget {
  /// Short section label shown in the badge pill (e.g. "TRACKS").
  final String badge;

  /// Large title shown in the expanded header (e.g. "Tracks").
  final String title;

  /// Secondary line below the title, typically an item count
  /// (e.g. "243 songs").
  final String? subtitle;

  /// Primary accent colour used for the gradient orbs.
  final Color accentColor;

  /// The search [TextField] widget to embed below the title.
  final Widget searchField;

  /// Optional row of controls (sort selector, order toggle, view-mode toggle).
  /// Shown below the search field in the expanded state.
  final Widget? controlsRow;

  /// Optional extra action buttons shown in the collapsed app bar row.
  final List<Widget>? actions;

  /// Whether to show a back button (defaults to false for top-level screens).
  final bool showBackButton;

  /// How tall the header is when fully expanded. Increase if [controlsRow]
  /// is provided so there is enough room for both rows.
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
      title: null,
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
                // ── Solid black base (always present, becomes the collapsed bar) ──
                Container(color: Colors.black),

                // ── Coloured gradient background — fades out as it collapses ──
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: _buildBackground(),
                ),

                // ── Decorative colour orbs — fade out as it collapses ──────
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: _buildOrbs(),
                ),

                // ── Gradient overlay (only visible when expanded) ───────────
                Opacity(
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.55),
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Expanded content (vertically centred) ─────────────────
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                      color: Colors.white.withOpacity(0.55),
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

                // ── Collapsed toolbar title ────────────────────────────────
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
                                  color: Colors.white.withOpacity(0.55),
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

  // ─────────────────────────────── Helpers ─────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [
            accentColor.withOpacity(0.35),
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
          child: _orb(accentColor.withOpacity(0.18), 180),
        ),
        // Right orb
        Positioned(
          right: -40,
          top: 60,
          child: _orb(Colors.blue.withOpacity(0.14), 150),
        ),
        // Bottom centre orb
        Positioned(
          left: 0,
          right: 0,
          bottom: -30,
          child: Center(
            child: _orb(accentColor.withOpacity(0.10), 120),
          ),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildBadgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.45),
          width: 1,
        ),
      ),
      child: Text(
        badge.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white.withOpacity(0.95),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
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
                color: Colors.white.withOpacity(0.45),
                fontFamily: FontConstants.fontFamily,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.55),
                size: 20,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: Colors.white.withOpacity(0.55), size: 18),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

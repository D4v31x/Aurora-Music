import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';

/// A beautiful blurred-artwork header for detail screens (album, artist, playlist, folder).
///
/// Shows a full-width blurred artwork image with the title, subtitle and metadata
/// centred on top. Includes a frosted pill badge at the top showing the content
/// type (e.g. ALBUM, ARTIST) and a back button.
///
/// The title + metadata stay visible throughout scrolling — they smoothly
/// crossfade from the large expanded layout into a compact pinned toolbar so
/// there is never a gap where the name disappears.
class DetailHeader extends StatelessWidget {
  final Uint8List? artworkBytes;
  final String? artworkFilePath;
  final String? fallbackAsset;
  final String title;
  final String? subtitle;
  final String? metadata;
  final String badge;
  final String? heroTag;
  final Color accentColor;
  final double expandedHeight;
  final List<Widget>? actions;

  const DetailHeader({
    super.key,
    this.artworkBytes,
    this.artworkFilePath,
    this.fallbackAsset,
    required this.title,
    this.subtitle,
    this.metadata,
    required this.badge,
    this.heroTag,
    this.accentColor = Colors.cyan,
    this.expandedHeight = 300,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final collapsedHeight = kToolbarHeight + topPadding;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: expandedHeight,
      pinned: true,
      automaticallyImplyLeading: false,
      leading: _buildBackButton(context),
      actions: actions,
      // We never set title here – our LayoutBuilder draws everything.
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
                // ── Blurred artwork background ──
                Opacity(
                  // Fade out artwork fully when collapsed – collapsed bar is text-only
                  opacity: (1.0 - collapseProgress).clamp(0.0, 1.0),
                  child: _buildBlurredBackground(context),
                ),

                // ── Solid dark background for collapsed state ──
                Opacity(
                  opacity: collapseProgress,
                  child: Container(
                    color: Colors.black,
                  ),
                ),

                // ── Gradient overlay ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),

                // ── Expanded content (badge, title, subtitle, metadata) ──
                // Centered vertically, fades out as the bar collapses
                Opacity(
                  opacity: (1.0 - collapseProgress * 2.0).clamp(0.0, 1.0),
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge pill
                            _buildBadgePill(),
                            const SizedBox(height: 16),
                            // Title
                            heroTag != null
                                ? Hero(
                                    tag: heroTag!,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: _buildTitleText(fontSize: 32),
                                    ),
                                  )
                                : _buildTitleText(fontSize: 32),
                            // Subtitle
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            // Metadata
                            if (metadata != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                metadata!,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Collapsed toolbar title ──
                // Fades in once the expanded content starts disappearing
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
                              textAlign: TextAlign.center,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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

  // ─────────────────────────── Sub-widgets ───────────────────────────

  Widget _buildBackButton(BuildContext context) {
    // PERF: No BackdropFilter – the back button is a leading widget in a
    // SliverAppBar that has scrolling content behind it, causing expensive
    // blur recomputation on every scroll frame.
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleText({required double fontSize}) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: FontConstants.fontFamily,
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBadgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        badge.toUpperCase(),
        style: TextStyle(
          fontFamily: FontConstants.fontFamily,
          color: Colors.white.withOpacity(0.95),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildBlurredBackground(BuildContext context) {
    Widget imageWidget;

    if (artworkBytes != null) {
      imageWidget = Image.memory(
        artworkBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    } else if (artworkFilePath != null) {
      imageWidget = Image.file(
        File(artworkFilePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (fallbackAsset != null) {
      imageWidget = Image.asset(
        fallbackAsset!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      // Gradient fallback
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.4),
              Colors.black87,
              Colors.black,
            ],
          ),
        ),
      );
    }

    // Always blur the header artwork – this is a design requirement,
    // not gated by performance mode.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: imageWidget,
          ),
          Container(
            color: Colors.black.withOpacity(0.15),
          ),
        ],
      ),
    );
  }
}

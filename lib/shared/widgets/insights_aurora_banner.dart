import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

/// An aurora-lights banner shown at the top of the home scroll view when
/// there is a Listening Insights notification to surface.
///
/// The aurora blobs are rendered with [CustomPaint] and, on capable devices,
/// blurred with [ImageFiltered] to produce the soft, shifting glow effect.
/// A [ShaderMask] fades the bottom edge to transparent so the banner bleeds
/// seamlessly into the rest of the home content.
class InsightsAuroraBanner extends StatefulWidget {
  final bool isNewFeature;
  final VoidCallback onExplore;
  final VoidCallback onDismiss;

  const InsightsAuroraBanner({
    super.key,
    required this.isNewFeature,
    required this.onExplore,
    required this.onDismiss,
  });

  @override
  State<InsightsAuroraBanner> createState() => _InsightsAuroraBannerState();
}

class _InsightsAuroraBannerState extends State<InsightsAuroraBanner>
    with TickerProviderStateMixin {
  late final AnimationController _auroraCtrl;
  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _auroraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    _auroraCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.12),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic)),
        child: _buildBanner(context, isLowEnd),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, bool isLowEnd) {
    return SizedBox(
      height: 210,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.60, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: Stack(
          children: [
            // ── Dark base gradient ──────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A0015), Color(0xFF0D1B4B)],
                  ),
                ),
              ),
            ),

            // ── Aurora blobs ─────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _auroraCtrl,
                builder: (_, __) {
                  final blobPaint = CustomPaint(
                    painter: _AuroraPainter(t: _auroraCtrl.value),
                  );
                  if (isLowEnd) return blobPaint;
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 48,
                      sigmaY: 48,
                      tileMode: TileMode.clamp,
                    ),
                    child: blobPaint,
                  );
                },
              ),
            ),

            // ── Readability gradient (dark bottom) ────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.55),
                    ],
                    stops: const [0.0, 0.40, 1.0],
                  ),
                ),
              ),
            ),

            // ── Text + buttons ────────────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isNewFeature
              ? 'Your Music Insights Are Here ✦'
              : 'Your Music Recap Awaits',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isNewFeature
              ? 'See your top tracks, artists & listening patterns'
              : 'Discover your top songs and listening trends',
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: 13,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Island pill CTA button
            GestureDetector(
              onTap: widget.onExplore,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF0288D1), Color(0xFF00E5FF)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Take me there',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Subtle dismiss link
            GestureDetector(
              onTap: widget.onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Aurora blob painter ────────────────────────────────────────────────────────

class _AuroraPainter extends CustomPainter {
  final double t; // 0.0 → 1.0, repeating

  const _AuroraPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;

    // Deep purple blob — sweeps left/right
    _blob(
      canvas,
      Offset(
        size.width * (0.1 + 0.35 * math.sin(t * tau * 0.7)),
        size.height * 0.22,
      ),
      size.width * 0.55,
      const Color(0xFF5C00B8),
      opacity: 0.80,
    );

    // Dark blue blob — sweeps diagonally
    _blob(
      canvas,
      Offset(
        size.width * (0.62 + 0.22 * math.cos(t * tau * 0.85)),
        size.height * (0.18 + 0.12 * math.sin(t * tau * 0.6)),
      ),
      size.width * 0.5,
      const Color(0xFF0D47A1),
      opacity: 0.75,
    );

    // Cyan blob — faster, smaller
    _blob(
      canvas,
      Offset(
        size.width * (0.42 + 0.30 * math.sin(t * tau * 1.0 + 1.0)),
        size.height * (0.08 + 0.15 * math.cos(t * tau * 0.55 + 0.5)),
      ),
      size.width * 0.38,
      const Color(0xFF00BCD4),
      opacity: 0.68,
    );

    // Midnight purple anchor blob
    _blob(
      canvas,
      Offset(
        size.width * (0.30 + 0.18 * math.cos(t * tau * 0.5 + 2.0)),
        size.height * 0.05,
      ),
      size.width * 0.50,
      const Color(0xFF1A003C),
      opacity: 0.90,
    );
  }

  void _blob(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    required double opacity,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

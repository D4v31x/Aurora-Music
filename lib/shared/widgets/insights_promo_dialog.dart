import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
const _kDeepPurple = Color(0xFF1A0050);
const _kDarkNavy = Color(0xFF0A1245);
const _kMidNavy = Color(0xFF0D2050);
const _kPurpleAccent = Color(0xFF7B2FBE);
const _kCyan = Color(0xFF00E5FF);
const _kCyanDark = Color(0xFF0288D1);
const _kRed = Color(0xFFFF1744);
const _kWhite = Colors.white;

/// A bold, animated Insights promotional dialog.
///
/// Use [InsightsPromoDialog.showNewFeature] once per app version to announce
/// the Insights feature, and [InsightsPromoDialog.showRecapReminder] for the
/// periodic "check your recap" nudge.
class InsightsPromoDialog extends StatefulWidget {
  final bool isNewFeature;
  final VoidCallback onExplore;

  const InsightsPromoDialog({
    super.key,
    required this.isNewFeature,
    required this.onExplore,
  });

  // ── Static helpers ──────────────────────────────────────────────────────────

  static Future<void> showNewFeature(
    BuildContext context, {
    required VoidCallback onExplore,
  }) =>
      _show(context, isNewFeature: true, onExplore: onExplore);

  static Future<void> showRecapReminder(
    BuildContext context, {
    required VoidCallback onExplore,
  }) =>
      _show(context, isNewFeature: false, onExplore: onExplore);

  static Future<void> _show(
    BuildContext context, {
    required bool isNewFeature,
    required VoidCallback onExplore,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.78),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, _, __) => InsightsPromoDialog(
        isNewFeature: isNewFeature,
        onExplore: onExplore,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  State<InsightsPromoDialog> createState() => _InsightsPromoDialogState();
}

class _InsightsPromoDialogState extends State<InsightsPromoDialog>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _glowAnim;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _floatAnim = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 340,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        final borderColor = Color.lerp(
          _kPurpleAccent.withOpacity(0.45),
          _kCyan.withOpacity(0.85),
          _glowAnim.value,
        )!;

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kDeepPurple, _kDarkNavy, _kMidNavy],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Stack(
              children: [
                // ── Decorative background dots ────────────────────────────
                _buildDots(),

                // ── Card content ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIconRing(),
                      const SizedBox(height: 28),
                      _buildTitle(),
                      const SizedBox(height: 14),
                      _buildDivider(),
                      const SizedBox(height: 14),
                      _buildSubtitle(),
                      const SizedBox(height: 32),
                      _buildCtaButton(),
                      const SizedBox(height: 14),
                      _buildDismissButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Decorative scattered dots ─────────────────────────────────────────────

  Widget _buildDots() {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: Stack(
        children: [
          _dot(top: 14, right: 28, color: _kRed, size: 7),
          _dot(top: 32, right: 60, color: _kCyan.withOpacity(0.6), size: 4),
          _dot(top: 8, left: 36, color: _kPurpleAccent.withOpacity(0.7), size: 5),
          _dot(top: 50, left: 18, color: _kCyan.withOpacity(0.4), size: 3),
          _dot(top: 20, left: 80, color: _kRed.withOpacity(0.5), size: 4),
          _dot(top: 60, right: 40, color: _kPurpleAccent.withOpacity(0.5), size: 6),
        ],
      ),
    );
  }

  Widget _dot({
    double? top,
    double? left,
    double? right,
    required Color color,
    required double size,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  // ── Glowing icon ring ─────────────────────────────────────────────────────

  Widget _buildIconRing() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnim, _floatAnim]),
      builder: (_, __) {
        final glow = _glowAnim.value;
        final floatOffset = math.sin(_floatAnim.value * math.pi) * 4.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kPurpleAccent.withOpacity(0.5),
                  _kDeepPurple,
                ],
              ),
              border: Border.all(
                color: _kCyan.withOpacity(0.4 + 0.5 * glow),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kCyan.withOpacity(0.18 + 0.28 * glow),
                  blurRadius: 22 + 12 * glow,
                  spreadRadius: 2 + 4 * glow,
                ),
                BoxShadow(
                  color: _kPurpleAccent.withOpacity(0.15 + 0.2 * glow),
                  blurRadius: 30,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              widget.isNewFeature
                  ? Icons.insights_rounded
                  : Icons.bar_chart_rounded,
              color: _kCyan,
              size: 38,
            ),
          ),
        );
      },
    );
  }

  // ── Gradient title text ───────────────────────────────────────────────────

  Widget _buildTitle() {
    final titleLines = widget.isNewFeature
        ? 'MUSIC\nINSIGHTS\nARE HERE'
        : 'YOUR\nMUSIC\nRECAP';

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [_kCyan, Color(0xFFE0E0FF), _kCyan],
        stops: [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(
        titleLines,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.5,
          height: 1.05,
          color: _kWhite, // overridden by ShaderMask
        ),
      ),
    );
  }

  // ── Thin cyan divider ─────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _kCyan, Colors.transparent],
              ),
            ),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _kRed,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _kCyan, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Subtitle ─────────────────────────────────────────────────────────────

  Widget _buildSubtitle() {
    final text = widget.isNewFeature
        ? 'Discover your top tracks, favourite artists, peak listening hours — and more.'
        : "It's time to revisit your music journey. Your top tracks, artists & listening patterns are waiting.";

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFFB0C4DE),
        height: 1.55,
      ),
    );
  }

  // ── CTA gradient button ───────────────────────────────────────────────────

  Widget _buildCtaButton() {
    final label =
        widget.isNewFeature ? 'EXPLORE NOW' : 'SEE MY RECAP';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        widget.onExplore();
      },
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, __) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPurpleAccent, _kCyanDark, _kCyan],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withOpacity(0.22 + 0.18 * _glowAnim.value),
                blurRadius: 16 + 8 * _glowAnim.value,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Dismiss text button ───────────────────────────────────────────────────

  Widget _buildDismissButton() {
    final label = widget.isNewFeature ? 'Maybe Later' : 'Not Now';
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7090B0),
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

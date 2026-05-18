/// Shared tile-building helpers used by all settings sub-screens.
///
/// All methods are static and accept [BuildContext] as first argument so
/// they can be called from any [State] without inheritance.
library;

import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../shared/providers/providers.dart';

class SettingsTiles {
  const SettingsTiles._();

  // ── Section header ──────────────────────────────────────────────────────────

  static Widget buildSectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          height: 1.2,
          fontFamily: FontConstants.fontFamily,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ── Glassmorphic card ───────────────────────────────────────────────────────

  static Widget buildGlassmorphicCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final cs = Theme.of(context).colorScheme;
    final bgColor = isLowEnd
        ? cs.surfaceContainerHigh
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = isLowEnd
        ? cs.outlineVariant
        : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isLowEnd
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(children: children),
      ),
    );
  }

  // ── Switch tile ─────────────────────────────────────────────────────────────

  static Widget buildSwitchTile(
    BuildContext context, {
    required Widget icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        if (!isFirst) _divider(context),
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: _iconChip(context, icon, primary),
          title: _tileTitle(title),
          subtitle: subtitle != null ? _tileSubtitle(context, subtitle) : null,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Action tile ─────────────────────────────────────────────────────────────

  static Widget buildActionTile(
    BuildContext context, {
    required Widget icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isFirst = false,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        iconColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        if (!isFirst) _divider(context),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _iconChip(context, icon, effectiveColor),
          title: _tileTitle(title),
          subtitle: subtitle != null ? _tileSubtitle(context, subtitle) : null,
          trailing: trailing ??
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: iconoir.NavArrowRight(
                    color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.45) ??
                        Colors.white38,
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
          onTap: onTap,
        ),
      ],
    );
  }

  // ── Slider tile ─────────────────────────────────────────────────────────────

  static Widget buildSliderTile(
    BuildContext context, {
    required Widget icon,
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String Function(double)? valueFormatter,
    bool isFirst = false,
    double? defaultValue,
    bool showArrows = false,
    double arrowStep = 0.05,
  }) {
    final draft = <double?>[null];
    return StatefulBuilder(
      builder: (context, setLocal) => _buildSliderContent(
        context,
        icon: icon,
        title: title,
        subtitle: subtitle,
        value: value,
        draft: draft[0],
        min: min,
        max: max,
        onChanged: (v) {
          setLocal(() => draft[0] = v);
          onChanged(v);
        },
        onChangeEnd: (v) {
          setLocal(() => draft[0] = null);
          onChangeEnd?.call(v);
        },
        valueFormatter: valueFormatter,
        isFirst: isFirst,
        defaultValue: defaultValue,
        showArrows: showArrows,
        arrowStep: arrowStep,
      ),
    );
  }

  static Widget _buildSliderContent(
    BuildContext context, {
    required Widget icon,
    required String title,
    String? subtitle,
    required double value,
    double? draft,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String Function(double)? valueFormatter,
    bool isFirst = false,
    double? defaultValue,
    bool showArrows = false,
    double arrowStep = 0.05,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display =
        valueFormatter?.call(draft ?? value) ?? (draft ?? value).toStringAsFixed(1);
    final snap = defaultValue != null ? (max - min) * 0.025 : 0.0;

    ValueChanged<double> wrapChange(ValueChanged<double> fn) =>
        defaultValue == null
            ? fn
            : (v) =>
                fn((v - defaultValue).abs() <= snap ? defaultValue : v);

    final wrappedOnChanged = wrapChange(onChanged);
    final wrappedOnChangeEnd =
        onChangeEnd == null ? null : wrapChange(onChangeEnd);

    return Column(
      children: [
        if (!isFirst) _divider(context),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _iconChip(context, icon,
                  Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _tileTitle(title),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            display,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: FontConstants.fontFamily,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) _tileSubtitle(context, subtitle),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        overlayColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                      ),
                      child: _buildSliderWidget(
                        context,
                        value: draft ?? value,
                        min: min,
                        max: max,
                        defaultValue: defaultValue,
                        onChanged: wrappedOnChanged,
                        onChangeEnd: wrappedOnChangeEnd,
                        showArrows: showArrows,
                        arrowStep: arrowStep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildSliderWidget(
    BuildContext context, {
    required double value,
    required double min,
    required double max,
    double? defaultValue,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    required bool showArrows,
    required double arrowStep,
  }) {
    Widget slider;
    if (defaultValue != null) {
      slider = LayoutBuilder(
        builder: (context, constraints) {
          const double pad = 24.0;
          final tw = constraints.maxWidth - pad * 2;
          final frac = (defaultValue - min) / (max - min);
          final markerLeft = pad + frac * tw;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
              Positioned(
                left: markerLeft - 1,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 2,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      slider = Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      );
    }

    if (!showArrows) return slider;

    final arrowColor = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            final v = (value - arrowStep).clamp(min, max);
            onChanged(v);
            onChangeEnd?.call(v);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: iconoir.NavArrowLeft(
                color: arrowColor, width: 20, height: 20),
          ),
        ),
        Expanded(child: slider),
        GestureDetector(
          onTap: () {
            final v = (value + arrowStep).clamp(min, max);
            onChanged(v);
            onChangeEnd?.call(v);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: iconoir.NavArrowRight(
                color: arrowColor, width: 20, height: 20),
          ),
        ),
      ],
    );
  }

  // ── Segmented choice tile ───────────────────────────────────────────────────

  static Widget buildSegmentedChoiceTile(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String subtitle,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    bool isFirst = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (!isFirst) _divider(context),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(color: cs.onPrimaryContainer),
                      child: icon,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tileTitle(title),
                        const SizedBox(height: 2),
                        _tileSubtitle(context, subtitle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(options.length, (i) {
                  final sel = i == selectedIndex;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i == options.length - 1 ? 0 : 8),
                      child: SettingsChoiceChip(
                        label: options[i],
                        selected: sel,
                        onTap: () => onChanged(i),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Animated visibility ─────────────────────────────────────────────────────

  static Widget buildAnimatedTile(
      {required bool visible, required Widget child}) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }

  // ── Shared micro-helpers ────────────────────────────────────────────────────

  static Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      thickness: 0.5,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  static Widget _iconChip(BuildContext context, Widget icon, Color color) =>
      Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: icon,
      );

  static Widget _tileTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: FontConstants.fontFamily,
        ),
      );

  static Widget _tileSubtitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontFamily: FontConstants.fontFamily,
            color: Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.7),
          ),
        ),
      );
}

// ── Shared choice chip ────────────────────────────────────────────────────────

class SettingsChoiceChip extends StatelessWidget {
  const SettingsChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? cs.primaryContainer
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03));
    final border = selected
        ? cs.primary.withValues(alpha: 0.0)
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.10));
    final fg = selected
        ? cs.onPrimaryContainer
        : (isDark
            ? Colors.white.withValues(alpha: 0.70)
            : Colors.black.withValues(alpha: 0.65));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: cs.primary.withValues(alpha: 0.12),
        highlightColor: cs.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontFamily: FontConstants.fontFamily,
              color: fg,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

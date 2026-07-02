import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../../core/constants/font_constants.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/sleep_timer_controller.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/glassmorphic_dialog.dart';

/// Sleep timer indicator widget for the app bar.
///
/// Shows a countdown when the sleep timer is active, with tap-to-expand
/// functionality for detailed time display.
class SleepTimerIndicator extends StatefulWidget {
  final VoidCallback? onTimerSet;

  const SleepTimerIndicator({super.key, this.onTimerSet});

  @override
  State<SleepTimerIndicator> createState() => _SleepTimerIndicatorState();
}

class _SleepTimerIndicatorState extends State<SleepTimerIndicator> {
  bool _isExpanded = false;
  Timer? _autoCollapseTimer;

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _autoCollapseTimer?.cancel();
        _autoCollapseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isExpanded = false);
          }
        });
      } else {
        _autoCollapseTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerController>(
      builder: (context, sleepTimerController, child) {
        if (!sleepTimerController.isActive) {
          return const SizedBox.shrink();
        }

        final remainingTime = sleepTimerController.remainingTime;
        if (remainingTime == null) {
          return const SizedBox.shrink();
        }

        final minutes = remainingTime.inMinutes;
        final seconds =
            (remainingTime.inSeconds % 60).toString().padLeft(2, '0');
        final progress = sleepTimerController.duration != null
            ? remainingTime.inSeconds / sleepTimerController.duration!.inSeconds
            : 0.0;

        return Container(
          width: 90.0,
          height: 32.0,
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded ? 120.0 : 32.0,
              height: 32.0,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Collapsed state
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isExpanded ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: _isExpanded,
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 1.5,
                              ),
                            ),
                            const iconoir.HalfMoon(
                              color: Colors.white,
                              width: 16,
                              height: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Expanded state
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isExpanded ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_isExpanded,
                      child: SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const iconoir.HalfMoon(
                              color: Colors.white,
                              width: 16,
                              height: 16,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$minutes:$seconds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.2,
                                  decoration: TextDecoration.none,
                                  fontFamily: FontConstants.fontFamily,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows a bottom sheet for configuring the sleep timer.
void showSleepTimerOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) => const _SleepTimerOptionsSheet(),
  );
}

/// Internal stateful widget for the sleep timer options sheet.
class _SleepTimerOptionsSheet extends StatefulWidget {
  const _SleepTimerOptionsSheet();

  @override
  State<_SleepTimerOptionsSheet> createState() => _SleepTimerOptionsSheetState();
}

class _SleepTimerOptionsSheetState extends State<_SleepTimerOptionsSheet> {
  int? _selectedMinutes;

  static const List<int> _presets = [5, 10, 15, 20, 30, 45, 60, 90];

  void _showCustomPicker() {
    int picked = _selectedMinutes ?? 30;
    showGlassmorphicDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return GlassmorphicDialog(
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child:
                      Icon(Icons.timer_outlined, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).setMinutes,
                  style: const TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CounterButton(
                  icon: const iconoir.Minus(
                      color: Colors.white, width: 20, height: 20),
                  onTap: () {
                    if (picked > 1) setDialogState(() => picked--);
                  },
                  colorScheme: cs,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$picked',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: cs.primary,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'min',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _CounterButton(
                  icon: const iconoir.Plus(
                      color: Colors.white, width: 20, height: 20),
                  onTap: () {
                    if (picked < 480) setDialogState(() => picked++);
                  },
                  colorScheme: cs,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            actions: [
              GlassmorphicTextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              GlassmorphicTextButton(
                isPrimary: true,
                onPressed: () {
                  setState(() => _selectedMinutes = picked);
                  Navigator.pop(ctx);
                },
                child: Text(AppLocalizations.of(context).set),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final sleepTimerController =
        Provider.of<SleepTimerController>(context, listen: false);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isLowEnd =
        Provider.of<PerformanceModeProvider>(context, listen: false)
            .isLowEndDevice;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final sheetBody = DecoratedBox(
      decoration: BoxDecoration(
        color: isLowEnd
            ? cs.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: isLowEnd
            ? Border.all(color: cs.outlineVariant)
            : Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Hero header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.28),
                        cs.primaryContainer.withValues(alpha: 0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.25)),
                  ),
                  child: Center(
                    child: iconoir.HalfMoon(
                        color: cs.primary, width: 26, height: 26),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sleepTimer,
                        style: const TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Music stops after…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active timer pill
                Consumer<SleepTimerController>(
                  builder: (context, timer, _) {
                    if (!timer.isActive) return const SizedBox.shrink();
                    final rem = timer.remainingTime!;
                    final m = rem.inMinutes;
                    final s =
                        (rem.inSeconds % 60).toString().padLeft(2, '0');
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cs.error.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconoir.Timer(
                              color: cs.error, width: 13, height: 13),
                          const SizedBox(width: 4),
                          Text(
                            '$m:$s',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: cs.error,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Big time display ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: _selectedMinutes != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: anim.drive(Tween(begin: 0.82, end: 1.0)),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '$_selectedMinutes',
                          key: ValueKey(_selectedMinutes),
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: cs.primary,
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -3,
                            height: 1.0,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 10),
                        child: Text(
                          'min',
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: cs.primary.withValues(alpha: 0.45),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Colors.white.withValues(alpha: 0.2),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick a duration below',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Horizontal scrollable preset chips ────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = _presets[i];
                final selected = _selectedMinutes == m;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 0 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedMinutes = m),
                      borderRadius: BorderRadius.circular(22),
                      splashColor: cs.onPrimary.withValues(alpha: 0.15),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Center(
                          child: Text(
                            '$m min',
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              color: selected
                                  ? cs.onPrimary
                                  : Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Custom duration row ───────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showCustomPicker,
                borderRadius: BorderRadius.circular(14),
                splashColor: cs.primary.withValues(alpha: 0.10),
                highlightColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (_selectedMinutes != null &&
                            !_presets.contains(_selectedMinutes))
                        ? cs.primaryContainer.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_selectedMinutes != null &&
                              !_presets.contains(_selectedMinutes))
                          ? cs.primary.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: (_selectedMinutes != null &&
                                !_presets.contains(_selectedMinutes))
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedMinutes != null &&
                                !_presets.contains(_selectedMinutes)
                            ? '$_selectedMinutes min (custom)'
                            : l10n.ownTimer,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: (_selectedMinutes != null &&
                                  !_presets.contains(_selectedMinutes))
                              ? cs.primary
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Action buttons ────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
            child: Row(
              children: [
                Consumer<SleepTimerController>(
                  builder: (context, timer, _) {
                    if (!timer.isActive) return const SizedBox.shrink();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            timer.cancelTimer();
                            Navigator.pop(context);
                          },
                          icon: iconoir.TimerOff(
                              color: cs.error, width: 18, height: 18),
                          label: Text(
                            l10n.cancel,
                            style: TextStyle(
                                color: cs.error,
                                fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: cs.error.withValues(alpha: 0.4)),
                            backgroundColor:
                                cs.errorContainer.withValues(alpha: 0.12),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selectedMinutes != null
                        ? () {
                            sleepTimerController.startTimer(
                              Duration(minutes: _selectedMinutes!),
                              () => audioPlayerService.pause(),
                            );
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const iconoir.HalfMoon(
                        color: Colors.white, width: 18, height: 18),
                    label: Text(
                      l10n.set,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      disabledBackgroundColor:
                          cs.primary.withValues(alpha: 0.18),
                      disabledForegroundColor:
                          cs.primary.withValues(alpha: 0.4),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(32)),
      child: isLowEnd
          ? sheetBody
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: sheetBody,
            ),
    );
  }
}

/// A small circular +/- button for the custom time picker.
class _CounterButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _CounterButton(
      {required this.icon, required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: colorScheme.primary.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

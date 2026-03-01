import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/audio_player_service.dart';
import '../../../shared/services/sleep_timer_controller.dart';

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
        if (!sleepTimerController.isActive) return const SizedBox.shrink();

        final remainingTime = sleepTimerController.remainingTime;
        if (remainingTime == null) return const SizedBox.shrink();

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
                            const Icon(
                              Icons.bedtime_outlined,
                              color: Colors.white,
                              size: 16,
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
                            const Icon(
                              Icons.bedtime_outlined,
                              color: Colors.white,
                              size: 16,
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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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

  // Preset durations in minutes shown in the grid
  static const List<int> _presets = [5, 10, 15, 20, 30, 45, 60, 90];

  Widget _buildPresetTile(int minutes, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$minutes',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSelected ? 22 : 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'min',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomPicker() {
    int picked = _selectedMinutes ?? 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('set_minutes'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // +/- counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CounterButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            if (picked > 1) {
                              setDialogState(() => picked--);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              Text(
                                '$picked',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                'min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CounterButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            if (picked < 480) {
                              setDialogState(() => picked++);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedMinutes = picked);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('set'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final sleepTimerController =
        Provider.of<SleepTimerController>(context, listen: false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header row
              Row(
                children: [
                  const Icon(
                    Icons.bedtime_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).translate('sleep_timer'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Active timer badge
                  Consumer<SleepTimerController>(
                    builder: (context, timer, _) {
                      if (!timer.isActive) return const SizedBox.shrink();
                      final rem = timer.remainingTime!;
                      final m = rem.inMinutes;
                      final s = (rem.inSeconds % 60).toString().padLeft(2, '0');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '$m:$s',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Preset grid — 4 columns, 2 rows
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _presets.length,
                itemBuilder: (context, i) {
                  final m = _presets[i];
                  return _buildPresetTile(
                    m,
                    _selectedMinutes == m,
                    () => setState(() => _selectedMinutes = m),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Custom duration button
              GestureDetector(
                onTap: _showCustomPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: Colors.white.withOpacity(0.75),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedMinutes != null &&
                                !_presets.contains(_selectedMinutes)
                            ? '$_selectedMinutes min (custom)'
                            : AppLocalizations.of(context)
                                .translate('own_timer'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Consumer<SleepTimerController>(
                    builder: (context, timer, _) {
                      if (!timer.isActive) return const SizedBox.shrink();
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: TextButton.icon(
                            onPressed: () {
                              timer.cancelTimer();
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.timer_off_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            label: Text(
                              AppLocalizations.of(context).translate('cancel'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.redAccent.withOpacity(0.12),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedMinutes != null
                          ? () {
                              sleepTimerController.startTimer(
                                Duration(minutes: _selectedMinutes!),
                                () => audioPlayerService.pause(),
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            Colors.white.withOpacity(0.2),
                        disabledForegroundColor:
                            Colors.white.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('set'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small circular +/- button for the custom time picker.
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

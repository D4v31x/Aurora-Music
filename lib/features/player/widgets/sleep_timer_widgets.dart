import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../mixins/services/audio_player_service.dart';
import '../../mixins/services/sleep_timer_controller.dart';

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

  Widget _buildCircularOption(String minutes, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              minutes,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSelected ? 20 : 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              'min',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberPicker() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    backgroundColor: Colors.transparent,
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedMinutes = index + 1);
                    },
                    children: List.generate(
                      120,
                      (index) => Center(
                        child: Text(
                          '${index + 1} min',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('set'),
                  ),
                ),
              ],
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            AppLocalizations.of(context).translate('sleep_timer'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularOption('5', _selectedMinutes == 5,
                  () => setState(() => _selectedMinutes = 5)),
              _buildCircularOption('10', _selectedMinutes == 10,
                  () => setState(() => _selectedMinutes = 10)),
              _buildCircularOption('15', _selectedMinutes == 15,
                  () => setState(() => _selectedMinutes = 15)),
              _buildCircularOption('30', _selectedMinutes == 30,
                  () => setState(() => _selectedMinutes = 30)),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _showNumberPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).translate('own_timer'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (sleepTimerController.isActive)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      sleepTimerController.cancelTimer();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.timer_off, color: Colors.redAccent),
                    label: Text(
                        AppLocalizations.of(context).translate('cancel'),
                        style: const TextStyle(color: Colors.redAccent)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (sleepTimerController.isActive) const SizedBox(width: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('set'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

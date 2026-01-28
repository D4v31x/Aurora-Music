import 'package:flutter/material.dart';
import '../../core/constants/font_constants.dart';
import '../../mixins/services/audio_player_service.dart';
import '../../mixins/utils/formatters/duration_formatter.dart';

/// A draggable progress bar for audio playback.
///
/// Displays current position and duration with a slider
/// that supports tap and drag gestures for seeking.
class PlayerProgressBar extends StatefulWidget {
  final AudioPlayerService audioService;
  final bool isTablet;

  const PlayerProgressBar({
    super.key,
    required this.audioService,
    this.isTablet = false,
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isDragging = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = widget.isTablet ? 80.0 : 50.0;

    return StreamBuilder<Duration?>(
      stream: widget.audioService.audioPlayer.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: widget.audioService.audioPlayer.positionStream,
          builder: (context, positionSnapshot) {
            var position = positionSnapshot.data ?? Duration.zero;
            if (position > duration) position = duration;

            final displayPosition = _isDragging
                ? Duration(
                    milliseconds:
                        (_dragValue! * duration.inMilliseconds).round())
                : position;

            final progress = duration.inMilliseconds > 0
                ? (displayPosition.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlider(duration, progress),
                  const SizedBox(height: 4),
                  _buildTimeLabels(displayPosition, duration),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSlider(Duration duration, double progress) {
    return SizedBox(
      height: widget.isTablet ? 44 : 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final percentage =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _isDragging = true;
                _dragValue = percentage;
              });
            },
            onTapUp: (details) {
              if (_dragValue != null) {
                final newPosition = duration * _dragValue!;
                widget.audioService.audioPlayer.seek(newPosition);
              }
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
            },
            onTapCancel: () {
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
            },
            onHorizontalDragStart: (details) {
              final percentage =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _isDragging = true;
                _dragValue = percentage;
              });
            },
            onHorizontalDragUpdate: (details) {
              final percentage =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _dragValue = percentage;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragValue != null) {
                final newPosition = duration * _dragValue!;
                widget.audioService.audioPlayer.seek(newPosition);
              }
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: width,
                height: _isDragging ? 8.0 : 4.0,
                child: Stack(
                  children: [
                    Container(
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(_isDragging ? 4.0 : 2.0),
                      ),
                    ),
                    AnimatedContainer(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 100),
                      width: width * (_isDragging ? _dragValue! : progress),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(_isDragging ? 4.0 : 2.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeLabels(Duration displayPosition, Duration duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formatDurationWithHours(displayPosition),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
        Text(
          formatDurationWithHours(duration),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
      ],
    );
  }
}

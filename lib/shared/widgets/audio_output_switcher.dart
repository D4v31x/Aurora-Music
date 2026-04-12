import 'dart:math';
import 'dart:ui';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';
import '../services/audio_output_service.dart';

// Smooth decelerate — feels like momentum dissipating.
const _smoothDecel = Cubic(0.25, 1.0, 0.5, 1.0);
// Slightly springy overshoot for width expansion.
const _springOut = Cubic(0.175, 0.885, 0.32, 1.05);
// Snappy ease-in for collapse.
const _collapseSnap = Cubic(0.5, 0.0, 0.75, 0.0);

const _green = Color(0xFF10B981);

/// Shows the audio output switcher with a Dynamic Island-style expansion.
Future<void> showAudioOutputSwitcher(
  BuildContext context, {
  Rect? sourceRect,
}) {
  final audioOutputService = AudioOutputService();
  audioOutputService.refreshDevices();

  return Navigator.of(context).push(
    _IslandExpandRoute(
      sourceRect: sourceRect,
      audioOutputService: audioOutputService,
    ),
  );
}

// ---------------------------------------------------------------------------
// Route
// ---------------------------------------------------------------------------

class _IslandExpandRoute extends PopupRoute<void> {
  final Rect? sourceRect;
  final AudioOutputService audioOutputService;

  _IslandExpandRoute({
    this.sourceRect,
    required this.audioOutputService,
  });

  @override
  Color? get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss audio output switcher';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _IslandExpandBody(
      animation: animation,
      sourceRect: sourceRect,
      audioOutputService: audioOutputService,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — morph + content fade
// ---------------------------------------------------------------------------

class _IslandExpandBody extends StatelessWidget {
  final Animation<double> animation;
  final Rect? sourceRect;
  final AudioOutputService audioOutputService;
  final VoidCallback onClose;

  const _IslandExpandBody({
    required this.animation,
    required this.sourceRect,
    required this.audioOutputService,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLowEnd = Provider.of<PerformanceModeProvider>(
      context,
      listen: false,
    ).isLowEndDevice;

    const double dialogHPad = 32;
    const double maxWidth = 360;
    final double dialogWidth =
        (screenSize.width - dialogHPad * 2).clamp(0, maxWidth);
    const double estimatedDialogHeight = 340;

    final dialogRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: dialogWidth,
      height: estimatedDialogHeight,
    );

    // No source pill — simple fade + scale.
    if (sourceRect == null) {
      return _buildFadeTransition(
        dialogRect: dialogRect,
        isLowEnd: isLowEnd,
      );
    }

    return _buildMorphTransition(
      dialogRect: dialogRect,
      src: sourceRect!,
      isLowEnd: isLowEnd,
    );
  }

  Widget _buildFadeTransition({
    required Rect dialogRect,
    required bool isLowEnd,
  }) {
    final fadeAnim = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    return AnimatedBuilder(
      animation: fadeAnim,
      builder: (context, child) {
        final t = fadeAnim.value;
        final scale = lerpDouble(0.92, 1.0, t)!;

        return Stack(
          children: [
            Positioned.fromRect(
              rect: dialogRect,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: t,
                  child: _MorphingIsland(
                    radius: 24,
                    strokeColor: _green,
                    strokeWidth: 1.0,
                    fillOpacity: 1.0,
                    isLowEnd: isLowEnd,
                    child: child!,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: _AudioOutputContent(
        audioOutputService: audioOutputService,
        onClose: onClose,
      ),
    );
  }

  Widget _buildMorphTransition({
    required Rect dialogRect,
    required Rect src,
    required bool isLowEnd,
  }) {
    // Staggered curves — each property has its own timing so the shape
    // feels like it's stretching organically rather than uniformly scaling.
    final widthAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: _springOut),
      reverseCurve: const Interval(0.3, 1.0, curve: _collapseSnap),
    );
    final heightAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.08, 0.85, curve: _smoothDecel),
      reverseCurve: const Interval(0.0, 0.8, curve: _collapseSnap),
    );
    final centerAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.75, curve: _smoothDecel),
      reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
    );
    final fillAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    final contentAnim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final tw = widthAnim.value;
        final th = heightAnim.value;
        final tc = centerAnim.value;
        final tf = fillAnim.value;
        final to = contentAnim.value;

        final currentCenter = Offset.lerp(src.center, dialogRect.center, tc)!;
        final currentWidth =
            lerpDouble(src.width, dialogRect.width, tw)!;
        final currentHeight =
            lerpDouble(src.height, dialogRect.height, th)!;

        final currentRect = Rect.fromCenter(
          center: currentCenter,
          width: currentWidth,
          height: currentHeight,
        );

        final currentRadius = lerpDouble(20, 24, max(tw, th))!;
        const strokeColor = _green;
        final strokeWidth = lerpDouble(1.5, 1.0, tw)!;

        return Stack(
          children: [
            Positioned.fromRect(
              rect: currentRect,
              child: _MorphingIsland(
                radius: currentRadius,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth,
                fillOpacity: tf,
                isLowEnd: isLowEnd,
                child: Opacity(
                  opacity: to,
                  child: child!,
                ),
              ),
            ),
          ],
        );
      },
      child: _AudioOutputContent(
        audioOutputService: audioOutputService,
        onClose: onClose,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Morphing island container
// ---------------------------------------------------------------------------

class _MorphingIsland extends StatelessWidget {
  final double radius;
  final Color strokeColor;
  final double strokeWidth;
  final double fillOpacity;
  final bool isLowEnd;
  final Widget child;

  const _MorphingIsland({
    required this.radius,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillOpacity,
    required this.isLowEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);

    final fillColor = isLowEnd
        ? colorScheme.surfaceContainerHigh.withValues(alpha: fillOpacity)
        : Colors.white.withValues(alpha: 0.1 * fillOpacity);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: borderRadius,
        border: Border.all(color: strokeColor, width: strokeWidth),
        boxShadow: fillOpacity > 0.3
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3 * fillOpacity),
                  blurRadius: 24 * fillOpacity,
                  offset: Offset(0, 8 * fillOpacity),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );

    if (!isLowEnd && fillOpacity > 0.1) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 25 * fillOpacity,
            sigmaY: 25 * fillOpacity,
          ),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ---------------------------------------------------------------------------
// Dialog content
// ---------------------------------------------------------------------------

class _AudioOutputContent extends StatelessWidget {
  final AudioOutputService audioOutputService;
  final VoidCallback onClose;

  const _AudioOutputContent({
    required this.audioOutputService,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
            child: Row(
              children: [
                const Iconoir.SoundHigh(
                  color: _green,
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Audio Output',
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            color: Colors.white.withValues(alpha: 0.1),
            height: 1,
          ),
          // Device list + current device
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListenableBuilder(
      listenable: audioOutputService,
      builder: (context, _) {
        final devices = audioOutputService.devices;

        if (devices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No audio devices found',
              style: TextStyle(
                fontFamily: FontConstants.fontFamily,
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final activeDevice = audioOutputService.activeDevice;
        final nonActiveDevices =
            devices.where((d) => !d.isActive).toList();

        return Column(
          children: [
            // Scrollable device list
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < devices.length; i++) ...[
                      _DeviceRow(
                        device: devices[i],
                        onTap: () => _onDeviceTap(devices[i]),
                      ),
                      if (i < devices.length - 1)
                        Divider(
                          color: Colors.white.withValues(alpha: 0.07),
                          height: 1,
                          indent: 44,
                          endIndent: 16,
                        ),
                    ],
                    if (nonActiveDevices.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No other devices detected',
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
            // Current device — pinned at bottom, edge-to-edge
            if (activeDevice != null)
              _CurrentDeviceCard(device: activeDevice),
          ],
        );
      },
    );
  }

  Future<void> _onDeviceTap(AudioOutputDevice device) async {
    await HapticFeedback.selectionClick();
    await audioOutputService.switchTo(device.id);
  }
}

// ---------------------------------------------------------------------------
// Device row — single-line: icon  Name • Type             [battery]
// ---------------------------------------------------------------------------

class _DeviceRow extends StatelessWidget {
  final AudioOutputDevice device;
  final VoidCallback onTap;

  const _DeviceRow({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = device.isActive;
    final baseColor = isActive ? _green : Colors.white;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Small inline icon
            _buildIcon(baseColor),
            const SizedBox(width: 12),
            // "Name • Type"
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: device.name,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: baseColor,
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: '  •  ${_typeLabel()}',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        color: isActive
                            ? _green.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Battery indicator for active Bluetooth
            if (isActive &&
                device.type == AudioOutputType.bluetooth &&
                device.batteryLevel >= 0) ...[
              const SizedBox(width: 8),
              _BatteryIndicator(level: device.batteryLevel),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    const s = 18.0;
    switch (device.type) {
      case AudioOutputType.bluetooth:
        return Icon(Icons.bluetooth_rounded, color: color, size: s);
      case AudioOutputType.wiredHeadset:
        return Iconoir.Headset(color: color, width: s, height: s);
      case AudioOutputType.usb:
        return Iconoir.Usb(color: color, width: s, height: s);
      case AudioOutputType.phone:
      case AudioOutputType.speaker:
        return Iconoir.SmartphoneDevice(color: color, width: s, height: s);
      case AudioOutputType.unknown:
        return Iconoir.SoundHigh(color: color, width: s, height: s);
    }
  }

  String _typeLabel() {
    switch (device.type) {
      case AudioOutputType.bluetooth:
        return 'Bluetooth Device';
      case AudioOutputType.wiredHeadset:
        return 'Wired';
      case AudioOutputType.usb:
        return 'USB Audio';
      case AudioOutputType.phone:
        return 'Built-in Speaker';
      case AudioOutputType.speaker:
        return 'Speaker';
      case AudioOutputType.unknown:
        return 'Audio Output';
    }
  }
}

// ---------------------------------------------------------------------------
// Battery indicator
// ---------------------------------------------------------------------------

class _BatteryIndicator extends StatelessWidget {
  final int level;

  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level <= 15 ? const Color(0xFFEF4444) : _green;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          level <= 15
              ? Icons.battery_alert_rounded
              : level <= 50
                  ? Icons.battery_3_bar_rounded
                  : Icons.battery_full_rounded,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 2),
        Text(
          '$level%',
          style: TextStyle(
            fontFamily: FontConstants.fontFamily,
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Current Device card at the bottom
// ---------------------------------------------------------------------------

class _CurrentDeviceCard extends StatelessWidget {
  final AudioOutputDevice device;

  const _CurrentDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: _green.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          color: _green.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            // Left: label + name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Device',
                    style: TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: _green.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontFamily: FontConstants.fontFamily,
                      color: _green,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (device.type == AudioOutputType.bluetooth &&
                      device.batteryLevel >= 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          device.batteryLevel <= 15
                              ? Icons.battery_alert_rounded
                              : Icons.battery_full_rounded,
                          color: device.batteryLevel <= 15
                              ? const Color(0xFFEF4444)
                              : _green.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${device.batteryLevel}%',
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            color: device.batteryLevel <= 15
                                ? const Color(0xFFEF4444)
                                : _green.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Right: large device icon
            _buildLargeIcon(),
          ],
        ),
    );
  }

  Widget _buildLargeIcon() {
    final color = _green.withValues(alpha: 0.5);
    const s = 36.0;
    switch (device.type) {
      case AudioOutputType.bluetooth:
        return Icon(Icons.bluetooth_rounded, color: color, size: s);
      case AudioOutputType.wiredHeadset:
        return Iconoir.Headset(color: color, width: s, height: s);
      case AudioOutputType.usb:
        return Iconoir.Usb(color: color, width: s, height: s);
      case AudioOutputType.phone:
      case AudioOutputType.speaker:
        return Iconoir.SmartphoneDevice(color: color, width: s, height: s);
      case AudioOutputType.unknown:
        return Iconoir.SoundHigh(color: color, width: s, height: s);
    }
  }
}

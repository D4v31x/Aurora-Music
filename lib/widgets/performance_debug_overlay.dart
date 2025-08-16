import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_mode_provider.dart';
import '../utils/frame_rate_monitor.dart';
import '../utils/device_capabilities.dart';

/// Debug overlay widget for performance monitoring and testing
/// Only visible in debug mode
class PerformanceDebugOverlay extends StatefulWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceDebugOverlay({
    super.key,
    required this.child,
    this.showOverlay = kDebugMode,
  });

  @override
  State<PerformanceDebugOverlay> createState() => _PerformanceDebugOverlayState();
}

class _PerformanceDebugOverlayState extends State<PerformanceDebugOverlay> {
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.showOverlay) {
      FrameRateMonitor.instance.startMonitoring();
    }
  }
  
  @override
  void dispose() {
    FrameRateMonitor.instance.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showOverlay) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: _buildDebugOverlay(),
        ),
      ],
    );
  }

  Widget _buildDebugOverlay() {
    return Consumer<PerformanceModeProvider>(
      builder: (context, performanceProvider, _) {
        return Container(
          constraints: BoxConstraints(
            maxWidth: _isExpanded ? 280 : 120,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Debug',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isExpanded) ...[
                        const SizedBox(width: 8),
                        _buildFpsIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              
              if (_isExpanded) ...[
                const Divider(color: Colors.grey, height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPerformanceInfo(),
                      const SizedBox(height: 8),
                      _buildDeviceInfo(performanceProvider),
                      const SizedBox(height: 8),
                      _buildControlButtons(performanceProvider),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFpsIndicator() {
    return StreamBuilder<double>(
      stream: Stream.periodic(const Duration(milliseconds: 500), (_) => FrameRateMonitor.instance.currentFps),
      builder: (context, snapshot) {
        final fps = snapshot.data ?? 0.0;
        final assessment = FrameRateMonitor.instance.getPerformanceAssessment();
        
        Color color;
        switch (assessment) {
          case PerformanceAssessment.excellent:
            color = Colors.green;
            break;
          case PerformanceAssessment.good:
            color = Colors.yellow;
            break;
          case PerformanceAssessment.fair:
            color = Colors.orange;
            break;
          case PerformanceAssessment.poor:
            color = Colors.red;
            break;
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${fps.toStringAsFixed(0)} FPS',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceInfo() {
    return StreamBuilder<double>(
      stream: Stream.periodic(const Duration(milliseconds: 500), (_) => FrameRateMonitor.instance.currentFps),
      builder: (context, snapshot) {
        final fps = snapshot.data ?? 0.0;
        final assessment = FrameRateMonitor.instance.getPerformanceAssessment();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'FPS: ${fps.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              'Status: ${assessment.displayName}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceInfo(PerformanceModeProvider performanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Level: ${DeviceCapabilities.isLowEndDevice ? "Low-End" : "High-End"}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (performanceProvider.isInitialized)
          Text(
            'Mode: ${performanceProvider.currentModeDisplayName}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        Text(
          'Target: ${DeviceCapabilities.targetFrameRate} FPS',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildControlButtons(PerformanceModeProvider performanceProvider) {
    return Column(
      children: [
        Text(
          'Controls',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeButton('High', PerformanceLevel.high, performanceProvider),
            const SizedBox(width: 4),
            _buildModeButton('Med', PerformanceLevel.medium, performanceProvider),
            const SizedBox(width: 4),
            _buildModeButton('Low', PerformanceLevel.low, performanceProvider),
          ],
        ),
      ],
    );
  }

  Widget _buildModeButton(String label, PerformanceLevel level, PerformanceModeProvider provider) {
    final isSelected = provider.currentMode == level;
    
    return GestureDetector(
      onTap: () {
        provider.setPerformanceMode(level);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
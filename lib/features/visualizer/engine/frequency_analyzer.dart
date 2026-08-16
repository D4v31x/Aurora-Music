/// Turns raw FFT complex-pair bytes from the native Visualizer channel into
/// an [AudioFeatureFrame]-ready spectrum + configurable named frequency-range
/// energies. Generalizes the old visualizer's hard-coded 48-bar log-bin
/// mapping into arbitrary, user-configurable [FrequencyRange]s.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_feature_frame.dart';

class FrequencyAnalyzerConfig {
  /// Number of spectrum bins to expose (independent of the frequency
  /// ranges below — this is just spectrum resolution for e.g. bar/line
  /// elements).
  final int spectrumResolution;
  final List<FrequencyRange> frequencyRanges;
  final double sampleRateHz;

  const FrequencyAnalyzerConfig({
    this.spectrumResolution = 64,
    this.frequencyRanges = FrequencyRange.defaults,
    this.sampleRateHz = 44100,
  });
}

class FrequencyAnalysisResult {
  final List<double> spectrum;
  final Map<String, double> frequencyEnergies;
  final double overallEnergy;
  final double rms;

  const FrequencyAnalysisResult({
    required this.spectrum,
    required this.frequencyEnergies,
    required this.overallEnergy,
    required this.rms,
  });

  static const empty = FrequencyAnalysisResult(
    spectrum: [],
    frequencyEnergies: {},
    overallEnergy: 0,
    rms: 0,
  );
}

/// Stateful only in that it smooths bin magnitudes frame-to-frame (matching
/// the feel of the previous visualizer) — holds no audio-analysis logic
/// beyond that simple attack/decay filter.
class FrequencyAnalyzer {
  final FrequencyAnalyzerConfig config;

  List<double>? _smoothedBins;
  late final List<int> _binStart;
  late final List<int> _binEnd;
  late final Map<String, (int start, int end)> _rangeBins;

  static const int _kFirstBin = 1;
  static const int _kLastBin = 256;

  FrequencyAnalyzer([this.config = const FrequencyAnalyzerConfig()]) {
    _initBins();
  }

  void _initBins() {
    final n = config.spectrumResolution;
    _binStart = List.filled(n, 0);
    _binEnd = List.filled(n, 1);
    for (int i = 0; i < n; i++) {
      final t0 = i / n;
      final t1 = (i + 1) / n;
      final s = (_kFirstBin * math.pow(_kLastBin / _kFirstBin, t0))
          .round()
          .clamp(_kFirstBin, _kLastBin);
      final e = (_kFirstBin * math.pow(_kLastBin / _kFirstBin, t1))
          .round()
          .clamp(s + 1, _kLastBin + 1);
      _binStart[i] = s;
      _binEnd[i] = e;
    }

    final binHz = config.sampleRateHz / 2 / _kLastBin;
    _rangeBins = {
      for (final range in config.frequencyRanges)
        range.name: (
          (range.minHz / binHz).round().clamp(_kFirstBin, _kLastBin),
          (range.maxHz / binHz).round().clamp(_kFirstBin + 1, _kLastBin + 1),
        ),
    };
  }

  /// Parses a raw FFT packet (0x01-prefixed complex-pair bytes, as sent by
  /// the native Visualizer channel) into a [FrequencyAnalysisResult]. Never
  /// throws — returns [FrequencyAnalysisResult.empty] on malformed input so
  /// a single bad packet can't take down the visualizer.
  FrequencyAnalysisResult analyzeFftPacket(Uint8List data) {
    try {
      if (data.length < 3) return FrequencyAnalysisResult.empty;
      final bd = data.buffer.asByteData(data.offsetInBytes, data.length);
      final fftLen = data.length - 1;
      final maxBin = (fftLen ~/ 2) - 1;
      if (maxBin < _kFirstBin) return FrequencyAnalysisResult.empty;

      // Raw magnitude per output spectrum bin, smoothed frame-to-frame.
      final smoothed = _smoothedBins ??= List.filled(config.spectrumResolution, 0.0);
      double totalEnergy = 0.0;
      double sumSquares = 0.0;
      int sampleCount = 0;

      for (int i = 0; i < config.spectrumResolution; i++) {
        final binStart = _binStart[i].clamp(1, maxBin);
        final binEnd = _binEnd[i].clamp(binStart + 1, maxBin + 1);
        final raw = _magnitudeForBinRange(bd, data.length, binStart, binEnd);
        final alpha = raw > smoothed[i] ? 0.30 : 0.10;
        smoothed[i] = (smoothed[i] * (1 - alpha) + raw.clamp(0.0, 1.0) * alpha)
            .clamp(0.0, 1.0);
        totalEnergy += smoothed[i];
        sumSquares += smoothed[i] * smoothed[i];
        sampleCount++;
      }

      final frequencyEnergies = <String, double>{
        for (final entry in _rangeBins.entries)
          entry.key: _magnitudeForBinRange(
              bd, data.length, entry.value.$1, entry.value.$2)
              .clamp(0.0, 1.0),
      };

      final overallEnergy =
          sampleCount == 0 ? 0.0 : (totalEnergy / sampleCount).clamp(0.0, 1.0);
      final rms =
          sampleCount == 0 ? 0.0 : math.sqrt(sumSquares / sampleCount).clamp(0.0, 1.0);

      return FrequencyAnalysisResult(
        spectrum: List<double>.from(smoothed),
        frequencyEnergies: frequencyEnergies,
        overallEnergy: overallEnergy,
        rms: rms,
      );
    } catch (_) {
      return FrequencyAnalysisResult.empty;
    }
  }

  double _magnitudeForBinRange(
      ByteData bd, int dataLength, int binStart, int binEnd) {
    double sum = 0.0;
    int count = 0;
    for (int b = binStart; b < binEnd; b++) {
      final idx = 1 + b * 2; // +1 to skip the 0x01 type-prefix byte
      if (idx + 1 >= dataLength) break;
      final real = bd.getInt8(idx).toDouble();
      final imag = bd.getInt8(idx + 1).toDouble();
      sum += math.sqrt(real * real + imag * imag);
      count++;
    }
    return count > 0 ? (sum / count) / 200.0 : 0.0;
  }
}

/// Parses raw waveform bytes from the native Visualizer channel (0x02
/// type-prefixed, unsigned 8-bit PCM-ish samples per Android's
/// `Visualizer.OnDataCaptureListener.onWaveFormDataCapture`) into a
/// normalized -1.0..1.0 waveform for waveform-reactive visualizer elements.
library;

import 'dart:typed_data';

/// Parses a 0x02-prefixed waveform packet. Never throws — returns an empty
/// list on malformed input.
List<double> parseWaveformPacket(Uint8List data, {int targetLength = 128}) {
  try {
    if (data.length < 2) return const [];
    final sampleCount = data.length - 1;
    if (sampleCount <= 0) return const [];

    // Downsample to targetLength by simple stride-picking — waveform
    // elements only need a visually-representative shape, not every sample.
    final step = (sampleCount / targetLength).clamp(1, sampleCount).floor();
    final result = <double>[];
    for (int i = 1; i < data.length; i += step) {
      result.add((data[i] - 128) / 128.0);
    }
    return result;
  } catch (_) {
    return const [];
  }
}

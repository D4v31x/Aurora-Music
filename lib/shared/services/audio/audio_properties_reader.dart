import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Reads audio properties (sample rate) from file binary headers without
/// external dependencies.
///
/// Supported formats:
///   - FLAC: STREAMINFO block
///   - MP3 / ID3v2: First valid MPEG frame header
///   - OGG Vorbis / OGG Opus: Identification header
///   - MP4 / M4A / AAC / ALAC: mdhd time-scale box
///   - WAV: RIFF fmt chunk
class AudioPropertiesReader {
  static const int _maxReadBytes = 65536;

  /// Bounded LRU-style cache: path → sample rate in Hz.
  static final Map<String, int?> _cache = {};
  static const int _cacheMaxSize = 200;

  /// Returns the actual sample rate in Hz from the audio file, or `null` when
  /// the format is unrecognised or the file cannot be read.
  static Future<int?> readSampleRate(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath];

    final result = await _read(filePath);

    if (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[filePath] = result;
    return result;
  }

  /// Invalidates one (or all) cached entries — call after the file changes.
  static void clearCache([String? filePath]) {
    if (filePath != null) {
      _cache.remove(filePath);
    } else {
      _cache.clear();
    }
  }

  /// Formats a sample rate in Hz as a human-readable kHz string,
  /// e.g. 44100 → "44.1 kHz", 48000 → "48 kHz".
  static String format(int? hz) {
    if (hz == null || hz <= 0) return '—';
    if (hz % 1000 == 0) return '${hz ~/ 1000} kHz';
    return '${(hz / 1000.0).toStringAsFixed(1)} kHz';
  }

  // ---------------------------------------------------------------------------
  // Internal entry point
  // ---------------------------------------------------------------------------

  static Future<int?> _read(String filePath) async {
    RandomAccessFile? raf;
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      raf = await file.open();
      final fileLen = await raf.length();
      if (fileLen < 12) return null;

      await raf.setPosition(0);
      final magic = await raf.read(12);
      if (magic.length < 4) return null;

      // FLAC – "fLaC"
      if (magic[0] == 0x66 && magic[1] == 0x4C &&
          magic[2] == 0x61 && magic[3] == 0x43) {
        final headLen = math.min(_maxReadBytes, fileLen);
        await raf.setPosition(0);
        final bytes = await raf.read(headLen);
        return _flac(bytes);
      }

      // ID3v2 → almost certainly MP3
      if (magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33) {
        final headLen = math.min(_maxReadBytes, fileLen);
        await raf.setPosition(0);
        final bytes = await raf.read(headLen);
        return _mp3(bytes);
      }

      // OGG container – "OggS"
      if (magic[0] == 0x4F && magic[1] == 0x67 &&
          magic[2] == 0x67 && magic[3] == 0x53) {
        final headLen = math.min(_maxReadBytes, fileLen);
        await raf.setPosition(0);
        final bytes = await raf.read(headLen);
        return _ogg(bytes);
      }

      // MP4 / M4A – "ftyp" box at offset 4
      if (magic.length >= 8 && magic[4] == 0x66 && magic[5] == 0x74 &&
          magic[6] == 0x79 && magic[7] == 0x70) {
        return await _mp4(raf, fileLen);
      }

      // WAV – "RIFF"
      if (magic[0] == 0x52 && magic[1] == 0x49 &&
          magic[2] == 0x46 && magic[3] == 0x46) {
        final headLen = math.min(_maxReadBytes, fileLen);
        await raf.setPosition(0);
        final bytes = await raf.read(headLen);
        return _wav(bytes);
      }

      // Raw MP3 without ID3 tag
      final headLen = math.min(_maxReadBytes, fileLen);
      await raf.setPosition(0);
      final bytes = await raf.read(headLen);
      return _mp3(bytes);
    } catch (e) {
      debugPrint('[AudioProperties] Error reading $filePath: $e');
      return null;
    } finally {
      await raf?.close();
    }
  }

  // ---------------------------------------------------------------------------
  // FLAC — STREAMINFO block (block type 0)
  // ---------------------------------------------------------------------------

  static int? _flac(Uint8List bytes) {
    int pos = 4; // skip "fLaC"
    while (pos + 4 <= bytes.length) {
      final blockHeader = bytes[pos];
      final isLast = (blockHeader & 0x80) != 0;
      final blockType = blockHeader & 0x7F;
      final blockLen =
          (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
      pos += 4;
      if (pos + blockLen > bytes.length) break;

      if (blockType == 0 && blockLen >= 14) {
        // Layout within STREAMINFO data:
        //   [0-1]  min_block_size
        //   [2-3]  max_block_size
        //   [4-6]  min_frame_size
        //   [7-9]  max_frame_size
        //   [10-12] sample_rate (20 bits) | channels-1 (3 bits) | bps-1 (5 bits)
        // sample_rate = byte[10]<<12 | byte[11]<<4 | byte[12]>>4
        final sr = (bytes[pos + 10] << 12) |
            (bytes[pos + 11] << 4) |
            (bytes[pos + 12] >> 4);
        return sr > 0 ? sr : null;
      }

      pos += blockLen;
      if (isLast) break;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // MP3 — scan for first valid MPEG sync frame
  // ---------------------------------------------------------------------------

  // Sample-rate lookup tables indexed by [version][srIndex]
  static const _mp3Sr = [
    [11025, 12000, 8000],  // MPEG 2.5
    <int>[],               // reserved
    [22050, 24000, 16000], // MPEG 2
    [44100, 48000, 32000], // MPEG 1
  ];

  static int? _mp3(Uint8List bytes) {
    for (int i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] != 0xFF) continue;
      final b1 = bytes[i + 1];
      if ((b1 & 0xE0) != 0xE0) continue; // 11-bit sync must be all 1s

      final version = (b1 >> 3) & 0x03; // 00=2.5, 01=reserved, 10=2, 11=1
      final layer = (b1 >> 1) & 0x03;   // 00=reserved, 01=L3, 10=L2, 11=L1
      if (version == 1 || layer == 0) continue;

      final b2 = bytes[i + 2];
      final bitrateIdx = (b2 >> 4) & 0x0F;
      final srIdx = (b2 >> 2) & 0x03;
      if (srIdx == 3 || bitrateIdx == 0x0F) continue; // reserved/invalid

      final table = _mp3Sr[version];
      if (table.isEmpty || srIdx >= table.length) continue;
      return table[srIdx];
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // OGG — Opus identification header or Vorbis identification header
  // ---------------------------------------------------------------------------

  static int? _ogg(Uint8List bytes) {
    // OpusHead: bytes "OpusHead" (8 bytes) + version (1) + channels (1) +
    //           pre-skip (2 LE) + input sample rate (4 LE)
    for (int i = 0; i + 16 <= bytes.length; i++) {
      if (bytes[i] == 0x4F && bytes[i + 1] == 0x70 &&
          bytes[i + 2] == 0x75 && bytes[i + 3] == 0x73 &&
          bytes[i + 4] == 0x48 && bytes[i + 5] == 0x65 &&
          bytes[i + 6] == 0x61 && bytes[i + 7] == 0x64) {
        final sr = _uint32le(bytes, i + 12);
        return sr > 0 ? sr : 48000; // Opus always decodes at 48 kHz
      }
    }

    // Vorbis ID header: 0x01 + "vorbis" (6) + version (4) + channels (1) +
    //                   sample rate (4 LE)
    for (int i = 0; i + 16 <= bytes.length; i++) {
      if (bytes[i] == 0x01 &&
          bytes[i + 1] == 0x76 && bytes[i + 2] == 0x6F &&
          bytes[i + 3] == 0x72 && bytes[i + 4] == 0x62 &&
          bytes[i + 5] == 0x69 && bytes[i + 6] == 0x73) {
        final sr = _uint32le(bytes, i + 12);
        return sr > 0 ? sr : null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // MP4 / M4A — walk boxes to find the audio `mdhd` time-scale
  // ---------------------------------------------------------------------------

  static Future<int?> _mp4(RandomAccessFile raf, int fileLen) async {
    // Read the first 4 MB; mdhd is deep inside moov but always near the start
    // for streamable files.
    final readLen = math.min(4 * 1024 * 1024, fileLen);
    await raf.setPosition(0);
    final bytes = await raf.read(readLen);
    return _mp4Container(bytes, 0, bytes.length);
  }

  static const _mp4Containers = {
    'moov', 'trak', 'mdia', 'minf', 'stbl', 'udta', 'ilst'
  };

  static int? _mp4Container(Uint8List b, int start, int end) {
    int pos = start;
    while (pos + 8 <= end) {
      int size = _uint32be(b, pos);
      if (pos + 8 > end) break;
      final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
      int headerSize = 8;

      if (size == 1) {
        if (pos + 16 > end) break;
        size = _uint64be(b, pos + 8);
        headerSize = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < headerSize || size > 100 * 1024 * 1024) break;

      final childEnd = math.min(pos + size, end);

      if (type == 'mdhd') {
        // mdhd: version(1)+flags(3) | creation(4or8) | modification(4or8) |
        //       time_scale(4) = sample rate for audio tracks
        if (pos + headerSize < end) {
          final version = b[pos + headerSize];
          // v0: creation(4)+modification(4) = 8 bytes; v1: 8+8 = 16 bytes
          final timeScaleOffset =
              pos + headerSize + 4 + (version == 1 ? 16 : 8);
          if (timeScaleOffset + 4 <= end) {
            final sr = _uint32be(b, timeScaleOffset);
            // Guard: audio sample rates are between 1 kHz and 200 kHz
            if (sr >= 1000 && sr <= 200000) return sr;
          }
        }
      } else if (_mp4Containers.contains(type)) {
        final r = _mp4Container(b, pos + headerSize, childEnd);
        if (r != null) return r;
      }

      pos += size;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // WAV — RIFF fmt chunk
  // ---------------------------------------------------------------------------

  static int? _wav(Uint8List bytes) {
    // RIFF(4) + file-size(4) + "WAVE"(4) = 12-byte header
    if (bytes.length < 36) return null;
    if (bytes[8] != 0x57 || bytes[9] != 0x41 ||
        bytes[10] != 0x56 || bytes[11] != 0x45) {
      return null;
    }

    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = _uint32le(bytes, pos + 4);
      pos += 8;

      if (chunkId == 'fmt ') {
        // fmt chunk: audio-format(2) + channels(2) + sample-rate(4) + ...
        if (pos + 8 <= bytes.length) {
          final sr = _uint32le(bytes, pos + 4);
          return sr > 0 ? sr : null;
        }
        break;
      }
      // Chunks are word-aligned (padded to even size)
      pos += chunkSize + (chunkSize & 1);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Integer helpers
  // ---------------------------------------------------------------------------

  static int _uint32be(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  static int _uint32le(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static int _uint64be(Uint8List b, int o) {
    int v = 0;
    for (int i = 0; i < 8; i++) {
      v = (v << 8) | b[o + i];
    }
    return v;
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Reads ReplayGain track gain from audio files without external dependencies.
///
/// Supported formats:
///   - MP3 / any file with an ID3v2.2, v2.3, or v2.4 header
///   - FLAC (reads the VORBIS_COMMENT metadata block)
///   - OGG Vorbis / OGG Opus (byte-level scan for the Vorbis comment pattern)
///
/// Usage:
///   final multiplier = await ReplayGainReader.getVolumeMultiplier(song.data);
///   await audioPlayer.setVolume(multiplier);
class ReplayGainReader {
  /// Maximum bytes read from a file for tag scanning (64 KB).
  /// ID3v2 and FLAC Vorbis comment blocks always appear at the very start
  /// of the file, so 64 KB is more than sufficient.
  static const int _maxReadBytes = 65536;

  /// Bounded simple LRU-style cache: path → volume multiplier.
  static final Map<String, double> _cache = {};
  static const int _cacheMaxSize = 200;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the linear volume multiplier (clamped to [0.1, 1.0]) derived from
  /// the REPLAYGAIN_TRACK_GAIN tag in [filePath].
  ///
  /// Returns **1.0** when:
  ///   - no ReplayGain tag is present, or
  ///   - the file format is not recognised, or
  ///   - the file cannot be read.
  static Future<double> getVolumeMultiplier(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final gainDb = await _readGainDb(filePath);
    final multiplier = gainDb == null
        ? 1.0
        : math.pow(10.0, gainDb / 20.0).toDouble().clamp(0.1, 1.0);

    if (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[filePath] = multiplier;
    return multiplier;
  }

  /// Removes one (or all) cached entries.
  /// Call this after editing a file's tags so the new value is re-read.
  static void clearCache([String? filePath]) {
    if (filePath != null) {
      _cache.remove(filePath);
    } else {
      _cache.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Format detection
  // ---------------------------------------------------------------------------

  static Future<double?> _readGainDb(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final raw = await file
          .openRead(0, _maxReadBytes)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));

      if (raw.length < 4) return null;
      final bytes = Uint8List.fromList(raw);

      // ID3v2 – "ID3"
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return _parseId3v2(bytes);
      }
      // FLAC – "fLaC"
      if (bytes[0] == 0x66 &&
          bytes[1] == 0x4C &&
          bytes[2] == 0x61 &&
          bytes[3] == 0x43) {
        return _parseFlac(bytes);
      }
      // OGG container – "OggS"
      if (bytes[0] == 0x4F &&
          bytes[1] == 0x67 &&
          bytes[2] == 0x67 &&
          bytes[3] == 0x53) {
        return _scanVorbisComment(bytes);
      }
      return null;
    } catch (e) {
      debugPrint('[ReplayGain] Error reading $filePath: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ID3v2 parser (v2.2, v2.3, v2.4)
  // ---------------------------------------------------------------------------

  static double? _parseId3v2(Uint8List bytes) {
    if (bytes.length < 10) return null;
    final version = bytes[3]; // 2, 3, or 4
    if (version < 2 || version > 4) return null;

    final tagSize = _synchsafe(bytes, 6);
    final tagEnd = (10 + tagSize).clamp(0, bytes.length);

    int pos = 10;

    // Skip optional extended header (v2.3/v2.4, flag bit 6 of byte 5)
    if (version >= 3 && (bytes[5] & 0x40) != 0) {
      if (pos + 4 > tagEnd) return null;
      final extSize =
          version == 4 ? _synchsafe(bytes, pos) : _uint32be(bytes, pos);
      pos += extSize;
    }

    final headerLen = version == 2 ? 6 : 10;

    while (pos + headerLen <= tagEnd) {
      if (bytes[pos] == 0) break; // padding

      String frameId;
      int frameSize;

      if (version == 2) {
        // 3-char frame ID + 3-byte big-endian size
        frameId = String.fromCharCodes(bytes.sublist(pos, pos + 3));
        frameSize =
            (bytes[pos + 3] << 16) | (bytes[pos + 4] << 8) | bytes[pos + 5];
        pos += 6;
      } else {
        // 4-char frame ID + 4-byte size + 2-byte flags
        frameId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        frameSize =
            version == 4 ? _synchsafe(bytes, pos + 4) : _uint32be(bytes, pos + 4);
        pos += 10;
      }

      if (frameSize <= 0 || pos + frameSize > tagEnd) break;

      final frameEnd = pos + frameSize;

      if ((version == 2 && frameId == 'TXX') ||
          (version >= 3 && frameId == 'TXXX')) {
        final gain = _parseTxxx(bytes, pos, frameEnd);
        if (gain != null) return gain;
      }

      pos = frameEnd;
    }
    return null;
  }

  /// Parse TXXX frame content starting at [start] (after the 10-byte header).
  static double? _parseTxxx(Uint8List bytes, int start, int end) {
    if (start >= end) return null;
    final encoding = bytes[start];
    start++;

    String desc;
    String value;

    if (encoding == 1 || encoding == 2) {
      // UTF-16 with BOM (1) or UTF-16BE without BOM (2)
      int i = start;
      bool bigEndian = encoding == 2;

      // Consume optional BOM
      if (i + 1 < end) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xFE) {
          bigEndian = false;
          i += 2;
        } else if (bytes[i] == 0xFE && bytes[i + 1] == 0xFF) {
          bigEndian = true;
          i += 2;
        }
      }

      // Find double-null terminator for the description field
      int descEnd = i;
      while (descEnd + 1 < end &&
          !(bytes[descEnd] == 0 && bytes[descEnd + 1] == 0)) {
        descEnd += 2;
      }

      desc = _decodeUtf16(bytes, i, descEnd, bigEndian).toLowerCase().trim();

      // Skip the double-null terminator
      int valueStart = descEnd + 2;

      // The value field may have its own BOM
      if (valueStart + 1 < end) {
        if (bytes[valueStart] == 0xFF && bytes[valueStart + 1] == 0xFE) {
          bigEndian = false;
          valueStart += 2;
        } else if (bytes[valueStart] == 0xFE && bytes[valueStart + 1] == 0xFF) {
          bigEndian = true;
          valueStart += 2;
        }
      }

      // Find end of value (double-null or frame boundary)
      int valueEnd = valueStart;
      while (valueEnd + 1 < end &&
          !(bytes[valueEnd] == 0 && bytes[valueEnd + 1] == 0)) {
        valueEnd += 2;
      }

      value = _decodeUtf16(bytes, valueStart, valueEnd, bigEndian).trim();
    } else {
      // Latin-1 (0) or UTF-8 (3) – single-byte null terminator
      int nullIdx = start;
      while (nullIdx < end && bytes[nullIdx] != 0) {
        nullIdx++;
      }

      desc = String.fromCharCodes(bytes.sublist(start, nullIdx))
          .toLowerCase()
          .trim();

      final valueStart = nullIdx + 1;
      int valueEnd = valueStart;
      while (valueEnd < end && bytes[valueEnd] != 0) {
        valueEnd++;
      }

      value =
          String.fromCharCodes(bytes.sublist(valueStart, valueEnd)).trim();
    }

    if (desc == 'replaygain_track_gain') return _parseDb(value);
    return null;
  }

  // ---------------------------------------------------------------------------
  // FLAC parser
  // ---------------------------------------------------------------------------

  static double? _parseFlac(Uint8List bytes) {
    int pos = 4; // skip "fLaC"
    while (pos + 4 <= bytes.length) {
      final blockHeader = bytes[pos];
      final isLast = (blockHeader & 0x80) != 0;
      final blockType = blockHeader & 0x7F;
      final blockLen =
          (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
      pos += 4;

      if (pos + blockLen > bytes.length) break;

      if (blockType == 4) {
        // VORBIS_COMMENT block
        return _parseVorbisCommentBlock(bytes, pos, pos + blockLen);
      }

      pos += blockLen;
      if (isLast) break;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Vorbis comment block (shared by FLAC; also used via byte-scan for OGG)
  // ---------------------------------------------------------------------------

  static double? _parseVorbisCommentBlock(
      Uint8List bytes, int start, int end) {
    if (start + 4 > end) return null;

    // Vendor string length (little-endian uint32)
    final vendorLen = _uint32le(bytes, start);
    int pos = start + 4 + vendorLen;
    if (pos + 4 > end) return null;

    final commentCount = _uint32le(bytes, pos);
    pos += 4;

    for (int i = 0; i < commentCount && pos + 4 <= end; i++) {
      final commentLen = _uint32le(bytes, pos);
      pos += 4;
      if (commentLen <= 0 || pos + commentLen > end) break;

      final comment =
          String.fromCharCodes(bytes.sublist(pos, pos + commentLen));
      final eqIdx = comment.indexOf('=');
      if (eqIdx > 0) {
        final key = comment.substring(0, eqIdx).toUpperCase();
        if (key == 'REPLAYGAIN_TRACK_GAIN') {
          return _parseDb(comment.substring(eqIdx + 1).trim());
        }
      }
      pos += commentLen;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // OGG: byte-level scan for Vorbis/Opus comment tags
  // ---------------------------------------------------------------------------

  /// Scans raw bytes for a case-insensitive "REPLAYGAIN_TRACK_GAIN=" pattern.
  /// This is format-agnostic and works for both OGG Vorbis and OGG Opus.
  static double? _scanVorbisComment(Uint8List bytes) {
    const pattern = 'replaygain_track_gain=';
    final patternBytes = Uint8List.fromList(pattern.codeUnits);
    final len = patternBytes.length;

    outer:
    for (int i = 0; i <= bytes.length - len; i++) {
      for (int j = 0; j < len; j++) {
        // Lowercase the byte before comparing
        final b = bytes[i + j] >= 0x41 && bytes[i + j] <= 0x5A
            ? bytes[i + j] | 0x20
            : bytes[i + j];
        if (b != patternBytes[j]) continue outer;
      }
      // Found — read value until null, LF, or CR
      int valueEnd = i + len;
      while (valueEnd < bytes.length &&
          bytes[valueEnd] != 0 &&
          bytes[valueEnd] != 0x0A &&
          bytes[valueEnd] != 0x0D) {
        valueEnd++;
      }
      final value =
          String.fromCharCodes(bytes.sublist(i + len, valueEnd)).trim();
      return _parseDb(value);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Decodes a range of [bytes] as UTF-16 (big or little endian).
  /// Only code points ≤ U+007F are kept; others are silently dropped.
  static String _decodeUtf16(
      Uint8List bytes, int start, int end, bool bigEndian) {
    final chars = <int>[];
    for (int i = start; i + 1 < end; i += 2) {
      final cp = bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8);
      if (cp > 0 && cp <= 0x7E) chars.add(cp);
    }
    return String.fromCharCodes(chars);
  }

  /// Parses a ReplayGain dB string such as "-6.50 dB", "+1.23 dB", or "-6.50".
  static double? _parseDb(String value) {
    final match =
        RegExp(r'^([+-]?\d+(?:\.\d+)?)').firstMatch(value.trim());
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Decodes a 4-byte synchsafe integer (ID3v2.4 sizes).
  static int _synchsafe(Uint8List bytes, int offset) =>
      ((bytes[offset] & 0x7F) << 21) |
      ((bytes[offset + 1] & 0x7F) << 14) |
      ((bytes[offset + 2] & 0x7F) << 7) |
      (bytes[offset + 3] & 0x7F);

  /// Decodes a 4-byte big-endian unsigned integer (ID3v2.3 frame sizes).
  static int _uint32be(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  /// Decodes a 4-byte little-endian unsigned integer (Vorbis comment lengths).
  static int _uint32le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

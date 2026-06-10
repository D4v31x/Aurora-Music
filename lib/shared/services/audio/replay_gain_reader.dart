import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Reads ReplayGain track gain from audio files without external dependencies.
///
/// Supported formats & tag variations:
///   - MP3 / ID3v2.2–2.4: TXXX `replaygain_track_gain` and the binary `RVA2`
///     relative-volume frame; APEv2 tags appended at the end of the file.
///   - FLAC: VORBIS_COMMENT `REPLAYGAIN_TRACK_GAIN` / `R128_TRACK_GAIN`.
///   - OGG Vorbis / OGG Opus: Vorbis-comment `REPLAYGAIN_*` and Opus
///     `R128_TRACK_GAIN` (Q7.8 fixed-point).
///   - MP4 / M4A / AAC / ALAC: iTunes freeform `----` atoms
///     (`com.apple.iTunes:replaygain_track_gain`).
///
/// Album gain is used as a fallback when track gain is absent. Tag-name
/// matching is case-insensitive and whitespace-tolerant.
///
/// Usage:
///   final multiplier = await ReplayGainReader.getVolumeMultiplier(song.data);
///   await audioPlayer.setVolume(multiplier);
class ReplayGainReader {
  /// Maximum bytes read from a file for tag scanning (64 KB).
  /// ID3v2 and FLAC Vorbis comment blocks always appear at the very start
  /// of the file, so 64 KB is more than sufficient.
  static const int _maxReadBytes = 65536;

  /// Maximum bytes read from a `moov` box when scanning MP4/M4A metadata.
  static const int _maxMoovBytes = 1 << 20; // 1 MB

  /// MP4 box types that may contain nested ReplayGain metadata.
  static const Set<String> _mp4Containers = {
    'moov',
    'udta',
    'ilst',
    'trak',
    'mdia',
    'minf',
    'stbl',
  };

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

  /// Returns the raw ReplayGain track gain in dB, or `null` if no tag found.
  ///
  /// Unlike [getVolumeMultiplier], this value is not clamped, so it can be
  /// positive (boost) or negative (attenuate). Useful for display purposes.
  static Future<double?> getTrackGainDb(String filePath) =>
      _readGainDb(filePath);

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
    RandomAccessFile? raf;
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      raf = await file.open();
      final fileLen = await raf.length();
      if (fileLen < 10) return null;

      // Peek at the first 10 bytes to detect format and determine read size.
      await raf.setPosition(0);
      final magic = await raf.read(10);
      if (magic.length < 4) return null;

      // ID3v2 – "ID3"
      if (magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33) {
        // The ID3v2 header encodes the exact tag size in bytes 6–9 as a
        // synchsafe integer. Read the FULL tag so that TXXX frames appended
        // after large embedded artwork are not missed.
        final tagSize = _synchsafe(magic, 6);
        // Cap at 20 MB to guard against corrupt headers.
        final readLen = math.min(10 + tagSize, math.min(20 * 1024 * 1024, fileLen));
        await raf.setPosition(0);
        final bytes = await raf.read(readLen);
        final gain = _parseId3v2(bytes);
        if (gain != null) return gain;
        // ID3 present but no ReplayGain – some MP3s carry APEv2 tags at the
        // end of the file instead (mp3gain / foobar2000).
        return await _parseApe(raf, fileLen);
      }

      final headLen = math.min(_maxReadBytes, fileLen);
      await raf.setPosition(0);
      final bytes = await raf.read(headLen);
      if (bytes.length < 4) return null;

      // FLAC – "fLaC"
      if (bytes[0] == 0x66 &&
          bytes[1] == 0x4C &&
          bytes[2] == 0x61 &&
          bytes[3] == 0x43) {
        return _parseFlac(bytes);
      }
      // OGG container – "OggS" (Vorbis / Opus)
      if (bytes[0] == 0x4F &&
          bytes[1] == 0x67 &&
          bytes[2] == 0x67 &&
          bytes[3] == 0x53) {
        return _scanVorbisComment(bytes);
      }
      // MP4 / M4A / AAC / ALAC – "ftyp" box at offset 4
      if (bytes.length >= 8 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return await _parseMp4(raf, fileLen);
      }
      // Unknown front header (e.g. raw MP3 without ID3) – try APEv2 at the end.
      return await _parseApe(raf, fileLen);
    } catch (e) {
      debugPrint('[ReplayGain] Error reading $filePath: $e');
      return null;
    } finally {
      await raf?.close();
    }
  }

  /// Reads [length] bytes from [raf] starting at [start].
  static Future<Uint8List> _readAt(
      RandomAccessFile raf, int start, int length) async {
    await raf.setPosition(start);
    return raf.read(length);
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

    double? trackGain;
    double? albumGain;
    double? rva2TrackGain;
    double? rva2AlbumGain;

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
        final tag = _parseTxxx(bytes, pos, frameEnd);
        if (tag != null) {
          if (tag.key == 'replaygain_track_gain') {
            trackGain ??= tag.db;
          } else if (tag.key == 'replaygain_album_gain') {
            albumGain ??= tag.db;
          }
        }
      } else if (version >= 3 && frameId == 'RVA2') {
        final tag = _parseRva2(bytes, pos, frameEnd);
        if (tag != null) {
          if (tag.key.contains('album')) {
            rva2AlbumGain ??= tag.db;
          } else {
            rva2TrackGain ??= tag.db;
          }
        }
      }

      pos = frameEnd;
    }
    // Prefer textual ReplayGain frames; fall back to the binary RVA2 frame.
    return trackGain ?? albumGain ?? rva2TrackGain ?? rva2AlbumGain;
  }

  /// Parses an `RVA2` (relative volume adjustment) frame. Returns the master
  /// channel's adjustment in dB along with the frame's identification string.
  static _RgTag? _parseRva2(Uint8List bytes, int start, int end) {
    // Identification: null-terminated Latin-1 string.
    int idEnd = start;
    while (idEnd < end && bytes[idEnd] != 0) {
      idEnd++;
    }
    final id =
        String.fromCharCodes(bytes.sublist(start, idEnd)).toLowerCase().trim();
    int pos = idEnd + 1;

    // Channels: type(1) + adjustment(2, signed) + peakBits(1) + peak(n).
    while (pos + 4 <= end) {
      final channelType = bytes[pos];
      // Signed 16-bit big-endian, in units of 1/512 dB.
      int raw = (bytes[pos + 1] << 8) | bytes[pos + 2];
      if (raw >= 0x8000) raw -= 0x10000;
      final db = raw / 512.0;
      final peakBits = bytes[pos + 3];
      final peakBytes = (peakBits + 7) >> 3;
      pos += 4 + peakBytes;
      // Master volume (1) – use it for the overall gain.
      if (channelType == 1) return _RgTag(id, db);
    }
    return null;
  }

  /// Parse TXXX frame content starting at [start] (after the 10-byte header).
  static _RgTag? _parseTxxx(Uint8List bytes, int start, int end) {
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

    final db = _parseDb(value);
    if (db == null) return null;
    return _RgTag(desc, db);
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

    double? trackGain;
    double? albumGain;
    double? r128Track;
    double? r128Album;

    for (int i = 0; i < commentCount && pos + 4 <= end; i++) {
      final commentLen = _uint32le(bytes, pos);
      pos += 4;
      if (commentLen <= 0 || pos + commentLen > end) break;

      final comment =
          String.fromCharCodes(bytes.sublist(pos, pos + commentLen));
      final eqIdx = comment.indexOf('=');
      if (eqIdx > 0) {
        final key = comment.substring(0, eqIdx).toUpperCase().trim();
        final raw = comment.substring(eqIdx + 1).trim();
        switch (key) {
          case 'REPLAYGAIN_TRACK_GAIN':
            trackGain ??= _parseDb(raw);
          case 'REPLAYGAIN_ALBUM_GAIN':
            albumGain ??= _parseDb(raw);
          case 'R128_TRACK_GAIN':
            r128Track ??= _parseR128(raw);
          case 'R128_ALBUM_GAIN':
            r128Album ??= _parseR128(raw);
        }
      }
      pos += commentLen;
    }
    return trackGain ?? albumGain ?? r128Track ?? r128Album;
  }

  // ---------------------------------------------------------------------------
  // OGG: byte-level scan for Vorbis/Opus comment tags
  // ---------------------------------------------------------------------------

  /// Scans raw bytes for ReplayGain / R128 comment tags (case-insensitive).
  /// Works for both OGG Vorbis and OGG Opus. Prefers track gain, then album
  /// gain, then the Opus R128 equivalents.
  static double? _scanVorbisComment(Uint8List bytes) {
    final track = _scanKey(bytes, 'replaygain_track_gain=');
    if (track != null) {
      final db = _parseDb(track);
      if (db != null) return db;
    }
    final album = _scanKey(bytes, 'replaygain_album_gain=');
    if (album != null) {
      final db = _parseDb(album);
      if (db != null) return db;
    }
    final r128Track = _scanKey(bytes, 'r128_track_gain=');
    if (r128Track != null) {
      final db = _parseR128(r128Track);
      if (db != null) return db;
    }
    final r128Album = _scanKey(bytes, 'r128_album_gain=');
    if (r128Album != null) {
      final db = _parseR128(r128Album);
      if (db != null) return db;
    }
    return null;
  }

  /// Case-insensitive byte scan for `[pattern]<value>`. Returns the raw value
  /// string (read until NUL, LF, or CR) or null when the pattern is absent.
  /// [pattern] must be supplied lowercase.
  static String? _scanKey(Uint8List bytes, String pattern) {
    final patternBytes = Uint8List.fromList(pattern.codeUnits);
    final len = patternBytes.length;
    if (bytes.length < len) return null;

    outer:
    for (int i = 0; i <= bytes.length - len; i++) {
      for (int j = 0; j < len; j++) {
        // Lowercase the byte before comparing
        final b = bytes[i + j] >= 0x41 && bytes[i + j] <= 0x5A
            ? bytes[i + j] | 0x20
            : bytes[i + j];
        if (b != patternBytes[j]) continue outer;
      }
      int valueEnd = i + len;
      while (valueEnd < bytes.length &&
          bytes[valueEnd] != 0 &&
          bytes[valueEnd] != 0x0A &&
          bytes[valueEnd] != 0x0D) {
        valueEnd++;
      }
      return String.fromCharCodes(bytes.sublist(i + len, valueEnd)).trim();
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // MP4 / M4A / AAC / ALAC parser
  // ---------------------------------------------------------------------------

  /// Walks the top-level MP4 box tree to find `moov` (which may be at the start
  /// or the end of the file) and extracts iTunes freeform ReplayGain atoms.
  static Future<double?> _parseMp4(RandomAccessFile raf, int fileLen) async {
    int pos = 0;
    while (pos + 8 <= fileLen) {
      final header = await _readAt(raf, pos, 8);
      if (header.length < 8) break;

      int size = _uint32be(header, 0);
      final type = String.fromCharCodes(header.sublist(4, 8));
      int headerSize = 8;

      if (size == 1) {
        // 64-bit extended size.
        final ext = await _readAt(raf, pos + 8, 8);
        if (ext.length < 8) break;
        size = _uint64be(ext, 0);
        headerSize = 16;
      } else if (size == 0) {
        // Box extends to end of file.
        size = fileLen - pos;
      }
      if (size < headerSize) break;

      if (type == 'moov') {
        // Cap the read to a sane bound – ReplayGain metadata is tiny.
        final bodyLen = math.min(size - headerSize, _maxMoovBytes);
        final moov = await _readAt(raf, pos + headerSize, bodyLen);
        return _parseMp4Container(moov, 0, moov.length);
      }
      pos += size;
    }
    return null;
  }

  /// Recursively searches MP4 boxes for iTunes freeform `----` ReplayGain atoms.
  static double? _parseMp4Container(Uint8List b, int start, int end) {
    double? trackGain;
    double? albumGain;

    int pos = start;
    while (pos + 8 <= end) {
      int size = _uint32be(b, pos);
      final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
      int headerSize = 8;

      if (size == 1) {
        if (pos + 16 > end) break;
        size = _uint64be(b, pos + 8);
        headerSize = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < headerSize || pos + size > end) break;

      final childStart = pos + headerSize;
      final childEnd = pos + size;

      if (type == '----') {
        final tag = _parseMp4Freeform(b, childStart, childEnd);
        if (tag != null) {
          if (tag.key == 'replaygain_track_gain') {
            trackGain ??= tag.db;
          } else if (tag.key == 'replaygain_album_gain') {
            albumGain ??= tag.db;
          }
        }
      } else if (type == 'meta') {
        // `meta` carries a 4-byte version/flags field before its children.
        final r = _parseMp4Container(b, childStart + 4, childEnd);
        if (r != null) return r;
      } else if (_mp4Containers.contains(type)) {
        final r = _parseMp4Container(b, childStart, childEnd);
        if (r != null) return r;
      }
      pos += size;
    }
    return trackGain ?? albumGain;
  }

  /// Parses an iTunes freeform `----` atom's `name` and `data` children.
  static _RgTag? _parseMp4Freeform(Uint8List b, int start, int end) {
    String? name;
    String? value;
    int pos = start;
    while (pos + 8 <= end) {
      final size = _uint32be(b, pos);
      if (size < 8 || pos + size > end) break;
      final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
      if (type == 'name' && pos + 12 <= pos + size) {
        // 4-byte version/flags, then the attribute name.
        name = String.fromCharCodes(b.sublist(pos + 12, pos + size))
            .toLowerCase()
            .trim();
      } else if (type == 'data' && pos + 16 <= pos + size) {
        // 4-byte data-type, 4-byte locale, then the UTF-8 value.
        value =
            String.fromCharCodes(b.sublist(pos + 16, pos + size)).trim();
      }
      pos += size;
    }
    if (name != null && value != null) {
      final db = _parseDb(value);
      if (db != null) return _RgTag(name, db);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // APEv2 tag parser (appended at the end of MP3 / WavPack / Monkey's Audio)
  // ---------------------------------------------------------------------------

  static Future<double?> _parseApe(RandomAccessFile raf, int fileLen) async {
    if (fileLen < 32) return null;

    // The APEv2 footer may sit just before a 128-byte ID3v1 trailer.
    final scanLen = math.min(fileLen, 160);
    final tail = await _readAt(raf, fileLen - scanLen, scanLen);

    int footerPos = -1;
    for (int i = tail.length - 32; i >= 0; i--) {
      if (tail[i] == 0x41 && // A
          tail[i + 1] == 0x50 && // P
          tail[i + 2] == 0x45 && // E
          tail[i + 3] == 0x54 && // T
          tail[i + 4] == 0x41 && // A
          tail[i + 5] == 0x47 && // G
          tail[i + 6] == 0x45 && // E
          tail[i + 7] == 0x58) {
        // X
        footerPos = i;
        break;
      }
    }
    if (footerPos < 0) return null;

    final tagSize = _uint32le(tail, footerPos + 12); // items + footer
    if (tagSize <= 32) return null;
    final itemsLen = tagSize - 32;
    final fileFooterPos = fileLen - scanLen + footerPos;
    final itemsStart = fileFooterPos - itemsLen;
    if (itemsStart < 0 || itemsLen > _maxReadBytes) return null;

    final data = await _readAt(raf, itemsStart, itemsLen);
    return _parseApeItems(data);
  }

  static double? _parseApeItems(Uint8List data) {
    double? trackGain;
    double? albumGain;
    int pos = 0;
    while (pos + 8 <= data.length) {
      final valueSize = _uint32le(data, pos);
      pos += 8; // value-size(4) + flags(4)
      int keyEnd = pos;
      while (keyEnd < data.length && data[keyEnd] != 0) {
        keyEnd++;
      }
      final key =
          String.fromCharCodes(data.sublist(pos, keyEnd)).toUpperCase().trim();
      pos = keyEnd + 1;
      if (valueSize < 0 || pos + valueSize > data.length) break;
      final value = String.fromCharCodes(data.sublist(pos, pos + valueSize));
      pos += valueSize;

      if (key == 'REPLAYGAIN_TRACK_GAIN') {
        trackGain ??= _parseDb(value);
      } else if (key == 'REPLAYGAIN_ALBUM_GAIN') {
        albumGain ??= _parseDb(value);
      }
    }
    return trackGain ?? albumGain;
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

  /// Parses an EBU R128 gain value (Q7.8 fixed-point integer, ref −23 LUFS)
  /// into dB. A +5 dB offset aligns it with the ReplayGain 89 dB reference.
  static double? _parseR128(String value) {
    final raw = int.tryParse(value.trim());
    if (raw == null) return null;
    return raw / 256.0 + 5.0;
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

  /// Decodes an 8-byte big-endian unsigned integer (MP4 64-bit box sizes).
  static int _uint64be(Uint8List bytes, int offset) {
    int v = 0;
    for (int i = 0; i < 8; i++) {
      v = (v << 8) | bytes[offset + i];
    }
    return v;
  }

  /// Decodes a 4-byte little-endian unsigned integer (Vorbis comment lengths).
  static int _uint32le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

/// A single parsed ReplayGain tag: its (lowercased) key plus the gain in dB.
class _RgTag {
  final String key;
  final double db;
  const _RgTag(this.key, this.db);
}

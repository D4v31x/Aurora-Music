/// Generates a shareable vertical video "clip" for a song: a short trimmed
/// audio segment muxed with a stylized, animated artwork card ("LISTENING
/// TO" label → artwork → title/artist → "NOW ON Aurora Music" branding),
/// suitable for sharing to Instagram/TikTok/WhatsApp-style vertical video
/// surfaces. The card elements animate in at the start of the clip and
/// animate back out at the end.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/font_constants.dart';

/// Thrown when clip generation fails at any stage (audio trim, artwork
/// render, or video mux).
class ShareClipException implements Exception {
  final String message;
  ShareClipException(this.message);

  @override
  String toString() => 'ShareClipException: $message';
}

class ShareClipService {
  static const int videoWidth = 1080;
  static const int videoHeight = 1920;

  /// Frame rate used for the intro/outro reveal animation segments. The
  /// (much longer) held middle segment is a single static frame, so this
  /// only affects file count/render cost, not overall clip length.
  static const int _frameFps = 24;
  static const double _introSeconds = 0.7;
  static const double _outroSeconds = 0.6;

  static const String _logoAssetPath =
      'assets/images/logo/Music_full_logo.png';

  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Renders and muxes a shareable vertical MP4 clip for [song].
  ///
  /// [start] is the offset into the source track where the clip begins and
  /// [clipDuration] is how long the clip should last (both are clamped to the
  /// track's actual duration by the caller). Returns the generated MP4 file.
  Future<File> generateClip({
    required SongModel song,
    required Duration start,
    required Duration clipDuration,
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
        '${tempDir.path}/share_clip_${DateTime.now().microsecondsSinceEpoch}');
    await workDir.create(recursive: true);

    try {
      onProgress?.call(0.03);

      final artworkBytes = await _audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
        quality: 100,
        size: 1200,
      );
      final artworkImage = (artworkBytes != null && artworkBytes.isNotEmpty)
          ? await _decodeImage(artworkBytes)
          : null;
      final glowColor = await _extractGlowColor(artworkBytes);
      final logoImage = await _loadLogoImage();

      onProgress?.call(0.08);

      final anim = await _renderFrames(
        song: song,
        artworkImage: artworkImage,
        logoImage: logoImage,
        glowColor: glowColor,
        clipDuration: clipDuration,
        workDir: workDir,
        onFramesProgress: (p) => onProgress?.call(0.08 + p * 0.42),
      );

      onProgress?.call(0.55);
      final trimmedAudioFile = await _trimAudio(
        sourcePath: song.data,
        start: start,
        duration: clipDuration,
        workDir: workDir,
      );

      onProgress?.call(0.7);
      final outputFile = await _composeVideo(
        workDir: workDir,
        heldSeconds: anim.heldSeconds,
        audioPath: trimmedAudioFile.path,
        duration: clipDuration,
      );

      onProgress?.call(1.0);
      return outputFile;
    } catch (e) {
      // Clean up partial work on failure; rethrow so the caller can surface
      // a message to the user.
      if (workDir.existsSync()) {
        try {
          await workDir.delete(recursive: true);
        } catch (_) {}
      }
      if (e is ShareClipException) rethrow;
      throw ShareClipException(e.toString());
    }
  }

  // ---------------------------------------------------------------------
  // Frame sequence rendering: intro (reveal) -> held (static) -> outro
  // (reverse reveal), each exported as PNGs for ffmpeg to stitch together.
  // ---------------------------------------------------------------------

  Future<
      ({
        int introCount,
        int outroCount,
        double heldSeconds,
      })> _renderFrames({
    required SongModel song,
    required ui.Image? artworkImage,
    required ui.Image logoImage,
    required Color glowColor,
    required Duration clipDuration,
    required Directory workDir,
    required void Function(double progress) onFramesProgress,
  }) async {
    final totalSeconds = clipDuration.inMilliseconds / 1000.0;

    var introSeconds = _introSeconds;
    var outroSeconds = _outroSeconds;
    // Guard against ultra-short clips: never let the intro+outro reveal
    // animation eat up more than 60% of the total clip duration.
    final maxAnimSeconds = totalSeconds * 0.6;
    if (maxAnimSeconds > 0 && introSeconds + outroSeconds > maxAnimSeconds) {
      final scale = maxAnimSeconds / (introSeconds + outroSeconds);
      introSeconds *= scale;
      outroSeconds *= scale;
    }

    final introCount = (introSeconds * _frameFps).round().clamp(1, 999);
    final outroCount = (outroSeconds * _frameFps).round().clamp(1, 999);
    final heldSeconds = (totalSeconds -
            (introCount / _frameFps) -
            (outroCount / _frameFps))
        .clamp(0.05, totalSeconds);

    final totalFrames = introCount + 1 + outroCount;
    var rendered = 0;

    for (var i = 0; i < introCount; i++) {
      final t = ((i + 1) / introCount) * 0.97;
      await _renderFrame(
        song: song,
        artworkImage: artworkImage,
        logoImage: logoImage,
        glowColor: glowColor,
        revealT: t,
        outPath:
            '${workDir.path}/intro_${i.toString().padLeft(3, '0')}.png',
      );
      rendered++;
      onFramesProgress(rendered / totalFrames);
    }

    await _renderFrame(
      song: song,
      artworkImage: artworkImage,
      logoImage: logoImage,
      glowColor: glowColor,
      revealT: 1.0,
      outPath: '${workDir.path}/held.png',
    );
    rendered++;
    onFramesProgress(rendered / totalFrames);

    for (var i = 0; i < outroCount; i++) {
      final t = 1.0 - ((i + 1) / outroCount);
      await _renderFrame(
        song: song,
        artworkImage: artworkImage,
        logoImage: logoImage,
        glowColor: glowColor,
        revealT: t,
        outPath:
            '${workDir.path}/outro_${i.toString().padLeft(3, '0')}.png',
      );
      rendered++;
      onFramesProgress(rendered / totalFrames);
    }

    return (
      introCount: introCount,
      outroCount: outroCount,
      heldSeconds: heldSeconds,
    );
  }

  /// Maps overall reveal progress [t] (0 = hidden, 1 = fully shown) to a
  /// per-element opacity using a staggered [start, end] window within the
  /// overall animation, so elements cascade in/out rather than popping
  /// together.
  double _reveal(double t, double start, double end) {
    return Interval(start, end, curve: Curves.easeOutCubic)
        .transform(t.clamp(0.0, 1.0));
  }

  /// Draws [paint] at the given [opacity], skipping the (relatively
  /// expensive) save-layer entirely when fully opaque — which is the common
  /// case for the single held frame that covers most of the clip's duration.
  void _withGroupOpacity(
    Canvas canvas,
    Rect bounds,
    double opacity,
    void Function(Canvas canvas) paint,
  ) {
    if (opacity >= 0.999) {
      paint(canvas);
      return;
    }
    canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)));
    paint(canvas);
    canvas.restore();
  }

  // ---------------------------------------------------------------------
  // Card rendering (label + artwork + title/artist + branding) -> PNG
  // ---------------------------------------------------------------------

  Future<void> _renderFrame({
    required SongModel song,
    required ui.Image? artworkImage,
    required ui.Image logoImage,
    required Color glowColor,
    required double revealT,
    required String outPath,
  }) async {
    final w = videoWidth.toDouble();
    final h = videoHeight.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Background: near-black base with a soft glow tinted by the artwork's
    // dominant color, centered roughly where the artwork sits.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(glowColor, Colors.black, 0.78)!,
            const Color(0xFF050506),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    const artSize = 660.0;
    const artTop = 300.0;
    final artRect = Rect.fromLTWH((w - artSize) / 2, artTop, artSize, artSize);

    canvas.drawCircle(
      artRect.center,
      artSize * 0.75,
      Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 140),
    );

    // ── "LISTENING TO" label ────────────────────────────────────────────
    final labelOpacity = _reveal(revealT, 0.0, 0.45);
    if (labelOpacity > 0.001) {
      _withGroupOpacity(
        canvas,
        Rect.fromLTWH(0, 130, w, 70),
        labelOpacity,
        (c) {
          final labelPainter = TextPainter(
            text: const TextSpan(
              text: 'LISTENING TO',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: FontConstants.fontFamily,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 6,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final dy = 170 + (1 - labelOpacity) * 24;
          labelPainter.paint(c, Offset((w - labelPainter.width) / 2 - 3, dy));
        },
      );
    }

    // ── Artwork card ─────────────────────────────────────────────────────
    final artOpacity = _reveal(revealT, 0.1, 0.65);
    if (artOpacity > 0.001) {
      final scale = 0.88 + 0.12 * artOpacity;
      canvas.save();
      canvas.translate(artRect.center.dx, artRect.center.dy);
      canvas.scale(scale);
      canvas.translate(-artRect.center.dx, -artRect.center.dy);
      _withGroupOpacity(canvas, artRect.inflate(60), artOpacity, (c) {
        final artRRect =
            RRect.fromRectAndRadius(artRect, const Radius.circular(28));
        c.drawRRect(
          artRRect.shift(const Offset(0, 18)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.5)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 40),
        );
        c.save();
        c.clipRRect(artRRect);
        if (artworkImage != null) {
          _drawImageCover(c, artworkImage, artRect);
        } else {
          c.drawRRect(
            artRRect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glowColor, Color.lerp(glowColor, Colors.black, 0.6)!],
              ).createShader(artRect),
          );
          _drawCenteredIcon(c, artRect, Icons.music_note_rounded, 200);
        }
        c.restore();
      });
      canvas.restore();
    }

    // ── Title + artist ───────────────────────────────────────────────────
    final textOpacity = _reveal(revealT, 0.3, 0.85);
    if (textOpacity > 0.001) {
      final dy = (1 - textOpacity) * 30;
      final titlePainter = TextPainter(
        text: TextSpan(
          text: song.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: FontConstants.fontFamily,
            fontSize: 62,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w - 140);
      const titleTop = artTop + artSize + 70;

      final artistPainter = TextPainter(
        text: TextSpan(
          text: song.artist ?? 'Unknown Artist',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontFamily: FontConstants.fontFamily,
            fontSize: 38,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w - 140);
      final artistTop = titleTop + titlePainter.height + 18;

      _withGroupOpacity(
        canvas,
        Rect.fromLTWH(0, titleTop - 10, w,
            artistTop + artistPainter.height - titleTop + 30),
        textOpacity,
        (c) {
          titlePainter.paint(
              c, Offset((w - titlePainter.width) / 2, titleTop + dy));
          artistPainter.paint(
              c, Offset((w - artistPainter.width) / 2, artistTop + dy));
        },
      );
    }

    // ── Footer: "NOW ON" + Aurora Music logo ────────────────────────────
    final footerOpacity = _reveal(revealT, 0.5, 1.0);
    if (footerOpacity > 0.001) {
      const logoWidth = 260.0;
      final logoHeight = logoWidth * logoImage.height / logoImage.width;
      final footerLabelTop = h - 300;
      final logoTop = h - 230;
      final dy = (1 - footerOpacity) * 20;

      _withGroupOpacity(
        canvas,
        Rect.fromLTWH(0, footerLabelTop - 10, w, h - footerLabelTop + 10),
        footerOpacity,
        (c) {
          final nowOnPainter = TextPainter(
            text: const TextSpan(
              text: 'NOW ON',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: FontConstants.fontFamily,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 5,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          nowOnPainter.paint(
              c, Offset((w - nowOnPainter.width) / 2 - 2, footerLabelTop + dy));

          final logoRect = Rect.fromLTWH(
              (w - logoWidth) / 2, logoTop + dy, logoWidth, logoHeight);
          paintImage(
            canvas: c,
            rect: logoRect,
            image: logoImage,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );
        },
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(videoWidth, videoHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw ShareClipException('Failed to encode clip artwork frame');
    }
    await File(outPath).writeAsBytes(byteData.buffer.asUint8List());
  }

  /// Extracts a vibrant color from the song's artwork to tint the card's
  /// background glow, falling back to a fixed brand purple when there's no
  /// artwork or palette extraction fails.
  Future<Color> _extractGlowColor(Uint8List? artworkBytes) async {
    const fallback = Color(0xFF8B5CF6);
    if (artworkBytes == null || artworkBytes.isEmpty) return fallback;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(artworkBytes),
        size: const Size(100, 100),
        maximumColorCount: 8,
      );
      final color = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (color == null) return fallback;
      // Keep the glow reasonably saturated/bright regardless of how muted
      // the source artwork is.
      final hsl = HSLColor.fromColor(color);
      return hsl
          .withLightness(hsl.lightness.clamp(0.35, 0.65))
          .withSaturation(hsl.saturation.clamp(0.45, 1.0))
          .toColor();
    } catch (_) {
      return fallback;
    }
  }

  Future<ui.Image> _loadLogoImage() async {
    final data = await rootBundle.load(_logoAssetPath);
    return _decodeImage(data.buffer.asUint8List());
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _drawImageCover(Canvas canvas, ui.Image image, Rect dest) {
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();
    final srcAspect = srcW / srcH;
    final destAspect = dest.width / dest.height;

    Rect src;
    if (srcAspect > destAspect) {
      final cropWidth = srcH * destAspect;
      final x = (srcW - cropWidth) / 2;
      src = Rect.fromLTWH(x, 0, cropWidth, srcH);
    } else {
      final cropHeight = srcW / destAspect;
      final y = (srcH - cropHeight) / 2;
      src = Rect.fromLTWH(0, y, srcW, cropHeight);
    }
    canvas.drawImageRect(image, src, dest, Paint()..filterQuality = FilterQuality.high);
  }

  void _drawCenteredIcon(
      Canvas canvas, Rect bounds, IconData icon, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        bounds.left + (bounds.width - textPainter.width) / 2,
        bounds.top + (bounds.height - textPainter.height) / 2,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FFmpeg: trim audio segment, then stitch intro/held/outro frame
  // sequences into a single video and mux with the trimmed audio.
  // ---------------------------------------------------------------------

  Future<File> _trimAudio({
    required String sourcePath,
    required Duration start,
    required Duration duration,
    required Directory workDir,
  }) async {
    final outPath = '${workDir.path}/trimmed_audio.m4a';
    final startSec = (start.inMilliseconds / 1000.0).toStringAsFixed(3);
    final durationSec = (duration.inMilliseconds / 1000.0).toStringAsFixed(3);

    // Re-encode to AAC so the audio stream is guaranteed compatible with the
    // MP4 container regardless of the source codec (mp3/flac/wav/etc.).
    final command =
        '-y -ss $startSec -t $durationSec -i "${sourcePath.replaceAll('"', '\\"')}" '
        '-vn -c:a aac -b:a 192k "$outPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw ShareClipException('Failed to trim audio: ${logs ?? returnCode}');
    }
    return File(outPath);
  }

  Future<File> _composeVideo({
    required Directory workDir,
    required double heldSeconds,
    required String audioPath,
    required Duration duration,
  }) async {
    final outPath = '${workDir.path}/clip.mp4';
    final totalSec = (duration.inMilliseconds / 1000.0).toStringAsFixed(3);
    final heldSec = heldSeconds.toStringAsFixed(3);

    final introPattern = '${workDir.path}/intro_%03d.png';
    final heldPath = '${workDir.path}/held.png';
    final outroPattern = '${workDir.path}/outro_%03d.png';

    final command = '-y '
        '-framerate $_frameFps -i "$introPattern" '
        '-loop 1 -t $heldSec -i "$heldPath" '
        '-framerate $_frameFps -i "$outroPattern" '
        '-i "$audioPath" '
        '-filter_complex "'
        '[0:v]format=yuv420p,fps=$_frameFps[v0];'
        '[1:v]format=yuv420p,fps=$_frameFps[v1];'
        '[2:v]format=yuv420p,fps=$_frameFps[v2];'
        '[v0][v1][v2]concat=n=3:v=1:a=0[outv]" '
        '-map "[outv]" -map 3:a '
        '-c:v libx264 -tune stillimage -preset veryfast -pix_fmt yuv420p '
        '-c:a aac -b:a 192k -t $totalSec -shortest "$outPath"';


    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw ShareClipException('Failed to render clip video: ${logs ?? returnCode}');
    }
    return File(outPath);
  }
}

part of '../audio_player_service.dart';

/// True timed crossfade engine.
///
/// When enabled, the outgoing track's volume is ramped down to zero while the
/// upcoming track — preloaded and playing on a temporary standby [AudioPlayer]
/// — is simultaneously ramped up from zero to full volume, using an
/// equal-power curve so the perceived loudness stays constant through the
/// transition. This produces a real overlapping crossfade rather than a hard
/// cut or a simple fade-to-silence-then-fade-in.
///
/// Two distinct hand-off strategies are used depending on [gaplessPlayback]:
///
/// - **Gapless mode** (default): the primary player already owns a
///   ConcatenatingAudioSource spanning the whole queue. After the ramp
///   completes we simply call `seekToNext()` on the *same* player and align
///   its position to the standby's — the existing gapless index-stream
///   bookkeeping in [_bindCorePlayerListeners] handles the rest automatically.
///   The standby player is discarded; `audioHandler.player` never changes.
/// - **Non-gapless mode**: each track is loaded individually via
///   `setAudioSource`, so there is no shared queue to advance. Instead the
///   standby player (already playing the next track) is promoted to become
///   the new primary via [AuroraAudioHandler.switchActivePlayer], and all
///   service-level listeners are rebound to it via [_bindCorePlayerListeners].
extension AudioCrossfadeControllerExtension on AudioPlayerService {
  /// Minimum/maximum allowed crossfade duration, enforced by the setter in
  /// audio/settings_manager.dart and used to clamp against short tracks here.
  static const int kMinCrossfadeMs = 1000;
  static const int kMaxCrossfadeMs = 12000;

  /// Registers an optional factory for building an [AudioPipeline] (e.g. one
  /// wrapping an [AndroidEqualizer]) for the standby player used during a
  /// non-gapless crossfade hand-off. Not required for gapless crossfades,
  /// since those never change which player is "primary" and therefore never
  /// lose their existing equalizer pipeline.
  void attachCrossfadePipelineFactory(AudioPipeline Function() factory) {
    _crossfadePipelineFactory = factory;
  }

  /// Starts (or restarts) the position watcher that decides when to trigger a
  /// crossfade. Safe to call multiple times — cancels any previous
  /// subscription first. No-ops silently while crossfade is disabled.
  void _initCrossfadeEngine() {
    _crossfadeWatchSub?.cancel();
    _crossfadeWatchSub = _audioPlayer.positionStream.listen(_onCrossfadeTick);
  }

  void _onCrossfadeTick(Duration position) {
    if (!_crossfadeEnabled || _crossfading) return;
    // just_audio already handles single-track repeat internally — don't
    // crossfade a track into itself.
    if (_loopMode == LoopMode.one) return;
    if (_playlist.isEmpty) return;

    final total = _audioPlayer.duration;
    if (total == null || total <= Duration.zero) return;

    // Clamp the fade window so it never exceeds roughly half the track's
    // duration (a 10-second fade on a 12-second track would start fading
    // almost immediately, which feels broken rather than musical).
    final maxFadeForTrack = (total.inMilliseconds / 2).floor();
    final fadeMs = _crossfadeDurationMs.clamp(
      kMinCrossfadeMs,
      maxFadeForTrack < kMinCrossfadeMs ? kMinCrossfadeMs : maxFadeForTrack,
    );

    final remaining = total - position;
    if (remaining.isNegative) return;
    if (remaining.inMilliseconds > fadeMs) return;

    final nextIndex = _peekNextIndexForCrossfade();
    if (nextIndex == null) return;

    unawaited(_beginCrossfade(nextIndex, fadeMs));
  }

  /// Returns the playlist index that should play next, mirroring the
  /// wrap/stop semantics of [skip], or `null` if playback should simply end
  /// (repeat off, at the last track).
  int? _peekNextIndexForCrossfade() {
    if (_currentIndex < _playlist.length - 1) return _currentIndex + 1;
    if (_loopMode == LoopMode.all && _playlist.isNotEmpty) return 0;
    return null;
  }

  /// Cancels an in-progress crossfade ramp (if any), restoring the primary
  /// player to full volume and disposing the standby player. Called before
  /// any manual navigation (skip/back/stop/pause/new playlist) so the user's
  /// action always wins over an in-flight automatic transition.
  Future<void> cancelCrossfadeIfActive() async {
    if (!_crossfading) return;
    _crossfading = false;
    _crossfadeRampTimer?.cancel();
    _crossfadeRampTimer = null;

    final standby = _standbyPlayer;
    _standbyPlayer = null;
    if (standby != null) {
      try {
        await standby.stop();
      } catch (_) {}
      try {
        await standby.dispose();
      } catch (_) {}
    }
    try {
      await _audioPlayer.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _beginCrossfade(int nextIndex, int fadeMs) async {
    if (_crossfading) return;
    if (nextIndex < 0 || nextIndex >= _playlist.length) return;

    _crossfading = true;
    final outgoing = _audioPlayer; // capture before any possible swap
    final nextSong = _playlist[nextIndex];
    AudioPlayer? standby;

    try {
      final pipeline = _crossfadePipelineFactory?.call();
      standby = pipeline != null
          ? AudioPlayer(audioPipeline: pipeline)
          : AudioPlayer();

      // Match the outgoing player's speed/pitch settings so the incoming
      // track doesn't suddenly change tempo when it becomes primary.
      await standby.setSpeed(_playbackSpeed);
      await standby.setPitch(_pitchWithSpeed ? _playbackSpeed : 1.0);

      final uri = nextSong.uri ?? nextSong.data;
      final nextMediaItem = await _createMediaItem(nextSong);
      await standby.setAudioSource(
        AudioSource.uri(Uri.parse(uri), tag: nextMediaItem),
      );
      await standby.setVolume(0.0);
      unawaited(standby.play());
      _standbyPlayer = standby;

      await _rampCrossfade(outgoing, standby, fadeMs);
      if (!_crossfading) {
        // Cancelled mid-ramp by a manual action — cancelCrossfadeIfActive()
        // already cleaned up both players.
        return;
      }

      if (_gaplessPlayback) {
        // The primary player still owns the ConcatenatingAudioSource for the
        // whole queue — advance it in place. This fires currentIndexStream,
        // which _bindCorePlayerListeners already handles (index/play-count/
        // notification/artwork bookkeeping) exactly as a natural gapless
        // auto-advance would.
        //
        // GUARD: if the estimated track duration used to schedule this
        // crossfade was a little longer than the real audio, `outgoing` may
        // have already reached the real end-of-track DURING the ramp and
        // auto-advanced to nextIndex on its own (just_audio's normal gapless
        // behavior) — the currentIndexStream listener already ran all the
        // bookkeeping for nextSong in that case. Calling seekToNext() again
        // here would then skip PAST nextIndex to the track after it, which
        // is exactly the "already at the next song, skips to the one after"
        // bug. Only advance if the player hasn't already gotten there itself.
        if (outgoing.currentIndex != nextIndex) {
          if (outgoing.hasNext) {
            await outgoing.seekToNext();
          } else if (_loopMode == LoopMode.all) {
            await outgoing.seek(Duration.zero, index: 0);
          }
        }
        // Align the primary's position to the standby's so there is no
        // audible jump when we mute/dispose the standby below.
        await outgoing.seek(standby.position);
        await outgoing.setVolume(1.0);

        _standbyPlayer = null;
        unawaited(standby.stop());
        unawaited(standby.dispose());
      } else {
        // Non-gapless: promote the standby to become the new primary player.
        audioHandler.switchActivePlayer(standby);
        _bindCorePlayerListeners();
        _initCrossfadeEngine();

        final oldIndex = _currentIndex;
        _currentIndex = nextIndex;
        _updateQueueCountForIndexChange(oldIndex, nextIndex);
        _incrementPlayCount(nextSong);
        _currentSongController.add(nextSong);
        currentSongNotifier.value = nextSong;
        _isPlaying = true;
        isPlayingNotifier.value = true;
        audioHandler.updateNotificationMediaItem(nextMediaItem);
        await standby.setVolume(1.0);

        _standbyPlayer = null;
        unawaited(outgoing.stop());
        unawaited(outgoing.dispose());

        unawaited(updateCurrentArtwork());
        unawaited(_updateBackgroundColors());
        _scheduleNotify();
        unawaited(saveQueueState());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Crossfade failed, falling back cleanly: $e');
      _crossfadeRampTimer?.cancel();
      _crossfadeRampTimer = null;
      try {
        await outgoing.setVolume(1.0);
      } catch (_) {}
      final failedStandby = standby;
      if (failedStandby != null) {
        try {
          await failedStandby.stop();
        } catch (_) {}
        try {
          await failedStandby.dispose();
        } catch (_) {}
      }
      _standbyPlayer = null;
    } finally {
      _crossfading = false;
    }
  }

  /// Ramps [from]'s volume 1→0 and [to]'s volume 0→1 over [fadeMs] using an
  /// equal-power (constant perceived loudness) curve. Resolves early —
  /// without throwing — if [cancelCrossfadeIfActive] flips `_crossfading` to
  /// false while the ramp is in progress.
  Future<void> _rampCrossfade(
    AudioPlayer from,
    AudioPlayer to,
    int fadeMs,
  ) async {
    const tickMs = 50;
    final steps = (fadeMs / tickMs).ceil().clamp(1, 1000);
    final completer = Completer<void>();
    var step = 0;

    _crossfadeRampTimer =
        Timer.periodic(const Duration(milliseconds: tickMs), (timer) async {
      if (!_crossfading) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      final outVolume = cos(t * pi / 2);
      final inVolume = sin(t * pi / 2);
      try {
        await from.setVolume(outVolume.clamp(0.0, 1.0));
        await to.setVolume(inVolume.clamp(0.0, 1.0));
      } catch (_) {
        // A player may have been stopped/disposed by a concurrent manual
        // action — abort the ramp gracefully rather than throwing.
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      if (t >= 1.0) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });

    return completer.future;
  }
}

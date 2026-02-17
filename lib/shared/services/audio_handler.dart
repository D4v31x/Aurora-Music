import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Custom audio handler that provides background playback with customized notification
/// Shows only: previous, play/pause, next (NO stop button)
class AuroraAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;

  /// Guard to prevent intermediate currentIndexStream events from
  /// overriding the correct mediaItem during setAudioSource calls.
  bool _suppressIndexUpdates = false;

  AuroraAudioHandler(this.player) {
    // Broadcast playback state changes
    player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    player.processingStateStream.listen((state) {
      _broadcastState();
    });

    player.playingStream.listen((playing) {
      _broadcastState();
    });

    // Broadcast current media item changes based on index
    player.currentIndexStream.listen((index) {
      if (_suppressIndexUpdates) return;
      if (index != null &&
          queue.value.isNotEmpty &&
          index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  /// Suppress automatic mediaItem updates from currentIndexStream.
  /// Call before setAudioSource to prevent intermediate index 0 from
  /// overriding the correct mediaItem.
  void suppressIndexUpdates() {
    _suppressIndexUpdates = true;
  }

  /// Resume automatic mediaItem updates from currentIndexStream.
  void resumeIndexUpdates() {
    _suppressIndexUpdates = false;
  }

  /// Broadcast current playback state to notification
  void _broadcastState() {
    playbackState.add(PlaybackState(
      // Only these 3 controls - NO stop button!
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Show all 3 buttons in compact notification view
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final currentIndex = player.currentIndex ?? 0;
    final queueLength = queue.value.length;
    if (currentIndex < queueLength - 1) {
      await player.seek(Duration.zero, index: currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final currentIndex = player.currentIndex ?? 0;
    if (currentIndex > 0) {
      await player.seek(Duration.zero, index: currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  /// Set the audio source with queue
  Future<void> setAudioSource(AudioSource source,
      {int initialIndex = 0}) async {
    await player.setAudioSource(source, initialIndex: initialIndex);
  }

  /// Update the notification with new media item
  void updateNotificationMediaItem(MediaItem item) {
    mediaItem.add(item);
    _broadcastState();
  }

  /// Update the queue for notification
  void updateNotificationQueue(List<MediaItem> items) {
    queue.add(items);
  }
}

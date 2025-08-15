import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/app_config.dart';
import '../services/logging_service.dart';

/// Service responsible for audio session management
/// Handles audio focus, interruptions, and background playback configuration
class AudioSessionService {
  static final AudioSessionService _instance = AudioSessionService._internal();
  factory AudioSessionService() => _instance;
  AudioSessionService._internal();

  AudioSession? _audioSession;
  bool _isInitialized = false;

  /// Initializes the audio session with proper configuration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioSession = await AudioSession.instance;
      
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _isInitialized = true;
      LoggingService.info('Audio session initialized successfully', 'AudioSessionService');
    } catch (e) {
      LoggingService.error('Failed to initialize audio session', 'AudioSessionService', e);
      rethrow;
    }
  }

  /// Configures gapless playback for an audio player
  Future<void> configureGaplessPlayback(AudioPlayer audioPlayer, List<AudioSource> sources) async {
    try {
      if (sources.isEmpty) return;

      final concatenatingSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: sources,
      );

      await audioPlayer.setAudioSource(concatenatingSource);
      LoggingService.debug('Gapless playback configured with ${sources.length} sources', 'AudioSessionService');
    } catch (e) {
      LoggingService.error('Failed to configure gapless playback', 'AudioSessionService', e);
      rethrow;
    }
  }

  /// Handles audio interruptions (phone calls, notifications, etc.)
  void setupInterruptionHandling(AudioPlayer audioPlayer) {
    if (_audioSession == null) return;

    _audioSession!.interruptionEventStream.listen((event) {
      LoggingService.debug('Audio interruption: ${event.type}', 'AudioSessionService');
      
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Lower volume during interruption
            audioPlayer.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Pause playback
            audioPlayer.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Restore volume after interruption
            audioPlayer.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            // Optionally resume playback
            // Note: We don't auto-resume to respect user intent
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  /// Handles becoming noisy events (headphones unplugged)
  void setupBecomingNoisyHandling(AudioPlayer audioPlayer) {
    if (_audioSession == null) return;

    _audioSession!.becomingNoisyEventStream.listen((_) {
      LoggingService.debug('Audio becoming noisy - pausing playback', 'AudioSessionService');
      audioPlayer.pause();
    });
  }

  /// Sets up comprehensive audio handling for an audio player
  Future<void> setupAudioHandling(AudioPlayer audioPlayer) async {
    await initialize();
    setupInterruptionHandling(audioPlayer);
    setupBecomingNoisyHandling(audioPlayer);
    
    LoggingService.info('Audio handling configured for player', 'AudioSessionService');
  }

  /// Activates the audio session
  Future<void> activate() async {
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        LoggingService.debug('Audio session activated', 'AudioSessionService');
      }
    } catch (e) {
      LoggingService.error('Failed to activate audio session', 'AudioSessionService', e);
    }
  }

  /// Deactivates the audio session
  Future<void> deactivate() async {
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
        LoggingService.debug('Audio session deactivated', 'AudioSessionService');
      }
    } catch (e) {
      LoggingService.error('Failed to deactivate audio session', 'AudioSessionService', e);
    }
  }

  /// Gets the current audio session
  AudioSession? get audioSession => _audioSession;

  /// Checks if the audio session is initialized
  bool get isInitialized => _isInitialized;
}
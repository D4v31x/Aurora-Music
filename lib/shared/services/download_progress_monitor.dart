import 'dart:async';
import 'batch_download_service.dart';

/// Monitors download progress and exposes it for the UI notification center
class DownloadProgressMonitor {
  static final DownloadProgressMonitor _instance =
      DownloadProgressMonitor._internal();
  factory DownloadProgressMonitor() => _instance;
  DownloadProgressMonitor._internal();

  final BatchDownloadService _downloadService = BatchDownloadService();
  StreamSubscription<DownloadProgress>? _progressSubscription;

  final _downloadStatusController = StreamController<String>.broadcast();
  Stream<String> get downloadStatusStream => _downloadStatusController.stream;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  DownloadProgress? _currentProgress;
  DownloadProgress? get currentProgress => _currentProgress;

  /// Start monitoring downloads
  void startMonitoring() {
    if (_progressSubscription != null) return;

    _progressSubscription = _downloadService.progressStream.listen((progress) {
      _currentProgress = progress;
      _isDownloading = !progress.isComplete;

      // Send status updates to the notification stream
      if (progress.isComplete) {
        _downloadStatusController.add('Download complete! ✓');

        // Clear the message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentProgress?.isComplete == true) {
            _downloadStatusController.add('');
            _isDownloading = false;
          }
        });
      } else {
        final percentage = (progress.percentage * 100).toStringAsFixed(0);
        _downloadStatusController.add(
            'Downloading: ${progress.completed}/${progress.total} ($percentage%)');
      }
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _isDownloading = false;
    _currentProgress = null;
  }

  /// Get current download status as a string
  String getCurrentStatus() {
    if (_currentProgress == null || _currentProgress!.isComplete) {
      return '';
    }

    final percentage = (_currentProgress!.percentage * 100).toStringAsFixed(0);
    return 'Downloading: ${_currentProgress!.completed}/${_currentProgress!.total} ($percentage%)';
  }

  void dispose() {
    stopMonitoring();
    _downloadStatusController.close();
  }
}

import 'package:flutter/material.dart';
import 'package:aurora_music_v01/core/constants/font_constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../shared/providers/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/pill_button.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as Iconoir;

class PermissionsPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const PermissionsPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  bool _audioPermissionGranted = false;
  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _bluetoothPermissionGranted = false;
  bool _microphonePermissionGranted = false;
  bool _isChecking = false;
  bool _shouldShowStoragePermission = false; // Android 12 and below
  bool _shouldShowBluetoothPermission = false;
  bool _shouldShowAudioPermission = false; // Android 13+ only

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeIn,
      ),
    );

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
    _checkAndroidVersion(); // Check Android version first
    _checkPermissions();
  }

  /// Check Android version to determine if storage permission should be shown
  /// Storage permission is only needed for Android 12 (API 32) and below
  Future<void> _checkAndroidVersion() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      setState(() {
        _shouldShowStoragePermission = false;
      });
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (!mounted) return;
      setState(() {
        // Show storage permission only for Android 12 (API 32) and lower
        _shouldShowStoragePermission = androidInfo.version.sdkInt <= 32;
        _shouldShowBluetoothPermission = androidInfo.version.sdkInt >= 31;
        // Show audio permission only for Android 13 (API 33) and higher
        _shouldShowAudioPermission = androidInfo.version.sdkInt >= 33;
      });
      debugPrint(
          '📱 Android SDK: ${androidInfo.version.sdkInt}, Show storage permission: $_shouldShowStoragePermission, Show audio permission: $_shouldShowAudioPermission');
    } catch (e) {
      debugPrint('⚠️ Error checking Android version: $e');
      // Fallback: show both permissions if we can't determine version
      if (!mounted) return;
      setState(() {
        _shouldShowStoragePermission = true;
        _shouldShowBluetoothPermission = true;
        _shouldShowAudioPermission = true;
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isChecking = true;
    });

    final notificationStatus = await Permission.notification.status;
    final bluetoothStatus = await Permission.bluetoothConnect.status;
    final microphoneStatus = await Permission.microphone.status;

    // Only check audio permission on Android 13+
    PermissionStatus? audioStatus;
    if (_shouldShowAudioPermission) {
      audioStatus = await Permission.audio.status;
    }

    // Only check storage permission if needed (Android 12 and below)
    PermissionStatus? storageStatus;
    if (_shouldShowStoragePermission) {
      storageStatus = await Permission.storage.status;
    }

    if (!mounted) return;
    setState(() {
      _audioPermissionGranted = audioStatus?.isGranted ??
          true; // Auto-grant if not needed (Android < 13)
      _storagePermissionGranted =
          storageStatus?.isGranted ?? true; // Auto-grant if not needed
      _notificationPermissionGranted = notificationStatus.isGranted;
      _bluetoothPermissionGranted = bluetoothStatus.isGranted;
      _microphonePermissionGranted = microphoneStatus.isGranted;
      _isChecking = false;
    });
  }

  Future<void> _requestAudioPermission() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await Permission.audio.request();
    await _checkPermissions();
  }

  Future<void> _requestStoragePermission() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await Permission.storage.request();
    await _checkPermissions();
  }

  Future<void> _requestBluetoothPermission() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await Permission.bluetoothConnect.request();
    await _checkPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await Permission.notification.request();
    await _checkPermissions();
  }

  Future<void> _requestMicrophonePermission() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await Permission.microphone.request();
    await _checkPermissions();
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isChecking = true;
    });

    // Only request audio permission on Android 13+
    if (_shouldShowAudioPermission) {
      await Permission.audio.request();
    }

    // Only request storage permission if needed (Android 12 and below)
    if (_shouldShowStoragePermission) {
      await Permission.storage.request();
    }

    if (_shouldShowBluetoothPermission) {
      await Permission.bluetoothConnect.request();
    }

    await Permission.microphone.request();
    await Permission.notification.request();

    await _checkPermissions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.6);

    // Required permission is granted: audio on Android 13+, storage on Android 12-
    final requiredPermissionGranted = _shouldShowAudioPermission
        ? _audioPermissionGranted
        : _storagePermissionGranted;
    final allGranted = _audioPermissionGranted && _storagePermissionGranted;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller, _exitController]),
            builder: (context, child) {
              return Column(
                children: [
                  const SizedBox(height: 48),

                  // Page icon
                  SlideTransition(
                    position: _exitController.isAnimating ||
                            _exitController.isCompleted
                        ? _exitSlideAnimation
                        : _titleSlideAnimation,
                    child: FadeTransition(
                      opacity: _exitController.isAnimating ||
                              _exitController.isCompleted
                          ? _exitFadeAnimation
                          : _titleFadeAnimation,
                      child: Iconoir.Shield(
                        color: Theme.of(context).colorScheme.primary,
                        height: 56,
                        width: 56,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  SlideTransition(
                    position: _exitController.isAnimating ||
                            _exitController.isCompleted
                        ? _exitSlideAnimation
                        : _titleSlideAnimation,
                    child: FadeTransition(
                      opacity: _exitController.isAnimating ||
                              _exitController.isCompleted
                          ? _exitFadeAnimation
                          : _titleFadeAnimation,
                      child: Text(
                        AppLocalizations.of(context)
                            .onboardingPermissionsTitle,
                        style: TextStyle(
                          fontFamily: FontConstants.fontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: _exitController.isAnimating ||
                            _exitController.isCompleted
                        ? _exitFadeAnimation
                        : _subtitleFadeAnimation,
                    child: Text(
                      AppLocalizations.of(context)
                          .onboardingPermissionsSubtitle,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Permission items
                  Expanded(
                    child: SlideTransition(
                      position: _exitController.isAnimating ||
                              _exitController.isCompleted
                          ? _exitSlideAnimation
                          : _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _exitController.isAnimating ||
                                _exitController.isCompleted
                            ? _exitFadeAnimation
                            : _contentFadeAnimation,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Only show audio permission for Android 13+
                              if (_shouldShowAudioPermission) ...[
                                _buildPermissionItem(
                                  context: context,
                                  icon: Iconoir.MusicNote(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 24,
                                    height: 24,
                                  ),
                                  title: AppLocalizations.of(context)
                                      .onboardingAudioAccess,
                                  description: AppLocalizations.of(context)
                                      .onboardingAudioAccessDesc,
                                  isGranted: _audioPermissionGranted,
                                  isRequired: true,
                                  isDark: isDark,
                                  onTap: _requestAudioPermission,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Only show storage permission for Android 12 and below
                              if (_shouldShowStoragePermission) ...[
                                _buildPermissionItem(
                                  context: context,
                                  icon: Iconoir.Folder(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 24,
                                    height: 24,
                                  ),
                                  title: AppLocalizations.of(context)
                                      .onboardingStorageAccess,
                                  description: AppLocalizations.of(context)
                                      .onboardingStorageAccessDesc,
                                  isGranted: _storagePermissionGranted,
                                  isRequired: true,
                                  isDark: isDark,
                                  onTap: _requestStoragePermission,
                                ),
                                const SizedBox(height: 12),
                              ],

                              _buildPermissionItem(
                                context: context,
                                icon: Iconoir.Bluetooth(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 24,
                                  height: 24,
                                ),
                                title: AppLocalizations.of(context)
                                    .onboardingBluetooth,
                                description: AppLocalizations.of(context)
                                    .onboardingBluetoothDesc,
                                isGranted: _bluetoothPermissionGranted,
                                isRequired: false,
                                isDark: isDark,
                                onTap: _requestBluetoothPermission,
                              ),

                              const SizedBox(height: 12),

                              _buildPermissionItem(
                                context: context,
                                icon: Iconoir.Bell(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 24,
                                  height: 24,
                                ),
                                title: AppLocalizations.of(context)
                                    .onboardingNotifications,
                                description: AppLocalizations.of(context)
                                    .onboardingNotificationsDesc,
                                isGranted: _notificationPermissionGranted,
                                isRequired: false,
                                isDark: isDark,
                                onTap: _requestNotificationPermission,
                              ),

                              const SizedBox(height: 12),

                              _buildPermissionItem(
                                context: context,
                                icon: Iconoir.SoundHigh(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 24,
                                  height: 24,
                                ),
                                title: AppLocalizations.of(context)
                                    .onboardingVisualizerAccess,
                                description: AppLocalizations.of(context)
                                    .onboardingVisualizerAccessDesc,
                                isGranted: _microphonePermissionGranted,
                                isRequired: false,
                                isDark: isDark,
                                onTap: _requestMicrophonePermission,
                              ),

                              const SizedBox(height: 24),

                              // Request permissions button
                              if (!allGranted)
                                PillButton(
                                  text: _isChecking
                                      ? AppLocalizations.of(context)
                                          .onboardingRequesting
                                      : AppLocalizations.of(context).onboardingGrantPermissions,
                                  onPressed: _isChecking
                                      ? null
                                      : _requestAllPermissions,
                                  isLoading: _isChecking,
                                  iconWidget: Iconoir.ShieldCheck(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 20,
                                    height: 20,
                                  ),
                                  width: double.infinity,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: requiredPermissionGranted
                        ? PillNavigationButtons(
                            backText:
                                AppLocalizations.of(context).back,
                            continueText: AppLocalizations.of(context)
                                .continueButton,
                            onBack: widget.onBack,
                            onContinue: () async {
                              await _exitController.forward();
                              widget.onContinue();
                            },
                          )
                        : Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)
                                    .onboardingAudioRequired,
                                style: const TextStyle(
                                  fontFamily: FontConstants.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFEF4444),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              PillNavigationButtons(
                                backText: AppLocalizations.of(context)
                                    .back,
                                continueText: AppLocalizations.of(context)
                                    .continueButton,
                                onBack: widget.onBack,
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required BuildContext context,
    required Widget icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isRequired,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final containerColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final titleColor = isDark ? Colors.white : Colors.black;
    final descriptionColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.6);
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isGranted || _isChecking) ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isGranted
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGranted
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGranted
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: isGranted
                          ? Theme.of(context).colorScheme.primary
                          : iconColor,
                    ),
                    child: icon,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        if (isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)
                                  .onboardingRequired,
                              style: const TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: 13,
                        color: descriptionColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              isGranted
                  ? Iconoir.CheckCircle(
                      color: Theme.of(context).colorScheme.primary,
                      width: 24,
                      height: 24,
                    )
                  : Iconoir.Circle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.3),
                      width: 24,
                      height: 24,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

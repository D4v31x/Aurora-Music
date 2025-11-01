import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../providers/theme_provider.dart';
import '../../../widgets/pill_button.dart';

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
  bool _isChecking = false;
  bool _shouldShowStoragePermission = false; // Android version check
  bool _shouldShowBluetoothPermission = false;

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
      setState(() {
        _shouldShowStoragePermission = false;
      });
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        // Show storage permission only for Android 12 (API 32) and lower
        _shouldShowStoragePermission = androidInfo.version.sdkInt <= 32;
        _shouldShowBluetoothPermission = androidInfo.version.sdkInt >= 31;
      });
      debugPrint(
          '📱 Android SDK: ${androidInfo.version.sdkInt}, Show storage permission: $_shouldShowStoragePermission');
    } catch (e) {
      debugPrint('⚠️ Error checking Android version: $e');
      // Fallback: show storage permission if we can't determine version
      setState(() {
        _shouldShowStoragePermission = true;
        _shouldShowBluetoothPermission = true;
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isChecking = true;
    });

    final audioStatus = await Permission.audio.status;
    final notificationStatus = await Permission.notification.status;
    final bluetoothStatus = await Permission.bluetoothConnect.status;

    // Only check storage permission if needed (Android 12 and below)
    PermissionStatus? storageStatus;
    if (_shouldShowStoragePermission) {
      storageStatus = await Permission.storage.status;
    }

    setState(() {
      _audioPermissionGranted = audioStatus.isGranted;
      _storagePermissionGranted =
          storageStatus?.isGranted ?? true; // Auto-grant if not needed
      _notificationPermissionGranted = notificationStatus.isGranted;
      _bluetoothPermissionGranted = bluetoothStatus.isGranted;
      _isChecking = false;
    });
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isChecking = true;
    });

    await Permission.audio.request();

    // Only request storage permission if needed (Android 12 and below)
    if (_shouldShowStoragePermission) {
      await Permission.storage.request();
    }

    if (_shouldShowBluetoothPermission) {
      await Permission.bluetoothConnect.request();
    }

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
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

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
                  const SizedBox(height: 80),

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
                        'Grant Permissions',
                        style: TextStyle(
                          fontFamily: 'Outfit',
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
                      'Aurora Music needs these permissions to work properly',
                      style: TextStyle(
                        fontFamily: 'Outfit',
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
                        child: Column(
                          children: [
                            _buildPermissionItem(
                              context: context,
                              icon: Icons.music_note_rounded,
                              title: 'Audio Access',
                              description:
                                  'Required to play and manage your music library',
                              isGranted: _audioPermissionGranted,
                              isRequired: true,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 12),

                            // Only show storage permission for Android 12 and below
                            if (_shouldShowStoragePermission) ...[
                              _buildPermissionItem(
                                context: context,
                                icon: Icons.folder_rounded,
                                title: 'Storage Access',
                                description:
                                    'Required to read music files from your device',
                                isGranted: _storagePermissionGranted,
                                isRequired: true,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                            ],

                            _buildPermissionItem(
                              context: context,
                              icon: Icons.bluetooth_rounded,
                              title: 'Bluetooth',
                              description:
                                  'Needed to connect to bluetooth devices',
                              isGranted: _bluetoothPermissionGranted,
                              isRequired: false,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 12),

                            _buildPermissionItem(
                              context: context,
                              icon: Icons.notifications_rounded,
                              title: 'Notifications',
                              description: 'Show playback controls and updates',
                              isGranted: _notificationPermissionGranted,
                              isRequired: false,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 24),

                            // Request permissions button
                            if (!allGranted)
                              PillButton(
                                text: _isChecking
                                    ? 'Requesting...'
                                    : 'Grant Permissions',
                                onPressed:
                                    _isChecking ? null : _requestAllPermissions,
                                isPrimary: true,
                                isLoading: _isChecking,
                                icon: Icons.shield_rounded,
                                width: double.infinity,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0, top: 16.0),
                    child: PillNavigationButtons(
                      onBack: widget.onBack,
                      onContinue: () async {
                        await _exitController.forward();
                        widget.onContinue();
                      },
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
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isRequired,
    required bool isDark,
  }) {
    final containerColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final titleColor = isDark ? Colors.white : Colors.black;
    final descriptionColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);
    final iconColor =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGranted
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color:
                  isGranted ? Theme.of(context).colorScheme.primary : iconColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: descriptionColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted
                ? Theme.of(context).colorScheme.primary
                : (isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.3)),
            size: 24,
          ),
        ],
      ),
    );
  }
}

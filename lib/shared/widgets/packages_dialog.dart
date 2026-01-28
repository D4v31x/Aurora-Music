import 'package:flutter/material.dart';
import '../constants/font_constants.dart';
import '../widgets/glassmorphic_container.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model class representing a package dependency
class PackageInfo {
  final String name;
  final String version;
  final String description;
  final String? url;

  const PackageInfo({
    required this.name,
    required this.version,
    required this.description,
    this.url,
  });
}

/// Dialog showing all packages used in the application
class PackagesDialog extends StatelessWidget {
  const PackagesDialog({super.key});

  /// List of all packages used in Aurora Music
  static const List<PackageInfo> packages = [
    PackageInfo(
      name: 'just_audio',
      version: '^0.10.4',
      description: 'Feature-rich audio player for Flutter',
      url: 'https://pub.dev/packages/just_audio',
    ),
    PackageInfo(
      name: 'audio_service',
      version: '^0.18.15',
      description: 'Background audio playback and media controls',
      url: 'https://pub.dev/packages/audio_service',
    ),
    PackageInfo(
      name: 'audio_session',
      version: 'any',
      description: 'Audio session management for proper audio focus',
      url: 'https://pub.dev/packages/audio_session',
    ),
    PackageInfo(
      name: 'on_audio_query',
      version: '^2.9.0',
      description: 'Query audio files from device storage',
      url: 'https://pub.dev/packages/on_audio_query',
    ),
    PackageInfo(
      name: 'audiotags',
      version: '^1.4.5',
      description: 'Read and write audio metadata tags',
      url: 'https://pub.dev/packages/audiotags',
    ),
    PackageInfo(
      name: 'provider',
      version: '^6.1.2',
      description: 'State management solution for Flutter',
      url: 'https://pub.dev/packages/provider',
    ),
    PackageInfo(
      name: 'shared_preferences',
      version: '^2.3.4',
      description: 'Persistent key-value storage',
      url: 'https://pub.dev/packages/shared_preferences',
    ),
    PackageInfo(
      name: 'path_provider',
      version: '^2.1.3',
      description: 'Access to device file system paths',
      url: 'https://pub.dev/packages/path_provider',
    ),
    PackageInfo(
      name: 'permission_handler',
      version: '^12.0.0+1',
      description: 'Handle runtime permissions',
      url: 'https://pub.dev/packages/permission_handler',
    ),
    PackageInfo(
      name: 'dynamic_color',
      version: '^1.7.0',
      description: 'Material You dynamic color theming',
      url: 'https://pub.dev/packages/dynamic_color',
    ),
    PackageInfo(
      name: 'palette_generator',
      version: '^0.3.3+4',
      description: 'Extract colors from images',
      url: 'https://pub.dev/packages/palette_generator',
    ),
    PackageInfo(
      name: 'lottie',
      version: '^3.2.0',
      description: 'Lottie animations for Flutter',
      url: 'https://pub.dev/packages/lottie',
    ),
    PackageInfo(
      name: 'flutter_staggered_animations',
      version: '^1.1.1',
      description: 'Staggered list animations',
      url: 'https://pub.dev/packages/flutter_staggered_animations',
    ),
    PackageInfo(
      name: 'animations',
      version: '^2.0.11',
      description: 'Pre-built Material animations',
      url: 'https://pub.dev/packages/animations',
    ),
    PackageInfo(
      name: 'blur',
      version: '^4.0.0',
      description: 'Blur effects for widgets',
      url: 'https://pub.dev/packages/blur',
    ),
    PackageInfo(
      name: 'mesh',
      version: '^0.5.0',
      description: 'Mesh gradient backgrounds',
      url: 'https://pub.dev/packages/mesh',
    ),
    PackageInfo(
      name: 'http',
      version: '^1.2.1',
      description: 'HTTP requests for API calls',
      url: 'https://pub.dev/packages/http',
    ),
    PackageInfo(
      name: 'spotify',
      version: '^0.13.7',
      description: 'Spotify Web API integration',
      url: 'https://pub.dev/packages/spotify',
    ),
    PackageInfo(
      name: 'url_launcher',
      version: '^6.2.6',
      description: 'Launch URLs in browser',
      url: 'https://pub.dev/packages/url_launcher',
    ),
    PackageInfo(
      name: 'share_plus',
      version: '^10.0.3',
      description: 'Share content with other apps',
      url: 'https://pub.dev/packages/share_plus',
    ),
    PackageInfo(
      name: 'package_info_plus',
      version: '^8.0.0',
      description: 'Get app version and package info',
      url: 'https://pub.dev/packages/package_info_plus',
    ),
    PackageInfo(
      name: 'device_info_plus',
      version: '^11.4.0',
      description: 'Get device information',
      url: 'https://pub.dev/packages/device_info_plus',
    ),
    PackageInfo(
      name: 'flutter_dotenv',
      version: '^5.1.0',
      description: 'Load environment variables from .env file',
      url: 'https://pub.dev/packages/flutter_dotenv',
    ),
    PackageInfo(
      name: 'crypto',
      version: '^3.0.6',
      description: 'Cryptographic hashing functions',
      url: 'https://pub.dev/packages/crypto',
    ),
    PackageInfo(
      name: 'html',
      version: '^0.15.4',
      description: 'HTML parsing utilities',
      url: 'https://pub.dev/packages/html',
    ),
    PackageInfo(
      name: 'intl',
      version: 'any',
      description: 'Internationalization and localization',
      url: 'https://pub.dev/packages/intl',
    ),
    PackageInfo(
      name: 'version',
      version: '^3.0.2',
      description: 'Version parsing and comparison',
      url: 'https://pub.dev/packages/version',
    ),
    PackageInfo(
      name: 'pub_semver',
      version: '^2.1.4',
      description: 'Semantic versioning utilities',
      url: 'https://pub.dev/packages/pub_semver',
    ),
    PackageInfo(
      name: 'miniplayer',
      version: '^1.0.1',
      description: 'Expandable mini player widget',
      url: 'https://pub.dev/packages/miniplayer',
    ),
    PackageInfo(
      name: 'clarity_flutter',
      version: '^1.6.0',
      description: 'Microsoft Clarity analytics',
      url: 'https://pub.dev/packages/clarity_flutter',
    ),
    PackageInfo(
      name: 'flutter_hooks',
      version: '^0.21.3+1',
      description: 'React-like hooks for Flutter',
      url: 'https://pub.dev/packages/flutter_hooks',
    ),
  ];

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: GlassmorphicContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Open Source Packages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${packages.length} packages used',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontFamily: FontConstants.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Package List
              Flexible(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: packages.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final package = packages[index];
                    return _PackageTile(
                      package: package,
                      onTap: package.url != null
                          ? () => _launchURL(package.url!)
                          : null,
                    );
                  },
                ),
              ),

              // Footer with acknowledgment
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Thank you to all the open source contributors!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontFamily: FontConstants.fontFamily,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual package tile widget
class _PackageTile extends StatelessWidget {
  final PackageInfo package;
  final VoidCallback? onTap;

  const _PackageTile({
    required this.package,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.extension,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Package info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          package.version,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontFamily: FontConstants.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontFamily: FontConstants.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

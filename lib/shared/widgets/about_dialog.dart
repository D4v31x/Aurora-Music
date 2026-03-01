import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/constants/font_constants.dart';
import '../../l10n/app_localizations.dart';
import './glassmorphic_container.dart';
import './changelog_dialog.dart';
import './packages_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class AuroraAboutDialog extends StatelessWidget {
  final String version;
  final String codename;

  const AuroraAboutDialog({
    super.key,
    required this.version,
    required this.codename,
  });

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _showChangelog(BuildContext context) {
    Navigator.pop(context); // Close about dialog first
    showDialog(
      context: context,
      builder: (BuildContext context) => ChangelogDialog(
        currentVersion: version,
      ),
    );
  }

  void _showPackages(BuildContext context) {
    Navigator.pop(context); // Close about dialog first
    showDialog(
      context: context,
      builder: (BuildContext context) => const PackagesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GlassmorphicContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Logo Section with gradient background
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo/Music_full_logo.png',
                      width: 190,
                      height: 70,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              // Content Section
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Version Info
                      _buildInfoRow(
                        icon: Icons.numbers,
                        title: 'Version',
                        value: version,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.label_outline,
                        title: 'Codename',
                        value: codename,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.person_outline,
                        title: 'Developer',
                        value: 'D4v31x',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.copyright,
                        title: 'Copyright',
                        value: '© ${DateTime.now().year} Aurora Software CZ',
                      ),

                      const SizedBox(height: 24),

                      // What's New Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showChangelog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.new_releases_outlined),
                          label: Text(
                            AppLocalizations.of(context).translate('whats_new'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: FontConstants.fontFamily,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Open Source Packages Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showPackages(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text(
                            'Open Source Packages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: FontConstants.fontFamily,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 24),

                      // Links Section
                      Text(
                        AppLocalizations.of(context)
                            .translate('connect_with_us'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontFamily: FontConstants.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(
                            icon: Icons.language,
                            label: 'Website',
                            onTap: () => _launchURL(
                                'https://aurorasoftware.netlify.app'),
                          ),
                          const SizedBox(width: 16),
                          _buildSocialButton(
                            icon: Icons.code,
                            label: 'GitHub',
                            onTap: () => _launchURL(
                                'https://github.com/D4v31x/Aurora-Music'),
                          ),
                          const SizedBox(width: 16),
                          _buildSocialButton(
                            icon: Icons.discord,
                            label: 'Instagram',
                            onTap: () => _launchURL(
                                'https://www.instagram.com/aurora.software'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Close Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('close'),
                    style: const TextStyle(
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
      ),
    ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          '$title:',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: FontConstants.fontFamily,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: FontConstants.fontFamily,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.1),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

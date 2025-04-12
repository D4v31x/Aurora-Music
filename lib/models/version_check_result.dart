class VersionCheckResult {
  final bool hasUpdate;
  final String? newVersion;
  final String? changelog;

  VersionCheckResult({
    required this.hasUpdate,
    this.newVersion,
    this.changelog,
  });
}

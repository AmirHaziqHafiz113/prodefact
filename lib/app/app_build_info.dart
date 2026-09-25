import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The short git commit this binary was built from, injected at build
/// time so QA screenshots identify the exact build:
///
///     flutter build apk --debug \
///       --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
///
/// Empty when not provided. Never hard-coded, so it can't go stale.
const kBuildGitSha = String.fromEnvironment('GIT_SHA');

/// What the Profile screen shows so testers can prove which APK they
/// have: the real app version and build number from the platform (not
/// a constant), plus the injected commit.
class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    this.gitSha,
  });

  final String version;
  final String buildNumber;
  final String? gitSha;

  /// Shown in debug/profile builds, and in any release build stamped
  /// with a commit (QA builds). A plain store release shows nothing.
  static bool get isQaBuild => !kReleaseMode || kBuildGitSha.isNotEmpty;

  String get versionLabel => 'Version: $version ($buildNumber)';

  String get buildLabel =>
      gitSha == null ? 'Build: not stamped' : 'Build: $gitSha';
}

final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    version: info.version,
    buildNumber: info.buildNumber,
    gitSha: kBuildGitSha.isEmpty ? null : kBuildGitSha,
  );
});

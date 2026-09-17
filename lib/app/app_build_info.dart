/// The app's own version/build — kept in sync with `pubspec.yaml`'s
/// `version:` field by hand (no `package_info_plus`/platform-channel
/// dependency added just for two static strings; see
/// docs/ui_design_system.md). Shown verbatim on the Profile screen's
/// App Info row — never a fabricated version string.
abstract final class AppBuildInfo {
  static const version = '0.1.0';
  static const build = '1';
}

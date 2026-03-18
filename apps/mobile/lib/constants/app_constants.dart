/// App-wide constants
class AppConstants {
  AppConstants._();

  /// Expected Bridge Server version (from packages/bridge/package.json)
  /// Used to check if the server needs updating
  static const String expectedBridgeVersion = '1.23.0';

  /// Maximum number of machines to keep in history
  /// Favorites are always kept, non-favorites are pruned by lastConnected
  static const int maxMachineHistory = 50;

  /// Default project path on remote machines (for SSH update commands)
  static const String defaultProjectPath = '~/Workspace/ccpocket';

  // ── External links ──

  /// Install landing page (redirects to App Store / Play Store on mobile)
  static const String installUrl = 'https://k9i-0.github.io/ccpocket/install';

  /// Primary share URL — uses install page for better mobile conversion
  static const String shareUrl = installUrl;

  /// GitHub repository URL
  static const String githubUrl = 'https://github.com/K9i-0/ccpocket';

  /// App Store URL (iOS)
  static const String appStoreUrl =
      'https://apps.apple.com/us/app/cc-pocket-dev-agent-remote/id6759188790';

  /// Play Store URL (Android)
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.k9i.ccpocket';
}

/// App-wide constants
class AppConstants {
  AppConstants._();

  /// Expected Bridge Server version (from packages/bridge/package.json)
  /// Used to check if the server needs updating
  static const String expectedBridgeVersion = '0.1.0';

  /// Maximum number of machines to keep in history
  /// Favorites are always kept, non-favorites are pruned by lastConnected
  static const int maxMachineHistory = 50;

  /// Default project path on remote machines (for SSH update commands)
  static const String defaultProjectPath = '~/Workspace/ccpocket';
}

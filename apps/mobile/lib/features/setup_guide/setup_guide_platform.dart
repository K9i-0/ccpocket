import '../../utils/platform_helper.dart';

/// Platform-specific flow used by [SetupGuideScreen].
enum SetupGuidePlatform {
  /// iOS / Android (or web): guides the user to prepare their Mac or PC host,
  /// recommending the macOS app for Mac users.
  mobile,

  /// macOS desktop app: starts and manages the local Bridge directly from the
  /// app without terminal commands.
  macOS,

  /// Linux / Windows desktop app: runs the Bridge via CLI on the local or a
  /// remote machine.
  desktopOther,
}

/// Resolves which setup guide flow to show, honoring test overrides first.
SetupGuidePlatform resolveSetupGuidePlatform({
  SetupGuidePlatform? platformOverride,
  bool? localBridgeOverride,
}) {
  if (platformOverride != null) return platformOverride;
  if (localBridgeOverride != null) {
    return localBridgeOverride
        ? SetupGuidePlatform.macOS
        : SetupGuidePlatform.mobile;
  }
  if (isMacOSPlatform) return SetupGuidePlatform.macOS;
  if (isDesktopPlatform) return SetupGuidePlatform.desktopOther;
  return SetupGuidePlatform.mobile;
}

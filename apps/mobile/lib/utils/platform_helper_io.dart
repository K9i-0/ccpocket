import 'dart:io';

import 'package:flutter/foundation.dart';

/// Returns the home directory path from environment variable.
String getHomeDirectory() => Platform.environment['HOME'] ?? '';

// These describe the host OS, except when a debug build overrides the target
// platform: multi_device_preview runs the app on macOS with
// `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`, and the UI should
// then look as it does on an iPhone. Native APIs of the host must use
// `Platform` from `dart:io` (or [isMobileHost]) instead.
bool _runsAs(Set<TargetPlatform> platforms, bool host) {
  final override = kDebugMode ? debugDefaultTargetPlatformOverride : null;
  return override == null ? host : platforms.contains(override);
}

/// Whether the app runs as a desktop OS (macOS, Windows, Linux).
bool get isDesktopPlatform => _runsAs(const {
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
}, Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Whether the app runs as a mobile OS (iOS, Android).
bool get isMobilePlatform => _runsAs(const {
  TargetPlatform.iOS,
  TargetPlatform.android,
}, Platform.isIOS || Platform.isAndroid);

/// Whether the app runs as macOS.
bool get isMacOSPlatform =>
    _runsAs(const {TargetPlatform.macOS}, Platform.isMacOS);

/// Whether the app runs as iOS.
bool get isIOSPlatform => _runsAs(const {TargetPlatform.iOS}, Platform.isIOS);

/// Whether the app runs as Android.
bool get isAndroidPlatform =>
    _runsAs(const {TargetPlatform.android}, Platform.isAndroid);

/// Whether the host OS is iOS or Android, for native APIs that exist only
/// there. Unlike [isMobilePlatform], it ignores a debug platform override.
bool get isMobileHost => Platform.isIOS || Platform.isAndroid;

/// Best-effort system locale name.
String? getSystemLocaleName() {
  try {
    return Platform.localeName;
  } catch (_) {
    return null;
  }
}

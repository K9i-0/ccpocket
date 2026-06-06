import 'dart:io';

/// Returns the home directory path from environment variable.
String getHomeDirectory() => Platform.environment['HOME'] ?? '';

/// Whether the current platform is a desktop OS (macOS, Windows, Linux).
bool get isDesktopPlatform =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Whether the current platform is a mobile OS (iOS, Android).
bool get isMobilePlatform => Platform.isIOS || Platform.isAndroid;

/// Whether the current platform is macOS.
bool get isMacOSPlatform => Platform.isMacOS;

/// Whether the current platform is iOS.
bool get isIOSPlatform => Platform.isIOS;

/// Whether the current platform is Android.
bool get isAndroidPlatform => Platform.isAndroid;

/// Best-effort system locale name.
String? getSystemLocaleName() {
  try {
    return Platform.localeName;
  } catch (_) {
    return null;
  }
}

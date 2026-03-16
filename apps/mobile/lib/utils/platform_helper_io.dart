import 'dart:io';

/// Returns the home directory path from environment variable.
String getHomeDirectory() => Platform.environment['HOME'] ?? '';

/// Whether the current platform is a desktop OS (macOS, Windows, Linux).
bool get isDesktopPlatform =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Whether the current platform is a mobile OS (iOS, Android).
bool get isMobilePlatform => Platform.isIOS || Platform.isAndroid;

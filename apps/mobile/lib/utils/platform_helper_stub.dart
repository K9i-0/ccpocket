// Stub implementation for Web platform.

/// Returns the home directory path. On Web, returns empty string.
String getHomeDirectory() => '';

/// Whether the current platform is a desktop OS (macOS, Windows, Linux).
bool get isDesktopPlatform => false;

/// Whether the current platform is a mobile OS (iOS, Android).
bool get isMobilePlatform => false;

/// Whether the current platform is macOS.
bool get isMacOSPlatform => false;

/// Whether the current platform is iOS.
bool get isIOSPlatform => false;

/// Whether the current platform is Android.
bool get isAndroidPlatform => false;

/// Best-effort system locale name. Unavailable on Web.
String? getSystemLocaleName() => null;

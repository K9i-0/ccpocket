import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Information about an available app update.
class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseUrl,
  });
}

/// Service to check GitHub Releases for macOS app updates.
///
/// Only active on macOS desktop. On other platforms, [checkForUpdate] always
/// returns null.
class AppUpdateService {
  static const _owner = 'K9i-0';
  static const _repo = 'ccpocket';
  static const _dismissedVersionKey = 'app_update_dismissed_version';
  static const _lastCheckKey = 'app_update_last_check';

  /// Minimum interval between checks (1 hour).
  static const _checkInterval = Duration(hours: 1);

  AppUpdateService._();
  static final instance = AppUpdateService._();

  AppUpdateInfo? _cachedUpdate;

  /// Returns cached update info (if any), without making a network request.
  AppUpdateInfo? get cachedUpdate => _cachedUpdate;

  /// Whether the user has dismissed the banner for the current latest version.
  bool _isDismissed = false;
  bool get isDismissedByUser => _isDismissed;

  /// Check for a newer macOS release on GitHub.
  ///
  /// Returns [AppUpdateInfo] if a newer version is available, null otherwise.
  /// Respects a minimum check interval to avoid excessive API calls.
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    // Only check on macOS desktop
    if (defaultTargetPlatform != TargetPlatform.macOS || kIsWeb) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();

    // Throttle checks unless forced
    if (!force) {
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (elapsed < _checkInterval.inMilliseconds && _cachedUpdate != null) {
        return _cachedUpdate;
      }
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.40.0"

      // Fetch latest macOS release tag
      final latestVersion = await _fetchLatestMacOSVersion();
      if (latestVersion == null) return null;

      // Save check timestamp
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      // Compare versions
      if (_isNewer(latestVersion, currentVersion)) {
        final tagName = 'macos/v$latestVersion';
        // URL-encode the + in the tag name
        final encodedTag = Uri.encodeComponent(tagName);
        _cachedUpdate = AppUpdateInfo(
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          downloadUrl:
              'https://github.com/$_owner/$_repo/releases/download/$encodedTag/ccpocket-macos-v$latestVersion.dmg',
          releaseUrl:
              'https://github.com/$_owner/$_repo/releases/tag/$encodedTag',
        );

        // Check if user dismissed this specific version
        final dismissedVersion = prefs.getString(_dismissedVersionKey);
        _isDismissed = dismissedVersion == latestVersion;

        return _cachedUpdate;
      }

      _cachedUpdate = null;
      return null;
    } catch (e) {
      debugPrint('App update check failed: $e');
      return _cachedUpdate; // Return cached result on error
    }
  }

  /// Mark the current latest version as dismissed by the user.
  Future<void> dismissUpdate() async {
    _isDismissed = true;
    if (_cachedUpdate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, _cachedUpdate!.latestVersion);
    }
  }

  /// Fetch the latest macOS release version from GitHub tags.
  Future<String?> _fetchLatestMacOSVersion() async {
    // Use the tags API to find the latest macos/v* tag
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/tags?per_page=20',
    );
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (response.statusCode != 200) return null;

    final tags = jsonDecode(response.body) as List<dynamic>;
    String? latestVersion;

    for (final tag in tags) {
      final name = tag['name'] as String;
      if (name.startsWith('macos/v')) {
        // Extract version: "macos/v1.40.0+67" → "1.40.0"
        final fullVersion = name.substring('macos/v'.length);
        final version = fullVersion.split('+').first;
        if (latestVersion == null || _isNewer(version, latestVersion)) {
          latestVersion = version;
        }
      }
    }

    return latestVersion;
  }

  /// Returns true if [a] is newer than [b] (simple semver comparison).
  static bool _isNewer(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va > vb) return true;
      if (va < vb) return false;
    }
    return false;
  }
}

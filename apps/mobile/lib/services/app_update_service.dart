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
  static const _gitHubApiBase = 'https://api.github.com/repos/$_owner/$_repo';

  /// Minimum interval between checks (1 hour).
  static const _checkInterval = Duration(hours: 1);

  AppUpdateService._({
    http.Client? httpClient,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _httpClient = httpClient ?? http.Client(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static final instance = AppUpdateService._();

  @visibleForTesting
  factory AppUpdateService.test({
    http.Client? httpClient,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) {
    return AppUpdateService._(
      httpClient: httpClient,
      packageInfoLoader: packageInfoLoader,
    );
  }

  final http.Client _httpClient;
  final Future<PackageInfo> Function() _packageInfoLoader;

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
      final info = await _packageInfoLoader();
      final currentVersion = info.version; // e.g. "1.40.0"

      // Fetch latest macOS release details
      final release = await _fetchLatestMacOSRelease();
      if (release == null) return null;

      // Save check timestamp
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      // Compare versions
      if (_isNewer(release.version, currentVersion)) {
        _cachedUpdate = AppUpdateInfo(
          latestVersion: release.version,
          currentVersion: currentVersion,
          downloadUrl: release.downloadUrl,
          releaseUrl: release.releaseUrl,
        );

        // Check if user dismissed this specific version
        final dismissedVersion = prefs.getString(_dismissedVersionKey);
        _isDismissed = dismissedVersion == release.version;

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

  /// Fetch the latest macOS release details from GitHub Releases.
  Future<_MacOSRelease?> _fetchLatestMacOSRelease() async {
    final uri = Uri.parse('$_gitHubApiBase/releases?per_page=20');
    final response = await _httpClient.get(
      uri,
      headers: {'Accept': 'application/vnd.github+json'},
    );

    if (response.statusCode != 200) return null;

    final releases = jsonDecode(response.body) as List<dynamic>;
    _MacOSRelease? latestRelease;

    for (final release in releases) {
      if (release is! Map<String, dynamic>) continue;
      final tagName = release['tag_name'] as String?;
      final htmlUrl = release['html_url'] as String?;
      if (tagName == null ||
          htmlUrl == null ||
          !tagName.startsWith('macos/v')) {
        continue;
      }

      final fullVersion = tagName.substring('macos/v'.length);
      final version = fullVersion.split('+').first;
      final assets = release['assets'] as List<dynamic>? ?? const [];
      final expectedAssetName = 'CC-Pocket-macos-v$version.dmg';
      final asset = assets.cast<Map<String, dynamic>?>().firstWhere(
        (candidate) => candidate?['name'] == expectedAssetName,
        orElse: () => null,
      );
      final downloadUrl = asset?['browser_download_url'] as String?;
      if (downloadUrl == null) continue;

      final candidate = _MacOSRelease(
        version: version,
        downloadUrl: downloadUrl,
        releaseUrl: htmlUrl,
      );

      if (latestRelease == null ||
          _isNewer(candidate.version, latestRelease.version)) {
        latestRelease = candidate;
      }
    }

    return latestRelease;
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

class _MacOSRelease {
  const _MacOSRelease({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  final String version;
  final String downloadUrl;
  final String releaseUrl;
}

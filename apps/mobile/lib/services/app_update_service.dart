import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateInstallMode { nativeUpdater, externalDownload }

/// Information about an available app update.
class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseUrl;
  final AppUpdateInstallMode installMode;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.installMode,
  });

  bool get canInstallInApp => installMode == AppUpdateInstallMode.nativeUpdater;
}

abstract class AppUpdateGateway {
  Future<Map<String, dynamic>?> probeForUpdate();
  Future<void> performUpdate();
  Future<bool> canUseNativeUpdater();
}

class MethodChannelAppUpdateGateway implements AppUpdateGateway {
  const MethodChannelAppUpdateGateway([
    this._channel = const MethodChannel('ccpocket/app_updater'),
  ]);

  final MethodChannel _channel;

  @override
  Future<Map<String, dynamic>?> probeForUpdate() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'probeForUpdate',
    );
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  @override
  Future<void> performUpdate() {
    return _channel.invokeMethod<void>('performUpdate');
  }

  @override
  Future<bool> canUseNativeUpdater() async {
    try {
      final feedUrl = await _channel.invokeMethod<String>('getFeedURL');
      return feedUrl != null && feedUrl.trim().isNotEmpty;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Native app updater unavailable: ${e.code}');
      return false;
    }
  }
}

/// Service to check for macOS app updates.
///
/// Native Sparkle-based probing is preferred when available. If Sparkle has not
/// been configured yet, the service falls back to GitHub Releases so the
/// current banner UX keeps working during rollout.
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
    AppUpdateGateway? gateway,
    Future<bool> Function(Uri uri)? launcher,
  }) : _httpClient = httpClient ?? http.Client(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _gateway = gateway ?? const MethodChannelAppUpdateGateway(),
       _launcher =
           launcher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  static final instance = AppUpdateService._();

  @visibleForTesting
  factory AppUpdateService.test({
    http.Client? httpClient,
    Future<PackageInfo> Function()? packageInfoLoader,
    AppUpdateGateway? gateway,
    Future<bool> Function(Uri uri)? launcher,
  }) {
    return AppUpdateService._(
      httpClient: httpClient,
      packageInfoLoader: packageInfoLoader,
      gateway: gateway,
      launcher: launcher,
    );
  }

  final http.Client _httpClient;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final AppUpdateGateway _gateway;
  final Future<bool> Function(Uri uri) _launcher;

  AppUpdateInfo? _cachedUpdate;

  /// Returns cached update info (if any), without making a network request.
  AppUpdateInfo? get cachedUpdate => _cachedUpdate;

  /// Whether the user has dismissed the banner for the current latest version.
  bool _isDismissed = false;
  bool get isDismissedByUser => _isDismissed;

  /// Check for a newer macOS release.
  ///
  /// Returns [AppUpdateInfo] if a newer version is available, null otherwise.
  /// Respects a minimum check interval to avoid excessive requests.
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (defaultTargetPlatform != TargetPlatform.macOS || kIsWeb) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (elapsed < _checkInterval.inMilliseconds && _cachedUpdate != null) {
        return _cachedUpdate;
      }
    }

    try {
      final packageInfo = await _packageInfoLoader();
      final currentVersion = packageInfo.version;

      final nativeUpdate = await _probeNativeUpdate(currentVersion);
      if (nativeUpdate != null) {
        await prefs.setInt(
          _lastCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        _cachedUpdate = nativeUpdate;
        _isDismissed =
            prefs.getString(_dismissedVersionKey) == nativeUpdate.latestVersion;
        return nativeUpdate;
      }

      final canUseNativeUpdater = await _gateway.canUseNativeUpdater();
      final fallbackUpdate = await _fetchGitHubReleaseUpdate(
        currentVersion,
        installMode: canUseNativeUpdater
            ? AppUpdateInstallMode.nativeUpdater
            : AppUpdateInstallMode.externalDownload,
      );
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      _cachedUpdate = fallbackUpdate;
      _isDismissed =
          fallbackUpdate != null &&
          prefs.getString(_dismissedVersionKey) == fallbackUpdate.latestVersion;
      return fallbackUpdate;
    } catch (e) {
      debugPrint('App update check failed: $e');
      return _cachedUpdate;
    }
  }

  Future<void> performUpdate(AppUpdateInfo update) async {
    if (update.installMode == AppUpdateInstallMode.nativeUpdater) {
      try {
        await _gateway.performUpdate();
        return;
      } catch (e) {
        debugPrint('Native app update failed, falling back to browser: $e');
      }
    }

    final uri = Uri.parse(update.downloadUrl);
    await _launcher(uri);
  }

  /// Mark the current latest version as dismissed by the user.
  Future<void> dismissUpdate() async {
    _isDismissed = true;
    if (_cachedUpdate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, _cachedUpdate!.latestVersion);
    }
  }

  Future<AppUpdateInfo?> _probeNativeUpdate(String currentVersion) async {
    try {
      final result = await _gateway.probeForUpdate();
      if (result == null) return null;

      final latestVersion = result['latestVersion'] as String?;
      if (latestVersion == null || !_isNewer(latestVersion, currentVersion)) {
        return null;
      }

      return AppUpdateInfo(
        latestVersion: latestVersion,
        currentVersion: result['currentVersion'] as String? ?? currentVersion,
        downloadUrl:
            result['downloadUrl'] as String? ??
            result['releaseUrl'] as String? ??
            '',
        releaseUrl:
            result['releaseUrl'] as String? ??
            result['downloadUrl'] as String? ??
            '',
        installMode: AppUpdateInstallMode.nativeUpdater,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Native app update probe unavailable: ${e.code}');
      return null;
    }
  }

  Future<AppUpdateInfo?> _fetchGitHubReleaseUpdate(
    String currentVersion, {
    required AppUpdateInstallMode installMode,
  }) async {
    final release = await _fetchLatestMacOSRelease();
    if (release == null || !_isNewer(release.version, currentVersion)) {
      return null;
    }

    return AppUpdateInfo(
      latestVersion: release.version,
      currentVersion: currentVersion,
      downloadUrl: release.downloadUrl,
      releaseUrl: release.releaseUrl,
      installMode: installMode,
    );
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

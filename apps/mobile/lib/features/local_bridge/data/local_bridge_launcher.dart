import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../utils/platform_helper.dart';
import 'local_bridge_client.dart';

/// Whether the Bridge LaunchAgent is registered with the system.
enum LauncherRegistration {
  /// This build or OS cannot start the Bridge from the app.
  unavailable,
  notRegistered,
  enabled,

  /// The user turned the item off in System Settings > Login Items.
  requiresApproval,
  unknown,
}

/// A macOS permission the Bridge run by the app depends on.
enum BridgePermission { loginItem, fullDiskAccess, screenCapture, localNetwork }

/// What macOS currently grants the Bridge; null where it could not be told.
class LauncherPermissions {
  const LauncherPermissions({this.fullDiskAccess, this.screenCapture});

  static LauncherPermissions? fromJson(Object? json) => json is Map
      ? LauncherPermissions(
          fullDiskAccess: json['fullDiskAccess'] is bool
              ? json['fullDiskAccess'] as bool
              : null,
          screenCapture: json['screenCapture'] is bool
              ? json['screenCapture'] as bool
              : null,
        )
      : null;

  final bool? fullDiskAccess;
  final bool? screenCapture;

  @override
  bool operator ==(Object other) =>
      other is LauncherPermissions &&
      other.fullDiskAccess == fullDiskAccess &&
      other.screenCapture == screenCapture;

  @override
  int get hashCode => Object.hash(fullDiskAccess, screenCapture);
}

class LauncherResult {
  const LauncherResult({
    required this.ok,
    required this.registration,
    this.error,
    this.permissions,
  });

  final bool ok;
  final LauncherRegistration registration;
  final String? error;
  final LauncherPermissions? permissions;
}

/// Why the launcher could not start the Bridge.
enum LauncherProblem {
  nodeMissing,
  nodeTooOld,
  portInUse,

  /// npm could not download or install the Bridge.
  installFailed,
  execFailed,
}

/// What the launcher last reported in `~/.ccpocket/launcher-status.json`.
class LauncherStatus {
  const LauncherStatus({
    required this.state,
    required this.updatedAt,
    this.nodeVersion,
    this.port,
    this.safeMode = false,
  });

  factory LauncherStatus.fromJson(Map<String, Object?> json) => LauncherStatus(
    state: json['state'] is String ? json['state']! as String : '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      json['updatedAt'] is num ? (json['updatedAt']! as num).toInt() : 0,
    ),
    nodeVersion: json['nodeVersion'] is String
        ? json['nodeVersion']! as String
        : null,
    port: json['port'] is num ? (json['port']! as num).toInt() : null,
    safeMode: json['safeMode'] == true,
  );

  final String state;
  final DateTime updatedAt;
  final String? nodeVersion;
  final int? port;
  final bool safeMode;

  LauncherProblem? get problem => switch (state) {
    'node_missing' => LauncherProblem.nodeMissing,
    'node_too_old' => LauncherProblem.nodeTooOld,
    'port_in_use' => LauncherProblem.portInUse,
    'install_failed' => LauncherProblem.installFailed,
    'exec_failed' => LauncherProblem.execFailed,
    _ => null,
  };
}

/// Starts and stops the Bridge as a LaunchAgent that outlives the app.
abstract class LocalBridgeLauncher {
  Future<bool> isAvailable();

  /// `register` (start now and at login), `unregister` (stop), `status` or
  /// `requestScreenCapture` (list the app under Screen Recording).
  Future<LauncherResult> run(String action);

  /// Opens the System Settings page where [permission] is granted.
  Future<bool> openSystemSettings(BridgePermission permission);

  Future<LauncherStatus?> readStatus();

  /// Port saved in the Bridge config file, if any.
  Future<int?> configuredPort();
}

/// macOS: the sandboxed app asks the bundled "CC Pocket Bridge" helper app to
/// register the agent. See docs/design/local-bridge-management.md.
class HelperLocalBridgeLauncher implements LocalBridgeLauncher {
  const HelperLocalBridgeLauncher();

  static const _channel = MethodChannel('ccpocket/local_bridge_helper');

  @override
  Future<bool> isAvailable() async {
    if (!isMacOSPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The helper answers one request at a time (a single request file), so a
  /// second request must wait or the first would never be answered.
  static Future<void> _pending = Future.value();

  @override
  Future<LauncherResult> run(String action) {
    final result = _pending.then((_) => _run(action));
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<LauncherResult> _run(String action) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('run', {
        'action': action,
      });
      return LauncherResult(
        ok: result?['ok'] == true,
        registration: switch (result?['status']) {
          'enabled' => LauncherRegistration.enabled,
          'notRegistered' => LauncherRegistration.notRegistered,
          'requiresApproval' => LauncherRegistration.requiresApproval,
          'unavailable' => LauncherRegistration.unavailable,
          _ => LauncherRegistration.unknown,
        },
        error: result?['error'] is String ? result!['error']! as String : null,
        permissions: LauncherPermissions.fromJson(result?['permissions']),
      );
    } on PlatformException catch (err) {
      return LauncherResult(
        ok: false,
        registration: LauncherRegistration.unknown,
        error: err.message,
      );
    } on MissingPluginException {
      return const LauncherResult(
        ok: false,
        registration: LauncherRegistration.unavailable,
      );
    }
  }

  @override
  Future<bool> openSystemSettings(BridgePermission permission) async {
    try {
      return await _channel.invokeMethod<bool>('openSettings', {
            'pane': permission.name,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, Object?>?> _readJson(String name) async {
    try {
      final file = File('${realHomeDirectory()}/.ccpocket/$name');
      final json = jsonDecode(await file.readAsString());
      return json is Map ? json.cast<String, Object?>() : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<LauncherStatus?> readStatus() async {
    final json = await _readJson('launcher-status.json');
    return json == null ? null : LauncherStatus.fromJson(json);
  }

  @override
  Future<int?> configuredPort() async {
    final settings = (await _readJson('bridge-config.json'))?['settings'];
    final port = settings is Map ? settings['port'] : null;
    return port is int ? port : null;
  }
}

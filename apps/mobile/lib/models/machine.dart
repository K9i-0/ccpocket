import 'package:freezed_annotation/freezed_annotation.dart';

part 'machine.freezed.dart';
part 'machine.g.dart';

/// Status of a machine's Bridge Server
enum MachineStatus {
  /// Not checked yet
  unknown,

  /// Health check passed (Bridge Server running)
  online,

  /// Health check failed (Bridge Server not running)
  offline,

  /// Network unreachable or connection refused
  unreachable,
}

/// SSH authentication type
enum SshAuthType {
  /// Password authentication
  password,

  /// Private key authentication
  privateKey,
}

/// Bridge Server version information from /version endpoint
@freezed
abstract class BridgeVersionInfo with _$BridgeVersionInfo {
  const BridgeVersionInfo._();

  const factory BridgeVersionInfo({
    required String version,
    String? nodeVersion,
    String? platform,
    String? arch,
    String? gitCommit,
    String? gitBranch,
  }) = _BridgeVersionInfo;

  factory BridgeVersionInfo.fromJson(Map<String, dynamic> json) =>
      _$BridgeVersionInfoFromJson(json);

  /// Compare versions (simple semver comparison)
  /// Returns: negative if this is older, 0 if equal, positive if this is newer
  int compareTo(String otherVersion) {
    final parts1 = version.split('.').map(int.tryParse).toList();
    final parts2 = otherVersion.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? (parts1[i] ?? 0) : 0;
      final p2 = i < parts2.length ? (parts2[i] ?? 0) : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  /// Check if update is needed (this version is older than expected)
  bool needsUpdate(String expectedVersion) => compareTo(expectedVersion) < 0;
}

/// Unified machine model combining saved machines and recent connections.
///
/// Key features:
/// - name is optional (defaults to host:port display)
/// - lastConnected for recency sorting
/// - isFavorite for pinning important machines
/// - host:port is the unique key for deduplication
@freezed
abstract class Machine with _$Machine {
  const Machine._();

  const factory Machine({
    /// Unique identifier (UUID)
    required String id,

    /// User-friendly display name (optional - shows host:port if null)
    String? name,

    /// IP address or hostname (typically Tailscale IP like 100.64.x.x)
    required String host,

    /// Bridge Server port
    @Default(8765) int port,

    /// Whether API key is stored in secure storage
    @Default(false) bool hasApiKey,

    /// Last successful connection time
    DateTime? lastConnected,

    /// Whether this machine is pinned/favorited (shows at top)
    @Default(false) bool isFavorite,

    // ---- SSH Configuration ----

    /// Whether SSH remote startup is enabled
    @Default(false) bool sshEnabled,

    /// SSH username
    String? sshUsername,

    /// SSH port
    @Default(22) int sshPort,

    /// SSH authentication type
    @Default(SshAuthType.password) SshAuthType sshAuthType,

    /// Whether SSH credentials are saved (password or private key in secure storage)
    @Default(false) bool hasCredentials,
  }) = _Machine;

  factory Machine.fromJson(Map<String, dynamic> json) =>
      _$MachineFromJson(json);

  /// Display name (name if set, otherwise host:port)
  String get displayName => name ?? '$host:$port';

  /// WebSocket URL for this machine
  String get wsUrl => 'ws://$host:$port';

  /// HTTP base URL for health checks
  String get httpUrl => 'http://$host:$port';

  /// Unique key for deduplication (host:port)
  String get uniqueKey => '$host:$port';

  /// Whether this machine can be started remotely (SSH configured)
  bool get canStartRemotely => sshEnabled && sshUsername != null;
}

/// Runtime state wrapper for Machine with status and version information.
/// This is used in the UI layer to track connection status without modifying the persisted model.
@freezed
abstract class MachineWithStatus with _$MachineWithStatus {
  const MachineWithStatus._();

  const factory MachineWithStatus({
    required Machine machine,
    @Default(MachineStatus.unknown) MachineStatus status,
    DateTime? lastChecked,
    String? lastError,

    /// Bridge version info (fetched during health check)
    BridgeVersionInfo? versionInfo,
  }) = _MachineWithStatus;

  /// Check if the machine needs a Bridge update
  bool needsUpdate(String expectedVersion) {
    if (versionInfo == null) return false;
    return versionInfo!.needsUpdate(expectedVersion);
  }
}

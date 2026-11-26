import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/local_bridge_client.dart';
import '../data/local_bridge_launcher.dart';
import '../data/local_bridge_models.dart';

part 'local_bridge_state.freezed.dart';

enum LocalBridgePhase {
  loading,

  /// Nothing answers on the port.
  notRunning,

  /// A Bridge is running but this app cannot read its pairing secret.
  secretUnavailable,

  /// The running Bridge is too old to be managed.
  updateRequired,
  ready,
  error,
}

/// What the screen is waiting for; at most one at a time.
enum LocalBridgeBusy {
  none,
  saving,
  restarting,
  rotatingKey,
  starting,
  stopping,
}

@freezed
abstract class LocalBridgeState with _$LocalBridgeState {
  const LocalBridgeState._();

  const factory LocalBridgeState({
    required int port,
    @Default(LocalBridgePhase.loading) LocalBridgePhase phase,
    LocalBridgeStatus? status,
    LocalBridgeConfig? config,
    LocalBridgePairing? pairing,
    LocalBridgeTools? tools,
    @Default(false) bool toolsLoading,

    /// The running Bridge has no `/tools` endpoint.
    @Default(false) bool toolsUnsupported,

    /// Unsaved changes: setting key -> new value; null removes the setting
    /// from the config file (back to the default).
    @Default(<String, Object?>{}) Map<String, Object?> edits,

    /// Setting key -> problem reported by the Bridge on save.
    @Default(<String, String>{}) Map<String, String> settingErrors,
    @Default(LocalBridgeBusy.none) LocalBridgeBusy busy,

    /// Last failed action, shown once by the screen.
    LocalBridgeFailure? actionFailure,

    /// The API key was replaced and applies after a restart.
    @Default(false) bool apiKeyRotated,
    String? errorDetail,

    /// Whether the app's LaunchAgent runs the Bridge.
    @Default(LauncherRegistration.unavailable)
    LauncherRegistration launcherRegistration,

    /// Port the launcher's Bridge listens on (the saved port, else 8765).
    /// Starting from the app only applies while that port is shown.
    @Default(8765) int launcherPort,

    /// What the launcher last reported (missing Node, port in use, ...).
    LauncherStatus? launcherStatus,

    /// macOS permissions of the Bridge the app runs, as last checked.
    LauncherPermissions? launcherPermissions,

    /// Starting from the app did not bring the Bridge up in time.
    @Default(false) bool startFailed,
  }) = _LocalBridgeState;

  /// The app can start a Bridge on this machine.
  bool get canStart =>
      launcherRegistration != LauncherRegistration.unavailable &&
      port == launcherPort;

  /// The Bridge is run by the app's LaunchAgent (so the app can stop it).
  bool get managedByApp => launcherRegistration == LauncherRegistration.enabled;

  /// A launcher problem that is still current: only meaningful while the
  /// agent is registered and no Bridge answers.
  LauncherProblem? get launcherProblem =>
      managedByApp && phase == LocalBridgePhase.notRunning
      ? launcherStatus?.problem
      : null;

  /// The macOS permissions apply: the Bridge is (or was) run by the app's
  /// agent. A Bridge started another way runs under its own identity.
  bool get showsPermissions =>
      launcherRegistration == LauncherRegistration.enabled ||
      launcherRegistration == LauncherRegistration.requiresApproval;

  /// A permission worth pointing out is missing.
  bool get permissionsNeedAttention =>
      launcherRegistration == LauncherRegistration.requiresApproval ||
      (managedByApp && launcherPermissions?.fullDiskAccess == false);

  bool get hasEdits => edits.isNotEmpty;

  bool get restartRequired =>
      apiKeyRotated ||
      (config?.restartRequired ?? status?.restartRequired ?? false);

  /// Value to show for [setting]: the unsaved edit if any.
  Object? displayValue(LocalBridgeSetting setting) =>
      edits.containsKey(setting.key)
      ? edits[setting.key]
      : setting.effectiveValue;
}

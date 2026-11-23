import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/local_bridge_client.dart';
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
enum LocalBridgeBusy { none, saving, restarting, rotatingKey }

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
  }) = _LocalBridgeState;

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

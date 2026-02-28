import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

/// Keys for FCM status messages (resolved to localized strings in the UI).
enum FcmStatusKey {
  unavailable,
  bridgeNotInitialized,
  tokenFailed,
  enabled,
  enabledPending,
  disabled,
  disabledPending,
}

/// Application-wide user settings.
@freezed
abstract class SettingsState with _$SettingsState {
  const SettingsState._();

  const factory SettingsState({
    /// Theme mode: system, light, or dark.
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// App display locale ID (e.g. 'ja', 'en').
    /// Empty string means follow the device default.
    @Default('') String appLocaleId,

    /// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
    /// Empty string means use device default.
    @Default('ja-JP') String speechLocaleId,

    /// Set of Machine IDs that have push notifications enabled.
    @Default({}) Set<String> fcmEnabledMachines,

    /// Set of Machine IDs that have privacy mode enabled for push notifications.
    @Default({}) Set<String> fcmPrivacyMachines,

    /// Currently connected Machine ID (null when disconnected).
    String? activeMachineId,

    /// Whether Firebase Messaging is available in this runtime.
    @Default(false) bool fcmAvailable,

    /// True while token registration/unregistration is being synchronized.
    @Default(false) bool fcmSyncInProgress,

    /// Last push sync status key (resolved to localized string in UI).
    FcmStatusKey? fcmStatusKey,

    /// Shorebird update track ('stable' or 'staging').
    @Default('stable') String shorebirdTrack,

    /// Indent size for list formatting (1-4 spaces).
    @Default(2) int indentSize,
  }) = _SettingsState;

  /// Whether push notifications are enabled for the currently connected machine.
  bool get fcmEnabled =>
      activeMachineId != null && fcmEnabledMachines.contains(activeMachineId);

  /// Whether privacy mode is enabled for the currently connected machine.
  bool get fcmPrivacy =>
      activeMachineId != null && fcmPrivacyMachines.contains(activeMachineId);
}

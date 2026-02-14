import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

/// Application-wide user settings.
@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    /// Theme mode: system, light, or dark.
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
    /// Empty string means use device default.
    @Default('ja-JP') String speechLocaleId,

    /// Whether remote push notifications are enabled by the user.
    @Default(false) bool fcmEnabled,

    /// Whether Firebase Messaging is available in this runtime.
    @Default(false) bool fcmAvailable,

    /// True while token registration/unregistration is being synchronized.
    @Default(false) bool fcmSyncInProgress,

    /// Last push sync status shown in Settings screen.
    String? fcmStatusMessage,
  }) = _SettingsState;
}

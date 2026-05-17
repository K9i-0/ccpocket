import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/app_icon.dart';
import '../../../models/code_font_family.dart';
import '../../../models/git_diff_interaction_mode.dart';
import '../../../models/new_session_tab.dart';
import '../../../models/terminal_app.dart';

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

enum UsageDisplayMode { remaining, used }

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
    @Default('') String speechLocaleId,

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

    /// App-specific multiplier applied on top of the system text scale.
    @Default(1.0) double textScale,

    /// Font size used only for code-oriented surfaces.
    @Default(12.0) double codeFontSize,

    /// Font family used only for code-oriented surfaces.
    @Default(CodeFontFamily.jetBrainsMono) CodeFontFamily codeFontFamily,

    /// Whether to hide the voice input button in the chat input bar.
    @Default(false) bool hideVoiceInput,

    /// How the Git diff screen maps horizontal gestures to actions.
    @Default(GitDiffInteractionMode.quickActions)
    GitDiffInteractionMode gitDiffInteractionMode,

    /// Whether Git diff focus mode should rotate mobile layouts to landscape.
    @Default(false) bool gitDiffFocusAutoLandscape,

    /// Whether to show a subtle badge when the current branch can push/pull.
    @Default(false) bool showRemoteGitStatusBadge,

    /// Whether to show the connected Bridge name in the session list.
    @Default(true) bool showBridgeNameInSessionList,

    /// Selected app icon preference for monthly Supporter perks.
    @Default(AppIconVariant.defaultIcon) AppIconVariant selectedAppIcon,

    /// Whether app icon switching is supported on the current platform.
    @Default(false) bool appIconSupported,

    /// External terminal app configuration (preset or custom URL template).
    @Default(TerminalAppConfig.empty) TerminalAppConfig terminalApp,

    /// Visible tabs (and their order) in the new session sheet.
    @Default(defaultNewSessionTabs) List<NewSessionTab> newSessionTabs,

    /// Whether Codex usage limits are shown as remaining quota or used quota.
    @Default(UsageDisplayMode.remaining) UsageDisplayMode usageDisplayMode,

    /// Whether new Codex sessions should be automatically named after the first turn.
    @Default(true) bool autoRenameCodexSessions,

    /// Whether new Claude sessions should be automatically named after the first turn.
    @Default(false) bool autoRenameClaudeSessions,
  }) = _SettingsState;

  /// Whether push notifications are enabled for the currently connected machine.
  bool get fcmEnabled =>
      activeMachineId != null && fcmEnabledMachines.contains(activeMachineId);

  /// Whether privacy mode is enabled for the currently connected machine.
  bool get fcmPrivacy =>
      activeMachineId != null && fcmPrivacyMachines.contains(activeMachineId);
}

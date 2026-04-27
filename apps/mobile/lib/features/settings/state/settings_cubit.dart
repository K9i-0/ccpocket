import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger.dart';
import '../../../models/app_icon.dart';
import '../../../models/messages.dart';
import '../../../models/new_session_tab.dart';
import '../../../models/terminal_app.dart';
import '../../../services/app_icon_service.dart';
import '../../../services/bridge_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/machine_manager_service.dart';
import '../../../services/revenuecat_service.dart';
import 'settings_state.dart';

/// Manages user settings with SharedPreferences persistence.
class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;
  final BridgeService? _bridge;
  final MachineManagerService? _machineManager;
  final FcmService _fcmService;
  final RevenueCatService? _revenueCat;
  final AppIconService _appIconService;
  StreamSubscription<BridgeConnectionState>? _bridgeSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeToken;
  VoidCallback? _supporterListener;

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyAppLocale = 'settings_app_locale';
  static const _keySpeechLocale = 'settings_speech_locale';
  static const _keyFcmMachines = 'settings_fcm_machines';
  static const _keyFcmPrivacyMachines = 'settings_fcm_privacy_machines';

  /// SharedPreferences key for the Shorebird update track.
  /// Also read directly from SharedPreferences in main.dart at startup.
  static const keyShorebirdTrack = 'settings_shorebird_track';
  static const _keyHideVoiceInput = 'settings_hide_voice_input';
  static const _keySelectedAppIcon = 'settings_selected_app_icon';
  static const _keyTerminalApp = 'settings_terminal_app';
  static const _keyNewSessionTabs = 'settings_new_session_tabs';
  static const _keyUsageDisplayMode = 'settings_usage_display_mode';
  static const _keyTextScale = 'settings_text_scale';
  // Legacy key for migration
  static const _keyIndentSize = 'settings_indent_size';
  // Legacy key for migration
  static const _keyFcmEnabled = 'settings_fcm_enabled';

  SettingsCubit(
    this._prefs, {
    BridgeService? bridgeService,
    MachineManagerService? machineManager,
    FcmService? fcmService,
    RevenueCatService? revenueCatService,
    AppIconService? appIconService,
  }) : _bridge = bridgeService,
       _machineManager = machineManager,
       _fcmService = fcmService ?? FcmService(),
       _revenueCat = revenueCatService,
       _appIconService = appIconService ?? AppIconService(),
       super(
         _load(_prefs).copyWith(
           appIconSupported:
               (appIconService ?? AppIconService()).isSupportedPlatform,
         ),
       ) {
    final bridge = _bridge;
    if (bridge != null) {
      _bridgeSub = bridge.connectionStatus.listen((status) {
        if (status == BridgeConnectionState.connected) {
          _updateActiveMachine();
          if (state.fcmEnabled) {
            unawaited(_syncPushRegistration());
          }
        } else if (status == BridgeConnectionState.disconnected) {
          emit(state.copyWith(activeMachineId: null, fcmStatusKey: null));
        }
      });
      // Resolve active machine if already connected at init time
      if (bridge.isConnected) {
        _updateActiveMachine();
      }
    }
    final revenueCat = _revenueCat;
    if (revenueCat != null) {
      _supporterListener = _handleSupporterStateChanged;
      revenueCat.supporterState.addListener(_supporterListener!);
    }
    if (state.fcmEnabledMachines.isNotEmpty) {
      unawaited(_initializePush());
    }
    unawaited(_initializeAppIconSupport());
    unawaited(_syncAppIcon(force: true));
  }

  /// Resolve the currently connected Machine ID from the bridge URL.
  void _updateActiveMachine() {
    final bridge = _bridge;
    final manager = _machineManager;
    if (bridge == null || manager == null) return;

    final url = bridge.lastUrl;
    if (url == null) return;

    final uri = Uri.tryParse(
      url.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://'),
    );
    if (uri == null) return;

    final machine = manager.findByHostPort(
      uri.host,
      uri.hasPort ? uri.port : 8765,
    );
    if (machine != null) {
      emit(state.copyWith(activeMachineId: machine.id));
    }
  }

  static SettingsState _load(SharedPreferences prefs) {
    final themeModeIndex = prefs.getInt(_keyThemeMode);
    final appLocale = prefs.getString(_keyAppLocale) ?? '';
    final speechLocale = prefs.getString(_keySpeechLocale);

    // Load per-machine FCM set
    var fcmMachines = <String>{};
    final machinesJson = prefs.getString(_keyFcmMachines);
    if (machinesJson != null) {
      final list = jsonDecode(machinesJson) as List;
      fcmMachines = list.cast<String>().toSet();
    } else {
      // Migrate from legacy global fcmEnabled: read machine IDs directly
      // from SharedPreferences (MachineManagerService may not be initialized yet)
      final legacyEnabled = prefs.getBool(_keyFcmEnabled) ?? false;
      if (legacyEnabled) {
        final machinesRaw = prefs.getString('machines_v2');
        if (machinesRaw != null) {
          try {
            final list = jsonDecode(machinesRaw) as List;
            fcmMachines = list
                .cast<Map<String, dynamic>>()
                .map((m) => m['id'] as String)
                .toSet();
          } catch (_) {
            // Ignore parse errors during migration
          }
        }
        // Persist migrated data and remove legacy key
        prefs.setString(_keyFcmMachines, jsonEncode(fcmMachines.toList()));
        prefs.remove(_keyFcmEnabled);
      }
    }

    // Load per-machine privacy mode set
    var fcmPrivacyMachines = <String>{};
    final privacyJson = prefs.getString(_keyFcmPrivacyMachines);
    if (privacyJson != null) {
      final list = jsonDecode(privacyJson) as List;
      fcmPrivacyMachines = list.cast<String>().toSet();
    }

    final shorebirdTrack = prefs.getString(keyShorebirdTrack) ?? 'stable';
    final indentSize = prefs.getInt(_keyIndentSize) ?? 2;
    final textScale = (prefs.getDouble(_keyTextScale) ?? textScaleDefault)
        .clamp(textScaleMin, textScaleMax);
    final hideVoiceInput = prefs.getBool(_keyHideVoiceInput) ?? false;
    final selectedAppIcon = appIconVariantFromId(
      prefs.getString(_keySelectedAppIcon),
    );
    final usageDisplayMode = _usageDisplayModeFromRaw(
      prefs.getString(_keyUsageDisplayMode),
    );

    // Load terminal app config
    var terminalApp = TerminalAppConfig.empty;
    final terminalJson = prefs.getString(_keyTerminalApp);
    if (terminalJson != null) {
      try {
        final map = jsonDecode(terminalJson) as Map<String, dynamic>;
        terminalApp = TerminalAppConfig.fromJson(map);
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Load new session tabs
    var newSessionTabs = defaultNewSessionTabs;
    final tabsJson = prefs.getString(_keyNewSessionTabs);
    if (tabsJson != null) {
      newSessionTabs = tabsFromJson(tabsJson) ?? defaultNewSessionTabs;
    }

    return SettingsState(
      themeMode:
          (themeModeIndex != null &&
              themeModeIndex >= 0 &&
              themeModeIndex < ThemeMode.values.length)
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      appLocaleId: appLocale,
      speechLocaleId: speechLocale ?? 'ja-JP',
      fcmEnabledMachines: fcmMachines,
      fcmPrivacyMachines: fcmPrivacyMachines,
      shorebirdTrack: shorebirdTrack,
      indentSize: indentSize.clamp(1, 4),
      textScale: textScale,
      hideVoiceInput: hideVoiceInput,
      selectedAppIcon: selectedAppIcon,
      terminalApp: terminalApp,
      newSessionTabs: newSessionTabs,
      usageDisplayMode: usageDisplayMode,
    );
  }

  static UsageDisplayMode _usageDisplayModeFromRaw(String? raw) {
    return switch (raw) {
      'used' => UsageDisplayMode.used,
      _ => UsageDisplayMode.remaining,
    };
  }

  Future<void> _initializeAppIconSupport() async {
    final supported = await _appIconService.isSupported();
    if (isClosed) return;
    if (supported == state.appIconSupported) return;
    emit(state.copyWith(appIconSupported: supported));
  }

  Future<void> _initializePush() async {
    final bridge = _bridge;
    if (bridge == null) return;
    final available = await _fcmService.init();
    emit(
      state.copyWith(
        fcmAvailable: available,
        fcmStatusKey: available ? null : FcmStatusKey.unavailable,
      ),
    );
    if (!available) return;

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcmService.onTokenRefresh.listen((token) {
      final previousToken = _fcmService.cacheToken(token);
      _activeToken = token;
      if (state.fcmEnabled && previousToken != null && previousToken != token) {
        bridge.unregisterPushToken(previousToken);
      }
      if (state.fcmEnabled) {
        unawaited(_syncPushRegistration());
      }
    });

    if (state.fcmEnabled) {
      await _syncPushRegistration();
    }
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt(_keyThemeMode, mode.index);
    emit(state.copyWith(themeMode: mode));
  }

  void setAppLocaleId(String localeId) {
    _prefs.setString(_keyAppLocale, localeId);
    emit(state.copyWith(appLocaleId: localeId));
    // Auto-sync push notification locale when app language changes
    if (state.fcmEnabled) {
      unawaited(_syncPushRegistration());
    }
  }

  /// Re-register push token with the current locale.
  /// Called from the "Update notification language" button in settings.
  Future<void> syncPushLocale() async {
    if (!state.fcmEnabled) return;
    emit(state.copyWith(fcmSyncInProgress: true, fcmStatusKey: null));
    await _syncPushRegistration();
  }

  void setIndentSize(int size) {
    final clamped = size.clamp(1, 4);
    _prefs.setInt(_keyIndentSize, clamped);
    emit(state.copyWith(indentSize: clamped));
  }

  /// Updates the global text scale used to render text throughout the app.
  /// Values outside the supported range are clamped before being persisted.
  void setTextScale(double scale) {
    final clamped = scale.clamp(textScaleMin, textScaleMax);
    _prefs.setDouble(_keyTextScale, clamped);
    emit(state.copyWith(textScale: clamped));
  }

  void setShorebirdTrack(String track) {
    _prefs.setString(keyShorebirdTrack, track);
    emit(state.copyWith(shorebirdTrack: track));
  }

  void setHideVoiceInput(bool hide) {
    _prefs.setBool(_keyHideVoiceInput, hide);
    emit(state.copyWith(hideVoiceInput: hide));
  }

  Future<void> setSelectedAppIcon(AppIconVariant icon) async {
    await _prefs.setString(_keySelectedAppIcon, icon.id);
    emit(state.copyWith(selectedAppIcon: icon));
    await _syncAppIcon(force: true, allowResetToDefault: true);
  }

  void setSpeechLocaleId(String localeId) {
    _prefs.setString(_keySpeechLocale, localeId);
    emit(state.copyWith(speechLocaleId: localeId));
  }

  void setTerminalApp(TerminalAppConfig config) {
    _prefs.setString(_keyTerminalApp, jsonEncode(config.toJson()));
    emit(state.copyWith(terminalApp: config));
  }

  void clearTerminalApp() {
    _prefs.remove(_keyTerminalApp);
    emit(state.copyWith(terminalApp: TerminalAppConfig.empty));
  }

  void setNewSessionTabs(List<NewSessionTab> tabs) {
    _prefs.setString(_keyNewSessionTabs, tabsToJson(tabs));
    emit(state.copyWith(newSessionTabs: tabs));
  }

  void setUsageDisplayMode(UsageDisplayMode mode) {
    _prefs.setString(_keyUsageDisplayMode, mode.name);
    emit(state.copyWith(usageDisplayMode: mode));
  }

  void toggleUsageDisplayMode() {
    final next = state.usageDisplayMode == UsageDisplayMode.remaining
        ? UsageDisplayMode.used
        : UsageDisplayMode.remaining;
    setUsageDisplayMode(next);
  }

  Future<void> toggleFcm(bool enabled) async {
    final machineId = state.activeMachineId;
    if (machineId == null) return;

    final updated = Set<String>.from(state.fcmEnabledMachines);
    if (enabled) {
      updated.add(machineId);
    } else {
      updated.remove(machineId);
    }
    await _prefs.setString(_keyFcmMachines, jsonEncode(updated.toList()));
    emit(
      state.copyWith(
        fcmEnabledMachines: updated,
        fcmSyncInProgress: true,
        fcmStatusKey: null,
      ),
    );

    if (!enabled) {
      await _syncPushUnregister();
      return;
    }

    var available = state.fcmAvailable;
    if (!available) {
      available = await _fcmService.init();
      emit(state.copyWith(fcmAvailable: available));
    }
    if (!available) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusKey: FcmStatusKey.unavailable,
        ),
      );
      return;
    }
    await _syncPushRegistration();
  }

  Future<void> toggleFcmPrivacy(bool enabled) async {
    final machineId = state.activeMachineId;
    if (machineId == null) return;

    final updated = Set<String>.from(state.fcmPrivacyMachines);
    if (enabled) {
      updated.add(machineId);
    } else {
      updated.remove(machineId);
    }
    await _prefs.setString(
      _keyFcmPrivacyMachines,
      jsonEncode(updated.toList()),
    );
    emit(state.copyWith(fcmPrivacyMachines: updated, fcmSyncInProgress: true));

    // Re-register to update privacy mode on the bridge
    if (state.fcmEnabled) {
      await _syncPushRegistration();
    } else {
      emit(state.copyWith(fcmSyncInProgress: false));
    }
  }

  /// Resolve the push notification locale from app settings or system locale.
  /// Returns a BCP-47 language subtag (e.g. "en", "ja", "zh").
  String _resolvePushLocale() {
    // Use explicit app locale if set
    final appLocale = state.appLocaleId;
    if (appLocale.isNotEmpty) {
      final lang = appLocale.split(RegExp(r'[-_]')).first.toLowerCase();
      if (lang == 'ja') return 'ja';
      if (lang == 'zh') return 'zh';
      return 'en';
    }
    // Fall back to system locale
    if (!kIsWeb) {
      try {
        final systemLocale = Platform.localeName;
        if (systemLocale.startsWith('ja')) return 'ja';
        if (systemLocale.startsWith('zh')) return 'zh';
      } catch (_) {
        // Platform.localeName may throw on some platforms
      }
    }
    return 'en';
  }

  Future<void> _syncPushRegistration() async {
    final bridge = _bridge;
    if (bridge == null) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusKey: FcmStatusKey.bridgeNotInitialized,
        ),
      );
      return;
    }

    final token = await _fcmService.getToken();
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusKey: FcmStatusKey.tokenFailed,
        ),
      );
      return;
    }

    _activeToken = token;
    bridge.registerPushToken(
      token: token,
      platform: _fcmService.platform,
      locale: _resolvePushLocale(),
      privacyMode: state.fcmPrivacy ? true : null,
    );
    final statusKey = bridge.isConnected
        ? FcmStatusKey.enabled
        : FcmStatusKey.enabledPending;
    emit(state.copyWith(fcmSyncInProgress: false, fcmStatusKey: statusKey));
  }

  Future<void> _syncPushUnregister() async {
    final bridge = _bridge;
    if (bridge == null) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusKey: FcmStatusKey.disabled,
        ),
      );
      return;
    }

    final token = _activeToken ?? await _fcmService.getToken();
    if (token != null && token.isNotEmpty) {
      bridge.unregisterPushToken(token);
    }
    _activeToken = null;
    final statusKey = bridge.isConnected
        ? FcmStatusKey.disabled
        : FcmStatusKey.disabledPending;
    emit(state.copyWith(fcmSyncInProgress: false, fcmStatusKey: statusKey));
  }

  void _handleSupporterStateChanged() {
    unawaited(_syncAppIcon());
  }

  Future<void> _syncAppIcon({
    bool force = false,
    bool allowResetToDefault = false,
  }) async {
    try {
      final supporterState = _revenueCat?.supporterState.value;
      if (supporterState != null &&
          (!supporterState.isAvailable || supporterState.isLoading)) {
        return;
      }
      await _appIconService.sync(
        selectedIcon: state.selectedAppIcon,
        isSupporter: supporterState?.isSupporter ?? false,
        force: force,
        allowResetToDefault: allowResetToDefault,
      );
    } catch (error, stackTrace) {
      logger.warning('[settings] failed to sync app icon', error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _bridgeSub?.cancel();
    await _tokenRefreshSub?.cancel();
    final listener = _supporterListener;
    if (listener != null) {
      _revenueCat?.supporterState.removeListener(listener);
    }
    return super.close();
  }
}

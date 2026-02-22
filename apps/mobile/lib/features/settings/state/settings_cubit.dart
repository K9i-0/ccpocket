import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/machine_manager_service.dart';
import 'settings_state.dart';

/// Manages user settings with SharedPreferences persistence.
class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;
  final BridgeService? _bridge;
  final MachineManagerService? _machineManager;
  final FcmService _fcmService;
  StreamSubscription<BridgeConnectionState>? _bridgeSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeToken;

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyAppLocale = 'settings_app_locale';
  static const _keySpeechLocale = 'settings_speech_locale';
  static const _keyFcmMachines = 'settings_fcm_machines';
  // Legacy key for migration
  static const _keyFcmEnabled = 'settings_fcm_enabled';

  SettingsCubit(
    this._prefs, {
    BridgeService? bridgeService,
    MachineManagerService? machineManager,
    FcmService? fcmService,
  }) : _bridge = bridgeService,
       _machineManager = machineManager,
       _fcmService = fcmService ?? FcmService(),
       super(_load(_prefs)) {
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
    unawaited(_initializePush());
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
    );
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

  void setSpeechLocaleId(String localeId) {
    _prefs.setString(_keySpeechLocale, localeId);
    emit(state.copyWith(speechLocaleId: localeId));
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

  /// Resolve the push notification locale from app settings or system locale.
  /// Returns a BCP-47 language subtag (e.g. "en", "ja").
  String _resolvePushLocale() {
    // Use explicit app locale if set
    final appLocale = state.appLocaleId;
    if (appLocale.isNotEmpty) {
      final lang = appLocale.split(RegExp(r'[-_]')).first.toLowerCase();
      if (lang == 'ja') return 'ja';
      return 'en';
    }
    // Fall back to system locale
    if (!kIsWeb) {
      try {
        final systemLocale = Platform.localeName;
        if (systemLocale.startsWith('ja')) return 'ja';
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

  @override
  Future<void> close() async {
    await _bridgeSub?.cancel();
    await _tokenRefreshSub?.cancel();
    return super.close();
  }
}

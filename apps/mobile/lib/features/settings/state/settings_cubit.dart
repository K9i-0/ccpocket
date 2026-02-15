import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../services/fcm_service.dart';
import 'settings_state.dart';

/// Manages user settings with SharedPreferences persistence.
class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;
  final BridgeService? _bridge;
  final FcmService _fcmService;
  StreamSubscription<BridgeConnectionState>? _bridgeSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeToken;

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keySpeechLocale = 'settings_speech_locale';
  static const _keyFcmEnabled = 'settings_fcm_enabled';

  SettingsCubit(
    this._prefs, {
    BridgeService? bridgeService,
    FcmService? fcmService,
  }) : _bridge = bridgeService,
       _fcmService = fcmService ?? FcmService(),
       super(_load(_prefs)) {
    final bridge = _bridge;
    if (bridge != null) {
      _bridgeSub = bridge.connectionStatus.listen((status) {
        if (status == BridgeConnectionState.connected && state.fcmEnabled) {
          unawaited(_syncPushRegistration());
        }
      });
    }
    unawaited(_initializePush());
  }

  static SettingsState _load(SharedPreferences prefs) {
    final themeModeIndex = prefs.getInt(_keyThemeMode);
    final speechLocale = prefs.getString(_keySpeechLocale);
    final fcmEnabled = prefs.getBool(_keyFcmEnabled) ?? false;
    return SettingsState(
      themeMode:
          (themeModeIndex != null &&
              themeModeIndex >= 0 &&
              themeModeIndex < ThemeMode.values.length)
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      speechLocaleId: speechLocale ?? 'ja-JP',
      fcmEnabled: fcmEnabled,
    );
  }

  Future<void> _initializePush() async {
    final bridge = _bridge;
    if (bridge == null) return;
    final available = await _fcmService.init();
    emit(
      state.copyWith(
        fcmAvailable: available,
        fcmStatusMessage: available ? null : 'Firebase 設定後に利用できます',
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

  void setSpeechLocaleId(String localeId) {
    _prefs.setString(_keySpeechLocale, localeId);
    emit(state.copyWith(speechLocaleId: localeId));
  }

  Future<void> toggleFcm(bool enabled) async {
    await _prefs.setBool(_keyFcmEnabled, enabled);
    emit(
      state.copyWith(
        fcmEnabled: enabled,
        fcmSyncInProgress: true,
        fcmStatusMessage: null,
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
          fcmStatusMessage: 'Firebase 設定後に利用できます',
        ),
      );
      return;
    }
    await _syncPushRegistration();
  }

  Future<void> _syncPushRegistration() async {
    final bridge = _bridge;
    if (bridge == null) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusMessage: 'Bridge が未初期化です',
        ),
      );
      return;
    }

    final token = await _fcmService.getToken();
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusMessage: 'FCM token を取得できませんでした',
        ),
      );
      return;
    }

    _activeToken = token;
    bridge.registerPushToken(token: token, platform: _fcmService.platform);
    final syncedMessage = bridge.isConnected
        ? '通知を有効化しました'
        : 'Bridge 再接続後に通知登録します';
    emit(
      state.copyWith(fcmSyncInProgress: false, fcmStatusMessage: syncedMessage),
    );
  }

  Future<void> _syncPushUnregister() async {
    final bridge = _bridge;
    if (bridge == null) {
      emit(
        state.copyWith(
          fcmSyncInProgress: false,
          fcmStatusMessage: '通知を無効化しました',
        ),
      );
      return;
    }

    final token = _activeToken ?? await _fcmService.getToken();
    if (token != null && token.isNotEmpty) {
      bridge.unregisterPushToken(token);
    }
    _activeToken = null;
    final syncedMessage = bridge.isConnected
        ? '通知を無効化しました'
        : 'Bridge 再接続後に通知解除します';
    emit(
      state.copyWith(fcmSyncInProgress: false, fcmStatusMessage: syncedMessage),
    );
  }

  @override
  Future<void> close() async {
    await _bridgeSub?.cancel();
    await _tokenRefreshSub?.cancel();
    return super.close();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

/// Manages user settings with SharedPreferences persistence.
class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keySpeechLocale = 'settings_speech_locale';

  SettingsCubit(this._prefs) : super(_load(_prefs));

  static SettingsState _load(SharedPreferences prefs) {
    final themeModeIndex = prefs.getInt(_keyThemeMode);
    final speechLocale = prefs.getString(_keySpeechLocale);
    return SettingsState(
      themeMode: (themeModeIndex != null &&
              themeModeIndex >= 0 &&
              themeModeIndex < ThemeMode.values.length)
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      speechLocaleId: speechLocale ?? 'ja-JP',
    );
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt(_keyThemeMode, mode.index);
    emit(state.copyWith(themeMode: mode));
  }

  void setSpeechLocaleId(String localeId) {
    _prefs.setString(_keySpeechLocale, localeId);
    emit(state.copyWith(speechLocaleId: localeId));
  }
}

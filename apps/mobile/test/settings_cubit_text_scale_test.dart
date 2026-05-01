import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit text scale', () {
    test('defaults to 100 percent and persists app scale', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.textScale, 1.0);

      cubit.setTextScale(0.9);

      expect(cubit.state.textScale, 0.9);
      expect(prefs.getDouble('settings_text_scale'), 0.9);

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.textScale, 0.9);

      await restored.close();
    });

    test('clamps text scale to the supported compact range', () async {
      SharedPreferences.setMockInitialValues({'settings_text_scale': 0.5});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.textScale, SettingsCubit.minTextScale);

      cubit.setTextScale(1.2);
      expect(cubit.state.textScale, SettingsCubit.maxTextScale);

      cubit.setTextScale(0.5);
      expect(cubit.state.textScale, SettingsCubit.minTextScale);

      await cubit.close();
    });

    test('persists provider-specific auto rename settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.autoRenameCodexSessions, isTrue);
      expect(cubit.state.autoRenameClaudeSessions, isFalse);

      cubit.setAutoRenameCodexSessions(false);
      cubit.setAutoRenameClaudeSessions(true);

      expect(cubit.state.autoRenameCodexSessions, isFalse);
      expect(cubit.state.autoRenameClaudeSessions, isTrue);
      expect(prefs.getBool('autoRenameCodexSessions'), isFalse);
      expect(prefs.getBool('autoRenameClaudeSessions'), isTrue);

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.autoRenameCodexSessions, isFalse);
      expect(restored.state.autoRenameClaudeSessions, isTrue);

      await restored.close();
    });

    test('remote git status badge defaults off and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.showRemoteGitStatusBadge, isFalse);

      cubit.setShowRemoteGitStatusBadge(true);

      expect(cubit.state.showRemoteGitStatusBadge, isTrue);
      expect(prefs.getBool('settings_show_remote_git_status_badge'), isTrue);

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.showRemoteGitStatusBadge, isTrue);

      await restored.close();
    });
  });
}

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/code_font_family.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/theme/code_text_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit text scale', () {
    test('defaults speech recognition locale to device default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.speechLocaleId, isEmpty);

      cubit.setSpeechLocaleId('ja-JP');
      expect(cubit.state.speechLocaleId, 'ja-JP');
      expect(prefs.getString('settings_speech_locale'), 'ja-JP');

      await cubit.close();
    });

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

    test(
      'code font defaults to Codex-sized JetBrains Mono and persists',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cubit = SettingsCubit(prefs);

        expect(cubit.state.codeFontSize, defaultCodeFontSize);
        expect(cubit.state.codeFontFamily, CodeFontFamily.jetBrainsMono);

        cubit.setCodeFontSize(16);
        cubit.setCodeFontFamily(CodeFontFamily.dejaVuSansMono);

        expect(cubit.state.codeFontSize, 16);
        expect(cubit.state.codeFontFamily, CodeFontFamily.dejaVuSansMono);
        expect(prefs.getDouble('settings_code_font_size'), 16);
        expect(
          prefs.getString('settings_code_font_family'),
          CodeFontFamily.dejaVuSansMono.id,
        );

        await cubit.close();

        final restored = SettingsCubit(prefs);
        expect(restored.state.codeFontSize, 16);
        expect(restored.state.codeFontFamily, CodeFontFamily.dejaVuSansMono);

        await restored.close();
      },
    );

    test('clamps code font size to the supported range', () async {
      SharedPreferences.setMockInitialValues({'settings_code_font_size': 4.0});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.codeFontSize, minCodeFontSize);

      cubit.setCodeFontSize(99);
      expect(cubit.state.codeFontSize, maxCodeFontSize);

      cubit.setCodeFontSize(1);
      expect(cubit.state.codeFontSize, minCodeFontSize);

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

    test('extended Codex Efforts default off and persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.showExtendedCodexEfforts, isFalse);

      cubit.setShowExtendedCodexEfforts(true);

      expect(cubit.state.showExtendedCodexEfforts, isTrue);
      expect(prefs.getBool('settings_show_extended_codex_efforts'), isTrue);

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.showExtendedCodexEfforts, isTrue);

      await restored.close();
    });

    test('persists enabled agents through new session tabs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(
        enabledAgentsModeFromTabs(cubit.state.newSessionTabs),
        EnabledAgentsMode.both,
      );

      cubit.setEnabledAgentsMode(EnabledAgentsMode.codex);
      expect(cubit.state.newSessionTabs, [NewSessionTab.codex]);
      expect(
        enabledAgentsModeFromTabs(cubit.state.newSessionTabs),
        EnabledAgentsMode.codex,
      );

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.newSessionTabs, [NewSessionTab.codex]);
      expect(
        enabledAgentsModeFromTabs(restored.state.newSessionTabs),
        EnabledAgentsMode.codex,
      );

      restored.setEnabledAgentsMode(EnabledAgentsMode.both);
      expect(restored.state.newSessionTabs.toSet(), {
        NewSessionTab.codex,
        NewSessionTab.claude,
      });

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

    test('Bridge name display defaults on and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.showBridgeNameInSessionList, isTrue);

      cubit.setShowBridgeNameInSessionList(false);

      expect(cubit.state.showBridgeNameInSessionList, isFalse);
      expect(
        prefs.getBool('settings_show_bridge_name_in_session_list'),
        isFalse,
      );

      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.showBridgeNameInSessionList, isFalse);

      await restored.close();
    });
  });
}

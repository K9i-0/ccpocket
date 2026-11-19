import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/session_list/services/session_start_defaults_store.dart';
import 'package:ccpocket/features/session_list/session_list_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _codexKey = 'session_start_defaults_codex_v1';

/// Bridge whose Codex catalog can change while the sheet is open, like the
/// fallback catalog a freshly restarted Bridge announces first.
class _CatalogBridge extends BridgeService {
  _CatalogBridge(this.models);

  List<String> models;
  final _catalogController = StreamController<List<SessionInfo>>.broadcast();

  @override
  List<String> get codexModels => models;
  @override
  Stream<List<SessionInfo>> get sessionList => _catalogController.stream;
  void publishCatalog(List<String> next) {
    models = next;
    _catalogController.add(const []);
  }

  @override
  void requestProjects() {}
  @override
  void dispose() {
    _catalogController.close();
    super.dispose();
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required BridgeService bridge,
  required NewSessionParams initialParams,
  Map<Provider, NewSessionParams> providerDefaults = const {},
  List<NewSessionTab> visibleTabs = defaultNewSessionTabs,
  required void Function(NewSessionParams?) onResult,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showNewSessionSheet(
                  context: context,
                  recentProjects: const [],
                  bridge: bridge,
                  initialParams: initialParams,
                  providerDefaults: providerDefaults,
                  visibleTabs: visibleTabs,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('dialog_start_button')));
  await tester.pumpAndSettle();
}

SystemMessage _created({
  String provider = 'claude',
  String projectPath = '/workspace/app',
  String? permissionMode,
}) => SystemMessage(
  subtype: 'session_created',
  sessionId: 's1',
  provider: provider,
  projectPath: projectPath,
  permissionMode: permissionMode,
);

void main() {
  group('new session sheet Antigravity tab', () {
    final withAntigravity = visibleNewSessionTabs(
      defaultNewSessionTabs,
      supportsAntigravity: true,
    );

    testWidgets('is hidden without the Bridge capability', (tester) async {
      final bridge = _CatalogBridge(const ['gpt-6-astra']);
      addTearDown(bridge.dispose);
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(projectPath: '/workspace/app'),
        visibleTabs: visibleNewSessionTabs(
          defaultNewSessionTabs,
          supportsAntigravity: false,
        ),
        onResult: (_) {},
      );

      expect(find.byKey(const ValueKey('new_session_tab_codex')), findsOne);
      expect(find.byKey(const ValueKey('new_session_tab_claude')), findsOne);
      expect(
        find.byKey(const ValueKey('new_session_tab_antigravity')),
        findsNothing,
      );
    });

    testWidgets('offers only a permission mode and starts with it', (
      tester,
    ) async {
      final bridge = _CatalogBridge(const ['gpt-6-astra']);
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.codex,
          model: 'gpt-6-astra',
        ),
        providerDefaults: {
          Provider.claude: NewSessionParams(
            projectPath: '/workspace/other',
            provider: Provider.claude,
            claudePermissionMode: PermissionMode.bypassPermissions,
            claudeModel: 'opus',
          ),
        },
        visibleTabs: withAntigravity,
        onResult: (value) => result = value,
      );

      await tester.tap(
        find.byKey(const ValueKey('new_session_tab_antigravity')),
      );
      await tester.pumpAndSettle();

      // No model picker and none of the Claude / Codex options.
      expect(
        find.byKey(const ValueKey('dialog_antigravity_model_note')),
        findsOne,
      );
      // Antigravity ships as a preview and says so before a session starts.
      expect(
        find.byKey(const ValueKey('dialog_antigravity_preview_badge')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('dialog_advanced_antigravity')),
        findsNothing,
      );
      // Claude's bypass default does not leak into this tab.
      expect(find.text('Default'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('dialog_antigravity_permission_mode')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bypass All'), findsNothing);
      expect(find.text('Auto'), findsNothing);
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.provider, Provider.antigravity);
      expect(result?.permissionMode, PermissionMode.plan);
      expect(result?.model, isNull);
      expect(result?.claudeModel, isNull);
      expect(result?.sandboxMode, isNull);
      expect(result?.projectPath, '/workspace/app');
    });

    testWidgets('saved Antigravity defaults do not leak into Claude', (
      tester,
    ) async {
      final bridge = _CatalogBridge(const ['gpt-6-astra']);
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.antigravity,
          permissionMode: PermissionMode.plan,
        ),
        providerDefaults: {
          Provider.claude: NewSessionParams(
            projectPath: '/workspace/other',
            provider: Provider.claude,
            claudePermissionMode: PermissionMode.acceptEdits,
          ),
        },
        visibleTabs: withAntigravity,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const ValueKey('new_session_tab_claude')));
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.provider, Provider.claude);
      expect(result?.permissionMode, PermissionMode.acceptEdits);
      expect(result?.planMode, isFalse);
    });
  });

  group('new session sheet provider defaults', () {
    testWidgets('Claude tab uses saved Claude defaults when opened on Codex', (
      tester,
    ) async {
      final bridge = _CatalogBridge(const ['gpt-6-astra']);
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.codex,
          model: 'gpt-6-astra',
        ),
        providerDefaults: {
          Provider.claude: NewSessionParams(
            projectPath: '/workspace/other',
            provider: Provider.claude,
            claudePermissionMode: PermissionMode.auto,
          ),
        },
        onResult: (value) => result = value,
      );

      await tester.tap(find.text('Claude').first);
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.provider, Provider.claude);
      expect(result?.permissionMode, PermissionMode.auto);
      // The project still follows the defaults the sheet opened with.
      expect(result?.projectPath, '/workspace/app');
    });

    testWidgets('Codex tab uses saved Codex model when opened on Claude', (
      tester,
    ) async {
      final bridge = _CatalogBridge(const ['gpt-5.6-sol', 'gpt-6-astra']);
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.claude,
          claudePermissionMode: PermissionMode.auto,
        ),
        providerDefaults: {
          Provider.codex: NewSessionParams(
            projectPath: '/workspace/app',
            provider: Provider.codex,
            model: 'gpt-6-astra',
          ),
        },
        onResult: (value) => result = value,
      );

      await tester.tap(find.text('Codex').first);
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.provider, Provider.codex);
      expect(result?.model, 'gpt-6-astra');
    });

    testWidgets('saved model is restored when the real catalog arrives', (
      tester,
    ) async {
      // A restarted Bridge first announces its fallback catalog.
      final bridge = _CatalogBridge(const ['gpt-5.6-sol', 'gpt-5.5']);
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.codex,
          model: 'gpt-6-astra',
        ),
        onResult: (value) => result = value,
      );

      bridge.publishCatalog(const ['gpt-5.6-sol', 'gpt-6-astra']);
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.model, 'gpt-6-astra');
      expect(result?.codexModelOverridden, isFalse);
    });
  });

  group('SessionStartDefaultsStore Codex model', () {
    const store = SessionStartDefaultsStore();

    setUp(() {
      SharedPreferences.setMockInitialValues({
        _codexKey: jsonEncode(
          sessionStartDefaultsToJson(
            NewSessionParams(
              projectPath: '/workspace/app',
              provider: Provider.codex,
              model: 'gpt-6-astra',
            ),
          ),
        ),
      });
    });

    test('keeps the saved model when the sheet fell back to another', () async {
      await store.save(
        NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.codex,
          model: 'gpt-5.6-sol',
        ),
      );

      final loaded = await store.loadFor(Provider.codex);
      expect(loaded?.model, 'gpt-6-astra');
    });

    test('saves a model the user picked in the sheet', () async {
      await store.save(
        NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.codex,
          model: 'gpt-5.6-sol',
          codexModelOverridden: true,
        ),
      );

      final loaded = await store.loadFor(Provider.codex);
      expect(loaded?.model, 'gpt-5.6-sol');
    });
  });

  group('claudeDefaultsCorrectionFor', () {
    final pending = NewSessionParams(
      projectPath: '/workspace/app',
      provider: Provider.claude,
      claudePermissionMode: PermissionMode.auto,
    );

    test('ignores session_created of other sessions', () {
      for (final msg in [
        _created(provider: 'codex', permissionMode: 'default'),
        _created(projectPath: '/workspace/other', permissionMode: 'default'),
        const SystemMessage(subtype: 'init', provider: 'claude'),
      ]) {
        final decision = claudeDefaultsCorrectionFor(pending, msg);
        expect(decision.matched, isFalse);
        expect(decision.corrected, isNull);
      }
    });

    test('keeps Auto when the Bridge does not report the mode', () {
      final decision = claudeDefaultsCorrectionFor(pending, _created());
      expect(decision.matched, isTrue);
      expect(decision.corrected, isNull);
    });

    test('keeps Auto when the session started in Auto', () {
      final decision = claudeDefaultsCorrectionFor(
        pending,
        _created(permissionMode: 'auto'),
      );
      expect(decision.matched, isTrue);
      expect(decision.corrected, isNull);
    });

    test('records the fallback mode reported for this session', () {
      final decision = claudeDefaultsCorrectionFor(
        pending,
        _created(permissionMode: 'default'),
      );
      expect(decision.matched, isTrue);
      expect(decision.corrected?.permissionMode, PermissionMode.defaultMode);
    });
  });
}

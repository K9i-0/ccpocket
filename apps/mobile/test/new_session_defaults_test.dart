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
import 'package:ccpocket/widgets/preview_badge.dart';
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

/// Bridge that knows what a new Antigravity session offers (`antigravity_v2`).
class _AntigravityCatalogBridge extends _CatalogBridge {
  _AntigravityCatalogBridge() : super(const ['gpt-6-astra']);

  final _results = StreamController<AntigravityCatalogMessage>.broadcast();
  AntigravitySettings? catalog;
  int requests = 0;

  @override
  bool get supportsAntigravityCatalog => true;
  @override
  AntigravitySettings? get antigravityCatalog => catalog;
  @override
  Stream<AntigravityCatalogMessage> get antigravityCatalogResults =>
      _results.stream;
  @override
  void requestAntigravityCatalog() => requests++;

  void publish(AntigravitySettings next) {
    catalog = next;
    _results.add(AntigravityCatalogMessage(catalog: next));
  }

  @override
  void dispose() {
    _results.close();
    super.dispose();
  }
}

final _antigravityCatalog = AntigravitySettings.fromJsonOrNull({
  'model': 'gemini-3.8-flash-high',
  'models': [
    {'id': 'gemini-3.8-flash-high', 'name': 'Gemini 3.8 Flash (High)'},
  ],
  'baseModel': 'gemini-3.8-flash',
  'modelOptions': [
    {
      'id': 'gemini-3.8-flash',
      'name': 'Gemini 3.8 Flash',
      'thoughtLevels': ['high', 'medium', 'low'],
    },
    {
      'id': 'gemini-3.1-pro',
      'name': 'Gemini 3.1 Pro',
      'thoughtLevels': ['high', 'low'],
    },
  ],
  'thoughtLevel': 'high',
  'permissionModes': ['default', 'acceptEdits', 'auto', 'plan'],
  'authMode': 'login',
  'tier': {'name': 'Google AI Ultra'},
})!;

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
      // Antigravity is a regular agent: no preview badge.
      expect(find.byType(PreviewBadge), findsNothing);
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

    testWidgets('offers the model, thinking level and account modes', (
      tester,
    ) async {
      final bridge = _AntigravityCatalogBridge();
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await _pumpSheet(
        tester,
        bridge: bridge,
        initialParams: NewSessionParams(
          projectPath: '/workspace/app',
          provider: Provider.antigravity,
          // Saved on another account; this one has no bypass mode.
          antigravityPermissionMode: PermissionMode.bypassPermissions,
          antigravityModel: 'gone-model',
        ),
        visibleTabs: withAntigravity,
        onResult: (value) => result = value,
      );
      expect(bridge.requests, 1);
      // Until the Bridge answers there is nothing to pick a model from.
      expect(
        find.byKey(const ValueKey('dialog_antigravity_model')),
        findsNothing,
      );

      bridge.publish(_antigravityCatalog);
      await tester.pumpAndSettle();
      expect(find.text('Gemini 3.8 Flash · High'), findsOne);
      expect(find.text('Google AI Ultra'), findsOne);

      await tester.tap(find.byKey(const ValueKey('dialog_antigravity_model')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('antigravity_model_option_gemini-3.1-pro')),
      );
      await tester.pumpAndSettle();
      // Pro has no medium level.
      expect(
        find.byKey(const ValueKey('antigravity_thought_level_medium')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('antigravity_thought_level_low')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Gemini 3.1 Pro · Low'), findsOne);

      await tester.tap(
        find.byKey(const ValueKey('dialog_antigravity_permission_mode')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bypass All'), findsNothing);
      await tester.tap(find.text('Auto').last);
      await tester.pumpAndSettle();
      await _start(tester);

      expect(result?.provider, Provider.antigravity);
      expect(result?.permissionMode, PermissionMode.auto);
      expect(result?.antigravityModel, 'gemini-3.1-pro');
      expect(result?.antigravityThoughtLevel, 'low');
    });

    testWidgets('with nothing saved it starts like the agy CLI', (
      tester,
    ) async {
      final bridge = _AntigravityCatalogBridge()..catalog = _antigravityCatalog;
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
        visibleTabs: withAntigravity,
        onResult: (value) => result = value,
      );
      await tester.tap(
        find.byKey(const ValueKey('new_session_tab_antigravity')),
      );
      await tester.pumpAndSettle();
      await _start(tester);

      // The account's default model, and auto because the account has it.
      expect(result?.permissionMode, PermissionMode.auto);
      expect(result?.antigravityModel, 'gemini-3.8-flash');
      expect(result?.antigravityThoughtLevel, 'high');
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

  group('Antigravity new-session model/level handling', () {
    final withAntigravity = visibleNewSessionTabs(
      defaultNewSessionTabs,
      supportsAntigravity: true,
    );

    testWidgets(
      'preserves saved model and thought level when started before catalog arrives',
      (tester) async {
        final bridge = _AntigravityCatalogBridge();
        addTearDown(bridge.dispose);
        NewSessionParams? result;
        await _pumpSheet(
          tester,
          bridge: bridge,
          visibleTabs: withAntigravity,
          initialParams: NewSessionParams(
            projectPath: '/workspace/app',
            provider: Provider.antigravity,
            antigravityPermissionMode: PermissionMode.acceptEdits,
            antigravityModel: 'gemini-3.8-flash',
            antigravityThoughtLevel: 'medium',
          ),
          onResult: (value) => result = value,
        );

        await _start(tester);

        expect(result?.antigravityModel, 'gemini-3.8-flash');
        expect(result?.antigravityThoughtLevel, 'medium');
      },
    );

    testWidgets(
      'clears thought level to null when switching to a model without thought levels',
      (tester) async {
        final bridge = _AntigravityCatalogBridge();
        addTearDown(bridge.dispose);
        bridge.catalog = AntigravitySettings.fromJsonOrNull({
          'model': 'gemini-3.8-flash-high',
          'models': [
            {'id': 'gemini-3.8-flash-high', 'name': 'Gemini 3.8 Flash (High)'},
            {'id': 'gpt-oss-120b', 'name': 'GPT-OSS 120B'},
          ],
          'baseModel': 'gemini-3.8-flash',
          'modelOptions': [
            {
              'id': 'gemini-3.8-flash',
              'name': 'Gemini 3.8 Flash',
              'thoughtLevels': ['high', 'low'],
            },
            {
              'id': 'gpt-oss-120b',
              'name': 'GPT-OSS 120B',
              'thoughtLevels': <String>[],
            },
          ],
          'thoughtLevel': 'high',
          'thoughtLevels': ['high', 'low'],
          'permissionModes': ['default', 'acceptEdits', 'plan'],
          'authMode': 'login',
        });

        NewSessionParams? result;
        await _pumpSheet(
          tester,
          bridge: bridge,
          visibleTabs: withAntigravity,
          initialParams: NewSessionParams(
            projectPath: '/workspace/app',
            provider: Provider.antigravity,
            antigravityPermissionMode: PermissionMode.defaultMode,
            antigravityModel: 'gemini-3.8-flash',
            antigravityThoughtLevel: 'high',
          ),
          onResult: (value) => result = value,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey('dialog_antigravity_model')),
        );
        await tester.tap(
          find.byKey(const ValueKey('dialog_antigravity_model')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('antigravity_model_option_gpt-oss-120b')),
        );
        await tester.pumpAndSettle();

        // Dismiss the model sheet
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await _start(tester);

        expect(result?.antigravityModel, 'gpt-oss-120b');
        expect(result?.antigravityThoughtLevel, isNull);
      },
    );
  });
}

import 'dart:convert';

import 'package:ccpocket/features/session_list/session_list_screen.dart';
import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/router/app_router.dart';
import 'package:ccpocket/router/session_stack_navigation.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/theme/provider_style.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settingsJson = <String, dynamic>{
  'model': 'gemini-3.8-flash-high',
  'models': [
    {'id': 'gemini-3.8-flash-high', 'name': 'Gemini 3.8 Flash (High)'},
    {'id': 'gemini-3.1-pro-low', 'name': 'Gemini 3.1 Pro (Low)'},
  ],
  'permissionMode': 'acceptEdits',
  'permissionModes': ['default', 'acceptEdits', 'plan'],
  'authMode': 'api_key',
};

Map<String, dynamic> _json(ClientMessage message) =>
    jsonDecode(message.toJson()) as Map<String, dynamic>;

void main() {
  group('Antigravity provider parsing', () {
    test('wire value resolves to the provider', () {
      expect(Provider.fromValue('antigravity'), Provider.antigravity);
      expect(providerFromRaw('antigravity'), Provider.antigravity);
      expect(providerFromRaw('codex'), Provider.codex);
      // Missing or unknown values keep meaning Claude.
      expect(providerFromRaw(null), Provider.claude);
      expect(providerFromRaw('something-else'), Provider.claude);
    });

    test('system init carries the settings object', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'sessionId': 'conv-1',
        'provider': 'antigravity',
        'model': 'gemini-3.8-flash-high',
        'permissionMode': 'acceptEdits',
        'slashCommands': ['goal', 'compact'],
        'antigravity': _settingsJson,
      }) as SystemMessage;

      final settings = msg.antigravity!;
      expect(settings.model, 'gemini-3.8-flash-high');
      expect(settings.modelLabel, 'Gemini 3.8 Flash (High)');
      expect(settings.models.map((m) => m.id), [
        'gemini-3.8-flash-high',
        'gemini-3.1-pro-low',
      ]);
      expect(settings.permissionMode, PermissionMode.acceptEdits);
      expect(settings.permissionModes, [
        PermissionMode.defaultMode,
        PermissionMode.acceptEdits,
        PermissionMode.plan,
      ]);
      expect(settings.authMode, 'api_key');
    });

    test('antigravity_settings with auto keeps the account modes', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'antigravity_settings',
        'sessionId': 'bridge-1',
        'provider': 'antigravity',
        'antigravity': {
          ..._settingsJson,
          'permissionMode': 'auto',
          'permissionModes': [
            'default',
            'acceptEdits',
            'auto',
            'plan',
            // The Bridge's own mode: it allows every request itself.
            'bypassPermissions',
            'something-new',
          ],
        },
      }) as SystemMessage;

      expect(msg.antigravity!.permissionMode, PermissionMode.auto);
      expect(msg.antigravity!.selectablePermissionModes, [
        PermissionMode.defaultMode,
        PermissionMode.acceptEdits,
        PermissionMode.auto,
        PermissionMode.plan,
        PermissionMode.bypassPermissions,
      ]);
    });

    test('settings carry families, levels, plan, context and version', () {
      final settings = AntigravitySettings.fromJsonOrNull({
        ..._settingsJson,
        'baseModel': 'gemini-3.8-flash',
        'modelOptions': [
          {
            'id': 'gemini-3.8-flash',
            'name': 'Gemini 3.8 Flash',
            'thoughtLevels': ['high', 'medium', 'low'],
          },
          {'id': 'gpt-oss-120b-medium', 'name': 'GPT-OSS 120B (Medium)'},
        ],
        'thoughtLevel': 'high',
        'thoughtLevels': ['low', 'medium', 'high'],
        'tier': {'id': 'g1-ultra', 'name': 'Google AI Ultra'},
        'contextUsage': {'used': 12349, 'size': 1048576},
        'agentVersion': '1.5.12',
      })!;

      expect(settings.hasModelOptions, isTrue);
      expect(settings.currentModelOption?.thoughtLevels, [
        'high',
        'medium',
        'low',
      ]);
      expect(settings.modelSummary, 'Gemini 3.8 Flash · High');
      expect(settings.modelOptions.last.thoughtLevels, isEmpty);
      expect(settings.tierName, 'Google AI Ultra');
      expect(settings.contextUsage?.percent, 1);
      expect(settings.agentVersion, '1.5.12');
      // Older Bridges report the full model name only.
      expect(
        AntigravitySettings.fromJsonOrNull(_settingsJson)!.modelSummary,
        'Gemini 3.8 Flash (High)',
      );
    });

    test('the catalog answer and the command descriptions parse', () {
      final catalog = ServerMessage.fromJson({
        'type': 'antigravity_catalog',
        'requestId': 'r1',
        'catalog': {
          ..._settingsJson,
          'permissionModes': ['default', 'auto'],
        },
      }) as AntigravityCatalogMessage;
      expect(catalog.catalog?.permissionModes, [
        PermissionMode.defaultMode,
        PermissionMode.auto,
      ]);
      final failed = ServerMessage.fromJson({
        'type': 'antigravity_catalog',
        'error': 'not signed in',
      }) as AntigravityCatalogMessage;
      expect(failed.catalog, isNull);
      expect(failed.error, 'not signed in');

      final commands = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'supported_commands',
        'provider': 'antigravity',
        'slashCommands': ['goal'],
        'slashCommandDescriptions': {'goal': 'Run until the goal is done.'},
      }) as SystemMessage;
      expect(commands.slashCommandDescriptions, {
        'goal': 'Run until the goal is done.',
      });
    });

    test('unknown modes fall back to default / acceptEdits / plan', () {
      final settings = AntigravitySettings.fromJsonOrNull({
        'models': <Object>[],
        'permissionModes': <Object>[],
        'authMode': 'login',
      })!;

      expect(settings.model, isNull);
      expect(settings.modelLabel, isNull);
      expect(
        settings.selectablePermissionModes,
        defaultAntigravityPermissionModes,
      );
      expect(
        settings.selectablePermissionModes,
        isNot(contains(PermissionMode.bypassPermissions)),
      );
    });

    test('session summary carries provider, title and settings', () {
      final session = SessionInfo.fromJson({
        'id': 'bridge-1',
        'provider': 'antigravity',
        'projectPath': '/tmp/project',
        'name': 'Fix the parser',
        'status': 'idle',
        'permissionMode': 'acceptEdits',
        'model': 'gemini-3.8-flash-high',
        'antigravitySettings': _settingsJson,
      });

      expect(session.provider, 'antigravity');
      expect(session.name, 'Fix the parser');
      expect(session.effectivePermissionMode, 'acceptEdits');
      expect(
        session.antigravitySettings!.modelLabel,
        'Gemini 3.8 Flash (High)',
      );
      // Status patches rebuild the summary; the settings must survive.
      expect(
        session.copyWith(status: 'running').antigravitySettings,
        session.antigravitySettings,
      );
    });
  });

  group('Antigravity system messages in the chat handler', () {
    test('antigravity_settings updates settings without a chat entry', () {
      final handler = ChatMessageHandler();
      final update = handler.handle(
        ServerMessage.fromJson({
          'type': 'system',
          'subtype': 'antigravity_settings',
          'sessionId': 'bridge-1',
          'provider': 'antigravity',
          'model': 'gemini-3.8-flash-high',
          'permissionMode': 'acceptEdits',
          'antigravity': _settingsJson,
        }),
        isBackground: false,
      );

      expect(update.entriesToAdd, isEmpty);
      expect(update.antigravitySettings!.model, 'gemini-3.8-flash-high');
      expect(update.permissionMode, PermissionMode.acceptEdits);
      // It carries the Bridge session id, not the conversation id.
      expect(update.claudeSessionId, isNull);
      // Never read as a Codex model.
      expect(update.codexModel, isNull);
    });

    test('history restores the latest settings and hides the messages', () {
      final handler = ChatMessageHandler();
      final update = handler.handle(
        HistoryMessage(
          messages: [
            ServerMessage.fromJson({
              'type': 'system',
              'subtype': 'init',
              'sessionId': 'conv-1',
              'provider': 'antigravity',
              'antigravity': _settingsJson,
            }),
            ServerMessage.fromJson({
              'type': 'system',
              'subtype': 'antigravity_settings',
              'sessionId': 'bridge-1',
              'provider': 'antigravity',
              'antigravity': {..._settingsJson, 'model': 'gemini-3.1-pro-low'},
            }),
          ],
        ),
        isBackground: false,
      );

      expect(update.entriesToAdd, isEmpty);
      expect(update.antigravitySettings!.model, 'gemini-3.1-pro-low');
      expect(update.claudeSessionId, 'conv-1');
      expect(update.codexModel, isNull);
    });
  });

  group('new session tabs', () {
    test('Antigravity tab follows the Bridge capability', () {
      expect(
        visibleNewSessionTabs(defaultNewSessionTabs, supportsAntigravity: true),
        [NewSessionTab.codex, NewSessionTab.claude, NewSessionTab.antigravity],
      );
      expect(
        visibleNewSessionTabs(
          defaultNewSessionTabs,
          supportsAntigravity: false,
        ),
        [NewSessionTab.codex, NewSessionTab.claude],
      );
    });

    test('a single agent shows the Antigravity tab only when it is on', () {
      expect(
        visibleNewSessionTabs(const [
          NewSessionTab.codex,
        ], supportsAntigravity: false),
        [NewSessionTab.codex],
      );
      expect(
        visibleNewSessionTabs(const [
          NewSessionTab.claude,
        ], supportsAntigravity: true),
        [NewSessionTab.claude, NewSessionTab.antigravity],
      );
    });

    test('Antigravity is saved as a position and can be the only agent', () {
      expect(tabsFromJson('["claude","antigravity","codex"]'), [
        NewSessionTab.claude,
        NewSessionTab.antigravity,
        NewSessionTab.codex,
      ]);
      const only = [NewSessionTab.antigravity];
      expect(
        tabsWithAgent(
          const [NewSessionTab.claude],
          NewSessionTab.claude,
          false,
        ),
        only,
      );
      expect(tabsFromJson(tabsToJson(only)), only);
      expect(enabledAgents(only, antigravity: true), only);
      expect(visibleNewSessionTabs(only, supportsAntigravity: true), only);
      // Without a Bridge that offers it, a session can still be started.
      expect(
        visibleNewSessionTabs(only, supportsAntigravity: false),
        defaultNewSessionTabs,
      );
      expect(tabsWithAgent(only, NewSessionTab.codex, true), [
        NewSessionTab.antigravity,
        NewSessionTab.codex,
      ]);
    });

    test('provider filters offer Antigravity only with the capability', () {
      expect(
        providerFiltersForEnabledTabs(
          defaultNewSessionTabs,
          supportsAntigravity: true,
        ),
        contains(ProviderFilter.antigravity),
      );
      expect(
        providerFiltersForEnabledTabs(
          defaultNewSessionTabs,
          supportsAntigravity: false,
        ),
        isNot(contains(ProviderFilter.antigravity)),
      );
      expect(
        providerFiltersForEnabledTabs(const [
          NewSessionTab.codex,
        ], supportsAntigravity: false),
        [ProviderFilter.codex],
      );
      // Antigravity alone needs no All either.
      expect(
        providerFiltersForEnabledTabs(const [
          NewSessionTab.antigravity,
        ], supportsAntigravity: true),
        [ProviderFilter.antigravity],
      );
    });
  });

  group('starting an Antigravity session', () {
    test('start sends only what Antigravity supports', () {
      final params = NewSessionParams(
        projectPath: '/tmp/project',
        provider: Provider.antigravity,
        permissionMode: PermissionMode.plan,
        useWorktree: true,
        worktreeBranch: 'feature/x',
        // Left over from other tabs; none of it applies.
        model: 'gpt-5.3-codex',
        claudeModel: 'opus',
        claudeEffort: ClaudeEffort.max,
      );

      final json = _json(antigravityStartMessage(params, requestId: 'req-1'));

      expect(json, {
        'type': 'start',
        'projectPath': '/tmp/project',
        'permissionMode': 'plan',
        'useWorktree': true,
        'worktreeBranch': 'feature/x',
        'provider': 'antigravity',
        'requestId': 'req-1',
      });
    });

    test('start carries the model family, thinking level and extra roots', () {
      final params = NewSessionParams(
        projectPath: '/tmp/project',
        provider: Provider.antigravity,
        antigravityPermissionMode: PermissionMode.auto,
        antigravityModel: 'gemini-3.8-flash',
        antigravityThoughtLevel: 'low',
        additionalWritableRoots: const ['/tmp/other'],
      );

      final json = _json(
        antigravityStartMessage(
          params,
          permissionModes: const [
            PermissionMode.defaultMode,
            PermissionMode.auto,
          ],
          requestId: 'req-1',
        ),
      );

      expect(json['permissionMode'], 'auto');
      expect(json['model'], 'gemini-3.8-flash');
      expect(json['effort'], 'low');
      expect(json['additionalWritableRoots'], ['/tmp/other']);
    });

    test('a mode the account does not offer starts in default', () {
      final legacy = NewSessionParams(
        projectPath: '/tmp/project',
        provider: Provider.antigravity,
        executionMode: ExecutionMode.fullAccess,
      );
      expect(legacy.permissionMode, PermissionMode.defaultMode);

      final auto = NewSessionParams(
        projectPath: '/tmp/project',
        provider: Provider.antigravity,
        antigravityPermissionMode: PermissionMode.auto,
      );
      expect(auto.permissionMode, PermissionMode.auto);
      // Unknown account (older Bridge): only the modes every account has.
      expect(
        _json(
          antigravityStartMessage(auto, requestId: 'req-1'),
        )['permissionMode'],
        'default',
      );
      expect(
        _json(
          antigravityStartMessage(
            auto,
            permissionModes: const [
              PermissionMode.defaultMode,
              PermissionMode.plan,
            ],
            requestId: 'req-1',
          ),
        )['permissionMode'],
        'default',
      );
    });

    test('defaults round-trip through persistence', () {
      final params = NewSessionParams(
        projectPath: '/tmp/project',
        provider: Provider.antigravity,
        permissionMode: PermissionMode.acceptEdits,
      );

      final restored = sessionStartDefaultsFromJson(
        sessionStartDefaultsToJson(params),
      )!;

      expect(restored.provider, Provider.antigravity);
      expect(restored.permissionMode, PermissionMode.acceptEdits);

      final full = sessionStartDefaultsFromJson(
        sessionStartDefaultsToJson(
          NewSessionParams(
            projectPath: '/tmp/project',
            provider: Provider.antigravity,
            antigravityPermissionMode: PermissionMode.bypassPermissions,
            antigravityModel: 'gemini-3.8-flash',
            antigravityThoughtLevel: 'medium',
          ),
        ),
      )!;
      expect(full.permissionMode, PermissionMode.bypassPermissions);
      expect(full.antigravityModel, 'gemini-3.8-flash');
      expect(full.antigravityThoughtLevel, 'medium');
    });

    test('resume command uses agy', () {
      const session = RecentSession(
        sessionId: 'conv-1',
        provider: 'antigravity',
        firstPrompt: '',
        created: '2026-11-19T00:00:00Z',
        modified: '2026-11-19T00:00:00Z',
        gitBranch: '',
        projectPath: '/tmp/project',
        isSidechain: false,
      );

      expect(
        buildResumeCommand(session),
        "cd '/tmp/project' && agy --conversation 'conv-1'",
      );
    });
  });

  group('tab order', () {
    const saved = [
      NewSessionTab.antigravity,
      NewSessionTab.claude,
      NewSessionTab.codex,
    ];

    test('Antigravity keeps its saved position, else comes last', () {
      expect(visibleNewSessionTabs(saved, supportsAntigravity: true), saved);
      expect(
        visibleNewSessionTabs(const [
          NewSessionTab.claude,
          NewSessionTab.codex,
        ], supportsAntigravity: true),
        [NewSessionTab.claude, NewSessionTab.codex, NewSessionTab.antigravity],
      );
      // Not offered by the Bridge, or switched off: left out.
      expect(visibleNewSessionTabs(saved, supportsAntigravity: false), [
        NewSessionTab.claude,
        NewSessionTab.codex,
      ]);
      // Next to a single agent it is offered like any other.
      expect(
        visibleNewSessionTabs(const [
          NewSessionTab.antigravity,
          NewSessionTab.codex,
        ], supportsAntigravity: true),
        [NewSessionTab.antigravity, NewSessionTab.codex],
      );
    });

    test('the position survives saving and switching agents', () {
      expect(tabsFromJson(tabsToJson(saved)), saved);
      expect(enabledAgents(saved, antigravity: true), saved);
      expect(tabsWithAgent(saved, NewSessionTab.codex, false), [
        NewSessionTab.antigravity,
        NewSessionTab.claude,
      ]);
      expect(tabsWithAgent(saved, NewSessionTab.codex, true), saved);
    });
  });

  group('plan usage', () {
    test('quota groups get short names and their own keys', () {
      final usage = UsageInfo.fromJson({
        'provider': 'antigravity',
        'label': 'Claude and GPT models',
        'fiveHour': null,
        'sevenDay': {'utilization': 0, 'resetsAt': '2026-11-26T14:16:16Z'},
      });
      expect(usage.groupLabel, 'Claude · GPT');
      expect(usage.compactGroupLabel, 'Claude+');
      expect(usage.usageKey, 'antigravity:Claude and GPT models');
      expect(
        const UsageInfo(
          provider: 'antigravity',
          label: 'Gemini Models',
        ).groupLabel,
        'Gemini',
      );
      expect(const UsageInfo(provider: 'codex').groupLabel, isNull);
      expect(const UsageInfo(provider: 'codex').usageKey, 'codex');
    });

    test('only an explicit refresh asks for a new Antigravity reading', () {
      expect(_json(ClientMessage.getUsage()), {'type': 'get_usage'});
      expect(_json(ClientMessage.getUsage(refreshAntigravity: true)), {
        'type': 'get_usage',
        'refreshAntigravity': true,
      });
    });
  });

  group('settings', () {
    test(
      'the Antigravity tab is on by default and can be turned off',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cubit = SettingsCubit(await SharedPreferences.getInstance());
        addTearDown(cubit.close);
        expect(cubit.state.showAntigravityTab, isTrue);

        cubit.setShowAntigravityTab(false);
        expect(cubit.state.showAntigravityTab, isFalse);
        final reloaded = SettingsCubit(await SharedPreferences.getInstance());
        addTearDown(reloaded.close);
        expect(reloaded.state.showAntigravityTab, isFalse);
      },
    );

    test('each agent switches on and off, and one always stays on', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);
      addTearDown(cubit.close);
      List<NewSessionTab> agents(SettingsCubit c) => enabledAgents(
        c.state.newSessionTabs,
        antigravity: c.state.showAntigravityTab,
      );
      expect(agents(cubit), [
        NewSessionTab.codex,
        NewSessionTab.claude,
        NewSessionTab.antigravity,
      ]);

      cubit.setAgentEnabled(NewSessionTab.codex, false);
      cubit.setAgentEnabled(NewSessionTab.claude, false);
      expect(agents(cubit), [NewSessionTab.antigravity]);
      // The last one cannot be switched off.
      cubit.setAgentEnabled(NewSessionTab.antigravity, false);
      expect(agents(cubit), [NewSessionTab.antigravity]);

      final reloaded = SettingsCubit(prefs);
      addTearDown(reloaded.close);
      expect(agents(reloaded), [NewSessionTab.antigravity]);
      reloaded.setAgentEnabled(NewSessionTab.claude, true);
      reloaded.setAgentEnabled(NewSessionTab.antigravity, false);
      expect(agents(reloaded), [NewSessionTab.claude]);
    });

    test('a single agent saved before keeps Antigravity off', () async {
      SharedPreferences.setMockInitialValues({
        'settings_new_session_tabs': '["claude"]',
      });
      final cubit = SettingsCubit(await SharedPreferences.getInstance());
      addTearDown(cubit.close);
      expect(cubit.state.showAntigravityTab, isFalse);
      // Chosen with the new selector, it stays on across restarts.
      cubit.setAgentEnabled(NewSessionTab.antigravity, true);
      final reloaded = SettingsCubit(await SharedPreferences.getInstance());
      addTearDown(reloaded.close);
      expect(reloaded.state.showAntigravityTab, isTrue);
    });

    test(
      'switching an agent off keeps the untouched Antigravity default',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cubit = SettingsCubit(prefs);
        addTearDown(cubit.close);
        cubit.setAgentEnabled(NewSessionTab.codex, false);
        final reloaded = SettingsCubit(prefs);
        addTearDown(reloaded.close);
        expect(reloaded.state.newSessionTabs, [NewSessionTab.claude]);
        expect(reloaded.state.showAntigravityTab, isTrue);
      },
    );
  });

  group('route selection', () {
    test('Antigravity opens the Claude-style screen with its provider', () {
      final route = chatRouteForProvider(
        Provider.antigravity,
        sessionId: 's1',
        permissionMode: 'plan',
      );

      expect(route, isA<ClaudeSessionRoute>());
      final args = route.args as ClaudeSessionRouteArgs;
      expect(args.provider, Provider.antigravity);
      expect(args.sessionId, 's1');
      expect(args.initialPermissionMode, 'plan');
    });

    test('Claude and Codex keep their routes', () {
      final claude = chatRouteForProvider(Provider.claude, sessionId: 's1');
      expect((claude.args as ClaudeSessionRouteArgs).provider, Provider.claude);
      expect(
        (chatRouteForProvider(null, sessionId: 's1').args
                as ClaudeSessionRouteArgs)
            .provider,
        Provider.claude,
      );
      expect(
        chatRouteForProvider(Provider.codex, sessionId: 's1'),
        isA<CodexSessionRoute>(),
      );
    });

    test('a stacked Antigravity route only matches its own provider', () {
      final route = chatRouteForProvider(Provider.antigravity, sessionId: 's1');
      bool matches(String provider) =>
          SessionStackNavigation.matchesDestination(
            routeIdentity: Object(),
            routeName: route.routeName,
            arguments: route.args,
            sessionId: 's1',
            provider: provider,
          );

      expect(matches('antigravity'), isTrue);
      expect(matches('claude'), isFalse);
    });

    test('Antigravity sessions are not pinnable', () {
      expect(isPinnableProvider('antigravity'), isFalse);
      expect(isPinnableProvider('claude'), isTrue);
      expect(isPinnableProvider(null), isTrue);
      expect(
        runningSessionPinKey(
          const SessionInfo(
            id: 'bridge-1',
            provider: 'antigravity',
            projectPath: '/tmp/project',
            claudeSessionId: 'conv-1',
            status: 'idle',
            createdAt: '',
            lastActivityAt: '',
          ),
        ),
        isNull,
      );
    });
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _additionalWritableRootHistoryKey =
    'new_session_additional_writable_root_history';

class _BridgeWithCodexProfiles extends BridgeService {
  _BridgeWithCodexProfiles({
    required this.availableProfiles,
    this.defaultProfile,
  });

  final List<String> availableProfiles;
  final String? defaultProfile;

  @override
  List<String> get codexProfiles => availableProfiles;

  @override
  String? get defaultCodexProfile => defaultProfile;
}

class _BridgeWithCodexModels extends BridgeService {
  @override
  List<String> get codexModels => const ['gpt-5.6-sol', 'gpt-5.4-mini'];

  @override
  Map<String, List<String>> get codexModelReasoningEfforts => const {
    'gpt-5.6-sol': ['xhigh', 'ultra'],
    'gpt-5.4-mini': ['low', 'medium'],
  };

  @override
  Map<String, List<String>> get codexModelServiceTiers => const {
    'gpt-5.6-sol': ['fast'],
  };
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

/// Enlarge the test viewport so the sheet content does not overflow.
void _enlargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('WorktreeInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'worktreePath': '/path/to/worktree',
        'branch': 'feature/x',
        'projectPath': '/path/to/project',
        'head': 'abc123',
      };
      final info = WorktreeInfo.fromJson(json);
      expect(info.worktreePath, '/path/to/worktree');
      expect(info.branch, 'feature/x');
      expect(info.projectPath, '/path/to/project');
      expect(info.head, 'abc123');
    });

    test('fromJson handles missing head', () {
      final json = {
        'worktreePath': '/path/to/worktree',
        'branch': 'main',
        'projectPath': '/path/to/project',
      };
      final info = WorktreeInfo.fromJson(json);
      expect(info.head, isNull);
    });
  });

  group('WorktreeListMessage', () {
    test('ServerMessage.fromJson parses worktree_list', () {
      final json = {
        'type': 'worktree_list',
        'worktrees': [
          {
            'worktreePath': '/wt1',
            'branch': 'ccpocket/s1',
            'projectPath': '/proj',
            'head': 'aaa',
          },
          {
            'worktreePath': '/wt2',
            'branch': 'ccpocket/s2',
            'projectPath': '/proj',
          },
        ],
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<WorktreeListMessage>());
      final wl = msg as WorktreeListMessage;
      expect(wl.worktrees, hasLength(2));
      expect(wl.worktrees[0].branch, 'ccpocket/s1');
      expect(wl.worktrees[0].head, 'aaa');
      expect(wl.worktrees[1].head, isNull);
    });

    test('ServerMessage.fromJson parses worktree_removed', () {
      final json = {
        'type': 'worktree_removed',
        'worktreePath': '/removed/path',
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<WorktreeRemovedMessage>());
      expect((msg as WorktreeRemovedMessage).worktreePath, '/removed/path');
    });

    test('worktree_list with empty worktrees', () {
      final json = {
        'type': 'worktree_list',
        'worktrees': <Map<String, dynamic>>[],
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<WorktreeListMessage>());
      expect((msg as WorktreeListMessage).worktrees, isEmpty);
    });
  });

  group('ClientMessage worktree', () {
    test('listWorktrees generates correct JSON', () {
      final msg = ClientMessage.listWorktrees('/my/project');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'list_worktrees');
      expect(json['projectPath'], '/my/project');
    });

    test('removeWorktree generates correct JSON', () {
      final msg = ClientMessage.removeWorktree('/proj', '/wt/path');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'remove_worktree');
      expect(json['projectPath'], '/proj');
      expect(json['worktreePath'], '/wt/path');
    });

    test('start includes worktree params when set', () {
      final msg = ClientMessage.start(
        '/proj',
        useWorktree: true,
        worktreeBranch: 'feature/test',
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'start');
      expect(json['useWorktree'], true);
      expect(json['worktreeBranch'], 'feature/test');
    });

    test('start omits worktree params when not set', () {
      final msg = ClientMessage.start('/proj');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'start');
      expect(json.containsKey('useWorktree'), false);
      expect(json.containsKey('worktreeBranch'), false);
    });

    test('start with useWorktree but no branch', () {
      final msg = ClientMessage.start('/proj', useWorktree: true);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['useWorktree'], true);
      expect(json.containsKey('worktreeBranch'), false);
    });

    test('start with empty branch string omits worktreeBranch', () {
      final msg = ClientMessage.start(
        '/proj',
        useWorktree: true,
        worktreeBranch: '',
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['useWorktree'], true);
      expect(json.containsKey('worktreeBranch'), false);
    });
  });

  group('NewSessionSheet - worktree UI', () {
    testWidgets('keyboard dismiss button clears project path focus', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [
                    (path: '/Users/me/Workspace/main', name: 'main'),
                  ],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dialog_project_path')));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('new_session_dismiss_keyboard_button')),
      );
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets(
      'additional writable root free input is saved as a suggestion',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        _enlargeViewport(tester);
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showNewSessionSheet(
                    context: context,
                    recentProjects: [
                      (path: '/Users/me/Workspace/main', name: 'main'),
                    ],
                    initialParams: NewSessionParams(
                      projectPath: '/Users/me/Workspace/main',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final addButton = find.byKey(
          const ValueKey('additional_writable_root_add_button'),
        );
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        const extraProject = '/Users/me/Workspace/codex';
        await tester.enterText(
          find.byKey(const ValueKey('additional_writable_root_field')),
          extraProject,
        );
        await tester.tap(
          find.byKey(const ValueKey('additional_writable_root_submit_button')),
        );
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(_additionalWritableRootHistoryKey), [
          extraProject,
        ]);
      },
    );

    testWidgets('additional writable root history appears in add sheet', (
      tester,
    ) async {
      const extraProject = '/Users/me/Workspace/codex';
      SharedPreferences.setMockInitialValues({
        _additionalWritableRootHistoryKey: [extraProject],
      });
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [
                    (path: '/Users/me/Workspace/main', name: 'main'),
                  ],
                  initialParams: NewSessionParams(
                    projectPath: '/Users/me/Workspace/main',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final addButton = find.byKey(
        const ValueKey('additional_writable_root_add_button'),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text(extraProject), findsOneWidget);
    });

    testWidgets(
      'additional writable root suggestions do not auto-open keyboard',
      (tester) async {
        const extraProject = '/Users/me/Workspace/codex';
        SharedPreferences.setMockInitialValues({
          _additionalWritableRootHistoryKey: [extraProject],
        });
        _enlargeViewport(tester);
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showNewSessionSheet(
                    context: context,
                    recentProjects: [
                      (path: '/Users/me/Workspace/main', name: 'main'),
                    ],
                    initialParams: NewSessionParams(
                      projectPath: '/Users/me/Workspace/main',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final addButton = find.byKey(
          const ValueKey('additional_writable_root_add_button'),
        );
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        final input = tester.widget<TextField>(
          find.byKey(const ValueKey('additional_writable_root_field')),
        );
        expect(input.autofocus, isFalse);
        expect(
          find.byKey(const ValueKey('additional_writable_root_scroll')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Codex profile picker stays hidden when no profiles exist', (
      tester,
    ) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  bridge: _BridgeWithCodexProfiles(availableProfiles: const []),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog_codex_profile')), findsNothing);
    });

    testWidgets('Codex profile picker appears when profiles exist', (
      tester,
    ) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  bridge: _BridgeWithCodexProfiles(
                    availableProfiles: const ['ccpocket'],
                    defaultProfile: 'ccpocket',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dialog_codex_profile')),
        findsOneWidget,
      );
      expect(
        find.text(
          'If the selected profile includes the same setting, it takes precedence over the options below.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Worktree FilterChip toggles', (tester) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final worktreeChip = find.text('Worktree');
      expect(worktreeChip, findsOneWidget);
      await tester.ensureVisible(worktreeChip);

      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsNothing,
      );

      await tester.tap(worktreeChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );
    });

    testWidgets('Branch input disappears when worktree deselected', (
      tester,
    ) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final worktreeChip = find.text('Worktree');
      await tester.ensureVisible(worktreeChip);
      await tester.tap(worktreeChip, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );

      await tester.ensureVisible(worktreeChip);
      await tester.tap(worktreeChip, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsNothing,
      );
    });

    testWidgets('Start returns params with worktree enabled', (tester) async {
      _enlargeViewport(tester);
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNewSessionSheet(
                    context: context,
                    recentProjects: [(path: '/test/proj', name: 'proj')],
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

      await tester.tap(find.text('proj'));
      await tester.pumpAndSettle();

      final worktreeChip = find.text('Worktree');
      await tester.ensureVisible(worktreeChip);
      await tester.tap(worktreeChip, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        'feature/test-branch',
      );
      await tester.pumpAndSettle();

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.useWorktree, true);
      expect(result!.worktreeBranch, 'feature/test-branch');
      expect(result!.projectPath, '/test/proj');
    });

    testWidgets('Start returns params without worktree', (tester) async {
      _enlargeViewport(tester);
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNewSessionSheet(
                    context: context,
                    recentProjects: [(path: '/test/proj', name: 'proj')],
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

      await tester.tap(find.text('proj'));
      await tester.pumpAndSettle();

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.useWorktree, false);
      expect(result!.worktreeBranch, isNull);
    });

    testWidgets('Start returns visible default Codex model when untouched', (
      tester,
    ) async {
      _enlargeViewport(tester);
      NewSessionParams? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('proj'));
      await tester.pumpAndSettle();

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.provider, Provider.codex);
      expect(result!.model, 'gpt-5.5');
      expect(result!.codexModelOverridden, false);
    });

    testWidgets('Codex provider can also enable worktree', (tester) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();

      expect(find.text('Worktree'), findsOneWidget);
      final worktreeChip = find.text('Worktree');
      await tester.ensureVisible(worktreeChip);
      await tester.tap(worktreeChip, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );
    });

    testWidgets('defaults to Codex on open', (tester) async {
      _enlargeViewport(tester);
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNewSessionSheet(
                    context: context,
                    recentProjects: [(path: '/test/proj', name: 'proj')],
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
      await tester.tap(find.text('proj'));
      await tester.pumpAndSettle();

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.provider, Provider.codex);
    });

    testWidgets('initialParams are applied to the sheet', (tester) async {
      _enlargeViewport(tester);
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNewSessionSheet(
                    context: context,
                    recentProjects: [(path: '/test/proj', name: 'proj')],
                    initialParams: NewSessionParams(
                      projectPath: '/test/proj',
                      provider: Provider.codex,
                      permissionMode: PermissionMode.acceptEdits,
                      model: 'gpt-5.3-codex',
                      codexSpeed: CodexSpeed.fast,
                      useWorktree: true,
                      worktreeBranch: 'feature/default',
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

      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Worktree'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );
      expect(find.text('feature/default'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialog_codex_speed_button')),
        findsOneWidget,
      );

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.provider, Provider.codex);
      expect(result!.useWorktree, isTrue);
      expect(result!.worktreeBranch, 'feature/default');
      expect(result!.codexSpeed, CodexSpeed.fast);
    });

    testWidgets('Codex keeps Effort visible and moves Model under advanced', (
      tester,
    ) async {
      _enlargeViewport(tester);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    showNewSessionSheet(
                      context: context,
                      recentProjects: [(path: '/test/proj', name: 'proj')],
                    );
                  },
                  child: const Text('Open Codex'),
                ),
                ElevatedButton(
                  onPressed: () {
                    showNewSessionSheet(
                      context: context,
                      recentProjects: [(path: '/test/proj', name: 'proj')],
                      initialParams: NewSessionParams(
                        projectPath: '/test/proj',
                        provider: Provider.claude,
                        permissionMode: PermissionMode.acceptEdits,
                      ),
                    );
                  },
                  child: const Text('Open Claude'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Codex'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog_codex_model')), findsNothing);
      expect(
        find.byKey(const ValueKey('dialog_codex_effort_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_speed_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_advanced_codex')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_web_search_mode')),
        findsNothing,
      );
      final modeButton = find.byKey(
        const ValueKey('dialog_codex_settings_mode'),
      );
      expect(
        find.descendant(
          of: modeButton,
          matching: find.byIcon(Icons.tune_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('dialog_codex_model_label')),
            )
            .data,
        '5.5',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('dialog_codex_effort_label')),
            )
            .data,
        'High',
      );

      await tester.tap(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: modeButton,
          matching: find.byIcon(Icons.tune_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: modeButton,
          matching: find.byIcon(Icons.linear_scale_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_quick_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_advanced_panel')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: modeButton,
          matching: find.byIcon(Icons.linear_scale_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_effort_slider')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_speed_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_advanced_panel')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('dialog_codex_model')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialog_codex_web_search_mode')),
        findsNothing,
      );
      expect(find.text('5.5'), findsNWidgets(2));
      expect(find.text('gpt-5.5'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('dialog_advanced_codex')),
      );
      await tester.tap(find.byKey(const ValueKey('dialog_advanced_codex')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_codex_web_search_mode')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_network_access')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_advanced_panel')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
      );
      await tester.tap(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_codex_effort_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_advanced_panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_web_search_mode')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_codex_network_access')),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(
          find.byKey(const ValueKey('dialog_codex_effort_slider')),
        ),
      ).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claude'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog_claude_model')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dialog_claude_effort')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dialog_advanced_claude')),
        findsOneWidget,
      );
    });

    testWidgets('Codex quick Speed button toggles Fast mode', (tester) async {
      _enlargeViewport(tester);
      final bridge = _BridgeWithCodexModels();
      addTearDown(bridge.dispose);
      NewSessionParams? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  initialParams: NewSessionParams(
                    projectPath: '/test/proj',
                    provider: Provider.codex,
                    permissionMode: PermissionMode.acceptEdits,
                    model: 'gpt-5.6-sol',
                    codexSpeed: CodexSpeed.standard,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog_codex_speed_button')));
      await tester.pumpAndSettle();

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.codexSpeed, CodexSpeed.fast);
    });

    testWidgets('Codex advanced model change normalizes Effort and Speed', (
      tester,
    ) async {
      _enlargeViewport(tester);
      final bridge = _BridgeWithCodexModels();
      addTearDown(bridge.dispose);
      NewSessionParams? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  initialParams: NewSessionParams(
                    projectPath: '/test/proj',
                    provider: Provider.codex,
                    permissionMode: PermissionMode.acceptEdits,
                    model: 'gpt-5.6-sol',
                    modelReasoningEffort: ReasoningEffort.xhigh,
                    codexSpeed: CodexSpeed.fast,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog_codex_model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5.4 Mini').last);
      await tester.pumpAndSettle();

      final effortField = tester
          .widget<DropdownButtonFormField<ReasoningEffort>>(
            find.byKey(const ValueKey('dialog_codex_effort_advanced')),
          );
      final speedField = tester.widget<DropdownButtonFormField<CodexSpeed>>(
        find.byKey(const ValueKey('dialog_codex_speed_advanced')),
      );
      expect(effortField.initialValue?.value, 'low');
      expect(speedField.initialValue, CodexSpeed.standard);

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.model, 'gpt-5.4-mini');
      expect(result!.modelReasoningEffort?.value, 'low');
      expect(result!.codexSpeed, CodexSpeed.standard);
    });

    testWidgets('Codex quick UI identifies an Advanced-only Effort', (
      tester,
    ) async {
      _enlargeViewport(tester);
      final bridge = _BridgeWithCodexModels();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  initialParams: NewSessionParams(
                    projectPath: '/test/proj',
                    provider: Provider.codex,
                    permissionMode: PermissionMode.acceptEdits,
                    model: 'gpt-5.6-sol',
                    modelReasoningEffort: ReasoningEffort.ultra,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final effortLabel = find.byKey(
        const ValueKey('dialog_codex_effort_label'),
      );
      expect(tester.widget<Text>(effortLabel).data, 'Ultra');
      expect(
        find.ancestor(of: effortLabel, matching: find.byType(ConstrainedBox)),
        findsWidgets,
      );
    });

    testWidgets('Codex quick slider includes Ultra when enabled in settings', (
      tester,
    ) async {
      _enlargeViewport(tester);
      final bridge = _BridgeWithCodexModels();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: [(path: '/test/proj', name: 'proj')],
                  showExtendedCodexEfforts: true,
                  initialParams: NewSessionParams(
                    projectPath: '/test/proj',
                    provider: Provider.codex,
                    permissionMode: PermissionMode.acceptEdits,
                    model: 'gpt-5.6-sol',
                    modelReasoningEffort: ReasoningEffort.xhigh,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final slider = find.byKey(const ValueKey('dialog_codex_effort_slider'));
      final sliderRect = tester.getRect(slider);
      await tester.tapAt(Offset(sliderRect.right - 8, sliderRect.center.dy));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('dialog_codex_effort_label')),
            )
            .data,
        'Ultra',
      );
    });
  });
}

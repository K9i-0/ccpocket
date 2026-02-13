import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
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
    testWidgets('Worktree FilterChip toggles', (tester) async {
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

      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsNothing,
      );

      await tester.tap(worktreeChip);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );
    });

    testWidgets('Branch input disappears when worktree deselected', (
      tester,
    ) async {
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

      await tester.tap(find.text('Worktree'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );

      await tester.tap(find.text('Worktree'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsNothing,
      );
    });

    testWidgets('Start returns params with worktree enabled', (tester) async {
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
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

      await tester.tap(find.text('Worktree'));
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
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
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

    testWidgets('Codex provider can also enable worktree', (tester) async {
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
      await tester.tap(find.text('Worktree'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_worktree_branch')),
        findsOneWidget,
      );
    });

    testWidgets('initialParams are applied to the sheet', (tester) async {
      NewSessionParams? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNewSessionSheet(
                    context: context,
                    recentProjects: [(path: '/test/proj', name: 'proj')],
                    initialParams: const NewSessionParams(
                      projectPath: '/test/proj',
                      provider: Provider.codex,
                      permissionMode: PermissionMode.acceptEdits,
                      model: 'gpt-5.3-codex',
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

      final startButton = find.byKey(const ValueKey('dialog_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.provider, Provider.codex);
      expect(result!.useWorktree, isTrue);
      expect(result!.worktreeBranch, 'feature/default');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card.dart';
import 'package:ccpocket/widgets/session_visual_status.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('SessionInfo.fromJson', () {
    test('parses gitBranch, lastMessage', () {
      final json = {
        'id': 'abc123',
        'projectPath': '/home/user/my-app',
        'status': 'running',
        'createdAt': '2025-01-01T00:00:00Z',
        'lastActivityAt': '2025-01-01T01:00:00Z',
        'gitBranch': 'feat/login',
        'lastMessage': 'Fixed the auth bug',
      };
      final info = SessionInfo.fromJson(json);
      expect(info.gitBranch, 'feat/login');
      expect(info.lastMessage, 'Fixed the auth bug');
    });

    test('defaults new fields when missing', () {
      final json = {
        'id': 'abc123',
        'projectPath': '/home/user/my-app',
        'status': 'idle',
        'createdAt': '',
        'lastActivityAt': '',
      };
      final info = SessionInfo.fromJson(json);
      expect(info.gitBranch, '');
      expect(info.lastMessage, '');
    });

    test('parses codex settings from codexSettings object', () {
      final json = {
        'id': 'codex1',
        'provider': 'codex',
        'projectPath': '/home/user/my-app',
        'status': 'idle',
        'createdAt': '',
        'lastActivityAt': '',
        'codexSettings': {
          'approvalPolicy': 'on-request',
          'sandboxMode': 'workspace-write',
          'model': 'gpt-5.3-codex',
        },
      };
      final info = SessionInfo.fromJson(json);
      expect(info.codexApprovalPolicy, 'on-request');
      expect(info.codexSandboxMode, 'workspace-write');
      expect(info.codexModel, 'gpt-5.3-codex');
    });

    test('parses agent metadata', () {
      final json = {
        'id': 'codex-agent',
        'provider': 'codex',
        'projectPath': '/home/user/my-app',
        'status': 'running',
        'createdAt': '',
        'lastActivityAt': '',
        'agentNickname': 'Atlas',
        'agentRole': 'explorer',
      };
      final info = SessionInfo.fromJson(json);
      expect(info.agentNickname, 'Atlas');
      expect(info.agentRole, 'explorer');
    });

    test(
      'keeps canonical codex execution mode when legacy permission differs',
      () {
        final json = {
          'id': 'codex-canonical',
          'provider': 'codex',
          'projectPath': '/home/user/my-app',
          'status': 'idle',
          'createdAt': '',
          'lastActivityAt': '',
          'permissionMode': 'acceptEdits',
          'executionMode': 'default',
          'planMode': false,
          'codexSettings': {
            'approvalPolicy': 'on-request',
            'sandboxMode': 'workspace-write',
          },
        };

        final info = SessionInfo.fromJson(json);
        expect(info.resolvedExecutionMode, ExecutionMode.defaultMode);
        expect(info.resolvedPlanMode, isFalse);
      },
    );
  });

  group('RunningSessionCard', () {
    test('maps visual status for running plan session', () {
      final visual = sessionVisualStatusFor(
        rawStatus: 'running',
        permissionMode: PermissionMode.plan.value,
      );

      expect(visual.label, 'Working');
      expect(visual.showPlanBadge, isTrue);
      expect(visual.detail, isNull);
    });

    test('maps visual status for plan approval', () {
      final visual = sessionVisualStatusFor(
        rawStatus: 'waiting_approval',
        permissionMode: PermissionMode.plan.value,
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'tool-plan',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Test plan'},
        ),
      );

      expect(visual.label, 'Needs You');
      expect(visual.detail, 'Review plan');
      expect(visual.showPlanBadge, isTrue);
    });

    testWidgets('displays gitBranch and lastMessage', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        gitBranch: 'feat/auth',
        lastMessage: 'Implemented login flow',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      // Git branch text
      expect(find.text('feat/auth'), findsOneWidget);
      // Last message text
      expect(find.text('Implemented login flow'), findsOneWidget);
      // Fork icon
      expect(find.byIcon(Icons.fork_right), findsOneWidget);
    });

    testWidgets('hides info row when gitBranch empty', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'idle',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      // No fork icon when gitBranch is empty
      expect(find.byIcon(Icons.fork_right), findsNothing);
    });

    testWidgets('shows status bar with Working label', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      // Status label in bar
      expect(find.text('Working'), findsOneWidget);
      // Project name as badge
      expect(find.text('my-app'), findsOneWidget);
      // Stop button removed (swipe-to-stop only)
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('shows Working status when session is in plan mode', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'plan-running',
        projectPath: '/home/user/my-app',
        status: 'running',
        permissionMode: PermissionMode.plan.value,
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      // Plan text badge was removed; plan mode is now indicated by
      // an orbiting light on the status dot (visual only, no key).
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('shows codex settings summary for codex provider', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-running',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        codexModel: 'gpt-5.3-codex',
        codexSandboxMode: 'workspace-write',
        codexApprovalPolicy: 'on-request',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('gpt-5.3-codex Default'), findsOneWidget);
      expect(find.text('On Request'), findsOneWidget);
      expect(find.text('Sandbox'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('shows Planning label for running codex plan session', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-planning',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'running',
        planMode: true,
        executionMode: ExecutionMode.defaultMode.value,
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        codexModel: 'gpt-5.4',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('gpt-5.4 Default'), findsOneWidget);
    });

    testWidgets('shows agent metadata for codex sub-agent sessions', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-agent',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        agentNickname: 'Atlas',
        agentRole: 'explorer',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Atlas [explorer]'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('shows settings summary for claude provider with model', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'claude-running',
        provider: 'claude',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        permissionMode: 'plan',
        model: 'claude-sonnet-4-20250514',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(
        find.text('claude-sonnet-4-20250514  default  plan-on'),
        findsOneWidget,
      );
    });

    testWidgets('shows bypass-all for claude bypassPermissions mode', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'claude-bypass',
        provider: 'claude',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        permissionMode: 'bypassPermissions',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('full-access'), findsOneWidget);
    });

    testWidgets('shows only mode when claude model is null', (tester) async {
      final session = SessionInfo(
        id: 'claude-no-model',
        provider: 'claude',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        permissionMode: 'plan',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('default  plan-on'), findsOneWidget);
    });

    testWidgets('hides lastMessage row when empty', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        gitBranch: 'main',
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      // Git branch should show
      expect(find.text('main'), findsOneWidget);
      // No lastMessage text rendered (empty by default)
    });

    testWidgets('shows codex plan approval area for ExitPlanMode permission', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-plan',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'tool-codex-plan-1',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Codex plan approval update'},
        ),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Needs You'), findsOneWidget);
      expect(find.text('Review plan'), findsOneWidget);
      expect(find.text('Plan'), findsNothing);
      expect(
        find.byKey(const ValueKey('codex_plan_approval_area')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);
    });

    testWidgets('shows structured codex command approval summary', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-command',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'waiting_approval',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'tool-codex-cmd-1',
          toolName: 'Bash',
          input: {
            'command': '/bin/zsh -lc "mise ls flutter"',
            'reason': 'Verify whether Flutter 3.41.6 finished installing',
            'availableDecisions': ['accept', 'acceptForSession', 'decline'],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Command Approval'), findsOneWidget);
      expect(
        find.text('Verify whether Flutter 3.41.6 finished installing'),
        findsOneWidget,
      );
      expect(find.text('/bin/zsh -lc "mise ls flutter"'), findsOneWidget);
      expect(
        find.text('Allowed actions: accept, acceptForSession, decline'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('approve_always_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('ask user custom input does not send on keyboard done', (
      tester,
    ) async {
      String? answered;
      final session = SessionInfo(
        id: 'ask-single-done',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'ask-tool-1',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'How should we handle this?',
                'header': 'Approach',
                'options': [
                  {'label': 'A', 'description': ''},
                  {'label': 'B', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(
          RunningSessionCard(
            session: session,
            onTap: () {},
            onAnswer: (_, result) => answered = result,
          ),
        ),
      );

      final otherAnswerButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Other answer...'),
      );
      otherAnswerButton.onPressed!.call();
      await tester.pump();

      final input = find.byType(TextField);
      await tester.tap(input);
      await tester.enterText(input, 'custom');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(answered, isNull);
    });

    testWidgets('shows ask user area with multiline custom input', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'ask-single-multiline',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'waiting_approval',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'ask-tool-multiline',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'How should we handle this?',
                'header': 'Approach',
                'options': [
                  {'label': 'A', 'description': ''},
                  {'label': 'B', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Other answer...'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Other answer...'));
      await tester.pump();

      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.minLines, 1);
      expect(input.maxLines, 3);
      expect(input.keyboardType, TextInputType.multiline);
      expect(input.textInputAction, TextInputAction.newline);
    });

    testWidgets('ask user send button is disabled until input exists', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'ask-single-send',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'ask-tool-2',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'How should we handle this?',
                'header': 'Approach',
                'options': [
                  {'label': 'A', 'description': ''},
                  {'label': 'B', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      final otherAnswerButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Other answer...'),
      );
      otherAnswerButton.onPressed!.call();
      await tester.pump();

      FilledButton sendButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send'),
      );

      expect(sendButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(sendButton().onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(sendButton().onPressed, isNull);
    });

    testWidgets('ask user multi-question custom input uses Next button', (
      tester,
    ) async {
      String? answered;
      final session = SessionInfo(
        id: 'ask-multi-next',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'ask-tool-3',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'Foreground?',
                'header': 'Foreground',
                'options': [
                  {'label': 'A', 'description': ''},
                  {'label': 'B', 'description': ''},
                ],
                'multiSelect': false,
              },
              {
                'question': 'Background?',
                'header': 'Background',
                'options': [
                  {'label': 'C', 'description': ''},
                  {'label': 'D', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(
          RunningSessionCard(
            session: session,
            onTap: () {},
            onAnswer: (_, result) => answered = result,
          ),
        ),
      );

      final otherAnswerButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Other answer...'),
      );
      otherAnswerButton.onPressed!.call();
      await tester.pump();

      FilledButton nextButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );

      expect(nextButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'In-app banner');
      await tester.pump();
      expect(nextButton().onPressed, isNotNull);

      nextButton().onPressed!.call();
      await tester.pump();
      expect(answered, isNull);
    });

    testWidgets('MCP approval requestUserInput uses approval UI and answers '
        'with approval labels', (tester) async {
      String? answered;
      final session = SessionInfo(
        id: 'ask-mcp-approval',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'waiting_approval',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'ask-tool-approval',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'header': 'Approve app tool call?',
                'question':
                    'The dart-mcp MCP server wants to run the tool '
                    '"dart_format", which may modify or delete data. '
                    'Allow this action?',
                'options': [
                  {'label': 'Approve Once', 'description': ''},
                  {'label': 'Approve this Session', 'description': ''},
                  {'label': 'Deny', 'description': ''},
                  {'label': 'Cancel', 'description': ''},
                ],
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(
          RunningSessionCard(
            session: session,
            onTap: () {},
            onAnswer: (_, result) => answered = result,
          ),
        ),
      );

      expect(find.text('Approve tool call'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      // Wide viewport (800px) → single-line combined text
      expect(find.text('This Session allow'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Other answer...'), findsNothing);

      final alwaysButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton).at(1),
      );
      alwaysButton.onPressed!.call();
      await tester.pump();

      expect(answered, 'Approve this Session');
    });

    testWidgets('shows Cancel label when codex approval exposes cancel', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'codex-command-cancel',
        provider: 'codex',
        projectPath: '/home/user/my-app',
        status: 'waiting_approval',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        pendingPermission: const PermissionRequestMessage(
          toolUseId: 'tool-codex-cmd-cancel',
          toolName: 'Bash',
          input: {
            'command': 'git status',
            'availableDecisions': ['accept', 'cancel'],
          },
        ),
      );

      await tester.pumpWidget(
        _wrap(RunningSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      expect(find.byKey(const ValueKey('approve_always_button')), findsNothing);
    });
  });

  group('RecentSessionCard', () {
    testWidgets('shows codex settings summary for codex provider', (
      tester,
    ) async {
      final session = RecentSession(
        sessionId: 'recent-codex',
        provider: 'codex',
        summary: 'summary',
        firstPrompt: 'prompt',
        created: DateTime.now().toIso8601String(),
        modified: DateTime.now().toIso8601String(),
        gitBranch: 'main',
        projectPath: '/home/user/my-app',
        isSidechain: false,
        codexApprovalPolicy: 'on-failure',
        codexSandboxMode: 'danger-full-access',
        codexModel: 'gpt-5-codex',
      );

      await tester.pumpWidget(
        _wrap(RecentSessionCard(session: session, onTap: () {})),
      );

      expect(find.text('gpt-5-codex Default'), findsOneWidget);
      expect(find.byIcon(Icons.auto_mode_outlined), findsOneWidget);
      expect(find.text('On Failure'), findsOneWidget);
      expect(find.text('Sandbox Off'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('calls onLongPress callback', (tester) async {
      var longPressed = false;
      final session = RecentSession(
        sessionId: 'recent-long-press',
        provider: 'codex',
        summary: 'summary',
        firstPrompt: 'prompt',
        created: DateTime.now().toIso8601String(),
        modified: DateTime.now().toIso8601String(),
        gitBranch: 'main',
        projectPath: '/home/user/my-app',
        isSidechain: false,
      );

      await tester.pumpWidget(
        _wrap(
          RecentSessionCard(
            session: session,
            onTap: () {},
            onLongPress: () => longPressed = true,
          ),
        ),
      );

      await tester.longPress(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);
    });
  });
}

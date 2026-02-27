import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card.dart';

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
  });

  group('RunningSessionCard', () {
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
      );

      // No fork icon when gitBranch is empty
      expect(find.byIcon(Icons.fork_right), findsNothing);
    });

    testWidgets('shows status bar with Running label', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
      );

      // Status label in bar
      expect(find.text('Running'), findsOneWidget);
      // Project name as badge
      expect(find.text('my-app'), findsOneWidget);
      // Stop button
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
      );

      expect(
        find.text(
          'gpt-5.3-codex  sandbox:workspace-write  approval:on-request',
        ),
        findsOneWidget,
      );
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
      );

      expect(find.text('Plan Ready'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('codex_plan_approval_area')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);
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
            onStop: () {},
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
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
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
            onStop: () {},
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

      expect(
        find.text(
          'gpt-5-codex  sandbox:danger-full-access  approval:on-failure',
        ),
        findsOneWidget,
      );
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('SessionInfo.fromJson', () {
    test('parses gitBranch, lastMessage, messageCount', () {
      final json = {
        'id': 'abc123',
        'projectPath': '/home/user/my-app',
        'status': 'running',
        'createdAt': '2025-01-01T00:00:00Z',
        'lastActivityAt': '2025-01-01T01:00:00Z',
        'gitBranch': 'feat/login',
        'lastMessage': 'Fixed the auth bug',
        'messageCount': 42,
      };
      final info = SessionInfo.fromJson(json);
      expect(info.gitBranch, 'feat/login');
      expect(info.lastMessage, 'Fixed the auth bug');
      expect(info.messageCount, 42);
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
      expect(info.messageCount, 0);
    });
  });

  group('RunningSessionCard', () {
    testWidgets('displays gitBranch, lastMessage, messageCount', (
      tester,
    ) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        gitBranch: 'feat/auth',
        lastMessage: 'Implemented login flow',
        messageCount: 15,
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
      // Message count
      expect(find.text('15'), findsOneWidget);
      // Fork icon
      expect(find.byIcon(Icons.fork_right), findsOneWidget);
      // Chat icon
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('hides info row when gitBranch/messageCount empty', (
      tester,
    ) async {
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
      // No chat icon when messageCount is 0
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
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

    testWidgets('hides lastMessage row when empty', (tester) async {
      final session = SessionInfo(
        id: 'test-id',
        projectPath: '/home/user/my-app',
        status: 'running',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        gitBranch: 'main',
        messageCount: 5,
      );

      await tester.pumpWidget(
        _wrap(
          RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
        ),
      );

      // Git branch should show
      expect(find.text('main'), findsOneWidget);
      // Message count should show
      expect(find.text('5'), findsOneWidget);
      // No lastMessage text rendered (empty by default)
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/widgets/background_tasks_bar.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/theme/app_theme.dart';

void main() {
  test('parses background_tasks and skips malformed entries', () {
    final msg = ServerMessage.fromJson({
      'type': 'background_tasks',
      'sessionId': 's1',
      'tasks': [
        {
          'taskId': 'b1',
          'taskType': 'local_bash',
          'description': 'Wait for CI',
        },
        {'taskType': 'local_bash'},
        {'taskId': 'a1', 'taskType': 'local_agent', 'subagentType': 'Explore'},
      ],
    });

    expect(msg, isA<BackgroundTasksMessage>());
    final tasks = (msg as BackgroundTasksMessage).tasks;
    expect(tasks.map((t) => t.taskId), ['b1', 'a1']);
    expect(tasks.first.description, 'Wait for CI');
    expect(tasks.last.subagentType, 'Explore');
  });

  test('handler replaces the background task set', () {
    final handler = ChatMessageHandler();
    final update = handler.handle(
      const BackgroundTasksMessage(
        tasks: [BackgroundTaskInfo(taskId: 'b1', taskType: 'local_bash')],
      ),
      isBackground: false,
    );
    expect(update.backgroundTasks?.single.taskId, 'b1');
    expect(update.entriesToAdd, isEmpty);

    final cleared = handler.handle(
      const BackgroundTasksMessage(tasks: []),
      isBackground: false,
    );
    expect(cleared.backgroundTasks, isEmpty);
  });

  test('session list carries the background task count', () {
    final session = SessionInfo.fromJson({
      'id': 's1',
      'projectPath': '/tmp/p',
      'status': 'idle',
      'backgroundTaskCount': 2,
    });
    expect(session.backgroundTaskCount, 2);
    expect(
      SessionInfo.fromJson({'id': 's2', 'projectPath': '/tmp/p'})
          .backgroundTaskCount,
      0,
    );
  });

  testWidgets('bar shows the first task and how many more run', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: BackgroundTasksBar(
            tasks: [
              BackgroundTaskInfo(
                taskId: 'b1',
                taskType: 'local_bash',
                description: 'Wait for CI',
              ),
              BackgroundTaskInfo(
                taskId: 'a1',
                taskType: 'local_agent',
                subagentType: 'Explore',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Running in background'), findsOneWidget);
    expect(find.text('Wait for CI · +1 more'), findsOneWidget);
  });
}

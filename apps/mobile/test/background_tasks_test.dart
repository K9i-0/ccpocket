import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/state/background_completion_gate.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_state.dart';
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

  test('session list carries the background agent count', () {
    final session = SessionInfo.fromJson({
      'id': 's1',
      'projectPath': '/tmp/p',
      'backgroundTaskCount': 3,
      'backgroundAgentCount': 1,
    });
    expect(session.backgroundAgentCount, 1);
    expect(
      const BackgroundTaskInfo(taskId: 'a', taskType: 'local_agent').isAgent,
      isTrue,
    );
    expect(
      const BackgroundTaskInfo(taskId: 'c', taskType: 'codex_agent').isAgent,
      isTrue,
    );
    expect(
      const BackgroundTaskInfo(taskId: 'm', taskType: 'monitor').isAgent,
      isFalse,
    );
  });

  test('only background agents defer the Claude completion', () {
    const shells = ChatSessionState(
      backgroundTasks: [
        BackgroundTaskInfo(taskId: 'b1', taskType: 'local_bash'),
        BackgroundTaskInfo(taskId: 'm1', taskType: 'monitor'),
      ],
    );
    expect(shells.hasBackgroundAgents, isFalse);
    expect(
      shells
          .copyWith(
            backgroundTasks: [
              ...shells.backgroundTasks,
              const BackgroundTaskInfo(taskId: 'a1', taskType: 'local_agent'),
            ],
          )
          .hasBackgroundAgents,
      isTrue,
    );
  });

  testWidgets('bar offers a stop button only when given one', (tester) async {
    var stopped = 0;
    Future<void> pump(VoidCallback? onStop) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BackgroundTasksBar(
            tasks: const [
              BackgroundTaskInfo(taskId: 'a1', taskType: 'local_agent'),
            ],
            onStop: onStop,
          ),
        ),
      ),
    );

    await pump(null);
    expect(
      find.byKey(const ValueKey('background_tasks_stop_button')),
      findsNothing,
    );

    await pump(() => stopped++);
    await tester.tap(
      find.byKey(const ValueKey('background_tasks_stop_button')),
    );
    expect(stopped, 1);
  });

  group('BackgroundCompletionGate', () {
    late bool settled;
    late int released;
    late BackgroundCompletionGate gate;

    void setUpGate() {
      settled = false;
      released = 0;
      gate = BackgroundCompletionGate(
        isSettled: () => settled,
        onRelease: () => released++,
      );
    }

    testWidgets('notifies directly without background work', (tester) async {
      setUpGate();
      expect(gate.hold(hasBackgroundWork: false), isFalse);
      expect(gate.isHolding, isFalse);
    });

    testWidgets('releases once the session stays settled', (tester) async {
      setUpGate();
      expect(gate.hold(hasBackgroundWork: true), isTrue);
      settled = true;
      gate.update();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(released, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(released, 1);
      expect(gate.isHolding, isFalse);
    });

    testWidgets('keeps holding when work resumes before settling', (
      tester,
    ) async {
      setUpGate();
      gate.hold(hasBackgroundWork: true);
      settled = true;
      gate.update();
      await tester.pump(const Duration(milliseconds: 500));
      settled = false;
      gate.update();
      await tester.pump(const Duration(seconds: 5));
      expect(released, 0);
      expect(gate.isHolding, isTrue);

      // A follow-up turn finished with nothing left in the background.
      expect(gate.hold(hasBackgroundWork: false), isFalse);
      expect(gate.isHolding, isFalse);
      gate.dispose();
    });
  });
}

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/session_runtime_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRuntimeStore', () {
    test('keeps goal state out of the chat timeline cache', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        const GoalStateMessage(
          sessionId: 's1',
          goal: CodexGoal(
            threadId: 'thread-1',
            objective: 'Goal',
            status: CodexThreadGoalStatus.active,
            tokenBudget: null,
            tokensUsed: 0,
            timeUsedSeconds: 0,
            createdAt: 1,
            updatedAt: 1,
          ),
        ),
      );

      expect(store.messages('s1'), isEmpty);
    });

    test('keeps repeated codex settings out of the chat timeline cache', () {
      final store = SessionRuntimeStore();
      const settings = SystemMessage(
        subtype: 'codex_settings',
        provider: 'codex',
        model: 'gpt-5.6-terra',
        modelReasoningEffort: 'xhigh',
        serviceTier: 'fast',
      );

      store.applyServerMessage('s1', settings);
      store.applyServerMessage('s1', settings);

      expect(store.messages('s1'), isEmpty);
    });

    test('keeps timeline and explorer history separated by session', () {
      final store = SessionRuntimeStore();

      store.applyServerMessage(
        's1',
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'a1',
            role: 'assistant',
            content: const [TextContent(text: 'one')],
            model: 'claude',
          ),
        ),
      );
      store.setExplorerHistory(
        's1',
        currentPath: '/repo/lib',
        recentPeekedFiles: const ['lib/main.dart'],
      );

      store.applyServerMessage(
        's2',
        const StatusMessage(status: ProcessStatus.running),
      );

      expect(store.messages('s1'), hasLength(1));
      expect(store.messages('s2'), hasLength(1));
      expect(store.getExplorerHistory('s1').currentPath, '/repo/lib');
      expect(store.getExplorerHistory('s2').currentPath, isEmpty);
    });

    test('history replaces the cached timeline', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'old',
            role: 'assistant',
            content: const [TextContent(text: 'old')],
            model: 'claude',
          ),
        ),
      );

      store.applyServerMessage(
        's1',
        HistoryMessage(
          messages: [
            const StatusMessage(status: ProcessStatus.idle),
            AssistantServerMessage(
              message: AssistantMessage(
                id: 'new',
                role: 'assistant',
                content: const [TextContent(text: 'new')],
                model: 'claude',
              ),
            ),
          ],
        ),
      );

      final messages = store.messages('s1');
      expect(messages, hasLength(2));
      expect(
        ((messages.last as AssistantServerMessage).message.content.single
                as TextContent)
            .text,
        'new',
      );
      expect(store.latestHistorySeq('s1'), 0);
      expect(store.cachedHistorySeq('s1'), 0);
    });

    test('history delta appends newer sequenced entries', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        const HistoryDeltaMessage(
          fromSeq: 1,
          toSeq: 2,
          entries: [
            HistoryEntry(
              seq: 2,
              message: StatusMessage(status: ProcessStatus.running),
            ),
          ],
        ),
      );

      expect(store.messages('s1'), hasLength(1));
      expect(store.latestHistorySeq('s1'), 2);
      expect(store.cachedHistorySeq('s1'), 0);
    });

    test('bootstrap history delta replaces unsequenced cached timeline', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'cached',
            role: 'assistant',
            content: const [TextContent(text: 'cached')],
            model: 'claude',
          ),
        ),
      );

      store.applyServerMessage(
        's1',
        const HistoryDeltaMessage(
          fromSeq: 1,
          toSeq: 1,
          entries: [
            HistoryEntry(
              seq: 1,
              message: StatusMessage(status: ProcessStatus.idle),
            ),
          ],
        ),
      );

      final messages = store.messages('s1');
      expect(messages, hasLength(1));
      expect(messages.single, isA<StatusMessage>());
      expect(store.latestHistorySeq('s1'), 1);
      expect(store.cachedHistorySeq('s1'), 1);
    });

    test('history snapshot replaces cached timeline and records sequence', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        const StatusMessage(status: ProcessStatus.running),
      );

      store.applyServerMessage(
        's1',
        const HistorySnapshotMessage(
          fromSeq: 5,
          toSeq: 7,
          reason: 'compacted',
          entries: [
            HistoryEntry(
              seq: 7,
              message: StatusMessage(status: ProcessStatus.idle),
            ),
          ],
        ),
      );

      final messages = store.messages('s1').cast<StatusMessage>();
      expect(messages, hasLength(1));
      expect(messages.single.status, ProcessStatus.idle);
      expect(store.latestHistorySeq('s1'), 7);
      expect(store.cachedHistorySeq('s1'), 7);
    });

    test('tracks latest and cached history sequence separately', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        const StatusMessage(status: ProcessStatus.starting),
        historySeq: 1,
      );
      store.applyServerMessage(
        's1',
        const InputAckMessage(clientMessageId: 'cm-1', acceptedSeq: 2),
        historySeq: 2,
      );
      store.applyServerMessage(
        's1',
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'assistant-1',
            role: 'assistant',
            content: const [TextContent(text: 'cached assistant')],
            model: 'gpt-5.5',
          ),
        ),
        historySeq: 4,
      );

      expect(store.latestHistorySeq('s1'), 4);
      expect(store.cachedHistorySeq('s1'), 1);

      store.applyServerMessage(
        's1',
        HistoryDeltaMessage(
          fromSeq: 2,
          toSeq: 4,
          entries: [
            const HistoryEntry(
              seq: 2,
              message: UserInputMessage(text: 'hi', clientMessageId: 'cm-1'),
            ),
            const HistoryEntry(
              seq: 3,
              message: StatusMessage(status: ProcessStatus.running),
            ),
            HistoryEntry(
              seq: 4,
              message: AssistantServerMessage(
                message: AssistantMessage(
                  id: 'assistant-1',
                  role: 'assistant',
                  content: const [TextContent(text: 'canonical assistant')],
                  model: 'gpt-5.5',
                ),
              ),
            ),
          ],
        ),
      );

      final messages = store.messages('s1');
      expect(messages.map((message) => message.runtimeType), [
        StatusMessage,
        UserInputMessage,
        StatusMessage,
        AssistantServerMessage,
      ]);
      expect((messages[1] as UserInputMessage).text, 'hi');
      expect(
        (((messages[3] as AssistantServerMessage).message.content.single)
                as TextContent)
            .text,
        'canonical assistant',
      );
      expect(store.latestHistorySeq('s1'), 4);
      expect(store.cachedHistorySeq('s1'), 4);
    });

    test('ignores transient stream deltas', () {
      final store = SessionRuntimeStore();

      store.applyServerMessage('s1', const StreamDeltaMessage(text: 'hello'));
      store.applyServerMessage('s1', const ThinkingDeltaMessage(text: 'hmm'));

      expect(store.messages('s1'), isEmpty);
    });

    test('migrates runtime state to a new session id', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        'pending',
        const StatusMessage(status: ProcessStatus.running),
      );
      store.setExplorerHistory(
        'pending',
        currentPath: '/repo',
        recentPeekedFiles: const ['README.md'],
      );

      store.migrateSession('pending', 'real');

      expect(store.messages('pending'), isEmpty);
      expect(store.getExplorerHistory('pending').currentPath, isEmpty);
      expect(store.messages('real'), hasLength(1));
      expect(store.getExplorerHistory('real').currentPath, '/repo');
      expect(store.latestHistorySeq('real'), 0);
      expect(store.cachedHistorySeq('real'), 0);
    });

    test('trims old messages per session', () {
      final store = SessionRuntimeStore(maxMessagesPerSession: 2);

      store.applyServerMessage(
        's1',
        const StatusMessage(status: ProcessStatus.starting),
      );
      store.applyServerMessage(
        's1',
        const StatusMessage(status: ProcessStatus.running),
      );
      store.applyServerMessage(
        's1',
        const StatusMessage(status: ProcessStatus.idle),
      );

      final messages = store.messages('s1').cast<StatusMessage>();
      expect(messages, hasLength(2));
      expect(messages.first.status, ProcessStatus.running);
      expect(messages.last.status, ProcessStatus.idle);
    });
  });
}

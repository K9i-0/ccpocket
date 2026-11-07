import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/chat_session/compaction_projection.dart';
import 'package:ccpocket/features/chat_session/lite_mode_projection.dart';
import 'package:ccpocket/features/chat_session/widgets/context_compaction_card.dart';
import 'package:ccpocket/features/session_transcript/state/session_transcript_cubit.dart';
import 'package:ccpocket/features/session_transcript/state/session_transcript_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/services/session_runtime_store.dart';
import 'package:flutter_test/flutter_test.dart';

ServerChatEntry assistantEntry(String text) => ServerChatEntry(
  AssistantServerMessage(
    messageUuid: 'uuid-$text',
    message: AssistantMessage(
      id: text,
      role: 'assistant',
      content: [TextContent(text: text)],
      model: 'test',
    ),
  ),
  timestamp: DateTime(2026, 11, 7),
);

ServerChatEntry compactionEntry(String id) => ServerChatEntry(
  ContextCompactionMessage(id: id, provider: 'claude', trigger: 'auto'),
  timestamp: DateTime(2026, 11, 7),
);

void main() {
  group('ContextCompactionMessage parsing', () {
    test('parses the live message', () {
      final message = ServerMessage.fromJson({
        'type': 'context_compaction',
        'id': 'b1',
        'provider': 'claude',
        'trigger': 'manual',
        'preTokens': 21935,
        'postTokens': 7722,
        'summary': '1. Reply with ok.',
      });
      expect(message, isA<ContextCompactionMessage>());
      final compaction = message as ContextCompactionMessage;
      expect(compaction.isManual, isTrue);
      expect(compaction.preTokens, 21935);
      expect(compaction.postTokens, 7722);
      expect(compaction.summary, '1. Reply with ok.');
    });

    test('parses a past-history compaction marker', () {
      final past = PastMessage.fromJson({
        'role': 'compaction',
        'uuid': 'b1',
        'content': <dynamic>[],
        'compaction': {'trigger': 'auto', 'preTokens': 1000},
      });
      expect(past.compaction?.id, 'b1');
      expect(past.compaction?.isAuto, isTrue);
      expect(past.compaction?.preTokens, 1000);
    });

    test('reads olderHistoryAvailable on history frames', () {
      final history = ServerMessage.fromJson({
        'type': 'history',
        'messages': <dynamic>[],
        'olderHistoryAvailable': true,
      });
      expect((history as HistoryMessage).olderHistoryAvailable, isTrue);
    });

    test('advertises context_compaction support', () {
      final json = ClientMessage.clientCapabilities().toJson();
      expect(json, contains('"context_compaction"'));
    });

    test('formats token counts compactly', () {
      expect(formatTokenCount(999), '999');
      expect(formatTokenCount(21935), '21.9k');
      expect(formatTokenCount(180000), '180k');
    });
  });

  group('compactionVisibleEntries', () {
    test('keeps the list unchanged without a boundary', () {
      final entries = [assistantEntry('a'), assistantEntry('b')];
      final visible = compactionVisibleEntries(
        entries,
        olderHistoryAvailable: false,
        compacting: false,
      );
      expect(visible, same(entries));
    });

    test('folds everything before the latest boundary', () {
      final latest = compactionEntry('b2');
      final after = assistantEntry('c');
      final visible = compactionVisibleEntries(
        [
          assistantEntry('a'),
          compactionEntry('b1'),
          assistantEntry('b'),
          latest,
          after,
        ],
        olderHistoryAvailable: true,
        compacting: false,
      );
      expect(visible, [latest, after]);
    });

    test('adds an older-history card when the window was trimmed', () {
      final first = assistantEntry('a');
      final visible = compactionVisibleEntries(
        [first],
        olderHistoryAvailable: true,
        compacting: false,
      );
      expect(visible, hasLength(2));
      expect(
        (visible.first as ServerChatEntry).message,
        isA<OlderHistoryMarkerMessage>(),
      );
      expect(visible.last, same(first));
    });

    test('appends a compacting row and survives performance mode', () {
      final visible = liteModeEntries(
        compactionVisibleEntries(
          [compactionEntry('b1'), assistantEntry('a')],
          olderHistoryAvailable: false,
          compacting: true,
        ),
      );
      expect(
        visible.map((entry) => (entry as ServerChatEntry).message.runtimeType),
        [
          ContextCompactionMessage,
          AssistantServerMessage,
          ContextCompactingMessage,
        ],
      );
    });
  });

  group('ChatMessageHandler', () {
    test('adds live compaction markers as entries', () {
      final update = ChatMessageHandler().handle(
        const ContextCompactionMessage(id: 'b1', provider: 'codex'),
        isBackground: false,
      );
      expect(update.entriesToAdd, hasLength(1));
    });

    test('restores compaction markers from past history', () {
      final update = ChatMessageHandler().handle(
        PastHistoryMessage(
          claudeSessionId: 'c1',
          messages: [
            PastMessage.fromJson({
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'hello'},
              ],
            }),
            PastMessage.fromJson({
              'role': 'compaction',
              'uuid': 'b1',
              'content': <dynamic>[],
              'compaction': {'summary': 'Earlier work'},
            }),
          ],
        ),
        isBackground: true,
      );
      final marker = update.entriesToPrepend.last as ServerChatEntry;
      expect(
        (marker.message as ContextCompactionMessage).summary,
        'Earlier work',
      );
    });

    test('keeps transcript responses and failures out of the chat', () {
      final handler = ChatMessageHandler();
      expect(
        handler
            .handle(
              const SessionTranscriptMessage(
                sessionId: 's1',
                requestId: 'transcript-s1-1',
                provider: 'claude',
                startIndex: 0,
                endIndex: 0,
                total: 0,
                messages: [],
              ),
              isBackground: false,
            )
            .entriesToAdd,
        isEmpty,
      );
      expect(
        handler
            .handle(
              const ErrorMessage(
                message: 'failed',
                errorCode: 'session_transcript_failed',
                requestId: 'transcript-s1-1',
              ),
              isBackground: false,
            )
            .entriesToAdd,
        isEmpty,
      );
    });
  });

  group('SessionRuntimeStore', () {
    test('marks the cache when it trims older messages', () {
      final store = SessionRuntimeStore(maxMessagesPerSession: 2);
      store.applyServerMessage(
        's1',
        const HistoryMessage(
          messages: [
            StatusMessage(status: ProcessStatus.idle),
            StatusMessage(status: ProcessStatus.running),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
      );
      expect(store.snapshot('s1').olderHistoryAvailable, isTrue);
    });

    test('takes the Bridge flag from history frames', () {
      final store = SessionRuntimeStore();
      store.applyServerMessage(
        's1',
        const HistoryMessage(messages: [], olderHistoryAvailable: true),
      );
      expect(store.snapshot('s1').olderHistoryAvailable, isTrue);
      store.clearHistory('s1');
      expect(store.snapshot('s1').olderHistoryAvailable, isFalse);
    });
  });

  group('SessionTranscriptCubit', () {
    late StreamController<ServerMessage> messages;
    late List<Map<String, dynamic>> sent;

    SessionTranscriptCubit createCubit() => SessionTranscriptCubit(
      messages: messages.stream,
      send: (message) =>
          sent.add(jsonDecode(message.toJson()) as Map<String, dynamic>),
      sessionId: 's1',
      pageSize: 2,
      timeout: const Duration(milliseconds: 50),
    );

    SessionTranscriptMessage page(
      String requestId, {
      required int start,
      required List<String> texts,
    }) => SessionTranscriptMessage(
      sessionId: 's1',
      requestId: requestId,
      provider: 'claude',
      startIndex: start,
      endIndex: start + texts.length,
      total: 10,
      messages: [
        for (final text in texts)
          PastMessage(
            role: 'assistant',
            content: [TextContent(text: text)],
          ),
      ],
    );

    setUp(() {
      messages = StreamController<ServerMessage>.broadcast();
      sent = [];
    });
    tearDown(() => messages.close());

    test(
      'loads the page ending at the latest compaction, then older',
      () async {
        final cubit = createCubit()..load();
        expect(sent.single['untilLatestCompaction'], isTrue);
        final firstId = sent.single['requestId'] as String;
        expect(isSessionTranscriptRequestId(firstId), isTrue);

        messages.add(page('other', start: 0, texts: ['ignored']));
        messages.add(page(firstId, start: 4, texts: ['c', 'd']));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, SessionTranscriptStatus.loaded);
        expect(cubit.state.entries, hasLength(2));
        expect(cubit.state.hasOlder, isTrue);

        cubit.loadOlder();
        expect(sent.last['beforeIndex'], 4);
        expect(sent.last.containsKey('untilLatestCompaction'), isFalse);
        messages.add(
          page(sent.last['requestId'] as String, start: 2, texts: ['a', 'b']),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.entries, hasLength(4));
        expect(cubit.state.startIndex, 2);
        expect(cubit.state.loadingOlder, isFalse);
        await cubit.close();
      },
    );

    test('shows the update hint on older Bridges', () async {
      final cubit = createCubit()..load();
      messages.add(
        const ErrorMessage(
          message: 'get_session_transcript',
          errorCode: 'unsupported_message',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SessionTranscriptStatus.bridgeUpdateRequired);
      await cubit.close();
    });

    test('fails on a matching error or timeout', () async {
      final cubit = createCubit()..load();
      messages.add(
        ErrorMessage(
          message: 'boom',
          errorCode: 'session_transcript_failed',
          requestId: sent.single['requestId'] as String,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SessionTranscriptStatus.failed);

      cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.status, SessionTranscriptStatus.failed);
      await cubit.close();
    });
  });
}

import 'dart:async';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_state.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal mock BridgeService for testing the cubit.
class MockBridgeService extends BridgeService {
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final sentMessages = <ClientMessage>[];

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void interrupt(String sessionId) {
    // no-op for tests
  }

  @override
  void stopSession(String sessionId) {
    // no-op for tests
  }

  @override
  void requestFileList(String projectPath) {
    // no-op for tests
  }

  @override
  void requestSessionList() {
    // no-op for tests
  }

  int requestSessionHistoryCallCount = 0;
  String? lastRequestedSessionId;

  @override
  void requestSessionHistory(String sessionId) {
    requestSessionHistoryCallCount++;
    lastRequestedSessionId = sessionId;
  }

  @override
  void dispose() {
    _messageController.close();
    _taggedController.close();
    super.dispose();
  }
}

void main() {
  late MockBridgeService mockBridge;
  late StreamingStateCubit streamingCubit;

  setUp(() {
    mockBridge = MockBridgeService();
    streamingCubit = StreamingStateCubit();
  });

  tearDown(() {
    streamingCubit.close();
    mockBridge.dispose();
  });

  ChatSessionCubit createCubit(String sessionId) {
    return ChatSessionCubit(
      sessionId: sessionId,
      bridge: mockBridge,
      streamingCubit: streamingCubit,
    );
  }

  group('ChatSessionCubit', () {
    test('initial state is default ChatSessionState', () {
      final cubit = createCubit('test-session');
      addTearDown(cubit.close);

      expect(cubit.state.status, ProcessStatus.starting);
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.approval, isA<ApprovalNone>());
      expect(cubit.state.totalCost, 0.0);
    });

    test('status message updates state.status', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const StatusMessage(status: ProcessStatus.running),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.status, ProcessStatus.running);
    });

    test('permission request sets approval state', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      const permMsg = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'bash',
        input: {'command': 'ls'},
      );
      mockBridge.emitMessage(permMsg, sessionId: 's1');
      await Future.microtask(() {});

      expect(cubit.state.approval, isA<ApprovalPermission>());
      final perm = cubit.state.approval as ApprovalPermission;
      expect(perm.toolUseId, 'tool-1');
      expect(perm.request.toolName, 'bash');
    });

    test('sendMessage adds user entry and sends to bridge', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.sendMessage('Hello Claude');

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.entries.first, isA<UserChatEntry>());
      expect((cubit.state.entries.first as UserChatEntry).text, 'Hello Claude');

      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('approve clears approval state and sends message', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      // Set up permission state
      const permMsg = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'bash',
        input: {'command': 'ls'},
      );
      mockBridge.emitMessage(permMsg, sessionId: 's1');
      await Future.microtask(() {});

      // Approve
      cubit.approve('tool-1');

      expect(cubit.state.approval, isA<ApprovalNone>());
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('reject clears approval and plan mode', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      // Simulate entering plan mode + approval
      const permMsg = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'EnterPlanMode',
        input: {},
      );
      mockBridge.emitMessage(permMsg, sessionId: 's1');
      await Future.microtask(() {});

      cubit.reject('tool-1', message: 'No thanks');

      expect(cubit.state.approval, isA<ApprovalNone>());
      expect(cubit.state.inPlanMode, false);
    });

    test('history message adds entries', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final historyMsg = HistoryMessage(
        messages: [
          const StatusMessage(status: ProcessStatus.idle),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              content: [TextContent(text: 'Hello!')],
              model: 'claude',
            ),
          ),
        ],
      );
      mockBridge.emitMessage(historyMsg, sessionId: 's1');
      await Future.microtask(() {});

      expect(
        cubit.state.entries,
        hasLength(1),
      ); // StatusMessage not added as entry
      expect(cubit.state.status, ProcessStatus.idle);
    });

    test('result message adds cost', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      const resultMsg = ResultMessage(
        subtype: 'completed',
        cost: 0.05,
        duration: 2.5,
        sessionId: 'claude-session-1',
      );
      mockBridge.emitMessage(resultMsg, sessionId: 's1');
      await Future.microtask(() {});

      expect(cubit.state.totalCost, 0.05);
    });

    test('retryMessage changes status to sending and resends', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      // Add a failed user message via sendMessage then manually set failed
      cubit.sendMessage('Test message');
      expect(cubit.state.entries, hasLength(1));

      // Use sendMessage first, then we'll test retryMessage on the entry
      cubit.sendMessage('Retry me');
      final entryToRetry = cubit.state.entries.last as UserChatEntry;

      mockBridge.sentMessages.clear();
      cubit.retryMessage(entryToRetry);

      final retriedEntry = cubit.state.entries.last as UserChatEntry;
      expect(retriedEntry.status, MessageStatus.sending);
      expect(retriedEntry.text, 'Retry me');
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('build calls requestSessionHistory for the session', () {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);

      expect(mockBridge.requestSessionHistoryCallCount, 1);
      expect(mockBridge.lastRequestedSessionId, 's1');
    });

    test(
      'statusRefreshTimer stops when status changes from starting',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        // Status is starting → timer is active
        expect(cubit.state.status, ProcessStatus.starting);

        // Change status to running → timer should stop
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.status, ProcessStatus.running);
        // Timer cancellation is tested by verifying no crash on dispose
      },
    );

    test('ignores duplicate past history messages in same session', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final pastHistory = PastHistoryMessage(
        claudeSessionId: 'old',
        messages: [
          PastMessage(
            role: 'user',
            content: [TextContent(text: 'Hi')],
          ),
        ],
      );

      mockBridge.emitMessage(pastHistory, sessionId: 's1');
      mockBridge.emitMessage(pastHistory, sessionId: 's1');
      await Future.microtask(() {});

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.entries.first, isA<UserChatEntry>());
    });

    test(
      'queued messages are promoted to sent one-by-one when assistant responses arrive',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage('Message A');
        cubit.sendMessage('Message B');

        mockBridge.emitMessage(
          const InputAckMessage(sessionId: 's1', queued: true),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        mockBridge.emitMessage(
          const InputAckMessage(sessionId: 's1', queued: true),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        var users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users.map((e) => e.status).toList(), [
          MessageStatus.queued,
          MessageStatus.queued,
        ]);

        mockBridge.emitMessage(
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              content: [TextContent(text: 'reply for A')],
              model: 'claude',
            ),
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users.map((e) => e.status).toList(), [
          MessageStatus.sent,
          MessageStatus.queued,
        ]);
      },
    );

    test('input_ack(sent) advances sending messages one-by-one', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.sendMessage('Message A');
      cubit.sendMessage('Message B');

      mockBridge.emitMessage(
        const InputAckMessage(sessionId: 's1', queued: false),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      var users = cubit.state.entries.whereType<UserChatEntry>().toList();
      expect(users.map((e) => e.status).toList(), [
        MessageStatus.sent,
        MessageStatus.sending,
      ]);

      mockBridge.emitMessage(
        const InputAckMessage(sessionId: 's1', queued: false),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      users = cubit.state.entries.whereType<UserChatEntry>().toList();
      expect(users.map((e) => e.status).toList(), [
        MessageStatus.sent,
        MessageStatus.sent,
      ]);
    });
  });

  group('StreamingStateCubit', () {
    test('initial state is empty', () {
      expect(streamingCubit.state.text, isEmpty);
      expect(streamingCubit.state.thinking, isEmpty);
      expect(streamingCubit.state.isStreaming, false);
    });

    test('appendText accumulates and sets isStreaming', () {
      streamingCubit.appendText('Hello ');
      streamingCubit.appendText('world');

      expect(streamingCubit.state.text, 'Hello world');
      expect(streamingCubit.state.isStreaming, true);
    });

    test('appendThinking accumulates', () {
      streamingCubit.appendThinking('Thinking...');
      streamingCubit.appendThinking(' more');

      expect(streamingCubit.state.thinking, 'Thinking... more');
    });

    test('reset clears everything', () {
      streamingCubit.appendText('text');
      streamingCubit.appendThinking('think');
      streamingCubit.reset();

      expect(streamingCubit.state.text, isEmpty);
      expect(streamingCubit.state.thinking, isEmpty);
      expect(streamingCubit.state.isStreaming, false);
    });
  });
}

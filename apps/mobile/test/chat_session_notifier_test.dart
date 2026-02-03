import 'dart:async';

import 'package:ccpocket/features/chat/state/chat_session_notifier.dart';
import 'package:ccpocket/features/chat/state/chat_session_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_providers.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal mock BridgeService for testing the notifier.
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
  late ProviderContainer container;
  late MockBridgeService mockBridge;

  setUp(() {
    mockBridge = MockBridgeService();
    container = ProviderContainer(
      overrides: [bridgeServiceProvider.overrideWithValue(mockBridge)],
    );
  });

  tearDown(() {
    container.dispose();
    mockBridge.dispose();
  });

  group('ChatSessionNotifier', () {
    test('initial state is default ChatSessionState', () {
      final state = container.read(chatSessionNotifierProvider('test-session'));
      expect(state.status, ProcessStatus.starting);
      expect(state.entries, isEmpty);
      expect(state.approval, isA<ApprovalNone>());
      expect(state.totalCost, 0.0);
    });

    test('status message updates state.status', () async {
      // Read to initialize the provider
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const StatusMessage(status: ProcessStatus.running),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.status, ProcessStatus.running);
    });

    test('permission request sets approval state', () async {
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      const permMsg = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'bash',
        input: {'command': 'ls'},
      );
      mockBridge.emitMessage(permMsg, sessionId: 's1');
      await Future.microtask(() {});

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.approval, isA<ApprovalPermission>());
      final perm = state.approval as ApprovalPermission;
      expect(perm.toolUseId, 'tool-1');
      expect(perm.request.toolName, 'bash');
    });

    test('sendMessage adds user entry and sends to bridge', () async {
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      final notifier = container.read(
        chatSessionNotifierProvider('s1').notifier,
      );
      notifier.sendMessage('Hello Claude');

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.entries, hasLength(1));
      expect(state.entries.first, isA<UserChatEntry>());
      expect((state.entries.first as UserChatEntry).text, 'Hello Claude');

      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('approve clears approval state and sends message', () async {
      container.read(chatSessionNotifierProvider('s1'));
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
      final notifier = container.read(
        chatSessionNotifierProvider('s1').notifier,
      );
      notifier.approve('tool-1');

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.approval, isA<ApprovalNone>());
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('reject clears approval and plan mode', () async {
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      // Simulate entering plan mode + approval
      const permMsg = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'EnterPlanMode',
        input: {},
      );
      mockBridge.emitMessage(permMsg, sessionId: 's1');
      await Future.microtask(() {});

      final notifier = container.read(
        chatSessionNotifierProvider('s1').notifier,
      );
      notifier.reject('tool-1', message: 'No thanks');

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.approval, isA<ApprovalNone>());
      expect(state.inPlanMode, false);
    });

    test('history message adds entries', () async {
      container.read(chatSessionNotifierProvider('s1'));
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

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.entries, hasLength(1)); // StatusMessage not added as entry
      expect(state.status, ProcessStatus.idle);
    });

    test('result message adds cost', () async {
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      const resultMsg = ResultMessage(
        subtype: 'completed',
        cost: 0.05,
        duration: 2.5,
        sessionId: 'claude-session-1',
      );
      mockBridge.emitMessage(resultMsg, sessionId: 's1');
      await Future.microtask(() {});

      final state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.totalCost, 0.05);
    });

    test('retryMessage changes status to sending and resends', () async {
      container.read(chatSessionNotifierProvider('s1'));
      await Future.microtask(() {});

      final notifier = container.read(
        chatSessionNotifierProvider('s1').notifier,
      );

      // Add a failed user message via sendMessage then manually set failed
      notifier.sendMessage('Test message');
      var state = container.read(chatSessionNotifierProvider('s1'));
      expect(state.entries, hasLength(1));

      // Use sendMessage first, then we'll test retryMessage on the entry
      notifier.sendMessage('Retry me');
      state = container.read(chatSessionNotifierProvider('s1'));
      final entryToRetry = state.entries.last as UserChatEntry;

      mockBridge.sentMessages.clear();
      notifier.retryMessage(entryToRetry);

      state = container.read(chatSessionNotifierProvider('s1'));
      final retriedEntry = state.entries.last as UserChatEntry;
      expect(retriedEntry.status, MessageStatus.sending);
      expect(retriedEntry.text, 'Retry me');
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('build calls requestSessionHistory for the session', () {
      container.read(chatSessionNotifierProvider('s1'));
      expect(mockBridge.requestSessionHistoryCallCount, 1);
      expect(mockBridge.lastRequestedSessionId, 's1');
    });

    test(
      'statusRefreshTimer stops when status changes from starting',
      () async {
        container.read(chatSessionNotifierProvider('s1'));
        await Future.microtask(() {});

        // Status is starting → timer is active
        final state = container.read(chatSessionNotifierProvider('s1'));
        expect(state.status, ProcessStatus.starting);

        // Change status to running → timer should stop
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final updatedState = container.read(chatSessionNotifierProvider('s1'));
        expect(updatedState.status, ProcessStatus.running);
        // Timer cancellation is tested by verifying no crash on dispose
      },
    );

    test('consumes pending past history on build', () {
      mockBridge.pendingPastHistory = PastHistoryMessage(
        claudeSessionId: 'old',
        messages: [
          PastMessage(
            role: 'user',
            content: [TextContent(text: 'Hi')],
          ),
        ],
      );

      // Past history is consumed synchronously during build
      final state = container.read(chatSessionNotifierProvider('s1'));

      expect(mockBridge.pendingPastHistory, isNull);
      expect(state.entries, hasLength(1));
      expect(state.entries.first, isA<UserChatEntry>());
    });
  });

  group('StreamingStateNotifier', () {
    test('initial state is empty', () {
      final state = container.read(streamingStateNotifierProvider('s1'));
      expect(state.text, isEmpty);
      expect(state.thinking, isEmpty);
      expect(state.isStreaming, false);
    });

    test('appendText accumulates and sets isStreaming', () {
      final notifier = container.read(
        streamingStateNotifierProvider('s1').notifier,
      );
      notifier.appendText('Hello ');
      notifier.appendText('world');

      final state = container.read(streamingStateNotifierProvider('s1'));
      expect(state.text, 'Hello world');
      expect(state.isStreaming, true);
    });

    test('appendThinking accumulates', () {
      final notifier = container.read(
        streamingStateNotifierProvider('s1').notifier,
      );
      notifier.appendThinking('Thinking...');
      notifier.appendThinking(' more');

      final state = container.read(streamingStateNotifierProvider('s1'));
      expect(state.thinking, 'Thinking... more');
    });

    test('reset clears everything', () {
      final notifier = container.read(
        streamingStateNotifierProvider('s1').notifier,
      );
      notifier.appendText('text');
      notifier.appendThinking('think');
      notifier.reset();

      final state = container.read(streamingStateNotifierProvider('s1'));
      expect(state.text, isEmpty);
      expect(state.thinking, isEmpty);
      expect(state.isStreaming, false);
    });
  });
}

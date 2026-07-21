import 'dart:async';
import 'dart:convert';

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
  final updatedOfflineInputs = <Map<String, dynamic>>[];
  final canceledOfflineInputs = <Map<String, dynamic>>[];
  final cachedMessagesBySession = <String, List<ServerMessage>>{};
  final historySeqBySession = <String, int>{};
  bool connected = true;

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  bool get isConnected => connected;

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
  Future<bool> updateOfflinePendingInput({
    required String sessionId,
    required String clientMessageId,
    required String text,
    List<Map<String, String>>? skills,
    List<Map<String, String>>? mentions,
  }) async {
    updatedOfflineInputs.add({
      'sessionId': sessionId,
      'clientMessageId': clientMessageId,
      'text': text,
      'skills': skills,
      'mentions': mentions,
    });
    return true;
  }

  @override
  Future<bool> cancelOfflinePendingInput({
    required String sessionId,
    required String clientMessageId,
  }) async {
    canceledOfflineInputs.add({
      'sessionId': sessionId,
      'clientMessageId': clientMessageId,
    });
    return true;
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
  List<ServerMessage> cachedSessionMessages(String sessionId) {
    return cachedMessagesBySession[sessionId] ?? const [];
  }

  @override
  int cachedSessionHistorySeq(String sessionId) {
    return historySeqBySession[sessionId] ?? 0;
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

  ChatSessionCubit createCubit(
    String sessionId, {
    Provider? provider,
    String? initialProjectPath,
  }) {
    return ChatSessionCubit(
      sessionId: sessionId,
      provider: provider,
      bridge: mockBridge,
      streamingCubit: streamingCubit,
      initialProjectPath: initialProjectPath,
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

    test(
      'initial project path is available before bridge metadata arrives',
      () {
        final cubit = createCubit(
          's1',
          initialProjectPath: '/Users/me/Workspace/ccpocket',
        );
        addTearDown(cubit.close);

        expect(cubit.state.projectPath, '/Users/me/Workspace/ccpocket');
      },
    );

    test('system message updates project path metadata', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const SystemMessage(
          subtype: 'session_created',
          projectPath: '/Users/me/Workspace/ccpocket',
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.projectPath, '/Users/me/Workspace/ccpocket');
    });

    test('history message restores project path metadata', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const HistoryMessage(
          messages: [
            SystemMessage(
              subtype: 'session_created',
              projectPath: '/Users/me/Workspace/ccpocket',
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.projectPath, '/Users/me/Workspace/ccpocket');
    });

    test(
      'codex explicit execution mode wins over legacy permission mode',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        mockBridge.emitMessage(
          const SystemMessage(
            subtype: 'set_permission_mode',
            provider: 'codex',
            permissionMode: 'acceptEdits',
            executionMode: 'default',
            planMode: false,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.executionMode, ExecutionMode.defaultMode);
        expect(cubit.state.planMode, isFalse);
      },
    );

    test(
      'codex initial on-failure approval policy falls back to on-request',
      () {
        final cubit = ChatSessionCubit(
          sessionId: 's1',
          provider: Provider.codex,
          bridge: mockBridge,
          streamingCubit: streamingCubit,
          initialPermissionMode: PermissionMode.acceptEdits,
          initialCodexApprovalPolicy: CodexApprovalPolicy.onFailure,
        );
        addTearDown(cubit.close);

        expect(cubit.state.codexApprovalPolicy, CodexApprovalPolicy.onRequest);
      },
    );

    test('codex auto review mode sends on-request with auto reviewer', () {
      final cubit = ChatSessionCubit(
        sessionId: 's1',
        provider: Provider.codex,
        bridge: mockBridge,
        streamingCubit: streamingCubit,
        initialPermissionMode: PermissionMode.acceptEdits,
      );
      addTearDown(cubit.close);

      cubit.setCodexApprovalPolicy(
        CodexApprovalPolicy.onRequest,
        approvalsReviewer: 'auto_review',
      );

      expect(cubit.state.codexApprovalPolicy, CodexApprovalPolicy.onRequest);
      expect(cubit.state.codexApprovalsReviewer, 'auto_review');
      final payload =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(payload['approvalPolicy'], 'on-request');
      expect(payload['approvalsReviewer'], 'auto_review');
    });

    test(
      'codex sandbox-only system message does not reset execution mode',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        mockBridge.emitMessage(
          const SystemMessage(
            subtype: 'set_permission_mode',
            provider: 'codex',
            permissionMode: 'bypassPermissions',
            executionMode: 'fullAccess',
            planMode: false,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.executionMode, ExecutionMode.fullAccess);

        mockBridge.emitMessage(
          const SystemMessage(
            subtype: 'session_created',
            provider: 'codex',
            sandboxMode: 'off',
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.executionMode, ExecutionMode.fullAccess);
        expect(cubit.state.planMode, isFalse);
      },
    );

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
      final entry = cubit.state.entries.first as UserChatEntry;
      expect(entry.text, 'Hello Claude');
      expect(entry.clientMessageId, isNotNull);

      expect(mockBridge.sentMessages, hasLength(1));
      final payload =
          jsonDecode(mockBridge.sentMessages.single.toJson())
              as Map<String, dynamic>;
      expect(payload['clientMessageId'], entry.clientMessageId);
      expect(payload.containsKey('baseSeq'), isFalse);
    });

    test('Codex /goal command sets goal without creating a chat turn', () {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      cubit.sendMessage('/goal Goal機能をCC Pocketに追加する');

      expect(cubit.state.entries, isEmpty);
      expect(mockBridge.sentMessages, hasLength(1));
      expect(
        jsonDecode(mockBridge.sentMessages.single.toJson()),
        <String, dynamic>{
          'type': 'set_goal',
          'sessionId': 's1',
          'objective': 'Goal機能をCC Pocketに追加する',
        },
      );
    });

    test('Codex /goal subcommands use goal RPCs instead of objectives', () {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      cubit.sendMessage('/goal pause');
      cubit.sendMessage('/goal resume');
      cubit.sendMessage('/goal clear');

      expect(cubit.state.entries, isEmpty);
      expect(
        mockBridge.sentMessages
            .map((message) => jsonDecode(message.toJson()))
            .toList(),
        [
          {'type': 'set_goal', 'sessionId': 's1', 'status': 'paused'},
          {'type': 'set_goal', 'sessionId': 's1', 'status': 'active'},
          {'type': 'clear_goal', 'sessionId': 's1'},
        ],
      );
    });

    test('Codex requests persisted goal after app-server init', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      mockBridge.emitMessage(
        const SystemMessage(subtype: 'init', sessionId: 'thread-1'),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
        'type': 'get_goal',
        'sessionId': 's1',
      });
    });

    test(
      'Codex goal state supports refresh, pause, resume, and clear',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);

        cubit.sendMessage('/goal');
        expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
          'type': 'get_goal',
          'sessionId': 's1',
        });

        const goal = CodexGoal(
          threadId: 'thread-1',
          objective: 'Persisted goal',
          status: CodexThreadGoalStatus.active,
          tokenBudget: null,
          tokensUsed: 10,
          timeUsedSeconds: 5,
          createdAt: 1,
          updatedAt: 2,
        );
        mockBridge.emitMessage(
          const GoalStateMessage(sessionId: 's1', goal: goal),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        expect(cubit.state.goal, goal);

        mockBridge.sentMessages.clear();
        cubit.toggleGoalPaused();
        expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
          'type': 'set_goal',
          'sessionId': 's1',
          'status': 'paused',
        });

        mockBridge.emitMessage(
          const GoalStateMessage(
            sessionId: 's1',
            goal: CodexGoal(
              threadId: 'thread-1',
              objective: 'Persisted goal',
              status: CodexThreadGoalStatus.paused,
              tokenBudget: null,
              tokensUsed: 10,
              timeUsedSeconds: 5,
              createdAt: 1,
              updatedAt: 3,
            ),
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        mockBridge.sentMessages.clear();
        cubit.toggleGoalPaused();
        expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
          'type': 'set_goal',
          'sessionId': 's1',
          'status': 'active',
        });

        mockBridge.sentMessages.clear();
        cubit.clearGoal();
        expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
          'type': 'clear_goal',
          'sessionId': 's1',
        });
      },
    );

    test('sendMessage while disconnected queues entry with baseSeq', () async {
      mockBridge.connected = false;
      mockBridge.historySeqBySession['s1'] = 9;
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.sendMessage('Offline input');

      final entry = cubit.state.entries.single as UserChatEntry;
      expect(entry.status, MessageStatus.queued);
      expect(entry.clientMessageId, isNotNull);

      final payload =
          jsonDecode(mockBridge.sentMessages.single.toJson())
              as Map<String, dynamic>;
      expect(payload['clientMessageId'], entry.clientMessageId);
      expect(payload['baseSeq'], 9);
    });

    test(
      'codex sendMessage while disconnected uses queued input panel state',
      () async {
        mockBridge.connected = false;
        mockBridge.historySeqBySession['s1'] = 7;
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage('Offline Codex input');
        cubit.sendMessage('Second input is blocked');

        expect(cubit.state.entries.whereType<UserChatEntry>(), isEmpty);
        expect(cubit.state.queuedInput?.text, 'Offline Codex input');
        expect(
          ChatSessionCubit.isOfflineQueuedInput(cubit.state.queuedInput),
          isTrue,
        );
        expect(mockBridge.sentMessages, hasLength(1));

        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        expect(payload['type'], 'input');
        expect(payload['text'], 'Offline Codex input');
        expect(payload['baseSeq'], 7);
        expect(
          ChatSessionCubit.offlineQueuedClientMessageId(
            cubit.state.queuedInput,
          ),
          payload['clientMessageId'],
        );

        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
            acceptedSeq: 8,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        expect(cubit.state.queuedInput, isNull);
      },
    );

    test(
      'codex online input moves to queue panel when delivery ack is slow',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Slow online Codex input');

        var users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.status, MessageStatus.sending);
        expect(cubit.state.queuedInput, isNull);

        await Future<void>.delayed(const Duration(milliseconds: 650));

        users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, isEmpty);
        expect(cubit.state.queuedInput?.text, 'Slow online Codex input');
        expect(
          ChatSessionCubit.isDeliveryPendingQueuedInput(
            cubit.state.queuedInput,
          ),
          isTrue,
        );

        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.queuedInput, isNull);
        users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Slow online Codex input');
        expect(users.single.status, MessageStatus.sent);
      },
    );

    test(
      'codex online input ack before delay keeps normal message entry',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Fast online Codex input');
        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        await Future<void>.delayed(const Duration(milliseconds: 650));

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.status, MessageStatus.sent);
        expect(cubit.state.queuedInput, isNull);
      },
    );

    test(
      'codex first input sent while starting is shown when ack arrives before delay',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        expect(cubit.state.status, ProcessStatus.starting);

        cubit.sendMessage('First Codex input while starting');

        expect(cubit.state.entries.whereType<UserChatEntry>(), isEmpty);
        expect(cubit.state.queuedInput, isNull);

        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
            queued: false,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        await Future<void>.delayed(const Duration(milliseconds: 650));

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'First Codex input while starting');
        expect(users.single.status, MessageStatus.sent);
        expect(cubit.state.queuedInput, isNull);
      },
    );

    test(
      'codex restored user input delta does not duplicate delivery pending entry',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Restored pending input');
        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        final clientMessageId = payload['clientMessageId'] as String;

        await Future<void>.delayed(const Duration(milliseconds: 650));
        mockBridge.emitMessage(
          InputAckMessage(sessionId: 's1', clientMessageId: clientMessageId),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.queuedInput, isNull);
        expect(cubit.state.entries.whereType<UserChatEntry>(), hasLength(1));

        mockBridge.emitMessage(
          UserInputMessage(
            text: 'Restored pending input',
            clientMessageId: clientMessageId,
            timestamp: '2026-04-28T12:00:00.000Z',
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Restored pending input');
        expect(users.single.status, MessageStatus.sent);
      },
    );

    test(
      'codex user_input with UUID and no local entry is displayed',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);

        mockBridge.emitMessage(
          const UserInputMessage(
            text: 'Message from another client',
            userMessageUuid: 'codex:user-turn:7',
            timestamp: '2026-04-28T12:00:00.000Z',
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Message from another client');
        expect(users.single.status, MessageStatus.sent);
        expect(users.single.messageUuid, 'codex:user-turn:7');
      },
    );

    test(
      'duplicate codex UUID user_input does not add a second entry',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        const userInput = UserInputMessage(
          text: 'Steered queued message',
          userMessageUuid: 'codex:user-turn:8',
          timestamp: '2026-04-28T12:00:00.000Z',
        );

        mockBridge.emitMessage(userInput, sessionId: 's1');
        mockBridge.emitMessage(userInput, sessionId: 's1');
        await Future.microtask(() {});

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Steered queued message');
        expect(users.single.messageUuid, 'codex:user-turn:8');
      },
    );

    test(
      'history replace keeps live tail without duplicating matched user input',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        mockBridge.emitMessage(
          const SystemMessage(subtype: 'init', provider: 'codex'),
          sessionId: 's1',
        );
        cubit.sendMessage('History matched input');
        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        final clientMessageId = payload['clientMessageId'] as String;
        mockBridge.emitMessage(
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              content: [const TextContent(text: 'live tail')],
              model: 'codex',
            ),
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        mockBridge.emitMessage(
          HistoryMessage(
            messages: [
              UserInputMessage(
                text: 'History matched input',
                clientMessageId: clientMessageId,
                timestamp: '2026-04-28T12:00:00.000Z',
              ),
            ],
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'History matched input');
        expect(
          cubit.state.entries.whereType<ServerChatEntry>().where(
            (entry) => entry.message is AssistantServerMessage,
          ),
          hasLength(1),
        );
      },
    );

    test(
      'history replace keeps completed live assistant missing from snapshot',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        const result = ResultMessage(subtype: 'success', sessionId: 'thread-1');
        final assistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'assistant-1',
            role: 'assistant',
            content: const [TextContent(text: 'Completed live response')],
            model: 'codex',
          ),
        );

        mockBridge.emitMessage(
          const StreamDeltaMessage(text: 'Completed live response'),
          sessionId: 's1',
        );
        mockBridge.emitMessage(assistant, sessionId: 's1');
        mockBridge.emitMessage(result, sessionId: 's1');
        await pumpEventQueue();

        mockBridge.emitMessage(
          const HistoryMessage(messages: [result]),
          sessionId: 's1',
        );
        await pumpEventQueue();

        final assistants = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>()
            .toList();
        expect(assistants, hasLength(1));
        expect(assistants.single.message.content, const [
          TextContent(text: 'Completed live response'),
        ]);
        expect(streamingCubit.state.isStreaming, isFalse);
      },
    );

    test(
      'history replace keeps richer live content for the same assistant id',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        final completeAssistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'assistant-1',
            role: 'assistant',
            content: const [TextContent(text: 'Complete response')],
            model: 'codex',
          ),
        );
        final incompleteAssistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'assistant-1',
            role: 'assistant',
            content: const [TextContent(text: '')],
            model: 'codex',
          ),
        );

        mockBridge.emitMessage(completeAssistant, sessionId: 's1');
        await pumpEventQueue();
        mockBridge.emitMessage(
          HistoryMessage(messages: [incompleteAssistant]),
          sessionId: 's1',
        );
        await pumpEventQueue();

        final assistant = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>()
            .single;
        expect(assistant.message.content, const [
          TextContent(text: 'Complete response'),
        ]);
      },
    );

    test(
      'history replace deduplicates matching assistants with different ids',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        final liveAssistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'live-assistant-id',
            role: 'assistant',
            content: const [TextContent(text: 'Completed response')],
            model: 'codex',
          ),
        );
        final historyAssistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'history-assistant-id',
            role: 'assistant',
            content: const [TextContent(text: 'Completed response')],
            model: 'codex',
          ),
        );

        mockBridge.emitMessage(liveAssistant, sessionId: 's1');
        await pumpEventQueue();
        mockBridge.emitMessage(
          HistoryMessage(messages: [historyAssistant]),
          sessionId: 's1',
        );
        await pumpEventQueue();

        final assistants = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>()
            .toList();
        expect(assistants, hasLength(1));
        expect(assistants.single.message.id, 'history-assistant-id');
      },
    );

    test(
      'history delta deduplicates current-turn messages with different ids',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        final liveAssistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'live-assistant-id',
            role: 'assistant',
            content: const [TextContent(text: 'Completed response')],
            model: 'codex',
          ),
        );
        final historyAssistant = AssistantServerMessage(
          messageUuid: 'history-item-id',
          message: AssistantMessage(
            id: 'history-assistant-id',
            role: 'assistant',
            content: const [TextContent(text: 'Completed response')],
            model: 'codex',
          ),
        );
        const liveResult = ResultMessage(
          subtype: 'success',
          result: 'Completed response',
          sessionId: 'live-thread-id',
        );
        const historyResult = ResultMessage(
          subtype: 'success',
          result: 'Completed response',
          sessionId: 'canonical-thread-id',
        );

        mockBridge.emitMessage(liveAssistant, sessionId: 's1');
        mockBridge.emitMessage(liveResult, sessionId: 's1');
        await pumpEventQueue();
        mockBridge.emitMessage(historyAssistant, sessionId: 's1');
        mockBridge.emitMessage(historyResult, sessionId: 's1');
        await pumpEventQueue();

        final serverMessages = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .toList();
        expect(
          serverMessages.whereType<AssistantServerMessage>(),
          hasLength(1),
        );
        expect(serverMessages.whereType<ResultMessage>(), hasLength(1));
      },
    );

    test('deduplicates repeated guardian approvals in the same turn', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);
      const approval = GuardianApprovalMessage(
        risk: GuardianApprovalRisk.medium,
        reason: 'Launching the app writes files outside the workspace.',
        authorization: 'medium',
      );

      mockBridge.emitMessage(approval, sessionId: 's1');
      mockBridge.emitMessage(approval, sessionId: 's1');
      await pumpEventQueue();

      final approvals = cubit.state.entries
          .whereType<ServerChatEntry>()
          .map((entry) => entry.message)
          .whereType<GuardianApprovalMessage>();
      expect(approvals, hasLength(1));
    });

    test(
      'same-turn live assistants with matching text remain distinct',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        AssistantServerMessage assistant(String id) => AssistantServerMessage(
          message: AssistantMessage(
            id: id,
            role: 'assistant',
            content: const [TextContent(text: 'Same response')],
            model: 'codex',
          ),
        );

        mockBridge.emitMessage(assistant('assistant-1'), sessionId: 's1');
        mockBridge.emitMessage(assistant('assistant-2'), sessionId: 's1');
        await pumpEventQueue();

        final assistants = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>();
        expect(assistants, hasLength(2));
      },
    );

    test(
      'stale history keeps same-text assistant from the current turn',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        AssistantServerMessage assistant(String id) => AssistantServerMessage(
          message: AssistantMessage(
            id: id,
            role: 'assistant',
            content: const [TextContent(text: 'OK')],
            model: 'codex',
          ),
        );
        const firstUser = UserInputMessage(
          text: 'Same prompt',
          userMessageUuid: 'user-turn-1',
        );
        const secondUser = UserInputMessage(
          text: 'Same prompt',
          userMessageUuid: 'user-turn-2',
        );
        final initialHistory = HistoryMessage(
          messages: [firstUser, assistant('assistant-1'), secondUser],
        );
        final staleHistory = HistoryMessage(
          messages: [firstUser, assistant('assistant-1')],
        );

        mockBridge.emitMessage(initialHistory, sessionId: 's1');
        await pumpEventQueue();
        mockBridge.emitMessage(assistant('assistant-2'), sessionId: 's1');
        await pumpEventQueue();
        mockBridge.emitMessage(staleHistory, sessionId: 's1');
        await pumpEventQueue();

        final assistants = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>()
            .toList();
        expect(assistants, hasLength(2));
        expect(assistants.map((message) => message.message.id), [
          'assistant-1',
          'assistant-2',
        ]);
      },
    );

    test(
      'history UUID matches a local client-id user at the turn boundary',
      () async {
        final cubit = createCubit('s1', provider: Provider.claude);
        addTearDown(cubit.close);

        cubit.sendMessage('Same prompt');
        await pumpEventQueue();
        expect(cubit.state.entries.whereType<UserChatEntry>(), hasLength(1));

        mockBridge.emitMessage(
          const HistoryMessage(
            messages: [
              UserInputMessage(
                text: 'Same prompt',
                userMessageUuid: 'server-user-uuid',
              ),
            ],
          ),
          sessionId: 's1',
        );
        await pumpEventQueue();

        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Same prompt');
      },
    );

    test(
      'identical assistant text in a later turn is not deduplicated',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        AssistantServerMessage assistant(String id) => AssistantServerMessage(
          message: AssistantMessage(
            id: id,
            role: 'assistant',
            content: const [TextContent(text: 'Same response')],
            model: 'codex',
          ),
        );

        mockBridge.emitMessage(assistant('assistant-1'), sessionId: 's1');
        mockBridge.emitMessage(
          const ResultMessage(subtype: 'success'),
          sessionId: 's1',
        );
        await pumpEventQueue();
        mockBridge.emitMessage(
          HistoryMessage(
            messages: [
              assistant('assistant-1'),
              const ResultMessage(subtype: 'success'),
            ],
          ),
          sessionId: 's1',
        );
        await pumpEventQueue();
        mockBridge.emitMessage(
          const UserInputMessage(
            text: 'Ask again',
            userMessageUuid: 'user-turn-2',
          ),
          sessionId: 's1',
        );
        await pumpEventQueue();
        expect(cubit.state.entries.whereType<UserChatEntry>(), hasLength(1));
        mockBridge.emitMessage(assistant('assistant-2'), sessionId: 's1');
        await pumpEventQueue();

        final assistants = cubit.state.entries
            .whereType<ServerChatEntry>()
            .map((entry) => entry.message)
            .whereType<AssistantServerMessage>();
        expect(assistants, hasLength(2));
      },
    );

    test(
      'codex assistant response clears delivery pending without ack',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Ack-less online Codex input');

        await Future<void>.delayed(const Duration(milliseconds: 650));
        expect(
          ChatSessionCubit.isDeliveryPendingQueuedInput(
            cubit.state.queuedInput,
          ),
          isTrue,
        );

        mockBridge.emitMessage(
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              content: [const TextContent(text: 'delivered')],
              model: 'codex',
            ),
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.queuedInput, isNull);
        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Ack-less online Codex input');
        expect(users.single.status, MessageStatus.sent);
      },
    );

    test('codex delivery pending input can be locally dismissed', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);
      mockBridge.emitMessage(
        const StatusMessage(status: ProcessStatus.idle),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      cubit.sendMessage('Dismiss delivery pending');
      await Future<void>.delayed(const Duration(milliseconds: 650));

      final item = cubit.state.queuedInput!;
      expect(ChatSessionCubit.isDeliveryPendingQueuedInput(item), isTrue);

      cubit.cancelQueuedInput(item);

      expect(cubit.state.queuedInput, isNull);
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test(
      'codex delivery pending input survives session cubit recreation',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Recreate delivery pending');
        await cubit.close();

        await Future<void>.delayed(const Duration(milliseconds: 650));

        final restored = createCubit('s1', provider: Provider.codex);
        addTearDown(restored.close);
        await Future.microtask(() {});

        expect(restored.state.queuedInput?.text, 'Recreate delivery pending');
        expect(
          ChatSessionCubit.isDeliveryPendingQueuedInput(
            restored.state.queuedInput,
          ),
          isTrue,
        );

        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(restored.state.queuedInput, isNull);
        final users = restored.state.entries
            .whereType<UserChatEntry>()
            .toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Recreate delivery pending');
        expect(users.single.status, MessageStatus.sent);
      },
    );

    test(
      'codex hidden delivery pending input survives fast recreation and ack',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Recreate before delivery delay');
        final payload =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        await cubit.close();

        final restored = createCubit('s1', provider: Provider.codex);
        addTearDown(restored.close);
        await Future.microtask(() {});

        expect(restored.state.queuedInput, isNull);

        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: payload['clientMessageId'] as String,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});
        await Future<void>.delayed(const Duration(milliseconds: 650));

        expect(restored.state.queuedInput, isNull);
        final users = restored.state.entries
            .whereType<UserChatEntry>()
            .toList();
        expect(users, hasLength(1));
        expect(users.single.text, 'Recreate before delivery delay');
        expect(users.single.status, MessageStatus.sent);
      },
    );

    test(
      'canceling delivery pending input clears restored pending state',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage('Cancel restored delivery pending');
        await Future<void>.delayed(const Duration(milliseconds: 650));

        cubit.cancelQueuedInput(cubit.state.queuedInput!);
        await cubit.close();

        final restored = createCubit('s1', provider: Provider.codex);
        addTearDown(restored.close);
        await Future.microtask(() {});

        expect(restored.state.queuedInput, isNull);
      },
    );

    test(
      'codex sendMessage includes structured skills and app mentions',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        mockBridge.emitMessage(
          const SystemMessage(
            subtype: 'supported_commands',
            provider: 'codex',
            skills: ['skill-creator'],
            skillMetadata: [
              CodexSkillMetadata(
                name: 'skill-creator',
                path: '/tmp/skill-creator/SKILL.md',
                description: 'Create a skill',
              ),
            ],
            apps: ['demo-app'],
            appMetadata: [
              CodexAppMetadata(
                id: 'demo-app',
                name: 'Demo App',
                description: 'Example connector',
              ),
            ],
            plugins: ['sample'],
            pluginMetadata: [
              CodexPluginMetadata(
                id: 'sample@test',
                name: 'sample',
                path: 'plugin://sample@test',
                marketplaceName: 'test',
                displayName: 'Sample Plugin',
                shortDescription: 'Example plugin',
              ),
            ],
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage(
          r'$skill-creator draft a skill and ask $demo-app with @sample',
        );

        expect(mockBridge.sentMessages, hasLength(1));
        final json =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        expect(json['skills'], [
          {'name': 'skill-creator', 'path': '/tmp/skill-creator/SKILL.md'},
        ]);
        expect(json['mentions'], [
          {'name': 'Demo App', 'path': 'app://demo-app'},
          {'name': 'Sample Plugin', 'path': 'plugin://sample@test'},
        ]);
      },
    );

    test(
      'codex sendMessage includes structured file and directory mentions',
      () async {
        final cubit = createCubit(
          's1',
          provider: Provider.codex,
          initialProjectPath: '/tmp/project',
        );
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage(
          'Review @apps/mobile/ and @apps/mobile/lib/main.dart',
          mentionablePaths: const [
            'apps/',
            'apps/mobile/',
            'apps/mobile/lib/',
            'apps/mobile/lib/main.dart',
          ],
        );

        expect(mockBridge.sentMessages, hasLength(1));
        final json =
            jsonDecode(mockBridge.sentMessages.single.toJson())
                as Map<String, dynamic>;
        expect(json['mentions'], [
          {'name': 'apps/mobile/', 'path': '/tmp/project/apps/mobile/'},
          {
            'name': 'apps/mobile/lib/main.dart',
            'path': '/tmp/project/apps/mobile/lib/main.dart',
          },
        ]);
      },
    );

    test('approve clears approval state and sends message', () async {
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

      cubit.approve('tool-1');

      expect(cubit.state.approval, isA<ApprovalNone>());
      expect(mockBridge.sentMessages, hasLength(1));
    });

    test(
      'tool suggestion install keeps approval visible while pending',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        const permission = PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {'toolName': 'GitHub', 'installState': 'idle'},
        );
        mockBridge.emitMessage(permission, sessionId: 's1');
        await Future.microtask(() {});

        cubit.installToolSuggestion('approval-0');

        expect(cubit.state.approval, isA<ApprovalPermission>());
        expect(mockBridge.sentMessages, hasLength(1));
        expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
          'type': 'install_tool_suggestion',
          'toolUseId': 'approval-0',
          'sessionId': 's1',
        });
      },
    );

    test('server resolution clears a completed tool suggestion', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {'toolName': 'GitHub', 'installState': 'installing'},
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});
      mockBridge.emitMessage(
        const PermissionResolvedMessage(toolUseId: 'approval-0'),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.approval, isA<ApprovalNone>());
    });

    test('approved permission is not restored by stale history', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});
      const permission = PermissionRequestMessage(
        toolUseId: 'tool-1',
        toolName: 'bash',
        input: {'command': 'ls'},
      );

      mockBridge.emitMessage(permission, sessionId: 's1');
      await Future.microtask(() {});
      cubit.approve('tool-1');
      mockBridge.emitMessage(
        const HistoryMessage(
          messages: [
            permission,
            StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.approval, isA<ApprovalNone>());
    });

    test(
      'tool result does not allow stale approval history to replay',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});
        const permission = PermissionRequestMessage(
          toolUseId: 'tool-1',
          toolName: 'bash',
          input: {'command': 'ls'},
        );

        mockBridge.emitMessage(permission, sessionId: 's1');
        await Future.microtask(() {});
        cubit.reject('tool-1');
        mockBridge.emitMessage(
          const ToolResultMessage(toolUseId: 'tool-1', content: 'rejected'),
          sessionId: 's1',
        );
        mockBridge.emitMessage(
          const HistoryMessage(
            messages: [
              permission,
              StatusMessage(status: ProcessStatus.waitingApproval),
            ],
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.approval, isA<ApprovalNone>());
      },
    );

    test('answered question is not restored by stale history', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});
      final ask = AssistantServerMessage(
        message: AssistantMessage(
          id: 'ask-message',
          role: 'assistant',
          content: [
            const ToolUseContent(
              id: 'ask-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {'question': 'Which option?'},
                ],
              },
            ),
          ],
          model: 'claude',
        ),
      );

      mockBridge.emitMessage(ask, sessionId: 's1');
      await Future.microtask(() {});
      cubit.answer('ask-1', 'A');
      mockBridge.emitMessage(
        HistoryMessage(
          messages: [
            ask,
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.approval, isA<ApprovalNone>());
    });

    test(
      'stale answered permission does not hide a later pending one',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});
        const answered = PermissionRequestMessage(
          toolUseId: 'tool-answered',
          toolName: 'bash',
          input: {'command': 'first'},
        );
        const pending = PermissionRequestMessage(
          toolUseId: 'tool-pending',
          toolName: 'bash',
          input: {'command': 'second'},
        );

        mockBridge.emitMessage(answered, sessionId: 's1');
        await Future.microtask(() {});
        cubit.approve('tool-answered');
        mockBridge.emitMessage(
          const HistoryMessage(
            messages: [
              answered,
              pending,
              StatusMessage(status: ProcessStatus.waitingApproval),
            ],
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.approval, isA<ApprovalPermission>());
        expect(
          (cubit.state.approval as ApprovalPermission).toolUseId,
          'tool-pending',
        );
      },
    );

    test(
      'answered permission remains suppressed after cubit recreation',
      () async {
        final firstCubit = createCubit('s1');
        await Future.microtask(() {});
        const permission = PermissionRequestMessage(
          toolUseId: 'tool-answered',
          toolName: 'bash',
          input: {'command': 'ls'},
        );
        mockBridge.emitMessage(permission, sessionId: 's1');
        await Future.microtask(() {});
        firstCubit.approve('tool-answered');
        await firstCubit.close();

        final recreatedCubit = createCubit('s1');
        addTearDown(recreatedCubit.close);
        await Future.microtask(() {});
        mockBridge.emitMessage(
          const HistoryMessage(
            messages: [
              permission,
              StatusMessage(status: ProcessStatus.waitingApproval),
            ],
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(recreatedCubit.state.approval, isA<ApprovalNone>());
      },
    );

    test('approving ExitPlanMode also clears plan mode state', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const SystemMessage(
          subtype: 'set_permission_mode',
          provider: 'codex',
          permissionMode: 'plan',
          executionMode: 'default',
          planMode: true,
        ),
        sessionId: 's1',
      );
      mockBridge.emitMessage(
        const PermissionRequestMessage(
          toolUseId: 'tool-plan',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Test plan'},
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.planMode, isTrue);
      expect(cubit.state.approval, isA<ApprovalPermission>());
      cubit.approve('tool-plan');

      expect(cubit.state.planMode, isFalse);
      expect(cubit.state.inPlanMode, isFalse);
      expect(cubit.state.permissionMode, PermissionMode.acceptEdits);
    });

    test('approving ExitPlanMode clears inPlanMode immediately', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'plan-msg',
            role: 'assistant',
            content: [
              const TextContent(text: 'Plan ready'),
              const ToolUseContent(
                id: 'tool-exit-1',
                name: 'EnterPlanMode',
                input: {},
              ),
            ],
            model: 'claude',
          ),
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});
      mockBridge.emitMessage(
        const PermissionRequestMessage(
          toolUseId: 'tool-exit-1',
          toolName: 'ExitPlanMode',
          input: {'plan': 'Implementation Plan'},
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.inPlanMode, isTrue);
      expect(cubit.state.approval, isA<ApprovalPermission>());

      cubit.approve('tool-exit-1');

      expect(cubit.state.approval, isA<ApprovalNone>());
      expect(cubit.state.inPlanMode, isFalse);
    });

    test('reject clears approval and plan mode', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

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

    test('setPermissionMode updates local mode state immediately', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.setPermissionMode(PermissionMode.plan);
      expect(cubit.state.permissionMode, PermissionMode.plan);
      expect(cubit.state.inPlanMode, isTrue);

      cubit.setPermissionMode(PermissionMode.defaultMode);
      expect(cubit.state.permissionMode, PermissionMode.defaultMode);
      expect(cubit.state.inPlanMode, isFalse);
    });

    test('setCodexModel updates state and sends bridge message', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      cubit.setCodexModel(
        ' gpt-5.4-mini ',
        reasoningEffort: ReasoningEffort.low,
      );

      expect(cubit.state.codexModel, 'gpt-5.4-mini');
      expect(cubit.state.codexModelReasoningEffort, ReasoningEffort.low);
      expect(mockBridge.sentMessages, hasLength(1));
      expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
        'type': 'set_codex_model',
        'model': 'gpt-5.4-mini',
        'modelReasoningEffort': 'low',
        'sessionId': 's1',
      });
    });

    test('setCodexModel is ignored for non-Codex sessions', () async {
      final cubit = createCubit('s1', provider: Provider.claude);
      addTearDown(cubit.close);

      cubit.setCodexModel('gpt-5.4-mini', reasoningEffort: ReasoningEffort.low);

      expect(cubit.state.codexModel, isNull);
      expect(cubit.state.codexModelReasoningEffort, isNull);
      expect(mockBridge.sentMessages, isEmpty);
    });

    test('setCodexSpeed updates state and sends bridge message', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      cubit.setCodexSpeed(CodexSpeed.fast);

      expect(cubit.state.codexSpeed, CodexSpeed.fast);
      expect(jsonDecode(mockBridge.sentMessages.single.toJson()), {
        'type': 'set_codex_speed',
        'serviceTier': 'fast',
        'sessionId': 's1',
      });
    });

    test('permission mode rolls back on mode-change error', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.setPermissionMode(PermissionMode.bypassPermissions);
      expect(cubit.state.permissionMode, PermissionMode.bypassPermissions);

      mockBridge.emitMessage(
        const ErrorMessage(
          message: 'Failed to set permission mode: forced test failure',
          errorCode: 'set_permission_mode_rejected',
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.permissionMode, PermissionMode.defaultMode);
      expect(cubit.state.inPlanMode, isFalse);
    });

    test(
      'auto mode unavailable rolls back to previous permission mode',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.setPermissionMode(PermissionMode.auto);
        expect(cubit.state.permissionMode, PermissionMode.auto);

        mockBridge.emitMessage(
          const ErrorMessage(
            message:
                'Auto mode is unavailable in this environment. Keeping the current permission mode.',
            errorCode: 'auto_mode_unavailable',
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.permissionMode, PermissionMode.defaultMode);
        expect(cubit.state.inPlanMode, isFalse);
      },
    );

    test('sandbox mode rolls back on mode-change error', () async {
      final cubit = createCubit('s1');
      addTearDown(cubit.close);
      await Future.microtask(() {});

      cubit.setSandboxMode(SandboxMode.on);
      expect(cubit.state.sandboxMode, SandboxMode.on);

      mockBridge.emitMessage(
        const ErrorMessage(
          message: 'Failed to set sandbox mode: forced test failure',
          errorCode: 'set_sandbox_mode_rejected',
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.sandboxMode, SandboxMode.off);
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

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.status, ProcessStatus.idle);
    });

    test('restores cached runtime messages before requesting history', () {
      mockBridge.cachedMessagesBySession['s1'] = [
        const StatusMessage(status: ProcessStatus.running),
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'cached-a1',
            role: 'assistant',
            content: [const TextContent(text: 'Cached response')],
            model: 'claude',
          ),
        ),
      ];

      final cubit = createCubit('s1');
      addTearDown(cubit.close);

      expect(mockBridge.requestSessionHistoryCallCount, 1);
      expect(cubit.state.status, ProcessStatus.running);
      expect(cubit.state.entries, hasLength(1));
      final entry = cubit.state.entries.single as ServerChatEntry;
      final msg = entry.message as AssistantServerMessage;
      expect(
        (msg.message.content.single as TextContent).text,
        'Cached response',
      );
    });

    test('restores cached queue state without visible ack entries', () {
      mockBridge.cachedMessagesBySession['s1'] = [
        const InputAckMessage(sessionId: 's1', queued: true),
        const ConversationQueueMessage(
          sessionId: 's1',
          limit: 1,
          items: [
            QueuedInputItem(
              itemId: 'queued-1',
              text: 'Queued while busy',
              createdAt: '2026-04-28T00:00:00.000Z',
            ),
          ],
        ),
      ];

      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);

      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.queuedInput?.itemId, 'queued-1');
      expect(cubit.state.queuedInput?.text, 'Queued while busy');
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

      cubit.sendMessage('Test message');
      expect(cubit.state.entries, hasLength(1));

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

        expect(cubit.state.status, ProcessStatus.starting);

        mockBridge.emitMessage(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        expect(cubit.state.status, ProcessStatus.running);
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

    test(
      'input_ack with clientMessageId updates the matching message',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage('Message A');
        cubit.sendMessage('Message B');
        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        final secondClientMessageId = users[1].clientMessageId;

        mockBridge.emitMessage(
          InputAckMessage(
            sessionId: 's1',
            clientMessageId: secondClientMessageId,
            queued: false,
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final updated = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(updated.map((e) => e.status).toList(), [
          MessageStatus.sending,
          MessageStatus.sent,
        ]);
      },
    );

    test(
      'input_rejected with clientMessageId fails only the matching message',
      () async {
        final cubit = createCubit('s1');
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage('Message A');
        cubit.sendMessage('Message B');
        final users = cubit.state.entries.whereType<UserChatEntry>().toList();
        final firstClientMessageId = users[0].clientMessageId;

        mockBridge.emitMessage(
          InputRejectedMessage(
            sessionId: 's1',
            clientMessageId: firstClientMessageId,
            reason: 'conflict',
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        final updated = cubit.state.entries.whereType<UserChatEntry>().toList();
        expect(updated.map((e) => e.status).toList(), [
          MessageStatus.failed,
          MessageStatus.sending,
        ]);
      },
    );

    test('codex busy send waits for bridge queue state', () async {
      final cubit = createCubit('s1', provider: Provider.codex);
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockBridge.emitMessage(
        const StatusMessage(status: ProcessStatus.running),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      cubit.sendMessage('Follow up');

      expect(cubit.state.entries.whereType<UserChatEntry>(), isEmpty);
      expect(mockBridge.sentMessages.last.type, 'input');

      mockBridge.emitMessage(
        const ConversationQueueMessage(
          sessionId: 's1',
          limit: 1,
          items: [
            QueuedInputItem(
              itemId: 'q1',
              text: 'Follow up',
              createdAt: '2026-04-25T00:00:00.000Z',
            ),
          ],
        ),
        sessionId: 's1',
      );
      await Future.microtask(() {});

      expect(cubit.state.queuedInput?.itemId, 'q1');
      expect(cubit.state.queuedInput?.text, 'Follow up');
    });

    test(
      'codex queued input update steer and cancel send client messages',
      () async {
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        const item = QueuedInputItem(
          itemId: 'q1',
          text: 'Original',
          createdAt: '2026-04-25T00:00:00.000Z',
        );

        cubit.updateQueuedInput(item, 'Edited');
        var payload =
            jsonDecode(mockBridge.sentMessages.last.toJson())
                as Map<String, dynamic>;
        expect(payload['type'], 'update_queued_input');
        expect(payload['itemId'], 'q1');
        expect(payload['text'], 'Edited');

        cubit.steerQueuedInput(item);
        payload =
            jsonDecode(mockBridge.sentMessages.last.toJson())
                as Map<String, dynamic>;
        expect(payload['type'], 'steer_queued_input');
        expect(payload['itemId'], 'q1');

        cubit.cancelQueuedInput(item);
        payload =
            jsonDecode(mockBridge.sentMessages.last.toJson())
                as Map<String, dynamic>;
        expect(payload['type'], 'cancel_queued_input');
        expect(payload['itemId'], 'q1');
      },
    );

    test(
      'offline codex queued input update and cancel mutate local pending input',
      () async {
        mockBridge.connected = false;
        final cubit = createCubit('s1', provider: Provider.codex);
        addTearDown(cubit.close);
        await Future.microtask(() {});

        cubit.sendMessage('Original offline');
        final item = cubit.state.queuedInput!;
        final clientMessageId = ChatSessionCubit.offlineQueuedClientMessageId(
          item,
        );

        cubit.updateQueuedInput(item, 'Edited offline');
        expect(cubit.state.queuedInput?.text, 'Edited offline');
        expect(mockBridge.updatedOfflineInputs.single, {
          'sessionId': 's1',
          'clientMessageId': clientMessageId,
          'text': 'Edited offline',
          'skills': <Map<String, String>>[],
          'mentions': <Map<String, String>>[],
        });
        expect(
          mockBridge.sentMessages.map((message) => message.type),
          isNot(contains('update_queued_input')),
        );

        cubit.steerQueuedInput(cubit.state.queuedInput!);
        expect(
          mockBridge.sentMessages.map((message) => message.type),
          isNot(contains('steer_queued_input')),
        );

        cubit.cancelQueuedInput(cubit.state.queuedInput!);
        expect(cubit.state.queuedInput, isNull);
        expect(mockBridge.canceledOfflineInputs.single, {
          'sessionId': 's1',
          'clientMessageId': clientMessageId,
        });
      },
    );
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

  group('Permission mode initialization', () {
    test(
      'cubit created with initialPermissionMode reflects it immediately',
      () {
        final cubit = ChatSessionCubit(
          sessionId: 'pm-test',
          bridge: mockBridge,
          streamingCubit: streamingCubit,
          initialPermissionMode: PermissionMode.bypassPermissions,
        );
        addTearDown(cubit.close);

        expect(cubit.state.permissionMode, PermissionMode.bypassPermissions);
      },
    );

    test(
      'cubit created with null initialPermissionMode defaults to defaultMode',
      () {
        final cubit = ChatSessionCubit(
          sessionId: 'pm-null',
          bridge: mockBridge,
          streamingCubit: streamingCubit,
        );
        addTearDown(cubit.close);

        expect(cubit.state.permissionMode, PermissionMode.defaultMode);
      },
    );

    test(
      'session_created message with permissionMode updates cubit state',
      () async {
        final cubit = ChatSessionCubit(
          sessionId: 'pm-update',
          bridge: mockBridge,
          streamingCubit: streamingCubit,
        );
        addTearDown(cubit.close);
        await Future.microtask(() {});

        expect(cubit.state.permissionMode, PermissionMode.defaultMode);

        const sessionCreated = SystemMessage(
          subtype: 'session_created',
          sessionId: 'pm-update',
          permissionMode: 'bypassPermissions',
        );
        mockBridge.emitMessage(sessionCreated, sessionId: 'pm-update');
        await Future.microtask(() {});

        expect(cubit.state.permissionMode, PermissionMode.bypassPermissions);
      },
    );

    test(
      'history message preserves initial permissionMode (does not reset)',
      () async {
        final cubit = ChatSessionCubit(
          sessionId: 'pm-history',
          bridge: mockBridge,
          streamingCubit: streamingCubit,
          initialPermissionMode: PermissionMode.bypassPermissions,
        );
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
                model: 'gpt-5-codex',
              ),
            ),
          ],
        );
        mockBridge.emitMessage(historyMsg, sessionId: 'pm-history');
        await Future.microtask(() {});

        expect(cubit.state.permissionMode, PermissionMode.bypassPermissions);
      },
    );
  });

  group('updateRecentPeekedFiles', () {
    test('moves reopened file to front without duplication', () {
      final updated = updateRecentPeekedFiles([
        'lib/main.dart',
        'lib/app.dart',
        'README.md',
      ], 'lib/app.dart');

      expect(updated, ['lib/app.dart', 'lib/main.dart', 'README.md']);
    });

    test('caps history at ten items', () {
      final updated = updateRecentPeekedFiles(
        List.generate(10, (i) => 'lib/file_$i.dart'),
        'lib/new.dart',
      );

      expect(updated.length, 10);
      expect(updated.first, 'lib/new.dart');
      expect(updated.last, 'lib/file_8.dart');
    });
  });
}

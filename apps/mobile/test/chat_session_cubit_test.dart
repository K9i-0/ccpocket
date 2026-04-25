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

  ChatSessionCubit createCubit(String sessionId, {Provider? provider}) {
    return ChatSessionCubit(
      sessionId: sessionId,
      provider: provider,
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
      expect((cubit.state.entries.first as UserChatEntry).text, 'Hello Claude');

      expect(mockBridge.sentMessages, hasLength(1));
    });

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
          ),
          sessionId: 's1',
        );
        await Future.microtask(() {});

        cubit.sendMessage(
          r'$skill-creator draft a skill and ask $demo-app for context',
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

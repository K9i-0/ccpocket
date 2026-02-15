import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/claude_code_session/claude_code_session_screen.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

// ---------------------------------------------------------------------------
// MockBridgeService — extends the cubit-test version with streams needed by
// ClaudeCodeSessionScreen (connectionStatus, fileList, sessionList).
// ---------------------------------------------------------------------------

class MockBridgeService extends BridgeService {
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();
  final sentMessages = <ClientMessage>[];

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<List<String>> get fileList => _fileListController.stream;

  @override
  Stream<List<SessionInfo>> get sessionList => _sessionListController.stream;

  @override
  String? get httpBaseUrl => 'http://localhost:8765';

  @override
  bool get isConnected => true;

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
  void interrupt(String sessionId) {}

  @override
  void stopSession(String sessionId) {}

  @override
  void requestFileList(String projectPath) {}

  @override
  void requestSessionList() {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void dispose() {
    _messageController.close();
    _taggedController.close();
    _connectionController.close();
    _fileListController.close();
    _sessionListController.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Widget test wrapper — provides all required providers for ClaudeCodeSessionScreen.
// ---------------------------------------------------------------------------

const testSessionId = 'test-session';

Future<Widget> buildTestClaudeCodeSessionScreen({
  required MockBridgeService bridge,
  String sessionId = testSessionId,
  String? projectPath,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DraftService>.value(value: DraftService(prefs)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConnectionCubit>(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              bridge.connectionStatus,
            ),
          ),
          BlocProvider<FileListCubit>(
            create: (_) => FileListCubit(const <String>[], bridge.fileList),
          ),
        ],
        child: ClaudeCodeSessionScreen(sessionId: sessionId, projectPath: projectPath),
      ),
    ),
  );
}

/// Backward-compatible alias used by existing tests.
Future<Widget> buildTestChatScreen({
  required MockBridgeService bridge,
  String sessionId = testSessionId,
  String? projectPath,
}) =>
    buildTestClaudeCodeSessionScreen(
      bridge: bridge,
      sessionId: sessionId,
      projectPath: projectPath,
    );

// ---------------------------------------------------------------------------
// Message builder helpers
// ---------------------------------------------------------------------------

PermissionRequestMessage makeBashPermission(String toolUseId) {
  return PermissionRequestMessage(
    toolUseId: toolUseId,
    toolName: 'Bash',
    input: const {'command': 'ls -la'},
  );
}

AssistantServerMessage makeAssistantMessage(
  String id,
  String text, {
  List<ToolUseContent> toolUses = const [],
}) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: id,
      role: 'assistant',
      content: [
        TextContent(text: text),
        ...toolUses,
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  );
}

AssistantServerMessage makeAskQuestionMessage(
  String toolUseId,
  List<Map<String, dynamic>> questions,
) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: 'ask-$toolUseId',
      role: 'assistant',
      content: [
        const TextContent(text: 'I have a question.'),
        ToolUseContent(
          id: toolUseId,
          name: 'AskUserQuestion',
          input: {'questions': questions},
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  );
}

AssistantServerMessage makePlanExitMessage(
  String id,
  String toolUseId,
  String planText,
) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: id,
      role: 'assistant',
      content: [
        TextContent(text: planText),
        ToolUseContent(
          id: toolUseId,
          name: 'ExitPlanMode',
          input: const {'plan': 'Implementation Plan'},
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  );
}

AssistantServerMessage makeEnterPlanMessage(String id, String toolUseId) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: id,
      role: 'assistant',
      content: [
        const TextContent(text: 'Let me plan the implementation.'),
        ToolUseContent(id: toolUseId, name: 'EnterPlanMode', input: const {}),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  );
}

HistoryMessage makeHistoryWithPendingApproval(
  String toolUseId, {
  ProcessStatus status = ProcessStatus.waitingApproval,
}) {
  return HistoryMessage(
    messages: [
      StatusMessage(status: status),
      makeAssistantMessage(
        'hist-1',
        'I need to run a command.',
        toolUses: [
          ToolUseContent(
            id: toolUseId,
            name: 'Bash',
            input: const {'command': 'ls -la'},
          ),
        ],
      ),
      PermissionRequestMessage(
        toolUseId: toolUseId,
        toolName: 'Bash',
        input: const {'command': 'ls -la'},
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Shared setup helpers
// ---------------------------------------------------------------------------

/// Standard plan mode setup: emits EnterPlanMode, ExitPlanMode with plan text,
/// PermissionRequest for ExitPlanMode, and waitingApproval status.
Future<void> setupPlanApproval(
  PatrolTester $,
  MockBridgeService bridge, {
  String planText = '# Implementation Plan\n\n## Steps\n- Step 1\n- Step 2',
}) async {
  await $.pumpWidget(await buildTestClaudeCodeSessionScreen(bridge: bridge));
  await pumpN($.tester);
  await emitAndPump($.tester, bridge, [
    makeEnterPlanMessage('enter-1', 'tool-enter-1'),
    makePlanExitMessage('exit-1', 'tool-exit-1', planText),
    const PermissionRequestMessage(
      toolUseId: 'tool-exit-1',
      toolName: 'ExitPlanMode',
      input: {'plan': 'Implementation Plan'},
    ),
    const StatusMessage(status: ProcessStatus.waitingApproval),
  ]);
  await pumpN($.tester);
}

/// Setup: emits two assistant messages with tool uses and their
/// corresponding permission requests, then a waitingApproval status.
///
/// After setup the cubit holds two pending PermissionRequests (tool-1 and
/// tool-2). The *last* one received (tool-2) is shown in the approval bar.
Future<void> setupMultiApproval(
  PatrolTester $,
  MockBridgeService bridge,
) async {
  await $.pumpWidget(await buildTestClaudeCodeSessionScreen(bridge: bridge));
  await pumpN($.tester);
  await emitAndPump($.tester, bridge, [
    makeAssistantMessage(
      'a1',
      'Command 1.',
      toolUses: [
        const ToolUseContent(
          id: 'tool-1',
          name: 'Bash',
          input: {'command': 'ls -la'},
        ),
      ],
    ),
    makeBashPermission('tool-1'),
    makeAssistantMessage(
      'a2',
      'Command 2.',
      toolUses: [
        const ToolUseContent(
          id: 'tool-2',
          name: 'Bash',
          input: {'command': 'git status'},
        ),
      ],
    ),
    const PermissionRequestMessage(
      toolUseId: 'tool-2',
      toolName: 'Bash',
      input: {'command': 'git status'},
    ),
    const StatusMessage(status: ProcessStatus.waitingApproval),
  ]);
  await pumpN($.tester);
}

/// Approve the currently shown permission and simulate the bridge returning
/// a tool result for it, so [_emitNextApprovalOrNone] can correctly mark it
/// as resolved in subsequent calls.
Future<void> approveAndEmitResult(
  PatrolTester $,
  MockBridgeService bridge,
  String toolUseId,
  String resultContent,
) async {
  await $.tester.tap(find.byKey(const ValueKey('approve_button')));
  await pumpN($.tester);
  await emitAndPump($.tester, bridge, [
    ToolResultMessage(toolUseId: toolUseId, content: resultContent),
  ]);
  await pumpN($.tester);
}

// ---------------------------------------------------------------------------
// Additional message builder helpers
// ---------------------------------------------------------------------------

ToolResultMessage makeToolResult(
  String toolUseId,
  String content, {
  String? toolName,
}) {
  return ToolResultMessage(
    toolUseId: toolUseId,
    content: content,
    toolName: toolName,
  );
}

ToolUseSummaryMessage makeToolUseSummary(
  String summary,
  List<String> precedingIds,
) {
  return ToolUseSummaryMessage(
    summary: summary,
    precedingToolUseIds: precedingIds,
  );
}

HistoryMessage makeHistoryWithPlanApproval(String toolUseId) {
  return HistoryMessage(
    messages: [
      const StatusMessage(status: ProcessStatus.waitingApproval),
      makeEnterPlanMessage('hist-enter-1', 'tool-enter-hist'),
      makePlanExitMessage('hist-exit-1', toolUseId, '# Plan\n\n- Step 1'),
      PermissionRequestMessage(
        toolUseId: toolUseId,
        toolName: 'ExitPlanMode',
        input: const {'plan': 'Implementation Plan'},
      ),
    ],
  );
}

HistoryMessage makeHistoryWithAskUser(
  String toolUseId,
  List<Map<String, dynamic>> questions,
) {
  return HistoryMessage(
    messages: [
      const StatusMessage(status: ProcessStatus.waitingApproval),
      makeAskQuestionMessage(toolUseId, questions),
    ],
  );
}

// ---------------------------------------------------------------------------
// Pump helpers — handle StatusIndicator's infinite animation
// ---------------------------------------------------------------------------

/// Pump multiple frames without waiting for animations to settle.
Future<void> pumpN(WidgetTester tester, {int count = 5}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Emit messages to the mock bridge with short pumps between each.
Future<void> emitAndPump(
  WidgetTester tester,
  MockBridgeService bridge,
  List<ServerMessage> messages, {
  String? sessionId,
}) async {
  for (final msg in messages) {
    bridge.emitMessage(msg, sessionId: sessionId ?? testSessionId);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// ClientMessage JSON helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> decodeClientMessage(ClientMessage msg) {
  return jsonDecode(msg.toJson()) as Map<String, dynamic>;
}

Map<String, dynamic>? findSentMessage(MockBridgeService bridge, String type) {
  for (final msg in bridge.sentMessages) {
    final decoded = decodeClientMessage(msg);
    if (decoded['type'] == type) return decoded;
  }
  return null;
}

List<Map<String, dynamic>> findAllSentMessages(
  MockBridgeService bridge,
  String type,
) {
  return bridge.sentMessages
      .map(decodeClientMessage)
      .where((m) => m['type'] == type)
      .toList();
}

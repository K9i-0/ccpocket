import 'dart:convert';

import 'package:ccpocket/features/session_list/services/session_resume_coordinator.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/offline_pending_action.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ResumeBridge extends BridgeService {
  final sentMessages = <ClientMessage>[];
  List<OfflinePendingAction> pendingActions = const [];

  @override
  List<OfflinePendingAction> get offlinePendingActions => pendingActions;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }
}

final _session = RecentSession(
  sessionId: 'claude-uuid',
  provider: 'claude',
  rawPermissionMode: 'acceptEdits',
  firstPrompt: 'Continue',
  created: '2026-07-24T00:00:00Z',
  modified: '2026-07-24T01:00:00Z',
  gitBranch: 'main',
  projectPath: '/workspace/app',
  resumeCwd: '/workspace/app/worktree',
  isSidechain: false,
  ownership: SessionOwnershipProjection.fromJson({
    'bridgeGeneration': 'generation-1',
    'bridgeSessionId': null,
    'providerThreadId': 'claude-uuid',
    'recordKind': 'recent',
    'origin': 'external',
    'owner': 'external',
    'runtimeStatus': 'idle',
    'attachmentState': 'external_idle',
    'capabilities': ['read_history', 'refresh', 'resume'],
    'readOnlyReason': null,
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ResumeBridge bridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'claude_session_settings_claude-uuid': jsonEncode({
        'permissionMode': 'plan',
        'executionMode': 'plan',
        'planMode': true,
        'sandboxMode': 'on',
        'claudeEffort': 'high',
        'claudeModel': 'opus',
        'claudeFallbackModel': 'sonnet',
        'claudeForkSession': true,
        'claudePersistSession': false,
      }),
    });
    bridge = _ResumeBridge();
  });

  tearDown(() {
    bridge.dispose();
  });

  test('resumes a deep link with the same persisted Claude settings', () async {
    final result = await SessionResumeCoordinator(bridge: bridge)
        .resume(_session, resumeRequestId: 'link-request-1');

    expect(result.disposition, SessionResumeDisposition.dispatched);
    expect(result.projectPath, '/workspace/app/worktree');
    final message =
        jsonDecode(bridge.sentMessages.single.toJson()) as Map<String, dynamic>;
    expect(message, containsPair('type', 'resume_session'));
    expect(message, containsPair('sessionId', 'claude-uuid'));
    expect(message, containsPair('projectPath', '/workspace/app/worktree'));
    expect(message, containsPair('permissionMode', 'plan'));
    expect(message, containsPair('executionMode', 'default'));
    expect(message, containsPair('planMode', true));
    expect(message, containsPair('sandboxMode', 'on'));
    expect(message, containsPair('effort', 'high'));
    expect(message, containsPair('model', 'opus'));
    expect(message, containsPair('fallbackModel', 'sonnet'));
    expect(message, containsPair('forkSession', true));
    expect(message, containsPair('persistSession', false));
    expect(message, containsPair('resumeRequestId', 'link-request-1'));
    expect(message, containsPair('providerThreadId', 'claude-uuid'));
    expect(message, containsPair('bridgeGeneration', 'generation-1'));
    expect(message, containsPair('expectedOwner', 'external'));
  });

  test('resumes a Codex profile without stale permission overrides', () async {
    final codexSession = RecentSession(
      sessionId: 'codex-thread',
      provider: 'codex',
      firstPrompt: 'Continue',
      created: '2026-07-24T00:00:00Z',
      modified: '2026-07-24T01:00:00Z',
      gitBranch: 'main',
      projectPath: '/workspace/app',
      isSidechain: false,
      codexApprovalPolicy: 'on-request',
      codexApprovalsReviewer: 'user',
      codexPermissionsMode: 'custom',
      codexSandboxMode: 'workspace-write',
      codexProfile: 'unrestricted',
      ownership: SessionOwnershipProjection.fromJson({
        'bridgeGeneration': 'generation-1',
        'bridgeSessionId': null,
        'providerThreadId': 'codex-thread',
        'recordKind': 'recent',
        'origin': 'external',
        'owner': 'external',
        'runtimeStatus': 'idle',
        'attachmentState': 'external_idle',
        'capabilities': ['read_history', 'refresh', 'resume'],
        'readOnlyReason': null,
      }),
    );

    final result = await SessionResumeCoordinator(bridge: bridge)
        .resume(codexSession);

    expect(result.disposition, SessionResumeDisposition.dispatched);
    final message =
        jsonDecode(bridge.sentMessages.single.toJson()) as Map<String, dynamic>;
    expect(message, containsPair('type', 'resume_session'));
    expect(message, containsPair('sessionId', 'codex-thread'));
    expect(message, containsPair('provider', 'codex'));
    expect(message, containsPair('profile', 'unrestricted'));
    expect(message, isNot(contains('approvalPolicy')));
    expect(message, isNot(contains('approvalsReviewer')));
    expect(message, isNot(contains('codexPermissionsMode')));
    expect(message, isNot(contains('sandboxMode')));
  });

  test('does not enqueue the same offline resume twice', () async {
    bridge.pendingActions = [
      OfflinePendingAction(
        id: 'resume:claude-uuid',
        kind: OfflinePendingActionKind.resume,
        projectPath: _session.projectPath,
        provider: 'claude',
        createdAt: DateTime.utc(2026, 7, 24),
        sessionId: _session.sessionId,
      ),
    ];

    final result = await SessionResumeCoordinator(bridge: bridge)
        .resume(_session);

    expect(result.disposition, SessionResumeDisposition.alreadyQueued);
    expect(bridge.sentMessages, isEmpty);
  });

  test('deduplicates the same connected resume request id', () async {
    final coordinator = SessionResumeCoordinator(bridge: bridge);

    final first = await coordinator.resume(
      _session,
      resumeRequestId: 'link-request-1',
    );
    final duplicate = await coordinator.resume(
      _session,
      resumeRequestId: 'link-request-1',
    );

    expect(first.disposition, SessionResumeDisposition.dispatched);
    expect(duplicate.disposition, SessionResumeDisposition.alreadyQueued);
    expect(bridge.sentMessages, hasLength(1));
  });

  test('explicit read-only probe carries the unknown-owner tuple', () async {
    final unknown = RecentSession(
      sessionId: 'claude-uuid',
      provider: 'claude',
      firstPrompt: 'Continue',
      created: '2026-07-24T00:00:00Z',
      modified: '2026-07-24T01:00:00Z',
      gitBranch: 'main',
      projectPath: '/workspace/app',
      isSidechain: false,
      ownership: SessionOwnershipProjection.fromJson({
        'bridgeGeneration': 'generation-2',
        'bridgeSessionId': null,
        'providerThreadId': 'claude-uuid',
        'recordKind': 'recent',
        'origin': 'disk',
        'owner': 'unknown',
        'runtimeStatus': 'unknown',
        'attachmentState': 'external_unknown',
        'capabilities': ['read_history', 'refresh', 'resume'],
        'readOnlyReason': 'external_owner_unknown',
      }),
    );

    await SessionResumeCoordinator(bridge: bridge)
        .resume(unknown, allowReadOnlyProbe: true);

    final message = jsonDecode(bridge.sentMessages.single.toJson());
    expect(message, containsPair('providerThreadId', 'claude-uuid'));
    expect(message, containsPair('bridgeGeneration', 'generation-2'));
    expect(message, containsPair('expectedOwner', 'unknown'));
  });

  test(
    'refuses an external resume without a complete ownership tuple',
    () async {
      const missingOwnership = RecentSession(
        sessionId: 'thread-missing-identity',
        provider: 'codex',
        firstPrompt: 'Continue',
        created: '2026-07-24T00:00:00Z',
        modified: '2026-07-24T01:00:00Z',
        gitBranch: 'main',
        projectPath: '/workspace/app',
        isSidechain: false,
      );

      expect(
        () => SessionResumeCoordinator(bridge: bridge).resume(missingOwnership),
        throwsA(isA<SessionResumeIdentityException>()),
      );
      expect(bridge.sentMessages, isEmpty);
    },
  );
}

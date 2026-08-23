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

const _session = RecentSession(
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
  });

  test('resumes a Codex profile without stale permission overrides', () async {
    const codexSession = RecentSession(
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
}

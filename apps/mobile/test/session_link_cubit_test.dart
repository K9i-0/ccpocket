import 'dart:async';

import 'package:ccpocket/features/session_link/state/session_link_cubit.dart';
import 'package:ccpocket/features/session_link/state/session_link_state.dart';
import 'package:ccpocket/features/session_list/services/session_resume_coordinator.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SessionLinkBridge extends BridgeService {
  final controller = StreamController<ServerMessage>.broadcast();
  late SessionLinkResolveResult result;

  @override
  Stream<ServerMessage> get messages => controller.stream;

  @override
  Future<SessionLinkResolveResult> resolveSessionLink(
    String sessionId, {
    String provider = 'claude',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return result;
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

class _ResumeCoordinator extends SessionResumeCoordinator {
  _ResumeCoordinator({required super.bridge});

  RecentSession? resumedSession;
  String? resumeRequestId;
  bool? allowReadOnlyProbe;

  @override
  Future<SessionResumeDispatch> resume(
    RecentSession session, {
    String? resumeRequestId,
    bool allowReadOnlyProbe = false,
  }) async {
    resumedSession = session;
    this.resumeRequestId = resumeRequestId;
    this.allowReadOnlyProbe = allowReadOnlyProbe;
    return SessionResumeDispatch(
      disposition: SessionResumeDisposition.dispatched,
      projectPath: session.projectPath,
      gitBranch: session.gitBranch,
    );
  }
}

RecentSession _recentSession() => const RecentSession(
  sessionId: 'claude-uuid',
  provider: 'claude',
  firstPrompt: 'Continue',
  created: '2026-07-24T00:00:00Z',
  modified: '2026-07-24T01:00:00Z',
  gitBranch: 'main',
  projectPath: '/workspace/app',
  isSidechain: false,
);

SessionOwnershipProjection _ownership({
  required String attachmentState,
  String? bridgeSessionId,
  String owner = 'external',
  String origin = 'external',
  String runtimeStatus = 'idle',
  List<String> capabilities = const ['read_history', 'refresh', 'resume'],
  String? readOnlyReason,
}) => SessionOwnershipProjection.fromJson({
  'bridgeGeneration': 'generation-1',
  'bridgeSessionId': bridgeSessionId,
  'providerThreadId': 'claude-uuid',
  'recordKind': bridgeSessionId == null ? 'recent' : 'live',
  'origin': origin,
  'owner': owner,
  'runtimeStatus': runtimeStatus,
  'attachmentState': attachmentState,
  'capabilities': capabilities,
  'readOnlyReason': readOnlyReason,
});

void main() {
  late _SessionLinkBridge bridge;

  setUp(() {
    bridge = _SessionLinkBridge();
  });

  tearDown(() {
    bridge.dispose();
  });

  test('opens an exact live Bridge session', () async {
    bridge.result = SessionLinkResolveResult.resolved(
      SessionLinkResolutionMessage(
        requestId: 'request-1',
        sourceSessionId: 'claude-uuid',
        status: SessionLinkResolutionStatus.live,
        bridgeSessionId: 'bridge-1',
        provider: 'claude',
        ownership: _ownership(
          attachmentState: 'owned',
          bridgeSessionId: 'bridge-1',
          owner: 'bridge',
          origin: 'bridge',
        ),
      ),
    );
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: 'claude-uuid',
      provider: 'claude',
    );
    addTearDown(cubit.close);

    await cubit.resolve();

    expect(
      cubit.state,
      const SessionLinkState.openLive(
        bridgeSessionId: 'bridge-1',
        provider: 'claude',
      ),
    );
  });

  test('shows a visible update failure for an older Bridge', () async {
    bridge.result = const SessionLinkResolveResult.unsupported();
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: 'claude-uuid',
      provider: 'claude',
    );
    addTearDown(cubit.close);

    await cubit.resolve();

    expect(
      cubit.state,
      const SessionLinkState.unavailable(
        reason: 'ownership_protocol_unavailable',
        recoveryAction: 'update_bridge',
      ),
    );
  });

  test('resumes an exact recent session and opens its new runtime', () async {
    final recentSession = _recentSession();
    bridge.result = SessionLinkResolveResult.resolved(
      SessionLinkResolutionMessage(
        requestId: 'request-1',
        sourceSessionId: recentSession.sessionId,
        status: SessionLinkResolutionStatus.recent,
        provider: 'claude',
        recentSession: recentSession,
        ownership: _ownership(attachmentState: 'external_idle'),
      ),
    );
    final coordinator = _ResumeCoordinator(bridge: bridge);
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: recentSession.sessionId,
      provider: 'claude',
      resumeCoordinator: coordinator,
      resumeRequestId: 'link-request-1',
    );
    addTearDown(cubit.close);

    await cubit.resolve();
    expect(cubit.state, const SessionLinkState.resuming());
    expect(coordinator.resumedSession?.sessionId, recentSession.sessionId);
    expect(coordinator.resumeRequestId, 'link-request-1');

    bridge.controller.add(
      SystemMessage(
        subtype: 'session_created',
        sessionId: 'bridge-2',
        resumeRequestId: 'link-request-1',
        provider: 'claude',
        ownership: _ownership(
          attachmentState: 'owned',
          bridgeSessionId: 'bridge-2',
          owner: 'bridge',
          origin: 'bridge',
        ),
      ),
    );
    await Future.microtask(() {});

    expect(cubit.state, isA<SessionLinkOpenResumed>());
    expect(
      (cubit.state as SessionLinkOpenResumed).session.sessionId,
      'bridge-2',
    );
    expect((cubit.state as SessionLinkOpenResumed).gitBranch, 'main');
  });

  test('opens external active and unknown sessions read-only', () async {
    for (final attachment in ['external_active', 'external_unknown']) {
      final ownership = _ownership(
        attachmentState: attachment,
        owner: attachment == 'external_unknown' ? 'unknown' : 'external',
        origin: attachment == 'external_unknown' ? 'disk' : 'external',
        runtimeStatus: attachment == 'external_unknown' ? 'unknown' : 'running',
        readOnlyReason: attachment == 'external_unknown'
            ? 'external_owner_unknown'
            : 'external_owner_active',
      );
      bridge.result = SessionLinkResolveResult.resolved(
        SessionLinkResolutionMessage(
          requestId: 'request-$attachment',
          sourceSessionId: 'claude-uuid',
          status: SessionLinkResolutionStatus.recent,
          provider: 'claude',
          recentSession: _recentSession(),
          ownership: ownership,
        ),
      );
      final coordinator = _ResumeCoordinator(bridge: bridge);
      final cubit = SessionLinkCubit(
        bridge: bridge,
        sourceSessionId: 'claude-uuid',
        provider: 'claude',
        resumeCoordinator: coordinator,
      );

      await cubit.resolve();

      expect(cubit.state, isA<SessionLinkOpenReadOnly>());
      expect(
        (cubit.state as SessionLinkOpenReadOnly).ownership.attachmentState,
        ownership.attachmentState,
      );
      expect(coordinator.resumedSession, isNull);
      await cubit.close();
    }
  });

  test(
    'resume when idle explicitly probes an unknown external owner',
    () async {
      final ownership = _ownership(
        attachmentState: 'external_unknown',
        owner: 'unknown',
        origin: 'disk',
        runtimeStatus: 'unknown',
        readOnlyReason: 'external_owner_unknown',
      );
      bridge.result = SessionLinkResolveResult.resolved(
        SessionLinkResolutionMessage(
          requestId: 'request-unknown',
          sourceSessionId: 'claude-uuid',
          status: SessionLinkResolutionStatus.recent,
          provider: 'claude',
          recentSession: _recentSession(),
          ownership: ownership,
        ),
      );
      final coordinator = _ResumeCoordinator(bridge: bridge);
      final cubit = SessionLinkCubit(
        bridge: bridge,
        sourceSessionId: 'claude-uuid',
        provider: 'claude',
        resumeCoordinator: coordinator,
        resumeRequestId: 'link-request-probe',
      );
      addTearDown(cubit.close);

      await cubit.resolve();
      expect(cubit.state, isA<SessionLinkOpenReadOnly>());

      await cubit.resumeWhenIdle();

      expect(coordinator.resumedSession?.sessionId, 'claude-uuid');
      expect(coordinator.resumeRequestId, 'link-request-probe');
      expect(coordinator.allowReadOnlyProbe, isTrue);
    },
  );

  test('renders scoped resume failure and keeps read-only recovery', () async {
    final ownership = _ownership(attachmentState: 'external_idle');
    bridge.result = SessionLinkResolveResult.resolved(
      SessionLinkResolutionMessage(
        requestId: 'request-1',
        sourceSessionId: 'claude-uuid',
        status: SessionLinkResolutionStatus.recent,
        provider: 'claude',
        recentSession: _recentSession(),
        ownership: ownership,
      ),
    );
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: 'claude-uuid',
      provider: 'claude',
      resumeCoordinator: _ResumeCoordinator(bridge: bridge),
      resumeRequestId: 'link-request-1',
    );
    addTearDown(cubit.close);

    await cubit.resolve();
    bridge.controller.add(
      const ErrorMessage(
        message: 'Another writer is active',
        operation: 'resume_session',
        providerThreadId: 'claude-uuid',
        bridgeGeneration: 'generation-1',
        errorCode: 'writer_conflict',
        retryable: true,
        recoveryAction: 'open_read_only',
      ),
    );
    await Future.microtask(() {});

    expect(cubit.state, isA<SessionLinkOpenReadOnly>());
    expect(
      (cubit.state as SessionLinkOpenReadOnly).failure?.sessionErrorCode,
      SessionControlErrorCode.writerConflict,
    );
  });

  test('ignores resume completions owned by another caller', () async {
    final recentSession = _recentSession();
    bridge.result = SessionLinkResolveResult.resolved(
      SessionLinkResolutionMessage(
        requestId: 'request-1',
        sourceSessionId: recentSession.sessionId,
        status: SessionLinkResolutionStatus.recent,
        provider: 'claude',
        recentSession: recentSession,
        ownership: _ownership(attachmentState: 'external_idle'),
      ),
    );
    final coordinator = _ResumeCoordinator(bridge: bridge);
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: recentSession.sessionId,
      provider: 'claude',
      resumeCoordinator: coordinator,
      resumeRequestId: 'link-request-1',
    );
    addTearDown(cubit.close);

    await cubit.resolve();
    bridge.controller.add(
      const SystemMessage(
        subtype: 'session_created',
        sessionId: 'bridge-other',
        resumeRequestId: 'other-request',
        provider: 'claude',
      ),
    );
    await Future.microtask(() {});

    expect(cubit.state, const SessionLinkState.resuming());
  });

  test('shows unavailable when the resolver has no exact match', () async {
    bridge.result = const SessionLinkResolveResult.resolved(
      SessionLinkResolutionMessage(
        requestId: 'request-1',
        sourceSessionId: 'missing',
        status: SessionLinkResolutionStatus.unavailable,
      ),
    );
    final cubit = SessionLinkCubit(
      bridge: bridge,
      sourceSessionId: 'missing',
      provider: 'claude',
    );
    addTearDown(cubit.close);

    await cubit.resolve();

    expect(
      cubit.state,
      const SessionLinkState.unavailable(
        reason: 'session_not_found',
        recoveryAction: 'refresh_sessions',
      ),
    );
  });
}

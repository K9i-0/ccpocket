import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../session_list/services/session_resume_coordinator.dart';
import 'session_link_state.dart';

class SessionLinkCubit extends Cubit<SessionLinkState> {
  SessionLinkCubit({
    required BridgeService bridge,
    required String sourceSessionId,
    required String provider,
    SessionResumeCoordinator? resumeCoordinator,
    String? resumeRequestId,
  }) : _bridge = bridge,
       _sourceSessionId = sourceSessionId,
       _provider = provider,
       _resumeRequestId =
           resumeRequestId ??
           'session-link-${DateTime.now().microsecondsSinceEpoch}',
       _resumeCoordinator =
           resumeCoordinator ?? SessionResumeCoordinator(bridge: bridge),
       super(const SessionLinkState.resolving());

  final BridgeService _bridge;
  final String _sourceSessionId;
  final String _provider;
  final String _resumeRequestId;
  final SessionResumeCoordinator _resumeCoordinator;
  StreamSubscription<ServerMessage>? _resumeSubscription;
  bool _started = false;
  String? _resumeGitBranch;
  RecentSession? _resumeSource;
  SessionOwnershipProjection? _resumeOwnership;

  Future<void> resolve() async {
    if (_started) return;
    _started = true;
    final result = await _bridge.resolveSessionLink(
      _sourceSessionId,
      provider: _provider,
    );
    if (isClosed) return;
    if (result.support == SessionLinkResolveSupport.unsupported) {
      emit(
        const SessionLinkState.unavailable(
          reason: 'ownership_protocol_unavailable',
          recoveryAction: 'update_bridge',
        ),
      );
      return;
    }
    if (result.support == SessionLinkResolveSupport.unavailable) {
      emit(const SessionLinkState.unavailable());
      return;
    }

    final resolution = result.resolution;
    if (resolution == null) {
      emit(const SessionLinkState.unavailable());
      return;
    }
    if (resolution.status == SessionLinkResolutionStatus.unavailable) {
      emit(
        const SessionLinkState.unavailable(
          reason: 'session_not_found',
          recoveryAction: 'refresh_sessions',
        ),
      );
      return;
    }
    final ownership = resolution.ownership;
    final route = ownership?.routeForProvider(resolution.provider ?? _provider);
    switch (route) {
      case SessionOwnershipRoute.ownedAttach:
        final bridgeSessionId = resolution.bridgeSessionId;
        if (bridgeSessionId == null || bridgeSessionId.isEmpty) {
          emit(
            const SessionLinkState.unavailable(
              reason: 'session_identity_missing',
              recoveryAction: 'refresh_sessions',
            ),
          );
          return;
        }
        emit(
          SessionLinkState.openLive(
            bridgeSessionId: bridgeSessionId,
            provider: resolution.provider ?? _provider,
          ),
        );
      case SessionOwnershipRoute.externalIdleResume:
        final recentSession = resolution.recentSession;
        if (recentSession == null) {
          emit(
            const SessionLinkState.unavailable(
              reason: 'session_identity_missing',
              recoveryAction: 'refresh_sessions',
            ),
          );
          return;
        }
        await _resume(recentSession, ownership!);
      case SessionOwnershipRoute.readOnlyHistory:
        final recentSession = resolution.recentSession;
        if (recentSession == null || ownership == null) {
          emit(
            const SessionLinkState.unavailable(
              reason: 'session_identity_missing',
              recoveryAction: 'refresh_sessions',
            ),
          );
          return;
        }
        _resumeSource = recentSession;
        _resumeOwnership = ownership;
        emit(
          SessionLinkState.openReadOnly(
            provider: resolution.provider ?? _provider,
            recentSession: recentSession,
            ownership: ownership,
          ),
        );
      case SessionOwnershipRoute.unavailable || null:
        emit(
          SessionLinkState.unavailable(
            reason: ownership?.readOnlyReason?.name ?? 'session_unavailable',
            recoveryAction: 'refresh_sessions',
          ),
        );
    }
  }

  Future<void> refresh() async {
    await _cancelResumeSubscription();
    _started = false;
    emit(const SessionLinkState.resolving());
    await resolve();
  }

  Future<void> resumeWhenIdle() async {
    final source = _resumeSource;
    final ownership = _resumeOwnership;
    if (source == null || ownership == null) {
      await refresh();
      return;
    }
    await _resume(source, ownership, allowReadOnlyProbe: true);
  }

  Future<void> _resume(
    RecentSession session,
    SessionOwnershipProjection ownership, {
    bool allowReadOnlyProbe = false,
  }) async {
    await _resumeSubscription?.cancel();
    _resumeSubscription = _bridge.messages.listen(_handleResumeMessage);
    _resumeSource = session;
    _resumeOwnership = ownership;
    emit(const SessionLinkState.resuming());
    final dispatch = await _resumeCoordinator.resume(
      session,
      resumeRequestId: _resumeRequestId,
      allowReadOnlyProbe: allowReadOnlyProbe,
    );
    if (isClosed) return;
    _resumeGitBranch = dispatch.gitBranch;
    if (dispatch.disposition == SessionResumeDisposition.alreadyQueued) {
      await _cancelResumeSubscription();
      emit(const SessionLinkState.unavailable());
    }
  }

  void _handleResumeMessage(ServerMessage message) {
    if (isClosed) return;
    if (message is ErrorMessage &&
        message.operation == 'resume_session' &&
        message.providerThreadId == _sourceSessionId) {
      unawaited(_cancelResumeSubscription());
      final source = _resumeSource;
      final ownership = _resumeOwnership;
      if (message.sessionRecoveryAction == SessionRecoveryAction.openReadOnly &&
          source != null &&
          ownership != null) {
        emit(
          SessionLinkState.openReadOnly(
            provider: source.provider ?? _provider,
            recentSession: source,
            ownership: ownership,
            failure: message,
          ),
        );
      } else {
        emit(
          SessionLinkState.unavailable(
            reason: message.errorCode,
            recoveryAction: message.recoveryAction,
            failure: message,
          ),
        );
      }
      return;
    }
    if (message is! SystemMessage) return;
    if (message.resumeRequestId != _resumeRequestId) return;
    if (message.subtype == 'session_created' && message.sessionId != null) {
      if (message.ownership?.routeForProvider(message.provider ?? _provider) !=
          SessionOwnershipRoute.ownedAttach) {
        unawaited(_cancelResumeSubscription());
        emit(
          const SessionLinkState.unavailable(
            reason: 'ownership_not_confirmed',
            recoveryAction: 'refresh_sessions',
          ),
        );
        return;
      }
      unawaited(_cancelResumeSubscription());
      emit(
        SessionLinkState.openResumed(
          session: message,
          gitBranch: _resumeGitBranch,
        ),
      );
      return;
    }
    if (message.subtype == 'session_resume_failed') {
      unawaited(_cancelResumeSubscription());
      emit(
        const SessionLinkState.unavailable(
          reason: 'resume_failed',
          recoveryAction: 'refresh_sessions',
        ),
      );
    }
  }

  Future<void> _cancelResumeSubscription() async {
    await _resumeSubscription?.cancel();
    _resumeSubscription = null;
  }

  @override
  Future<void> close() async {
    await _cancelResumeSubscription();
    return super.close();
  }
}

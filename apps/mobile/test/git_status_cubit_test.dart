import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/state/git_status_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';

class _GitStatusBridge extends BridgeService {
  final _statusController =
      StreamController<GitStatusResultMessage>.broadcast();
  final _stoppedController = StreamController<String>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<GitStatusResultMessage> get gitStatusResults =>
      _statusController.stream;

  @override
  Stream<String> get stoppedSessions => _stoppedController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  void emitStatus(GitStatusResultMessage message) {
    _statusController.add(message);
  }

  void emitStopped(String sessionId) {
    _stoppedController.add(sessionId);
  }

  @override
  void dispose() {
    _statusController.close();
    _stoppedController.close();
  }
}

void main() {
  group('GitStatusCubit', () {
    test('refresh marks session loading and sends git_status', () {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(bridge: bridge);
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      cubit.refresh(sessionId: 's1', projectPath: '/repo');

      final entry = cubit.state.entryFor('s1');
      expect(entry?.loading, isTrue);
      expect(entry?.showBadge, isFalse);
      final json =
          jsonDecode(bridge.sentMessages.single.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_status');
      expect(json['projectPath'], '/repo');
      expect(json['sessionId'], 's1');
      expect(json.containsKey('includeRemote'), isFalse);
    });

    test('updates badge state from git_status_result', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(bridge: bridge);
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      cubit.refresh(sessionId: 's1', projectPath: '/repo');
      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: true,
          stagedCount: 1,
          unstagedCount: 2,
          untrackedCount: 0,
        ),
      );
      await Future.microtask(() {});

      final entry = cubit.state.entryFor('s1');
      expect(entry?.loading, isFalse);
      expect(entry?.hasUncommittedChanges, isTrue);
      expect(entry?.showBadge, isTrue);
      expect(entry?.stagedCount, 1);
      expect(entry?.unstagedCount, 2);
    });

    test('requests and shows remote badge when enabled', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(
        bridge: bridge,
        remoteStatusBadgeEnabled: () => true,
      );
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      cubit.refresh(sessionId: 's1', projectPath: '/repo');

      final json =
          jsonDecode(bridge.sentMessages.single.toJson())
              as Map<String, dynamic>;
      expect(json['includeRemote'], isTrue);

      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: false,
          stagedCount: 0,
          unstagedCount: 0,
          untrackedCount: 0,
          remoteStatusIncluded: true,
          hasRemoteChanges: true,
          commitsAhead: 1,
          commitsBehind: 2,
          hasUpstream: true,
        ),
      );
      await Future.microtask(() {});

      final entry = cubit.state.entryFor('s1');
      expect(entry?.showDirtyBadge, isFalse);
      expect(entry?.showRemoteBadge(enabled: true), isTrue);
      expect(entry?.commitsAhead, 1);
      expect(entry?.commitsBehind, 2);
      expect(entry?.remoteCheckedAt, isNotNull);
    });

    test('dirty badge takes precedence over remote badge', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(bridge: bridge);
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: true,
          stagedCount: 0,
          unstagedCount: 1,
          untrackedCount: 0,
          remoteStatusIncluded: true,
          hasRemoteChanges: true,
          commitsAhead: 1,
          commitsBehind: 0,
          hasUpstream: true,
        ),
      );
      await Future.microtask(() {});

      final entry = cubit.state.entryFor('s1');
      expect(entry?.showDirtyBadge, isTrue);
      expect(entry?.showRemoteBadge(enabled: true), isFalse);
    });

    test('remote status uses ttl unless forced', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(
        bridge: bridge,
        remoteStatusBadgeEnabled: () => true,
      );
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      cubit.refresh(sessionId: 's1', projectPath: '/repo');
      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: false,
          stagedCount: 0,
          unstagedCount: 0,
          untrackedCount: 0,
          remoteStatusIncluded: true,
          hasRemoteChanges: true,
          commitsAhead: 1,
          commitsBehind: 0,
          hasUpstream: true,
        ),
      );
      await Future.microtask(() {});

      cubit.refresh(sessionId: 's1', projectPath: '/repo');
      var json =
          jsonDecode(bridge.sentMessages.last.toJson()) as Map<String, dynamic>;
      expect(json.containsKey('includeRemote'), isFalse);

      cubit.refresh(sessionId: 's1', projectPath: '/repo', forceRemote: true);
      json =
          jsonDecode(bridge.sentMessages.last.toJson()) as Map<String, dynamic>;
      expect(json['includeRemote'], isTrue);
    });

    test('does not show badge for error results', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(bridge: bridge);
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: true,
          stagedCount: 1,
          unstagedCount: 0,
          untrackedCount: 0,
          error: 'not a git repo',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.entryFor('s1')?.showBadge, isFalse);
    });

    test('clears cached status when session stops', () async {
      final bridge = _GitStatusBridge();
      final cubit = GitStatusCubit(bridge: bridge);
      addTearDown(() {
        cubit.close();
        bridge.dispose();
      });

      bridge.emitStatus(
        const GitStatusResultMessage(
          sessionId: 's1',
          projectPath: '/repo',
          hasUncommittedChanges: true,
          stagedCount: 0,
          unstagedCount: 1,
          untrackedCount: 0,
        ),
      );
      await Future.microtask(() {});
      expect(cubit.state.entryFor('s1'), isNotNull);

      bridge.emitStopped('s1');
      await Future.microtask(() {});

      expect(cubit.state.entryFor('s1'), isNull);
    });
  });
}

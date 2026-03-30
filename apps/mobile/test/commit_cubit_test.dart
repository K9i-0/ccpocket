import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/state/commit_cubit.dart';
import 'package:ccpocket/features/git/state/commit_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';

class MockCommitBridgeService extends BridgeService {
  final _commitController =
      StreamController<GitCommitResultMessage>.broadcast();
  final _pushController = StreamController<GitPushResultMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<GitCommitResultMessage> get gitCommitResults =>
      _commitController.stream;

  @override
  Stream<GitPushResultMessage> get gitPushResults => _pushController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  void emitCommit(GitCommitResultMessage msg) => _commitController.add(msg);
  void emitPush(GitPushResultMessage msg) => _pushController.add(msg);

  @override
  void dispose() {
    _commitController.close();
    _pushController.close();
  }
}

void main() {
  group('CommitCubit', () {
    late MockCommitBridgeService mockBridge;
    late CommitCubit cubit;

    setUp(() {
      mockBridge = MockCommitBridgeService();
      cubit = CommitCubit(bridge: mockBridge, projectPath: '/p');
    });

    tearDown(() {
      cubit.close();
      mockBridge.dispose();
    });

    test('initial state is idle', () {
      expect(cubit.state.status, CommitStatus.idle);
      expect(cubit.state.message, '');
      expect(cubit.state.autoGenerate, isTrue);
    });

    test('setMessage updates message', () {
      cubit.setMessage('feat: add feature');
      expect(cubit.state.message, 'feat: add feature');
    });

    test('toggleAutoGenerate toggles flag', () {
      cubit.toggleAutoGenerate();
      expect(cubit.state.autoGenerate, isFalse);
      cubit.toggleAutoGenerate();
      expect(cubit.state.autoGenerate, isTrue);
    });

    test('commit sends git_commit with message', () {
      cubit.toggleAutoGenerate();
      cubit.setMessage('feat: add x');
      cubit.commit();

      expect(cubit.state.status, CommitStatus.committing);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_commit');
      expect(json['message'], 'feat: add x');
    });

    test('commit with autoGenerate sends autoGenerate: true', () {
      cubit.commit();

      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['autoGenerate'], isTrue);
      expect(json.containsKey('message'), isFalse);
    });

    test('successful commit sets success status', () async {
      cubit.commit();
      mockBridge.emitCommit(
        const GitCommitResultMessage(
          success: true,
          commitHash: 'abc123',
          message: 'feat: add x',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.status, CommitStatus.success);
      expect(cubit.state.commitHash, 'abc123');
    });

    test('failed commit sets error status', () async {
      cubit.commit();
      mockBridge.emitCommit(
        const GitCommitResultMessage(
          success: false,
          error: 'Nothing to commit',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.status, CommitStatus.error);
      expect(cubit.state.error, 'Nothing to commit');
    });

    test('commitAndPush chains commit then push', () async {
      cubit.toggleAutoGenerate();
      cubit.setMessage('feat: x');
      cubit.commitAndPush();

      expect(cubit.state.status, CommitStatus.committing);

      mockBridge.emitCommit(
        const GitCommitResultMessage(success: true, commitHash: 'abc'),
      );
      await Future.microtask(() {});

      expect(cubit.state.status, CommitStatus.pushing);
      final pushJson =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(pushJson['type'], 'git_push');

      mockBridge.emitPush(
        const GitPushResultMessage(
          success: true,
          remote: 'origin',
          branch: 'feat/x',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.status, CommitStatus.success);
    });

    test('commitAndPush stops on commit failure', () async {
      cubit.commitAndPush();

      mockBridge.emitCommit(
        const GitCommitResultMessage(success: false, error: 'staging empty'),
      );
      await Future.microtask(() {});

      expect(cubit.state.status, CommitStatus.error);
      expect(cubit.state.error, 'staging empty');
      // Should NOT have sent git_push
      expect(
        mockBridge.sentMessages.where((m) => m.type == 'git_push').length,
        0,
      );
    });

    test('updateStagedSummary updates counts', () {
      cubit.updateStagedSummary(fileCount: 3, insertions: 42, deletions: 8);

      expect(cubit.state.stagedFileCount, 3);
      expect(cubit.state.insertions, 42);
      expect(cubit.state.deletions, 8);
    });

    test('reset returns to idle state', () async {
      cubit.commit();
      mockBridge.emitCommit(
        const GitCommitResultMessage(success: true, commitHash: 'abc'),
      );
      await Future.microtask(() {});

      cubit.reset();
      expect(cubit.state, const CommitState());
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/state/branch_cubit.dart';
import 'package:ccpocket/features/git/state/branch_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';

class MockBranchBridgeService extends BridgeService {
  final _branchesController =
      StreamController<GitBranchesResultMessage>.broadcast();
  final _createController =
      StreamController<GitCreateBranchResultMessage>.broadcast();
  final _checkoutController =
      StreamController<GitCheckoutBranchResultMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<GitBranchesResultMessage> get gitBranchesResults =>
      _branchesController.stream;

  @override
  Stream<GitCreateBranchResultMessage> get gitCreateBranchResults =>
      _createController.stream;

  @override
  Stream<GitCheckoutBranchResultMessage> get gitCheckoutBranchResults =>
      _checkoutController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  void emitBranches(GitBranchesResultMessage msg) =>
      _branchesController.add(msg);
  void emitCreate(GitCreateBranchResultMessage msg) =>
      _createController.add(msg);
  void emitCheckout(GitCheckoutBranchResultMessage msg) =>
      _checkoutController.add(msg);

  @override
  void dispose() {
    _branchesController.close();
    _createController.close();
    _checkoutController.close();
  }
}

void main() {
  group('BranchCubit', () {
    late MockBranchBridgeService mockBridge;
    late BranchCubit cubit;

    setUp(() {
      mockBridge = MockBranchBridgeService();
      cubit = BranchCubit(bridge: mockBridge, projectPath: '/p');
    });

    tearDown(() {
      cubit.close();
      mockBridge.dispose();
    });

    test('initial state is empty', () {
      expect(cubit.state, const BranchState());
      expect(cubit.state.branches, isEmpty);
      expect(cubit.state.current, isNull);
      expect(cubit.state.loading, isFalse);
    });

    test('loadBranches sends git_branches and updates on result', () async {
      cubit.loadBranches();

      expect(cubit.state.loading, isTrue);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_branches');

      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login', 'fix/bug'],
          remoteStatusByBranch: {
            'feat/login': GitBranchRemoteStatus(
              ahead: 2,
              behind: 1,
              hasUpstream: true,
            ),
          },
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.current, 'main');
      expect(cubit.state.branches, ['main', 'feat/login', 'fix/bug']);
      expect(cubit.state.remoteStatusByBranch['feat/login']?.ahead, 2);
    });

    test('loadBranches handles error', () async {
      cubit.loadBranches();

      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: '',
          branches: [],
          error: 'not a git repo',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, 'not a git repo');
    });

    test('search filters branches locally', () async {
      cubit.loadBranches();
      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login', 'feat/signup', 'fix/bug'],
        ),
      );
      await Future.microtask(() {});

      cubit.search('feat');
      expect(cubit.state.query, 'feat');
      expect(cubit.filteredBranches, ['feat/login', 'feat/signup']);
    });

    test('search with empty query returns all branches', () async {
      cubit.loadBranches();
      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login'],
        ),
      );
      await Future.microtask(() {});

      cubit.search('');
      expect(cubit.filteredBranches, ['main', 'feat/login']);
    });

    test('createBranch sends message and refreshes on success', () async {
      cubit.createBranch('feat/new', checkout: true);

      expect(cubit.state.creating, isTrue);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_create_branch');
      expect(json['name'], 'feat/new');
      expect(json['checkout'], isTrue);

      mockBridge.emitCreate(const GitCreateBranchResultMessage(success: true));
      await Future.microtask(() {});

      expect(cubit.state.creating, isFalse);
      // Should have sent a loadBranches refresh
      expect(
        mockBridge.sentMessages.where((m) => m.type == 'git_branches').length,
        1,
      );
    });

    test('createBranch failure sets error', () async {
      cubit.createBranch('dup');

      mockBridge.emitCreate(
        const GitCreateBranchResultMessage(
          success: false,
          error: 'branch exists',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.creating, isFalse);
      expect(cubit.state.error, 'branch exists');
    });

    test('checkout sends message and refreshes', () async {
      cubit.checkout('feat/login');

      expect(cubit.state.loading, isTrue);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_checkout_branch');
      expect(json['branch'], 'feat/login');

      mockBridge.emitCheckout(
        const GitCheckoutBranchResultMessage(success: true),
      );
      await Future.microtask(() {});

      // Should refresh branches
      expect(
        mockBridge.sentMessages.where((m) => m.type == 'git_branches').length,
        1,
      );
    });

    test('failed checkout sets error', () async {
      cubit.checkout('nonexistent');

      mockBridge.emitCheckout(
        const GitCheckoutBranchResultMessage(
          success: false,
          error: 'branch not found',
        ),
      );
      await Future.microtask(() {});

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, 'branch not found');
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/widgets/branch_selector_sheet.dart';
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
  void send(ClientMessage message) => sentMessages.add(message);

  void emitBranches(GitBranchesResultMessage msg) =>
      _branchesController.add(msg);

  @override
  void dispose() {
    _branchesController.close();
    _createController.close();
    _checkoutController.close();
  }
}

Widget _buildTestApp(MockBranchBridgeService mockBridge) {
  return MaterialApp(
    home: RepositoryProvider<BridgeService>.value(
      value: mockBridge,
      child: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showBranchSelectorSheet(context, '/p'),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('BranchSelectorSheet', () {
    late MockBranchBridgeService mockBridge;

    setUp(() {
      mockBridge = MockBranchBridgeService();
    });

    tearDown(() {
      mockBridge.dispose();
    });

    testWidgets('renders branch list', (tester) async {
      await tester.pumpWidget(_buildTestApp(mockBridge));
      await tester.tap(find.text('Open'));
      await tester.pump();

      // Emit branches
      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login', 'fix/bug'],
          remoteStatusByBranch: {
            'main': GitBranchRemoteStatus(
              ahead: 0,
              behind: 0,
              hasUpstream: true,
            ),
            'feat/login': GitBranchRemoteStatus(
              ahead: 2,
              behind: 1,
              hasUpstream: true,
            ),
            'fix/bug': GitBranchRemoteStatus(
              ahead: 0,
              behind: 0,
              hasUpstream: false,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('main'), findsOneWidget);
      expect(find.text('feat/login'), findsOneWidget);
      expect(find.text('fix/bug'), findsOneWidget);
      expect(find.text('↑2'), findsOneWidget);
      expect(find.text('↓1'), findsOneWidget);
      expect(find.text('No upstream'), findsOneWidget);
    });

    testWidgets('search filters displayed branches', (tester) async {
      await tester.pumpWidget(_buildTestApp(mockBridge));
      await tester.tap(find.text('Open'));
      await tester.pump();

      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login', 'feat/signup', 'fix/bug'],
          remoteStatusByBranch: {
            'feat/login': GitBranchRemoteStatus(
              ahead: 1,
              behind: 0,
              hasUpstream: true,
            ),
            'feat/signup': GitBranchRemoteStatus(
              ahead: 0,
              behind: 2,
              hasUpstream: true,
            ),
            'fix/bug': GitBranchRemoteStatus(
              ahead: 0,
              behind: 0,
              hasUpstream: false,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Type in search
      await tester.enterText(
        find.byKey(const ValueKey('branch_search_field')),
        'feat',
      );
      await tester.pump();

      expect(find.text('feat/login'), findsOneWidget);
      expect(find.text('feat/signup'), findsOneWidget);
      expect(find.text('fix/bug'), findsNothing);
    });

    testWidgets('tapping branch triggers checkout', (tester) async {
      await tester.pumpWidget(_buildTestApp(mockBridge));
      await tester.tap(find.text('Open'));
      await tester.pump();

      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main', 'feat/login'],
          remoteStatusByBranch: {
            'feat/login': GitBranchRemoteStatus(
              ahead: 0,
              behind: 0,
              hasUpstream: true,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap non-current branch
      await tester.tap(find.text('feat/login'));
      await tester.pumpAndSettle();

      // Should have sent checkout message
      expect(
        mockBridge.sentMessages.any((m) => m.type == 'git_checkout_branch'),
        isTrue,
      );
    });

    testWidgets('create branch button opens dialog', (tester) async {
      await tester.pumpWidget(_buildTestApp(mockBridge));
      await tester.tap(find.text('Open'));
      await tester.pump();

      mockBridge.emitBranches(
        const GitBranchesResultMessage(
          current: 'main',
          branches: ['main'],
          remoteStatusByBranch: {
            'main': GitBranchRemoteStatus(
              ahead: 0,
              behind: 0,
              hasUpstream: true,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create_branch_button')));
      await tester.pumpAndSettle();

      expect(find.text('New Branch'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('new_branch_name_field')),
        findsOneWidget,
      );
    });
  });
}

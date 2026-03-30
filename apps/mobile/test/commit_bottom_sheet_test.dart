import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/state/commit_cubit.dart';
import 'package:ccpocket/features/git/widgets/commit_bottom_sheet.dart';
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
  void send(ClientMessage message) => sentMessages.add(message);

  void emitCommit(GitCommitResultMessage msg) => _commitController.add(msg);

  @override
  void dispose() {
    _commitController.close();
    _pushController.close();
  }
}

Widget _buildTestApp(CommitCubit cubit) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showCommitBottomSheet(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('CommitBottomSheet', () {
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

    testWidgets('renders commit message field', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('commit_message_field')),
        findsOneWidget,
      );
    });

    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('commit_button_action')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('commit_push_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('commit_pr_button')), findsNothing);
    });

    testWidgets('auto-generate is enabled by default', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final autoGenerate = tester.widget<Switch>(
        find.byKey(const ValueKey('auto_generate_switch')),
      );
      expect(autoGenerate.value, isTrue);
    });

    testWidgets('commit button enabled when message empty', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final commitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('commit_button_action')),
      );
      expect(commitButton.onPressed, isNotNull);
    });

    testWidgets('manual entry is available when auto-generate is off', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('auto_generate_switch')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('commit_message_field')),
        'feat: add feature',
      );
      await tester.pump();

      final commitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('commit_button_action')),
      );
      expect(commitButton.onPressed, isNotNull);
    });

    testWidgets('text field is disabled while auto-generate is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('commit_message_field')),
      );
      expect(textField.enabled, isFalse);
      expect(textField.decoration?.hintText, 'Auto-generate with AI');
    });

    testWidgets('shows progress during commit', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap commit button
      await tester.tap(find.byKey(const ValueKey('commit_button_action')));
      await tester.pump();

      expect(find.byKey(const ValueKey('commit_progress')), findsOneWidget);
      expect(find.text('Committing...'), findsOneWidget);
    });

    testWidgets('shows success state after commit', (tester) async {
      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      cubit.setMessage('feat: x');
      cubit.commit();
      mockBridge.emitCommit(
        const GitCommitResultMessage(success: true, commitHash: 'abc1234'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Committed: abc1234'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}

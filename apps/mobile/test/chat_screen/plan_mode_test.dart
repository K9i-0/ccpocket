import 'package:ccpocket/features/chat/widgets/plan_mode_chip.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

const _planText = '''# Implementation Plan

## Step 1: Data Layer
- Create user model
- Add repository

## Step 2: UI Layer
- Create list screen
- Create detail screen

## Step 3: Testing
- Unit tests
- Widget tests

## Step 4: Integration
- Wire up navigation''';

Future<void> setupPlanApproval(PatrolTester $, MockBridgeService bridge) async {
  await $.pumpWidget(buildTestChatScreen(bridge: bridge));
  await pumpN($.tester);
  await emitAndPump($.tester, bridge, [
    makeEnterPlanMessage('enter-1', 'tool-enter-1'),
    makePlanExitMessage('exit-1', 'tool-exit-1', _planText),
    const PermissionRequestMessage(
      toolUseId: 'tool-exit-1',
      toolName: 'ExitPlanMode',
      input: {'plan': 'Implementation Plan'},
    ),
    const StatusMessage(status: ProcessStatus.waitingApproval),
  ]);
  await pumpN($.tester);
}

void main() {
  group('Plan Mode', () {
    patrolWidgetTest('C1: PlanModeChip displays when EnterPlanMode', ($) async {
      final bridge = MockBridgeService();
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        makeEnterPlanMessage('enter-1', 'tool-enter-1'),
      ]);
      await pumpN($.tester);

      expect($(PlanModeChip), findsOneWidget);
    });

    patrolWidgetTest(
      'C2: Plan approval bar shows Accept Plan / Keep Planning',
      ($) async {
        final bridge = MockBridgeService();
        await setupPlanApproval($, bridge);

        expect($(find.text('Accept Plan')), findsOneWidget);
        expect($(find.text('Keep Planning')), findsOneWidget);
        expect(
          $(find.byKey(const ValueKey('approve_always_button'))),
          findsNothing,
        );
      },
    );

    patrolWidgetTest('C3: Feedback input exists in plan approval', ($) async {
      final bridge = MockBridgeService();
      await setupPlanApproval($, bridge);

      expect(
        $(find.byKey(const ValueKey('plan_feedback_input'))),
        findsOneWidget,
      );
    });

    patrolWidgetTest('C4: Clear Context chip exists and toggles', ($) async {
      final bridge = MockBridgeService();
      await setupPlanApproval($, bridge);

      final chipFinder = find.byKey(const ValueKey('clear_context_chip'));
      expect($(chipFinder), findsOneWidget);

      // Verify chip is initially not selected
      var chip = $.tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isFalse);

      // Tap to toggle
      await $.tester.tap(chipFinder);
      await pumpN($.tester);

      // Verify chip is now selected
      chip = $.tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isTrue);
    });

    patrolWidgetTest('C5: Accept Plan sends approve', ($) async {
      final bridge = MockBridgeService();
      await setupPlanApproval($, bridge);

      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
    });

    patrolWidgetTest(
      'C6: Keep Planning with feedback sends reject with message',
      ($) async {
        final bridge = MockBridgeService();
        await setupPlanApproval($, bridge);

        // Enter feedback text
        await $.tester.enterText(
          find.byKey(const ValueKey('plan_feedback_input')),
          'Please add error handling',
        );
        await pumpN($.tester);

        // Tap Keep Planning (reject)
        await $.tester.tap(find.byKey(const ValueKey('reject_button')));
        await pumpN($.tester);

        final msg = findSentMessage(bridge, 'reject');
        expect(msg, isNotNull);
        expect(msg!['message'], 'Please add error handling');
      },
    );

    patrolWidgetTest('C7: Clear Context enabled sends clearContext: true', (
      $,
    ) async {
      final bridge = MockBridgeService();
      await setupPlanApproval($, bridge);

      // Tap clear context chip to enable it
      await $.tester.tap(find.byKey(const ValueKey('clear_context_chip')));
      await pumpN($.tester);

      // Tap Accept Plan (approve)
      await $.tester.tap(find.byKey(const ValueKey('approve_button')));
      await pumpN($.tester);

      final msg = findSentMessage(bridge, 'approve');
      expect(msg, isNotNull);
      expect(msg!['clearContext'], true);
    });

    patrolWidgetTest('C8: View Plan button exists', ($) async {
      final bridge = MockBridgeService();
      await setupPlanApproval($, bridge);

      expect(
        $(find.byKey(const ValueKey('view_plan_header_button'))),
        findsOneWidget,
      );
    });
  });
}

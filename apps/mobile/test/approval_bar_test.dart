import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/approval_bar.dart';

void main() {
  late TextEditingController feedbackController;

  setUp(() {
    feedbackController = TextEditingController();
  });

  tearDown(() {
    feedbackController.dispose();
  });

  Widget buildSubject({
    PermissionRequestMessage? pendingPermission,
    bool isPlanApproval = false,
    VoidCallback? onApprove,
    VoidCallback? onReject,
    VoidCallback? onApproveAlways,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ApprovalBar(
          appColors: AppColors.dark(),
          pendingPermission: pendingPermission,
          isPlanApproval: isPlanApproval,
          planFeedbackController: feedbackController,
          onApprove: onApprove ?? () {},
          onReject: onReject ?? () {},
          onApproveAlways: onApproveAlways ?? () {},
        ),
      ),
    );
  }

  group('ApprovalBar', () {
    testWidgets('shows tool name and summary for regular approval', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls -la'},
          ),
        ),
      );

      expect(find.text('Bash'), findsOneWidget);
      expect(find.text('ls -la'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Allow for this session'), findsOneWidget);
    });

    testWidgets('shows plan approval labels', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'ExitPlanMode',
            input: {},
          ),
          isPlanApproval: true,
        ),
      );

      expect(find.text('Plan Approval'), findsOneWidget);
      expect(find.text('Accept Plan'), findsOneWidget);
      expect(find.text('Keep Planning'), findsOneWidget);
      // "Allow for this session" hidden for plan approval
      expect(find.text('Allow for this session'), findsNothing);
    });

    testWidgets('shows feedback field for plan approval', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'ExitPlanMode',
            input: {},
          ),
          isPlanApproval: true,
        ),
      );

      expect(find.byKey(const ValueKey('plan_feedback_input')), findsOneWidget);
    });

    testWidgets('hides feedback field for regular approval', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
        ),
      );

      expect(find.byKey(const ValueKey('plan_feedback_input')), findsNothing);
    });

    testWidgets('approve callback fires on tap', (tester) async {
      var approved = false;
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
          onApprove: () => approved = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('approve_button')));
      expect(approved, isTrue);
    });

    testWidgets('reject callback fires on tap', (tester) async {
      var rejected = false;
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
          onReject: () => rejected = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('reject_button')));
      expect(rejected, isTrue);
    });

    testWidgets('approve always callback fires on tap', (tester) async {
      var approvedAlways = false;
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
          onApproveAlways: () => approvedAlways = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('approve_always_button')));
      expect(approvedAlways, isTrue);
    });

    testWidgets('fallback summary when no permission', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Tool execution requires approval'), findsOneWidget);
      expect(find.text('Approval Required'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
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
    PlanApprovalUiMode planApprovalUiMode = PlanApprovalUiMode.claude,
    VoidCallback? onApprove,
    VoidCallback? onReject,
    VoidCallback? onApproveAlways,
    VoidCallback? onViewPlan,
    VoidCallback? onApproveClearContext,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ApprovalBar(
          appColors: AppColors.dark(),
          pendingPermission: pendingPermission,
          isPlanApproval: isPlanApproval,
          planApprovalUiMode: planApprovalUiMode,
          planFeedbackController: feedbackController,
          onApprove: onApprove ?? () {},
          onReject: onReject ?? () {},
          onApproveAlways: onApproveAlways ?? () {},
          onViewPlan: onViewPlan,
          onApproveClearContext: onApproveClearContext,
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
      expect(find.text('Always'), findsOneWidget);
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
      // "Always" hidden for plan approval
      expect(find.text('Always'), findsNothing);
    });

    testWidgets('codex plan approval hides keep planning and clear action', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'ExitPlanMode',
            input: {},
          ),
          isPlanApproval: true,
          planApprovalUiMode: PlanApprovalUiMode.codex,
          onApproveClearContext: () {},
        ),
      );

      expect(find.byKey(const ValueKey('keep_planning_card')), findsNothing);
      expect(find.byKey(const ValueKey('plan_feedback_input')), findsNothing);
      expect(
        find.byKey(const ValueKey('approve_clear_context_button')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('reject_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('approve_button')), findsOneWidget);
    });

    testWidgets('shows feedback field inside Keep Planning card', (
      tester,
    ) async {
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

      // Feedback input is inside the Keep Planning card
      expect(find.byKey(const ValueKey('keep_planning_card')), findsOneWidget);
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
      expect(find.byKey(const ValueKey('keep_planning_card')), findsNothing);
    });

    testWidgets('reject callback fires on send button tap', (tester) async {
      var rejected = false;
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'ExitPlanMode',
            input: {},
          ),
          isPlanApproval: true,
          onReject: () => rejected = true,
        ),
      );

      // Send button inside Keep Planning card triggers reject
      await tester.tap(find.byKey(const ValueKey('reject_button')));
      expect(rejected, isTrue);
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

    testWidgets('reject callback fires on tap for regular approval', (
      tester,
    ) async {
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

    testWidgets(
      'shows View Plan button when isPlanApproval and onViewPlan set',
      (tester) async {
        var viewedPlan = false;
        await tester.pumpWidget(
          buildSubject(
            pendingPermission: const PermissionRequestMessage(
              toolUseId: 'tu-1',
              toolName: 'ExitPlanMode',
              input: {},
            ),
            isPlanApproval: true,
            onViewPlan: () => viewedPlan = true,
          ),
        );

        final button = find.byKey(const ValueKey('view_plan_header_button'));
        expect(button, findsOneWidget);

        await tester.tap(button);
        expect(viewedPlan, isTrue);
      },
    );

    testWidgets('hides View Plan button when onViewPlan is null', (
      tester,
    ) async {
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

      expect(
        find.byKey(const ValueKey('view_plan_header_button')),
        findsNothing,
      );
    });

    testWidgets('hides View Plan button for regular approval', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {'command': 'ls'},
          ),
          onViewPlan: () {},
        ),
      );

      expect(
        find.byKey(const ValueKey('view_plan_header_button')),
        findsNothing,
      );
    });

    testWidgets('View Plan button has View / Edit tooltip', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'ExitPlanMode',
            input: {},
          ),
          isPlanApproval: true,
          onViewPlan: () {},
        ),
      );

      final iconButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('view_plan_header_button')),
      );
      expect(iconButton.tooltip, 'View / Edit Plan');
    });

    testWidgets(
      'shows Accept & Clear button when onApproveClearContext is set',
      (tester) async {
        var cleared = false;
        await tester.pumpWidget(
          buildSubject(
            pendingPermission: const PermissionRequestMessage(
              toolUseId: 'tu-1',
              toolName: 'ExitPlanMode',
              input: {},
            ),
            isPlanApproval: true,
            onApproveClearContext: () => cleared = true,
          ),
        );

        final button = find.byKey(
          const ValueKey('approve_clear_context_button'),
        );
        expect(button, findsOneWidget);
        expect(find.text('Accept & Clear'), findsOneWidget);

        await tester.tap(button);
        expect(cleared, isTrue);
      },
    );

    testWidgets(
      'hides Accept & Clear button when onApproveClearContext is null',
      (tester) async {
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

        expect(
          find.byKey(const ValueKey('approve_clear_context_button')),
          findsNothing,
        );
      },
    );
  });
}

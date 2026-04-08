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

      expect(find.text('Command Approval'), findsOneWidget);
      expect(find.text('ls -la'), findsOneWidget);
      expect(find.text('Allow Once'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Permanently allow'), findsOneWidget);
      expect(find.text('Approve only this request'), findsNothing);
      expect(find.text('Stop this action'), findsNothing);
      expect(find.text('Command'), findsNothing);
    });

    testWidgets('shows granular approval detail lines', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'Bash',
            input: {
              'command': 'curl https://example.com',
              'additionalPermissions': {
                'fileSystem': {
                  'write': ['/tmp/project'],
                },
              },
              'proposedExecpolicyAmendment': {'mode': 'allow'},
              'availableDecisions': ['accept', 'decline'],
            },
          ),
        ),
      );

      expect(
        find.text('Additional permissions: fileSystem.write=/tmp/project'),
        findsOneWidget,
      );
      expect(find.text('Exec policy: mode=allow'), findsOneWidget);
      expect(find.text('Allowed actions: accept, decline'), findsOneWidget);
      expect(find.text('Allow command execution'), findsOneWidget);
      expect(find.text('One-time approval'), findsNothing);
    });

    testWidgets('shows primary target without redundant approval badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          pendingPermission: const PermissionRequestMessage(
            toolUseId: 'tu-1',
            toolName: 'AskUserQuestion',
            input: {
              'serverName': 'postgres',
              'questions': [
                {
                  'header': 'Approve app tool call?',
                  'question': 'Tool call: postgres.query("SELECT 1")',
                  'options': [
                    {'label': 'Approve Once', 'description': 'Allow once.'},
                    {
                      'label': 'Approve this Session',
                      'description': 'Allow for this session.',
                    },
                    {'label': 'Deny', 'description': 'Reject this tool call.'},
                    {'label': 'Cancel', 'description': 'Cancel and go back.'},
                  ],
                  'multiSelect': false,
                },
              ],
              'availableDecisions': ['accept', 'acceptForSession', 'decline'],
            },
          ),
          planApprovalUiMode: PlanApprovalUiMode.codex,
        ),
      );

      expect(find.text('Approve app tool call?'), findsOneWidget);
      expect(
        find.text('Tool call: postgres.query("SELECT 1")'),
        findsOneWidget,
      );
      expect(find.text('App Tool'), findsNothing);
      expect(find.text('Session-wide option available'), findsNothing);
      expect(
        find.text('Reuse this approval in the current session'),
        findsNothing,
      );
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
      // Tool approval buttons are hidden for plan approval
      expect(find.text('Permanently allow'), findsNothing);
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

    testWidgets('keep planning input is configured for multiline entry', (
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

      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('plan_feedback_input')),
      );
      expect(input.minLines, 1);
      expect(input.maxLines, 3);
      expect(input.keyboardType, TextInputType.multiline);
      expect(input.textInputAction, TextInputAction.newline);
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

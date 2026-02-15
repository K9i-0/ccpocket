import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';

/// Bottom bar that presents tool-use / plan approval controls.
///
/// Pure presentation — all actions are dispatched via callbacks.
class ApprovalBar extends StatelessWidget {
  final AppColors appColors;
  final PermissionRequestMessage? pendingPermission;
  final bool isPlanApproval;
  final TextEditingController planFeedbackController;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onApproveAlways;
  final VoidCallback? onViewPlan;

  /// Callback for "Accept & Clear Context" button (plan approval only).
  final VoidCallback? onApproveClearContext;

  const ApprovalBar({
    super.key,
    required this.appColors,
    required this.pendingPermission,
    required this.isPlanApproval,
    required this.planFeedbackController,
    required this.onApprove,
    required this.onReject,
    required this.onApproveAlways,
    this.onViewPlan,
    this.onApproveClearContext,
  });

  @override
  Widget build(BuildContext context) {
    final summary = pendingPermission != null
        ? (isPlanApproval
              ? 'Review the plan above and approve or continue planning'
              : pendingPermission!.summary)
        : 'Tool execution requires approval';
    final toolName = isPlanApproval
        ? 'Plan Approval'
        : pendingPermission?.toolName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            appColors.approvalBar,
            appColors.approvalBar.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          top: BorderSide(color: appColors.approvalBarBorder, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, toolName, summary),
            const SizedBox(height: 6),
            if (isPlanApproval) ...[
              const SizedBox(height: 6),
              _buildKeepPlanningCard(context),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 6),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? toolName, String summary) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: (isPlanApproval ? cs.primary : appColors.permissionIcon)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPlanApproval ? Icons.assignment : Icons.shield,
            color: isPlanApproval ? cs.primary : appColors.permissionIcon,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toolName ?? 'Approval Required',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary,
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
                maxLines: isPlanApproval ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isPlanApproval && onViewPlan != null)
          IconButton(
            key: const ValueKey('view_plan_header_button'),
            icon: Icon(Icons.open_in_full, size: 18, color: cs.primary),
            tooltip: 'View / Edit Plan',
            onPressed: onViewPlan,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  /// "Keep Planning" card with feedback input + send button.
  Widget _buildKeepPlanningCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('keep_planning_card'),
      decoration: BoxDecoration(
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Keep Planning',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.subtleText,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('plan_feedback_input'),
                  controller: planFeedbackController,
                  decoration: InputDecoration(
                    hintText: 'What should be changed...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: appColors.subtleText,
                    ),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('reject_button'),
                icon: Icon(Icons.send, size: 20, color: cs.primary),
                tooltip: 'Send feedback & keep planning',
                onPressed: onReject,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (isPlanApproval) {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('approve_button'),
              onPressed: onApprove,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Accept Plan',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          if (onApproveClearContext != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                key: const ValueKey('approve_clear_context_button'),
                onPressed: onApproveClearContext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'Accept & Clear',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('reject_button'),
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const ValueKey('approve_button'),
            onPressed: onApprove,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Approve', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            key: const ValueKey('approve_always_button'),
            onPressed: onApproveAlways,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Always', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

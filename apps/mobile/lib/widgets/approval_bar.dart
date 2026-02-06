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
  final bool clearContext;
  final ValueChanged<bool>? onClearContextChanged;

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
    this.clearContext = false,
    this.onClearContextChanged,
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
              _buildFeedbackField(context),
            ],
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

  Widget _buildFeedbackField(BuildContext context) {
    return TextField(
      key: const ValueKey('plan_feedback_input'),
      controller: planFeedbackController,
      decoration: InputDecoration(
        hintText: 'Feedback for plan revision...',
        hintStyle: TextStyle(fontSize: 12, color: appColors.subtleText),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
      maxLines: 3,
      minLines: 1,
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (isPlanApproval) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClearContextChanged != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: const ValueKey('clear_context_chip'),
                label: const Text(
                  'Clear Context',
                  style: TextStyle(fontSize: 12),
                ),
                selected: clearContext,
                onSelected: onClearContextChanged!,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (onClearContextChanged != null) const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('reject_button'),
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Keep Planning',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
            ],
          ),
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

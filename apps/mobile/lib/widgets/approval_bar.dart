import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';

enum PlanApprovalUiMode { claude, codex }

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
  final PlanApprovalUiMode planApprovalUiMode;

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
    this.planApprovalUiMode = PlanApprovalUiMode.claude,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = pendingPermission != null
        ? (isPlanApproval ? l.planApprovalSummary : pendingPermission!.summary)
        : l.toolApprovalSummary;
    final toolName = isPlanApproval
        ? l.planApproval
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
            _ApprovalHeader(
              appColors: appColors,
              isPlanApproval: isPlanApproval,
              toolName: toolName,
              summary: summary,
              onViewPlan: onViewPlan,
            ),
            const SizedBox(height: 6),
            if (isPlanApproval &&
                planApprovalUiMode == PlanApprovalUiMode.claude) ...[
              const SizedBox(height: 6),
              _KeepPlanningCard(
                appColors: appColors,
                planFeedbackController: planFeedbackController,
                onReject: onReject,
              ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 6),
            _ApprovalButtons(
              isPlanApproval: isPlanApproval,
              planApprovalUiMode: planApprovalUiMode,
              onApprove: onApprove,
              onReject: onReject,
              onApproveAlways: onApproveAlways,
              onApproveClearContext: onApproveClearContext,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalHeader extends StatelessWidget {
  final AppColors appColors;
  final bool isPlanApproval;
  final String? toolName;
  final String summary;
  final VoidCallback? onViewPlan;

  const _ApprovalHeader({
    required this.appColors,
    required this.isPlanApproval,
    required this.toolName,
    required this.summary,
    this.onViewPlan,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                toolName ?? l.approvalRequired,
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
            tooltip: l.viewEditPlan,
            onPressed: onViewPlan,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }
}

/// "Keep Planning" card with feedback input + send button.
class _KeepPlanningCard extends StatelessWidget {
  final AppColors appColors;
  final TextEditingController planFeedbackController;
  final VoidCallback onReject;

  const _KeepPlanningCard({
    required this.appColors,
    required this.planFeedbackController,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('keep_planning_card'),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.keepPlanning,
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
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: l.keepPlanningHint,
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
                tooltip: l.sendFeedbackKeepPlanning,
                onPressed: onReject,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalButtons extends StatelessWidget {
  final bool isPlanApproval;
  final PlanApprovalUiMode planApprovalUiMode;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onApproveAlways;
  final VoidCallback? onApproveClearContext;

  const _ApprovalButtons({
    required this.isPlanApproval,
    required this.planApprovalUiMode,
    required this.onApprove,
    required this.onReject,
    required this.onApproveAlways,
    this.onApproveClearContext,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isPlanApproval) {
      if (planApprovalUiMode == PlanApprovalUiMode.codex) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('reject_button'),
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(l.reject, style: const TextStyle(fontSize: 13)),
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
                child: Text(l.acceptPlan, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          if (onApproveClearContext != null) ...[
            Expanded(
              child: FilledButton.tonal(
                key: const ValueKey('approve_clear_context_button'),
                onPressed: onApproveClearContext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  l.acceptAndClear,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton(
              key: const ValueKey('approve_button'),
              onPressed: onApprove,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(l.acceptPlan, style: const TextStyle(fontSize: 13)),
            ),
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
            child: Text(l.reject, style: const TextStyle(fontSize: 13)),
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
            child: Text(l.approve, style: const TextStyle(fontSize: 13)),
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
            child: Text(l.always, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

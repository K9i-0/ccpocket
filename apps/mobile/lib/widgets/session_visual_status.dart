import '../l10n/app_localizations.dart';
import '../models/messages.dart';

enum SessionPrimaryStatus { working, needsYou, ready }

class SessionVisualStatus {
  final SessionPrimaryStatus primary;
  final String label;
  final String? detail;
  final bool showPlanBadge;
  final bool animate;

  const SessionVisualStatus({
    required this.primary,
    required this.label,
    this.detail,
    required this.showPlanBadge,
    required this.animate,
  });
}

SessionVisualStatus sessionVisualStatusFor({
  required AppLocalizations l,
  required String rawStatus,
  String? permissionMode,
  PermissionRequestMessage? pendingPermission,
}) {
  final showPlanBadge = permissionMode == PermissionMode.plan.value;

  if (pendingPermission != null) {
    final detail = switch (pendingPermission.toolName) {
      'ExitPlanMode' => l.statusReviewPlan,
      'AskUserQuestion' =>
        pendingPermission.isRequestUserInputApproval
            ? l.statusApproveToolCall
            : l.statusAnswerQuestion,
      _ => l.statusApproveTool(pendingPermission.toolName),
    };
    return SessionVisualStatus(
      primary: SessionPrimaryStatus.needsYou,
      label: l.statusNeedsYou,
      detail: detail,
      showPlanBadge: showPlanBadge,
      animate: true,
    );
  }

  return switch (rawStatus) {
    'starting' || 'running' => SessionVisualStatus(
      primary: SessionPrimaryStatus.working,
      label: l.statusWorking,
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    'compacting' => SessionVisualStatus(
      primary: SessionPrimaryStatus.working,
      label: l.statusWorking,
      detail: l.statusCleaningContext,
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    'waiting_approval' => SessionVisualStatus(
      primary: SessionPrimaryStatus.needsYou,
      label: l.statusNeedsYou,
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    _ => SessionVisualStatus(
      primary: SessionPrimaryStatus.ready,
      label: l.statusReady,
      showPlanBadge: showPlanBadge,
      animate: false,
    ),
  };
}

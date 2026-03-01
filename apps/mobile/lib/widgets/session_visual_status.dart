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
  required String rawStatus,
  String? permissionMode,
  PermissionRequestMessage? pendingPermission,
}) {
  final showPlanBadge = permissionMode == PermissionMode.plan.value;

  if (pendingPermission != null) {
    final detail = switch (pendingPermission.toolName) {
      'ExitPlanMode' => 'Review plan',
      'AskUserQuestion' => 'Answer question',
      _ => 'Approve ${pendingPermission.toolName}',
    };
    return SessionVisualStatus(
      primary: SessionPrimaryStatus.needsYou,
      label: 'Needs You',
      detail: detail,
      showPlanBadge: showPlanBadge,
      animate: true,
    );
  }

  return switch (rawStatus) {
    'starting' || 'running' => SessionVisualStatus(
      primary: SessionPrimaryStatus.working,
      label: 'Working',
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    'compacting' => SessionVisualStatus(
      primary: SessionPrimaryStatus.working,
      label: 'Working',
      detail: 'Cleaning up context',
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    'waiting_approval' => SessionVisualStatus(
      primary: SessionPrimaryStatus.needsYou,
      label: 'Needs You',
      showPlanBadge: showPlanBadge,
      animate: true,
    ),
    _ => SessionVisualStatus(
      primary: SessionPrimaryStatus.ready,
      label: 'Ready',
      showPlanBadge: showPlanBadge,
      animate: false,
    ),
  };
}

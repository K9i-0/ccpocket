import '../../models/messages.dart';

enum PermissionTranscriptStatus {
  pending,
  approved,
  approvedForSession,
  rejected,
  answered,
  resolved,
}

PermissionTranscriptStatus? syntheticPermissionOutcome(
  ToolResultMessage message,
) {
  return switch (message.permissionOutcome) {
    PermissionOutcome.approved => PermissionTranscriptStatus.approved,
    PermissionOutcome.approvedForSession =>
      PermissionTranscriptStatus.approvedForSession,
    PermissionOutcome.rejected => PermissionTranscriptStatus.rejected,
    PermissionOutcome.answered => PermissionTranscriptStatus.answered,
    null => null,
  };
}

bool isSyntheticPermissionOutcome(ToolResultMessage message) =>
    syntheticPermissionOutcome(message) != null;

Map<String, PermissionTranscriptStatus> derivePermissionTranscriptStatuses(
  List<ChatEntry> entries, {
  required ProcessStatus processStatus,
  String? activeToolUseId,
}) {
  final statuses = <String, PermissionTranscriptStatus>{};

  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    switch (entry.message) {
      case PermissionRequestMessage(:final toolUseId):
        statuses.putIfAbsent(
          toolUseId,
          () => PermissionTranscriptStatus.pending,
        );
      case PermissionResolvedMessage(:final toolUseId):
        if (statuses[toolUseId] == PermissionTranscriptStatus.pending) {
          statuses[toolUseId] = PermissionTranscriptStatus.resolved;
        }
      case final ToolResultMessage result:
        if (!statuses.containsKey(result.toolUseId)) continue;
        final outcome = syntheticPermissionOutcome(result);
        if (outcome != null) {
          statuses[result.toolUseId] = outcome;
        } else if (statuses[result.toolUseId] ==
            PermissionTranscriptStatus.pending) {
          statuses[result.toolUseId] = PermissionTranscriptStatus.resolved;
        }
      default:
        break;
    }
  }

  // Old Bridges can restore a request without a permission_resolved event.
  // If the session itself is no longer waiting, do not present that request as
  // actionable. The currently active request remains pending during the brief
  // permission_request -> waiting_approval status race.
  if (processStatus != ProcessStatus.waitingApproval) {
    for (final entry in statuses.entries.toList()) {
      if (entry.value == PermissionTranscriptStatus.pending &&
          entry.key != activeToolUseId) {
        statuses[entry.key] = PermissionTranscriptStatus.resolved;
      }
    }
  }

  return statuses;
}

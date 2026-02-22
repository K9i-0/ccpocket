import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';
import '../../../widgets/slash_command_sheet.dart' show SlashCommand;

part 'chat_session_state.freezed.dart';

/// Core state for a single chat session, managed by [ChatSessionNotifier].
@freezed
abstract class ChatSessionState with _$ChatSessionState {
  const factory ChatSessionState({
    // Process status
    @Default(ProcessStatus.starting) ProcessStatus status,

    // Messages
    @Default([]) List<ChatEntry> entries,

    // Approval / AskUserQuestion
    @Default(ApprovalState.none()) ApprovalState approval,

    // Session metadata
    String? claudeSessionId,
    String? projectPath,
    String? gitBranch,

    // Flags
    @Default(false) bool pastHistoryLoaded,
    @Default(false) bool bulkLoading,
    @Default(false) bool inPlanMode,
    @Default(false) bool collapseToolResults,

    // Permission mode selected by the user
    @Default(PermissionMode.defaultMode) PermissionMode permissionMode,

    // Sandbox mode for Codex sessions
    @Default(SandboxMode.on) SandboxMode sandboxMode,

    // Tool use IDs hidden by tool_use_summary (subagent compression)
    @Default({}) Set<String> hiddenToolUseIds,

    // Rewind preview (dry-run result)
    RewindPreviewMessage? rewindPreview,

    // Cost tracking
    @Default(0.0) double totalCost,
    Duration? totalDuration,

    // Slash commands available in this session
    @Default([]) List<SlashCommand> slashCommands,
  }) = _ChatSessionState;
}

/// Represents the current approval/question state.
///
/// Uses sealed union so the UI can pattern-match exhaustively.
@freezed
abstract class ApprovalState with _$ApprovalState {
  /// No pending approval.
  const factory ApprovalState.none() = ApprovalNone;

  /// A tool is requesting permission to execute.
  const factory ApprovalState.permission({
    required String toolUseId,
    required PermissionRequestMessage request,
  }) = ApprovalPermission;

  /// Claude is asking the user a question (AskUserQuestion tool).
  const factory ApprovalState.askUser({
    required String toolUseId,
    required Map<String, dynamic> input,
  }) = ApprovalAskUser;
}

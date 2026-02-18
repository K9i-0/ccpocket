import 'dart:convert';
import 'dart:typed_data';

// ---- Assistant content types ----

sealed class AssistantContent {
  factory AssistantContent.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'text' => TextContent(text: json['text'] as String),
      'tool_use' => ToolUseContent(
        id: json['id'] as String,
        name: json['name'] as String,
        input: Map<String, dynamic>.from(json['input'] as Map),
      ),
      'thinking' => ThinkingContent(
        thinking: json['thinking'] as String? ?? '',
      ),
      _ => TextContent(text: '[Unknown content type: ${json['type']}]'),
    };
  }
}

class TextContent implements AssistantContent {
  final String text;
  const TextContent({required this.text});
}

class ToolUseContent implements AssistantContent {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  const ToolUseContent({
    required this.id,
    required this.name,
    required this.input,
  });
}

class ThinkingContent implements AssistantContent {
  final String thinking;
  const ThinkingContent({required this.thinking});
}

// ---- Assistant message ----

class AssistantMessage {
  final String id;
  final String role;
  final List<AssistantContent> content;
  final String model;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.model,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    final contentList = (json['content'] as List)
        .map((c) => AssistantContent.fromJson(c as Map<String, dynamic>))
        .toList();
    return AssistantMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: contentList,
      model: json['model'] as String? ?? '',
    );
  }
}

// ---- Bridge connection state ----

enum BridgeConnectionState { disconnected, connecting, connected, reconnecting }

// ---- Message status (for user messages) ----

enum MessageStatus { sending, sent, failed }

// ---- Process status ----

enum ProcessStatus {
  starting,
  idle,
  running,
  waitingApproval;

  static ProcessStatus fromString(String value) {
    return switch (value) {
      'starting' => ProcessStatus.starting,
      'idle' => ProcessStatus.idle,
      'running' => ProcessStatus.running,
      'waiting_approval' => ProcessStatus.waitingApproval,
      _ => ProcessStatus.idle,
    };
  }
}

// ---- Provider ----

enum Provider {
  claude('claude', 'Claude Code'),
  codex('codex', 'Codex');

  final String value;
  final String label;
  const Provider(this.value, this.label);
}

// ---- Permission mode ----

enum PermissionMode {
  defaultMode('default', 'Default'),
  plan('plan', 'Plan'),
  acceptEdits('acceptEdits', 'Accept Edits'),
  bypassPermissions('bypassPermissions', 'Bypass All');

  final String value;
  final String label;
  const PermissionMode(this.value, this.label);
}

enum ClaudeEffort {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  max('max', 'Max');

  final String value;
  final String label;
  const ClaudeEffort(this.value, this.label);
}

// ---- Codex sandbox mode ----

enum SandboxMode {
  readOnly('read-only', 'Read Only'),
  workspaceWrite('workspace-write', 'Workspace Write'),
  dangerFullAccess('danger-full-access', 'Full Access ⚠️');

  final String value;
  final String label;
  const SandboxMode(this.value, this.label);
}

// ---- Codex approval policy ----

enum ApprovalPolicy {
  never('never', 'Never (Auto)'),
  onRequest('on-request', 'On Request'),
  onFailure('on-failure', 'On Failure'),
  untrusted('untrusted', 'Untrusted');

  final String value;
  final String label;
  const ApprovalPolicy(this.value, this.label);
}

enum ReasoningEffort {
  minimal('minimal', 'Minimal'),
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  xhigh('xhigh', 'XHigh');

  final String value;
  final String label;
  const ReasoningEffort(this.value, this.label);
}

enum WebSearchMode {
  disabled('disabled', 'Disabled'),
  cached('cached', 'Cached'),
  live('live', 'Live');

  final String value;
  final String label;
  const WebSearchMode(this.value, this.label);
}

// ---- Image reference ----

class ImageRef {
  final String id;
  final String url;
  final String mimeType;

  const ImageRef({required this.id, required this.url, required this.mimeType});

  factory ImageRef.fromJson(Map<String, dynamic> json) {
    return ImageRef(
      id: json['id'] as String,
      url: json['url'] as String,
      mimeType: json['mimeType'] as String,
    );
  }
}

// ---- Worktree info ----

class WorktreeInfo {
  final String worktreePath;
  final String branch;
  final String projectPath;
  final String? head;

  const WorktreeInfo({
    required this.worktreePath,
    required this.branch,
    required this.projectPath,
    this.head,
  });

  factory WorktreeInfo.fromJson(Map<String, dynamic> json) {
    return WorktreeInfo(
      worktreePath: json['worktreePath'] as String,
      branch: json['branch'] as String,
      projectPath: json['projectPath'] as String,
      head: json['head'] as String?,
    );
  }
}

// ---- Gallery image ----

class GalleryImage {
  final String id;
  final String url;
  final String mimeType;
  final String projectPath;
  final String projectName;
  final String? sessionId;
  final String addedAt;
  final int sizeBytes;

  const GalleryImage({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.projectPath,
    required this.projectName,
    this.sessionId,
    required this.addedAt,
    required this.sizeBytes,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: json['id'] as String,
      url: json['url'] as String,
      mimeType: json['mimeType'] as String,
      projectPath: json['projectPath'] as String,
      projectName: json['projectName'] as String,
      sessionId: json['sessionId'] as String?,
      addedAt: json['addedAt'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }
}

// ---- Usage info ----

class UsageWindow {
  final double utilization;
  final String resetsAt;

  const UsageWindow({required this.utilization, required this.resetsAt});

  factory UsageWindow.fromJson(Map<String, dynamic> json) {
    return UsageWindow(
      utilization: (json['utilization'] as num).toDouble(),
      resetsAt: json['resetsAt'] as String,
    );
  }

  /// Parse resetsAt as DateTime (ISO 8601).
  DateTime? get resetsAtDateTime => DateTime.tryParse(resetsAt);
}

class UsageInfo {
  final String provider;
  final UsageWindow? fiveHour;
  final UsageWindow? sevenDay;
  final String? error;

  const UsageInfo({
    required this.provider,
    this.fiveHour,
    this.sevenDay,
    this.error,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      provider: json['provider'] as String,
      fiveHour: json['fiveHour'] != null
          ? UsageWindow.fromJson(json['fiveHour'] as Map<String, dynamic>)
          : null,
      sevenDay: json['sevenDay'] != null
          ? UsageWindow.fromJson(json['sevenDay'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  bool get hasData => fiveHour != null || sevenDay != null;
  bool get hasError => error != null && !hasData;
}

// ---- Helpers ----

/// Normalize tool_result content: Claude CLI may send String or List of content blocks.
String _normalizeToolResultContent(dynamic content) {
  if (content is String) return content;
  if (content is List) {
    return content
        .whereType<Map<String, dynamic>>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text']?.toString() ?? '')
        .join('\n');
  }
  return content?.toString() ?? '';
}

// ---- Server messages ----

sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'system' => SystemMessage(
        subtype: json['subtype'] as String? ?? '',
        sessionId: json['sessionId'] as String?,
        model: json['model'] as String?,
        provider: json['provider'] as String?,
        projectPath: json['projectPath'] as String?,
        permissionMode: json['permissionMode'] as String?,
        sandboxMode: json['sandboxMode'] as String?,
        slashCommands:
            (json['slashCommands'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        skills:
            (json['skills'] as List?)?.map((e) => e as String).toList() ??
            const [],
        worktreePath: json['worktreePath'] as String?,
        worktreeBranch: json['worktreeBranch'] as String?,
        clearContext: json['clearContext'] as bool? ?? false,
      ),
      'assistant' => AssistantServerMessage(
        message: AssistantMessage.fromJson(
          json['message'] as Map<String, dynamic>,
        ),
        messageUuid: json['messageUuid'] as String?,
      ),
      'tool_result' => ToolResultMessage(
        toolUseId: json['toolUseId'] as String,
        content: _normalizeToolResultContent(json['content']),
        toolName: json['toolName'] as String?,
        images:
            (json['images'] as List?)
                ?.map((i) => ImageRef.fromJson(i as Map<String, dynamic>))
                .toList() ??
            const [],
        userMessageUuid: json['userMessageUuid'] as String?,
      ),
      'result' => ResultMessage(
        subtype: json['subtype'] as String? ?? '',
        result: json['result'] as String?,
        error: json['error'] as String?,
        cost: (json['cost'] as num?)?.toDouble(),
        duration: (json['duration'] as num?)?.toDouble(),
        sessionId: json['sessionId'] as String?,
        stopReason: json['stopReason'] as String?,
        inputTokens: json['inputTokens'] as int?,
        cachedInputTokens: json['cachedInputTokens'] as int?,
        outputTokens: json['outputTokens'] as int?,
        toolCalls: json['toolCalls'] as int?,
        fileEdits: json['fileEdits'] as int?,
      ),
      'error' => ErrorMessage(message: json['message'] as String),
      'status' => StatusMessage(
        status: ProcessStatus.fromString(json['status'] as String),
      ),
      'history' => HistoryMessage(
        messages: (json['messages'] as List)
            .map((m) => ServerMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      ),
      'permission_request' => PermissionRequestMessage(
        toolUseId: json['toolUseId'] as String,
        toolName: json['toolName'] as String,
        input: Map<String, dynamic>.from(json['input'] as Map),
      ),
      'stream_delta' => StreamDeltaMessage(text: json['text'] as String),
      'thinking_delta' => ThinkingDeltaMessage(text: json['text'] as String),
      'session_list' => SessionListMessage(
        sessions: (json['sessions'] as List)
            .map((s) => SessionInfo.fromJson(s as Map<String, dynamic>))
            .toList(),
      ),
      'recent_sessions' => RecentSessionsMessage(
        sessions: (json['sessions'] as List)
            .map((s) => RecentSession.fromJson(s as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] as bool? ?? false,
      ),
      'past_history' => PastHistoryMessage(
        claudeSessionId: json['claudeSessionId'] as String? ?? '',
        messages: (json['messages'] as List)
            .map((m) => PastMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      ),
      'gallery_list' => GalleryListMessage(
        images: (json['images'] as List)
            .map((i) => GalleryImage.fromJson(i as Map<String, dynamic>))
            .toList(),
      ),
      'gallery_new_image' => GalleryNewImageMessage(
        image: GalleryImage.fromJson(json['image'] as Map<String, dynamic>),
      ),
      'window_list' => WindowListMessage(
        windows: (json['windows'] as List)
            .map((w) => WindowInfo.fromJson(w as Map<String, dynamic>))
            .toList(),
      ),
      'screenshot_result' => ScreenshotResultMessage(
        success: json['success'] as bool? ?? false,
        image: json['image'] != null
            ? GalleryImage.fromJson(json['image'] as Map<String, dynamic>)
            : null,
        error: json['error'] as String?,
      ),
      'debug_bundle' => DebugBundleMessage(
        sessionId: json['sessionId'] as String? ?? '',
        generatedAt: json['generatedAt'] as String? ?? '',
        session: DebugBundleSession.fromJson(
          json['session'] as Map<String, dynamic>? ?? const {},
        ),
        pastMessageCount: json['pastMessageCount'] as int? ?? 0,
        historySummary:
            (json['historySummary'] as List?)?.cast<String>() ?? const [],
        debugTrace:
            (json['debugTrace'] as List?)
                ?.map(
                  (e) => DebugTraceEvent.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        traceFilePath: json['traceFilePath'] as String?,
        savedBundlePath: json['savedBundlePath'] as String?,
        reproRecipe: DebugReproRecipe.fromJson(
          json['reproRecipe'] as Map<String, dynamic>? ??
              const <String, dynamic>{},
        ),
        agentPrompt: json['agentPrompt'] as String? ?? '',
        diff: json['diff'] as String? ?? '',
        diffError: json['diffError'] as String?,
      ),
      'file_list' => FileListMessage(
        files: (json['files'] as List).cast<String>(),
      ),
      'project_history' => ProjectHistoryMessage(
        projects: (json['projects'] as List).cast<String>(),
      ),
      'diff_result' => DiffResultMessage(
        diff: json['diff'] as String? ?? '',
        error: json['error'] as String?,
      ),
      'worktree_list' => WorktreeListMessage(
        worktrees: (json['worktrees'] as List)
            .map((w) => WorktreeInfo.fromJson(w as Map<String, dynamic>))
            .toList(),
      ),
      'worktree_removed' => WorktreeRemovedMessage(
        worktreePath: json['worktreePath'] as String,
      ),
      'tool_use_summary' => ToolUseSummaryMessage(
        summary: json['summary'] as String,
        precedingToolUseIds:
            (json['precedingToolUseIds'] as List?)?.cast<String>() ?? const [],
      ),
      'user_input' => UserInputMessage(
        text: json['text'] as String? ?? '',
        userMessageUuid: json['userMessageUuid'] as String?,
        isSynthetic: json['isSynthetic'] as bool? ?? false,
        isMeta: json['isMeta'] as bool? ?? false,
      ),
      'rewind_preview' => RewindPreviewMessage(
        canRewind: json['canRewind'] as bool? ?? false,
        filesChanged: (json['filesChanged'] as List?)?.cast<String>(),
        insertions: json['insertions'] as int?,
        deletions: json['deletions'] as int?,
        error: json['error'] as String?,
      ),
      'rewind_result' => RewindResultMessage(
        success: json['success'] as bool? ?? false,
        mode: json['mode'] as String? ?? 'both',
        error: json['error'] as String?,
      ),
      'input_ack' => InputAckMessage(sessionId: json['sessionId'] as String?),
      'input_rejected' => InputRejectedMessage(
        sessionId: json['sessionId'] as String?,
        reason: json['reason'] as String?,
      ),
      'usage_result' => UsageResultMessage(
        providers: (json['providers'] as List)
            .map((p) => UsageInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
      ),
      'recording_list' => RecordingListMessage(
        recordings: (json['recordings'] as List)
            .map((r) => RecordingInfo.fromJson(r as Map<String, dynamic>))
            .toList(),
      ),
      'recording_content' => RecordingContentMessage(
        sessionId: json['sessionId'] as String? ?? '',
        content: json['content'] as String? ?? '',
      ),
      _ => ErrorMessage(message: 'Unknown message type: ${json['type']}'),
    };
  }
}

class SystemMessage implements ServerMessage {
  final String subtype;
  final String? sessionId;
  final String? model;
  final String? provider;
  final String? projectPath;
  final String? permissionMode;
  final String? sandboxMode;
  final List<String> slashCommands;
  final List<String> skills;
  final String? worktreePath;
  final String? worktreeBranch;
  final bool clearContext;
  const SystemMessage({
    required this.subtype,
    this.sessionId,
    this.model,
    this.provider,
    this.projectPath,
    this.permissionMode,
    this.sandboxMode,
    this.slashCommands = const [],
    this.skills = const [],
    this.worktreePath,
    this.worktreeBranch,
    this.clearContext = false,
  });
}

class AssistantServerMessage implements ServerMessage {
  final AssistantMessage message;
  final String? messageUuid;
  const AssistantServerMessage({required this.message, this.messageUuid});
}

class ToolResultMessage implements ServerMessage {
  final String toolUseId;
  final String content;
  final String? toolName;
  final List<ImageRef> images;
  final String? userMessageUuid;
  const ToolResultMessage({
    required this.toolUseId,
    required this.content,
    this.toolName,
    this.images = const [],
    this.userMessageUuid,
  });
}

class ResultMessage implements ServerMessage {
  final String subtype;
  final String? result;
  final String? error;
  final double? cost;
  final double? duration;
  final String? sessionId;
  final String? stopReason;
  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;
  final int? toolCalls;
  final int? fileEdits;
  const ResultMessage({
    required this.subtype,
    this.result,
    this.error,
    this.cost,
    this.duration,
    this.sessionId,
    this.stopReason,
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
    this.toolCalls,
    this.fileEdits,
  });
}

class ErrorMessage implements ServerMessage {
  final String message;
  const ErrorMessage({required this.message});
}

class StatusMessage implements ServerMessage {
  final ProcessStatus status;
  const StatusMessage({required this.status});
}

class HistoryMessage implements ServerMessage {
  final List<ServerMessage> messages;
  const HistoryMessage({required this.messages});
}

class PermissionRequestMessage implements ServerMessage {
  final String toolUseId;
  final String toolName;
  final Map<String, dynamic> input;
  const PermissionRequestMessage({
    required this.toolUseId,
    required this.toolName,
    required this.input,
  });

  /// Human-readable summary of the permission request input.
  String get summary {
    final parts = <String>[];
    for (final key in ['command', 'file_path', 'path', 'pattern', 'url']) {
      if (input.containsKey(key)) {
        final val = input[key].toString();
        parts.add(val.length > 60 ? '${val.substring(0, 60)}...' : val);
      }
    }
    return parts.isNotEmpty ? parts.join(' | ') : toolName;
  }
}

class StreamDeltaMessage implements ServerMessage {
  final String text;
  const StreamDeltaMessage({required this.text});
}

class ThinkingDeltaMessage implements ServerMessage {
  final String text;
  const ThinkingDeltaMessage({required this.text});
}

class SessionListMessage implements ServerMessage {
  final List<SessionInfo> sessions;
  const SessionListMessage({required this.sessions});
}

class RecentSessionsMessage implements ServerMessage {
  final List<RecentSession> sessions;
  final bool hasMore;
  const RecentSessionsMessage({required this.sessions, this.hasMore = false});
}

class PastHistoryMessage implements ServerMessage {
  final String claudeSessionId;
  final List<PastMessage> messages;
  const PastHistoryMessage({
    required this.claudeSessionId,
    required this.messages,
  });
}

class GalleryListMessage implements ServerMessage {
  final List<GalleryImage> images;
  const GalleryListMessage({required this.images});
}

class GalleryNewImageMessage implements ServerMessage {
  final GalleryImage image;
  const GalleryNewImageMessage({required this.image});
}

// ---- Screenshot / Window ----

class WindowInfo {
  final int windowId;
  final String ownerName;
  final String windowTitle;

  const WindowInfo({
    required this.windowId,
    required this.ownerName,
    required this.windowTitle,
  });

  factory WindowInfo.fromJson(Map<String, dynamic> json) {
    return WindowInfo(
      windowId: json['windowId'] as int,
      ownerName: json['ownerName'] as String? ?? '',
      windowTitle: json['windowTitle'] as String? ?? '',
    );
  }
}

class WindowListMessage implements ServerMessage {
  final List<WindowInfo> windows;
  const WindowListMessage({required this.windows});
}

class ScreenshotResultMessage implements ServerMessage {
  final bool success;
  final GalleryImage? image;
  final String? error;
  const ScreenshotResultMessage({
    required this.success,
    this.image,
    this.error,
  });
}

class DebugTraceEvent {
  final String ts;
  final String sessionId;
  final String direction;
  final String channel;
  final String type;
  final String? detail;

  const DebugTraceEvent({
    required this.ts,
    required this.sessionId,
    required this.direction,
    required this.channel,
    required this.type,
    this.detail,
  });

  factory DebugTraceEvent.fromJson(Map<String, dynamic> json) {
    return DebugTraceEvent(
      ts: json['ts'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      direction: json['direction'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      type: json['type'] as String? ?? '',
      detail: json['detail'] as String?,
    );
  }
}

class DebugBundleSession {
  final String id;
  final String provider;
  final String status;
  final String projectPath;
  final String? worktreePath;
  final String? worktreeBranch;
  final String? claudeSessionId;
  final String createdAt;
  final String lastActivityAt;

  const DebugBundleSession({
    required this.id,
    required this.provider,
    required this.status,
    required this.projectPath,
    this.worktreePath,
    this.worktreeBranch,
    this.claudeSessionId,
    required this.createdAt,
    required this.lastActivityAt,
  });

  factory DebugBundleSession.fromJson(Map<String, dynamic> json) {
    return DebugBundleSession(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      status: json['status'] as String? ?? '',
      projectPath: json['projectPath'] as String? ?? '',
      worktreePath: json['worktreePath'] as String?,
      worktreeBranch: json['worktreeBranch'] as String?,
      claudeSessionId: json['claudeSessionId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      lastActivityAt: json['lastActivityAt'] as String? ?? '',
    );
  }
}

class DebugReproRecipe {
  final String wsUrlHint;
  final String startBridgeCommand;
  final Map<String, dynamic> resumeSessionMessage;
  final Map<String, dynamic> getHistoryMessage;
  final Map<String, dynamic> getDebugBundleMessage;
  final List<String> notes;

  const DebugReproRecipe({
    this.wsUrlHint = '',
    this.startBridgeCommand = '',
    this.resumeSessionMessage = const <String, dynamic>{},
    this.getHistoryMessage = const <String, dynamic>{},
    this.getDebugBundleMessage = const <String, dynamic>{},
    this.notes = const [],
  });

  factory DebugReproRecipe.fromJson(Map<String, dynamic> json) {
    return DebugReproRecipe(
      wsUrlHint: json['wsUrlHint'] as String? ?? '',
      startBridgeCommand: json['startBridgeCommand'] as String? ?? '',
      resumeSessionMessage:
          (json['resumeSessionMessage'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      getHistoryMessage:
          (json['getHistoryMessage'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      getDebugBundleMessage:
          (json['getDebugBundleMessage'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      notes: (json['notes'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class DebugBundleMessage implements ServerMessage {
  final String sessionId;
  final String generatedAt;
  final DebugBundleSession session;
  final int pastMessageCount;
  final List<String> historySummary;
  final List<DebugTraceEvent> debugTrace;
  final String? traceFilePath;
  final String? savedBundlePath;
  final DebugReproRecipe reproRecipe;
  final String agentPrompt;
  final String diff;
  final String? diffError;

  const DebugBundleMessage({
    required this.sessionId,
    required this.generatedAt,
    required this.session,
    required this.pastMessageCount,
    this.historySummary = const [],
    this.debugTrace = const [],
    this.traceFilePath,
    this.savedBundlePath,
    this.reproRecipe = const DebugReproRecipe(),
    this.agentPrompt = '',
    required this.diff,
    this.diffError,
  });
}

class FileListMessage implements ServerMessage {
  final List<String> files;
  const FileListMessage({required this.files});
}

class ProjectHistoryMessage implements ServerMessage {
  final List<String> projects;
  const ProjectHistoryMessage({required this.projects});
}

class DiffResultMessage implements ServerMessage {
  final String diff;
  final String? error;
  const DiffResultMessage({required this.diff, this.error});
}

class WorktreeListMessage implements ServerMessage {
  final List<WorktreeInfo> worktrees;
  const WorktreeListMessage({required this.worktrees});
}

class WorktreeRemovedMessage implements ServerMessage {
  final String worktreePath;
  const WorktreeRemovedMessage({required this.worktreePath});
}

/// Summary of tool uses within a subagent (Task tool).
/// This message replaces multiple tool_result messages with a compressed summary.
class ToolUseSummaryMessage implements ServerMessage {
  /// Human-readable summary of the tools used (e.g., "Read 3 files and analyzed code")
  final String summary;

  /// IDs of the tool_use calls that this summary replaces
  final List<String> precedingToolUseIds;

  const ToolUseSummaryMessage({
    required this.summary,
    this.precedingToolUseIds = const [],
  });
}

/// User text input message (emitted from history replay).
///
/// Bridge sends this when restoring in-memory history so that Flutter can
/// reconstruct [UserChatEntry] with the original text and UUID.
class UserInputMessage implements ServerMessage {
  final String text;
  final String? userMessageUuid;

  /// Whether this message was synthetically generated by Claude CLI
  /// (e.g. plan approval, Task agent prompts) rather than typed by the user.
  final bool isSynthetic;

  /// Whether this is a meta message (e.g. skill loading prompt).
  final bool isMeta;
  const UserInputMessage({
    required this.text,
    this.userMessageUuid,
    this.isSynthetic = false,
    this.isMeta = false,
  });
}

class RewindPreviewMessage implements ServerMessage {
  final bool canRewind;
  final List<String>? filesChanged;
  final int? insertions;
  final int? deletions;
  final String? error;
  const RewindPreviewMessage({
    required this.canRewind,
    this.filesChanged,
    this.insertions,
    this.deletions,
    this.error,
  });
}

class RewindResultMessage implements ServerMessage {
  final bool success;
  final String mode;
  final String? error;
  const RewindResultMessage({
    required this.success,
    required this.mode,
    this.error,
  });
}

class InputAckMessage implements ServerMessage {
  final String? sessionId;
  const InputAckMessage({this.sessionId});
}

class InputRejectedMessage implements ServerMessage {
  final String? sessionId;
  final String? reason;
  const InputRejectedMessage({this.sessionId, this.reason});
}

class UsageResultMessage implements ServerMessage {
  final List<UsageInfo> providers;
  const UsageResultMessage({required this.providers});
}

class RecordingListMessage implements ServerMessage {
  final List<RecordingInfo> recordings;
  const RecordingListMessage({required this.recordings});
}

class RecordingContentMessage implements ServerMessage {
  final String sessionId;
  final String content;
  const RecordingContentMessage({
    required this.sessionId,
    required this.content,
  });
}

class RecordingInfo {
  final String name;
  final String modified;
  final int sizeBytes;
  final String? projectPath;
  final String? summary;
  final String? firstPrompt;
  final String? lastPrompt;

  const RecordingInfo({
    required this.name,
    required this.modified,
    required this.sizeBytes,
    this.projectPath,
    this.summary,
    this.firstPrompt,
    this.lastPrompt,
  });

  factory RecordingInfo.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return RecordingInfo(
      name: json['name'] as String? ?? '',
      modified: json['modified'] as String? ?? '',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      projectPath: meta?['projectPath'] as String?,
      summary: json['summary'] as String?,
      firstPrompt: json['firstPrompt'] as String?,
      lastPrompt: json['lastPrompt'] as String?,
    );
  }

  /// Display text prioritizing summary > firstPrompt > name fallback.
  String get displayText {
    if (summary != null && summary!.isNotEmpty) return summary!;
    if (firstPrompt != null && firstPrompt!.isNotEmpty) return firstPrompt!;
    return name;
  }

  /// Short project name (last path component).
  String? get projectName {
    if (projectPath == null || projectPath!.isEmpty) return null;
    final parts = projectPath!.split('/');
    return parts.last;
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DateTime? get modifiedDate => DateTime.tryParse(modified);
}

class PastMessage {
  final String role;
  final String? uuid;
  final String? timestamp;

  /// Whether this is a meta message (e.g. skill loading prompt).
  final bool isMeta;
  final List<AssistantContent> content;
  const PastMessage({
    required this.role,
    this.uuid,
    this.timestamp,
    this.isMeta = false,
    required this.content,
  });

  factory PastMessage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final List<AssistantContent> contentList;
    if (rawContent is String) {
      // Handle string content (e.g. user message after interrupt)
      contentList = rawContent.isNotEmpty
          ? [TextContent(text: rawContent)]
          : [];
    } else {
      contentList = (rawContent as List? ?? [])
          .map((c) => AssistantContent.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return PastMessage(
      role: json['role'] as String? ?? '',
      uuid: json['uuid'] as String?,
      timestamp: json['timestamp'] as String?,
      isMeta: json['isMeta'] as bool? ?? false,
      content: contentList,
    );
  }
}

// ---- Recent session (from sessions-index.json) ----

/// Display mode for session list cards.
enum SessionDisplayMode {
  first('First'),
  last('Last'),
  summary('Summary');

  final String label;
  const SessionDisplayMode(this.label);
}

class RecentSession {
  final String sessionId;
  final String? provider;
  final String? summary;
  final String firstPrompt;
  final String? lastPrompt;
  final int messageCount;
  final String created;
  final String modified;
  final String gitBranch;
  final String projectPath;
  final String? resumeCwd;
  final bool isSidechain;
  final String? codexApprovalPolicy;
  final String? codexSandboxMode;
  final String? codexModel;
  final String? codexModelReasoningEffort;
  final bool? codexNetworkAccessEnabled;
  final String? codexWebSearchMode;

  const RecentSession({
    required this.sessionId,
    this.provider,
    this.summary,
    required this.firstPrompt,
    this.lastPrompt,
    required this.messageCount,
    required this.created,
    required this.modified,
    required this.gitBranch,
    required this.projectPath,
    this.resumeCwd,
    required this.isSidechain,
    this.codexApprovalPolicy,
    this.codexSandboxMode,
    this.codexModel,
    this.codexModelReasoningEffort,
    this.codexNetworkAccessEnabled,
    this.codexWebSearchMode,
  });

  factory RecentSession.fromJson(Map<String, dynamic> json) {
    final codexSettings = json['codexSettings'] as Map<String, dynamic>?;
    return RecentSession(
      sessionId: json['sessionId'] as String,
      provider: json['provider'] as String?,
      summary: json['summary'] as String?,
      firstPrompt: json['firstPrompt'] as String? ?? '',
      lastPrompt: json['lastPrompt'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      created: json['created'] as String? ?? '',
      modified: json['modified'] as String? ?? '',
      gitBranch: json['gitBranch'] as String? ?? '',
      projectPath: json['projectPath'] as String? ?? '',
      resumeCwd: json['resumeCwd'] as String?,
      isSidechain: json['isSidechain'] as bool? ?? false,
      codexApprovalPolicy: codexSettings?['approvalPolicy'] as String?,
      codexSandboxMode: codexSettings?['sandboxMode'] as String?,
      codexModel: codexSettings?['model'] as String?,
      codexModelReasoningEffort:
          codexSettings?['modelReasoningEffort'] as String?,
      codexNetworkAccessEnabled:
          codexSettings?['networkAccessEnabled'] as bool?,
      codexWebSearchMode: codexSettings?['webSearchMode'] as String?,
    );
  }

  /// Extract project name from path (last segment)
  String get projectName {
    final parts = projectPath.split('/');
    return parts.isNotEmpty ? parts.last : projectPath;
  }

  /// Display text: summary if available, otherwise firstPrompt
  String get displayText {
    if (summary != null && summary!.isNotEmpty) return summary!;
    if (firstPrompt.isNotEmpty) return firstPrompt;
    return '(no description)';
  }
}

// ---- Session info (for multi-session) ----

class SessionInfo {
  final String id;
  final String? provider;
  final String projectPath;
  final String? claudeSessionId;
  final String status;
  final String createdAt;
  final String lastActivityAt;
  final String gitBranch;
  final String lastMessage;
  final int messageCount;
  final String? worktreePath;
  final String? worktreeBranch;
  final String? permissionMode;
  final String? codexApprovalPolicy;
  final String? codexSandboxMode;
  final String? codexModel;
  final String? codexModelReasoningEffort;
  final bool? codexNetworkAccessEnabled;
  final String? codexWebSearchMode;
  final PermissionRequestMessage? pendingPermission;

  const SessionInfo({
    required this.id,
    this.provider,
    required this.projectPath,
    this.claudeSessionId,
    required this.status,
    required this.createdAt,
    required this.lastActivityAt,
    this.gitBranch = '',
    this.lastMessage = '',
    this.messageCount = 0,
    this.worktreePath,
    this.worktreeBranch,
    this.permissionMode,
    this.codexApprovalPolicy,
    this.codexSandboxMode,
    this.codexModel,
    this.codexModelReasoningEffort,
    this.codexNetworkAccessEnabled,
    this.codexWebSearchMode,
    this.pendingPermission,
  });

  SessionInfo copyWith({
    String? status,
    PermissionRequestMessage? pendingPermission,
    bool clearPermission = false,
  }) {
    return SessionInfo(
      id: id,
      provider: provider,
      projectPath: projectPath,
      claudeSessionId: claudeSessionId,
      status: status ?? this.status,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
      gitBranch: gitBranch,
      lastMessage: lastMessage,
      messageCount: messageCount,
      worktreePath: worktreePath,
      worktreeBranch: worktreeBranch,
      permissionMode: permissionMode,
      codexApprovalPolicy: codexApprovalPolicy,
      codexSandboxMode: codexSandboxMode,
      codexModel: codexModel,
      codexModelReasoningEffort: codexModelReasoningEffort,
      codexNetworkAccessEnabled: codexNetworkAccessEnabled,
      codexWebSearchMode: codexWebSearchMode,
      pendingPermission: clearPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
    );
  }

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    final codexSettings = json['codexSettings'] as Map<String, dynamic>?;
    final permJson = json['pendingPermission'] as Map<String, dynamic>?;
    return SessionInfo(
      id: json['id'] as String,
      provider: json['provider'] as String?,
      projectPath: json['projectPath'] as String,
      claudeSessionId: json['claudeSessionId'] as String?,
      status: json['status'] as String? ?? 'idle',
      createdAt: json['createdAt'] as String? ?? '',
      lastActivityAt: json['lastActivityAt'] as String? ?? '',
      gitBranch: json['gitBranch'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      worktreePath: json['worktreePath'] as String?,
      worktreeBranch: json['worktreeBranch'] as String?,
      permissionMode: json['permissionMode'] as String?,
      codexApprovalPolicy: codexSettings?['approvalPolicy'] as String?,
      codexSandboxMode: codexSettings?['sandboxMode'] as String?,
      codexModel: codexSettings?['model'] as String?,
      codexModelReasoningEffort:
          codexSettings?['modelReasoningEffort'] as String?,
      codexNetworkAccessEnabled:
          codexSettings?['networkAccessEnabled'] as bool?,
      codexWebSearchMode: codexSettings?['webSearchMode'] as String?,
      pendingPermission: permJson != null
          ? PermissionRequestMessage(
              toolUseId: permJson['toolUseId'] as String,
              toolName: permJson['toolName'] as String,
              input: Map<String, dynamic>.from(permJson['input'] as Map),
            )
          : null,
    );
  }
}

// ---- Client messages ----

class ClientMessage {
  final Map<String, dynamic> _json;
  ClientMessage._(this._json);

  factory ClientMessage.start(
    String projectPath, {
    String? sessionId,
    bool? continueMode,
    String? permissionMode,
    String? effort,
    int? maxTurns,
    double? maxBudgetUsd,
    String? fallbackModel,
    bool? forkSession,
    bool? persistSession,
    bool? useWorktree,
    String? worktreeBranch,
    String? existingWorktreePath,
    String? provider,
    String? model,
    String? approvalPolicy,
    String? sandboxMode,
    String? modelReasoningEffort,
    bool? networkAccessEnabled,
    String? webSearchMode,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'start',
      'projectPath': projectPath,
      'sessionId': ?sessionId,
      if (continueMode == true) 'continue': true,
      'permissionMode': ?permissionMode,
      'effort': ?effort,
      'maxTurns': ?maxTurns,
      'maxBudgetUsd': ?maxBudgetUsd,
      'fallbackModel': ?fallbackModel,
      'forkSession': ?forkSession,
      'persistSession': ?persistSession,
      if (useWorktree == true) 'useWorktree': true,
      if (worktreeBranch != null && worktreeBranch.isNotEmpty)
        'worktreeBranch': worktreeBranch,
      'existingWorktreePath': ?existingWorktreePath,
      'provider': ?provider,
      'model': ?model,
      'approvalPolicy': ?approvalPolicy,
      'sandboxMode': ?sandboxMode,
      'modelReasoningEffort': ?modelReasoningEffort,
      'networkAccessEnabled': ?networkAccessEnabled,
      'webSearchMode': ?webSearchMode,
    });
  }

  factory ClientMessage.input(
    String text, {
    String? sessionId,
    String? imageId,
    String? imageBase64,
    String? mimeType,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'input',
      'text': text,
      'sessionId': ?sessionId,
      'imageId': ?imageId,
      'imageBase64': ?imageBase64,
      'mimeType': ?mimeType,
    });
  }

  factory ClientMessage.pushRegister({
    required String token,
    required String platform,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'push_register',
    'token': token,
    'platform': platform,
  });

  factory ClientMessage.pushUnregister(String token) => ClientMessage._(
    <String, dynamic>{'type': 'push_unregister', 'token': token},
  );

  factory ClientMessage.setPermissionMode(String mode, {String? sessionId}) {
    return ClientMessage._(<String, dynamic>{
      'type': 'set_permission_mode',
      'mode': mode,
      'sessionId': ?sessionId,
    });
  }

  factory ClientMessage.setSandboxMode(
    String sandboxMode, {
    String? sessionId,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'set_sandbox_mode',
      'sandboxMode': sandboxMode,
      'sessionId': ?sessionId,
    });
  }

  factory ClientMessage.approve(
    String id, {
    Map<String, dynamic>? updatedInput,
    bool clearContext = false,
    String? sessionId,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'approve',
      'id': id,
      'updatedInput': ?updatedInput,
      if (clearContext) 'clearContext': true,
      'sessionId': ?sessionId,
    });
  }

  factory ClientMessage.approveAlways(String id, {String? sessionId}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'approve_always',
        'id': id,
        'sessionId': ?sessionId,
      });

  factory ClientMessage.reject(
    String id, {
    String? message,
    String? sessionId,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'reject',
      'id': id,
      'message': ?message,
      'sessionId': ?sessionId,
    });
  }

  factory ClientMessage.answer(
    String toolUseId,
    String result, {
    String? sessionId,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'answer',
      'toolUseId': toolUseId,
      'result': result,
      'sessionId': ?sessionId,
    });
  }

  factory ClientMessage.getHistory(String sessionId) =>
      ClientMessage._({'type': 'get_history', 'sessionId': sessionId});

  factory ClientMessage.getDebugBundle(
    String sessionId, {
    int? traceLimit,
    bool? includeDiff,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'get_debug_bundle',
    'sessionId': sessionId,
    'traceLimit': ?traceLimit,
    'includeDiff': ?includeDiff,
  });

  factory ClientMessage.listSessions() =>
      ClientMessage._({'type': 'list_sessions'});

  factory ClientMessage.stopSession(String sessionId) =>
      ClientMessage._({'type': 'stop_session', 'sessionId': sessionId});

  factory ClientMessage.listRecentSessions({
    int? limit,
    int? offset,
    String? projectPath,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'list_recent_sessions',
      'limit': ?limit,
      'offset': ?offset,
      'projectPath': ?projectPath,
    });
  }

  factory ClientMessage.resumeSession(
    String sessionId,
    String projectPath, {
    String? permissionMode,
    String? effort,
    int? maxTurns,
    double? maxBudgetUsd,
    String? fallbackModel,
    bool? forkSession,
    bool? persistSession,
    String? provider,
    String? approvalPolicy,
    String? sandboxMode,
    String? model,
    String? modelReasoningEffort,
    bool? networkAccessEnabled,
    String? webSearchMode,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'resume_session',
      'sessionId': sessionId,
      'projectPath': projectPath,
      'permissionMode': ?permissionMode,
      'effort': ?effort,
      'maxTurns': ?maxTurns,
      'maxBudgetUsd': ?maxBudgetUsd,
      'fallbackModel': ?fallbackModel,
      'forkSession': ?forkSession,
      'persistSession': ?persistSession,
      'provider': ?provider,
      'approvalPolicy': ?approvalPolicy,
      'sandboxMode': ?sandboxMode,
      'model': ?model,
      'modelReasoningEffort': ?modelReasoningEffort,
      'networkAccessEnabled': ?networkAccessEnabled,
      'webSearchMode': ?webSearchMode,
    });
  }

  factory ClientMessage.listGallery({String? project, String? sessionId}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'list_gallery',
        'project': ?project,
        'sessionId': ?sessionId,
      });

  factory ClientMessage.listFiles(String projectPath) =>
      ClientMessage._({'type': 'list_files', 'projectPath': projectPath});

  factory ClientMessage.getDiff(String projectPath) =>
      ClientMessage._({'type': 'get_diff', 'projectPath': projectPath});

  factory ClientMessage.interrupt({String? sessionId}) => ClientMessage._(
    <String, dynamic>{'type': 'interrupt', 'sessionId': ?sessionId},
  );

  factory ClientMessage.listProjectHistory() =>
      ClientMessage._({'type': 'list_project_history'});

  factory ClientMessage.removeProjectHistory(String projectPath) =>
      ClientMessage._({
        'type': 'remove_project_history',
        'projectPath': projectPath,
      });

  factory ClientMessage.listWorktrees(String projectPath) =>
      ClientMessage._({'type': 'list_worktrees', 'projectPath': projectPath});

  factory ClientMessage.removeWorktree(
    String projectPath,
    String worktreePath,
  ) => ClientMessage._({
    'type': 'remove_worktree',
    'projectPath': projectPath,
    'worktreePath': worktreePath,
  });

  factory ClientMessage.rewind(
    String sessionId,
    String targetUuid,
    String mode,
  ) => ClientMessage._({
    'type': 'rewind',
    'sessionId': sessionId,
    'targetUuid': targetUuid,
    'mode': mode,
  });

  factory ClientMessage.rewindDryRun(String sessionId, String targetUuid) =>
      ClientMessage._({
        'type': 'rewind_dry_run',
        'sessionId': sessionId,
        'targetUuid': targetUuid,
      });

  factory ClientMessage.listWindows() =>
      ClientMessage._({'type': 'list_windows'});

  factory ClientMessage.getUsage() => ClientMessage._({'type': 'get_usage'});

  factory ClientMessage.listRecordings() =>
      ClientMessage._({'type': 'list_recordings'});

  factory ClientMessage.getRecording(String sessionId) =>
      ClientMessage._({'type': 'get_recording', 'sessionId': sessionId});

  factory ClientMessage.takeScreenshot({
    required String mode,
    int? windowId,
    required String projectPath,
    String? sessionId,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'take_screenshot',
    'mode': mode,
    'projectPath': projectPath,
    'windowId': ?windowId,
    'sessionId': ?sessionId,
  });

  String toJson() => jsonEncode(_json);
}

// ---- Chat entry (for UI display) ----

sealed class ChatEntry {
  DateTime get timestamp;
}

class ServerChatEntry implements ChatEntry {
  final ServerMessage message;
  @override
  final DateTime timestamp;
  ServerChatEntry(this.message, {DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class UserChatEntry implements ChatEntry {
  final String text;
  final String? sessionId;
  final String? imageId;
  final String? imageUrl;
  final Uint8List? imageBytes;
  MessageStatus status;

  /// UUID assigned by the SDK for this user message (set when tool_result arrives).
  String? messageUuid;
  @override
  final DateTime timestamp;
  UserChatEntry(
    this.text, {
    DateTime? timestamp,
    this.sessionId,
    this.imageId,
    this.imageUrl,
    this.imageBytes,
    this.status = MessageStatus.sending,
    this.messageUuid,
  }) : timestamp = timestamp ?? DateTime.now();
}

class StreamingChatEntry implements ChatEntry {
  String text;
  @override
  final DateTime timestamp;
  StreamingChatEntry({this.text = '', DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

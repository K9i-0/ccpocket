import 'dart:convert';
import 'dart:typed_data';

import '../utils/request_user_input.dart';

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
      model: sanitizeCodexModelName(json['model'] as String?) ?? '',
    );
  }
}

// ---- Bridge connection state ----

enum BridgeConnectionState { disconnected, connecting, connected, reconnecting }

// ---- Message status (for user messages) ----

enum MessageStatus { sending, sent, queued, failed }

// ---- Process status ----

enum ProcessStatus {
  starting,
  idle,
  running,
  waitingApproval,
  compacting;

  static ProcessStatus fromString(String value) {
    return switch (value) {
      'starting' => ProcessStatus.starting,
      'idle' => ProcessStatus.idle,
      'running' => ProcessStatus.running,
      'waiting_approval' => ProcessStatus.waitingApproval,
      'compacting' => ProcessStatus.compacting,
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

String? sanitizeCodexModelName(String? model) {
  final normalized = model?.trim();
  if (normalized == null || normalized.isEmpty || normalized == 'codex') {
    return null;
  }
  return normalized;
}

// ---- Permission mode ----

enum PermissionMode {
  defaultMode('default', 'Default'),
  acceptEdits('acceptEdits', 'Accept Edits'),
  plan('plan', 'Plan'),
  bypassPermissions('bypassPermissions', 'Bypass All');

  final String value;
  final String label;
  const PermissionMode(this.value, this.label);
}

enum ExecutionMode {
  defaultMode('default', 'Default'),
  acceptEdits('acceptEdits', 'Accept Edits'),
  fullAccess('fullAccess', 'Full Access');

  final String value;
  final String label;
  const ExecutionMode(this.value, this.label);
}

ExecutionMode? executionModeFromRaw(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final value in ExecutionMode.values) {
    if (value.value == raw) return value;
  }
  return null;
}

bool derivePlanMode({bool? planMode, String? permissionMode}) {
  return planMode ?? (permissionMode == PermissionMode.plan.value);
}

ExecutionMode deriveExecutionMode({
  String? provider,
  String? executionMode,
  String? permissionMode,
  String? approvalPolicy,
}) {
  final explicit = executionModeFromRaw(executionMode);
  if (explicit != null) return explicit;

  if (permissionMode == PermissionMode.bypassPermissions.value) {
    return ExecutionMode.fullAccess;
  }
  if (permissionMode == PermissionMode.acceptEdits.value) {
    return provider == Provider.codex.value
        ? ExecutionMode.defaultMode
        : ExecutionMode.acceptEdits;
  }
  if (approvalPolicy == 'never') return ExecutionMode.fullAccess;
  return ExecutionMode.defaultMode;
}

PermissionMode legacyPermissionModeFromModes(
  Provider provider, {
  required ExecutionMode executionMode,
  required bool planMode,
}) {
  if (planMode) return PermissionMode.plan;
  switch (executionMode) {
    case ExecutionMode.defaultMode:
      return provider == Provider.codex
          ? PermissionMode.acceptEdits
          : PermissionMode.defaultMode;
    case ExecutionMode.acceptEdits:
      return PermissionMode.acceptEdits;
    case ExecutionMode.fullAccess:
      return PermissionMode.bypassPermissions;
  }
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

// ---- Sandbox mode (Claude & Codex) ----

enum SandboxMode {
  on('on', 'Sandbox On'),
  off('off', 'Sandbox Off');

  final String value;
  final String label;
  const SandboxMode(this.value, this.label);
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
        claudeSessionId: json['claudeSessionId'] as String?,
        model: json['model'] as String?,
        approvalPolicy: json['approvalPolicy'] as String?,
        provider: json['provider'] as String?,
        projectPath: json['projectPath'] as String?,
        permissionMode: json['permissionMode'] as String?,
        executionMode: json['executionMode'] as String?,
        planMode: json['planMode'] as bool?,
        sandboxMode: json['sandboxMode'] as String?,
        modelReasoningEffort: json['modelReasoningEffort'] as String?,
        networkAccessEnabled: json['networkAccessEnabled'] as bool?,
        webSearchMode: json['webSearchMode'] as String?,
        slashCommands:
            (json['slashCommands'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        skills:
            (json['skills'] as List?)?.map((e) => e as String).toList() ??
            const [],
        skillMetadata:
            (json['skillMetadata'] as List?)
                ?.map(
                  (e) => CodexSkillMetadata.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        worktreePath: json['worktreePath'] as String?,
        worktreeBranch: json['worktreeBranch'] as String?,
        clearContext: json['clearContext'] as bool? ?? false,
        sourceSessionId: json['sourceSessionId'] as String?,
        tipCode: json['tipCode'] as String?,
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
      'error' => ErrorMessage(
        message: json['message'] as String,
        errorCode: json['errorCode'] as String?,
      ),
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
      'permission_resolved' => PermissionResolvedMessage(
        toolUseId: json['toolUseId'] as String,
      ),
      'stream_delta' => StreamDeltaMessage(text: json['text'] as String),
      'thinking_delta' => ThinkingDeltaMessage(text: json['text'] as String),
      'session_list' => SessionListMessage(
        sessions: (json['sessions'] as List)
            .map((s) => SessionInfo.fromJson(s as Map<String, dynamic>))
            .toList(),
        allowedDirs:
            (json['allowedDirs'] as List?)?.map((e) => e as String).toList() ??
            const [],
        claudeModels:
            (json['claudeModels'] as List?)?.map((e) => e as String).toList() ??
            const [],
        codexModels:
            (json['codexModels'] as List?)?.map((e) => e as String).toList() ??
            const [],
        bridgeVersion: json['bridgeVersion'] as String?,
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
      'file_content' => FileContentMessage(
        filePath: json['filePath'] as String,
        content: json['content'] as String? ?? '',
        language: json['language'] as String?,
        error: json['error'] as String?,
        totalLines: json['totalLines'] as int?,
        truncated: json['truncated'] as bool? ?? false,
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
        errorCode: json['errorCode'] as String?,
        imageChanges:
            (json['imageChanges'] as List?)
                ?.map(
                  (e) => DiffImageChange.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      ),
      'diff_image_result' => DiffImageResultMessage(
        filePath: json['filePath'] as String,
        version: json['version'] as String,
        base64: json['base64'] as String?,
        mimeType: json['mimeType'] as String?,
        error: json['error'] as String?,
        oldBase64: json['oldBase64'] as String?,
        newBase64: json['newBase64'] as String?,
      ),
      'worktree_list' => WorktreeListMessage(
        worktrees: (json['worktrees'] as List)
            .map((w) => WorktreeInfo.fromJson(w as Map<String, dynamic>))
            .toList(),
        mainBranch: json['mainBranch'] as String?,
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
        imageCount: json['imageCount'] as int? ?? 0,
        timestamp: json['timestamp'] as String?,
        imageUrls:
            (json['images'] as List?)
                ?.map((e) => (e as Map<String, dynamic>)['url'] as String?)
                .whereType<String>()
                .toList() ??
            const [],
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
      'input_ack' => InputAckMessage(
        sessionId: json['sessionId'] as String?,
        queued: json['queued'] as bool? ?? false,
      ),
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
      'message_images_result' => MessageImagesResultMessage(
        messageUuid: json['messageUuid'] as String? ?? '',
        images:
            (json['images'] as List?)
                ?.map((i) => ImageRef.fromJson(i as Map<String, dynamic>))
                .toList() ??
            const [],
      ),
      'prompt_history_backup_result' => PromptHistoryBackupResultMessage(
        success: json['success'] as bool? ?? false,
        backedUpAt: json['backedUpAt'] as String?,
        error: json['error'] as String?,
      ),
      'prompt_history_restore_result' => PromptHistoryRestoreResultMessage(
        success: json['success'] as bool? ?? false,
        data: json['data'] as String?,
        appVersion: json['appVersion'] as String?,
        dbVersion: json['dbVersion'] as int?,
        backedUpAt: json['backedUpAt'] as String?,
        error: json['error'] as String?,
      ),
      'prompt_history_backup_info' => PromptHistoryBackupInfoMessage(
        exists: json['exists'] as bool? ?? false,
        appVersion: json['appVersion'] as String?,
        dbVersion: json['dbVersion'] as int?,
        backedUpAt: json['backedUpAt'] as String?,
        sizeBytes: json['sizeBytes'] as int?,
      ),
      'rename_result' => RenameResultMessage(
        sessionId: json['sessionId'] as String? ?? '',
        name: json['name'] as String?,
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'archive_result' => ArchiveResultMessage(
        sessionId: json['sessionId'] as String? ?? '',
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'branch_update' => BranchUpdateMessage(
        sessionId: json['sessionId'] as String? ?? '',
        branch: json['branch'] as String? ?? '',
      ),
      // ---- Git Operations (Phase 1-3) ----
      'git_stage_result' => GitStageResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_unstage_result' => GitUnstageResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_unstage_hunks_result' => GitUnstageHunksResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_commit_result' => GitCommitResultMessage(
        success: json['success'] as bool? ?? false,
        commitHash: json['commitHash'] as String?,
        message: json['message'] as String?,
        error: json['error'] as String?,
      ),
      'git_push_result' => GitPushResultMessage(
        success: json['success'] as bool? ?? false,
        remote: json['remote'] as String?,
        branch: json['branch'] as String?,
        error: json['error'] as String?,
      ),
      'git_status_result' => GitStatusResultMessage(
        staged: (json['staged'] as List?)?.cast<String>() ?? const [],
        unstaged: (json['unstaged'] as List?)?.cast<String>() ?? const [],
        untracked: (json['untracked'] as List?)?.cast<String>() ?? const [],
      ),
      'git_branches_result' => GitBranchesResultMessage(
        current: json['current'] as String? ?? '',
        branches: (json['branches'] as List?)?.cast<String>() ?? const [],
        checkedOutBranches:
            (json['checkedOutBranches'] as List?)?.cast<String>() ?? const [],
        remoteStatusByBranch:
            (json['remoteStatusByBranch'] as Map?)?.map(
              (key, value) => MapEntry(
                key as String,
                GitBranchRemoteStatus.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            ) ??
            const {},
        error: json['error'] as String?,
      ),
      'git_create_branch_result' => GitCreateBranchResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_checkout_branch_result' => GitCheckoutBranchResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_revert_file_result' => GitRevertFileResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_revert_hunks_result' => GitRevertHunksResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_fetch_result' => GitFetchResultMessage(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      ),
      'git_pull_result' => GitPullResultMessage(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
        error: json['error'] as String?,
      ),
      'git_remote_status_result' => GitRemoteStatusResultMessage(
        ahead: json['ahead'] as int? ?? 0,
        behind: json['behind'] as int? ?? 0,
        branch: json['branch'] as String? ?? '',
        hasUpstream: json['hasUpstream'] as bool? ?? false,
      ),
      _ => ErrorMessage(message: 'Unknown message type: ${json['type']}'),
    };
  }
}

/// Metadata for a Codex skill, returned by the `skills/list` RPC.
class CodexSkillMetadata {
  final String name;
  final String path;
  final String description;
  final String? shortDescription;
  final bool enabled;
  final String scope;
  final String? displayName;
  final String? defaultPrompt;
  final String? brandColor;

  const CodexSkillMetadata({
    required this.name,
    required this.path,
    required this.description,
    this.shortDescription,
    this.enabled = true,
    this.scope = 'user',
    this.displayName,
    this.defaultPrompt,
    this.brandColor,
  });

  factory CodexSkillMetadata.fromJson(Map<String, dynamic> json) {
    return CodexSkillMetadata(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      scope: json['scope'] as String? ?? 'user',
      displayName: json['displayName'] as String?,
      defaultPrompt: json['defaultPrompt'] as String?,
      brandColor: json['brandColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'path': path};

  /// Best human-readable label for UI display.
  String get label => displayName ?? name;

  /// Best short description for UI display.
  String get summary => shortDescription ?? description;
}

class SystemMessage implements ServerMessage {
  final String subtype;
  final String? sessionId;

  /// The full Claude CLI session UUID (for JSONL lookups).
  /// Falls back to [sessionId] when not provided.
  final String? claudeSessionId;
  final String? model;
  final String? approvalPolicy;
  final String? provider;
  final String? projectPath;
  final String? permissionMode;
  final String? executionMode;
  final bool? planMode;
  final String? sandboxMode;
  final String? modelReasoningEffort;
  final bool? networkAccessEnabled;
  final String? webSearchMode;
  final List<String> slashCommands;
  final List<String> skills;
  final List<CodexSkillMetadata> skillMetadata;
  final String? worktreePath;
  final String? worktreeBranch;
  final bool clearContext;
  final String? sourceSessionId;
  final String? tipCode;
  const SystemMessage({
    required this.subtype,
    this.sessionId,
    this.claudeSessionId,
    this.model,
    this.approvalPolicy,
    this.provider,
    this.projectPath,
    this.permissionMode,
    this.executionMode,
    this.planMode,
    this.sandboxMode,
    this.modelReasoningEffort,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.slashCommands = const [],
    this.skills = const [],
    this.skillMetadata = const [],
    this.worktreePath,
    this.worktreeBranch,
    this.clearContext = false,
    this.sourceSessionId,
    this.tipCode,
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
  final String? errorCode;
  const ErrorMessage({required this.message, this.errorCode});
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

  bool get isRequestUserInputApproval =>
      toolName == 'AskUserQuestion' && isMcpApprovalRequestUserInput(input);

  bool get isMcpElicitation => toolName == 'McpElicitation';

  bool get isPermissionGrantRequest => toolName == 'Permissions';

  String get displayToolName {
    if (isRequestUserInputApproval) {
      return requestUserInputHeader(input) ?? 'App Tool Approval';
    }
    if (isMcpElicitation) {
      final serverName = input['serverName'] as String?;
      return serverName == null || serverName.isEmpty
          ? 'MCP Elicitation'
          : 'MCP: $serverName';
    }
    if (isPermissionGrantRequest) {
      return 'Additional Permissions';
    }
    return toolName;
  }

  /// Human-readable summary of the permission request input.
  String get summary {
    if (isRequestUserInputApproval) {
      return requestUserInputQuestionText(input) ?? displayToolName;
    }
    if (isMcpElicitation) {
      final message = input['message'] as String?;
      final url = input['url'] as String?;
      if (message != null &&
          message.isNotEmpty &&
          url != null &&
          url.isNotEmpty) {
        return '$message | $url';
      }
      return message ?? url ?? displayToolName;
    }
    if (isPermissionGrantRequest) {
      final reason = input['reason'] as String?;
      if (reason != null && reason.isNotEmpty) return reason;
      if (input['permissions'] != null) return 'Grant requested permissions';
    }
    final parts = <String>[];
    for (final key in [
      'command',
      'file_path',
      'path',
      'pattern',
      'url',
      'reason',
    ]) {
      if (input.containsKey(key)) {
        final val = input[key].toString();
        parts.add(val);
      }
    }
    return parts.isNotEmpty ? parts.join(' | ') : toolName;
  }

  List<String> get detailLines {
    final lines = <String>[];

    if (isPermissionGrantRequest) {
      final permissions = _flattenPermissionValues(input['permissions']);
      if (permissions.isNotEmpty) {
        lines.add('Permissions: ${permissions.join(', ')}');
      }
    }

    final additionalPermissions = _flattenPermissionValues(
      input['additionalPermissions'],
    );
    if (additionalPermissions.isNotEmpty) {
      lines.add('Additional permissions: ${additionalPermissions.join(', ')}');
    }

    final execAmendment = _stringMapSummary(
      input['proposedExecpolicyAmendment'],
    );
    if (execAmendment != null) {
      lines.add('Exec policy: $execAmendment');
    }

    final networkAmendments = _networkPolicySummary(
      input['proposedNetworkPolicyAmendments'],
    );
    if (networkAmendments != null) {
      lines.add('Network policy: $networkAmendments');
    }

    final availableDecisions = _stringList(input['availableDecisions']);
    if (availableDecisions.isNotEmpty) {
      lines.add('Allowed actions: ${availableDecisions.join(', ')}');
    }

    return lines;
  }
}

List<String> _flattenPermissionValues(dynamic value, [String prefix = '']) {
  if (value is Map) {
    final out = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final nextPrefix = prefix.isEmpty ? key : '$prefix.$key';
      out.addAll(_flattenPermissionValues(entry.value, nextPrefix));
    }
    return out;
  }
  if (value is List) {
    return value
        .map((entry) => entry.toString())
        .where((entry) => entry.isNotEmpty)
        .map((entry) => prefix.isEmpty ? entry : '$prefix=$entry')
        .toList();
  }
  if (value is bool || value is num || value is String) {
    final text = value.toString();
    if (text.isEmpty) return const [];
    return [prefix.isEmpty ? text : '$prefix=$text'];
  }
  return const [];
}

String? _stringMapSummary(dynamic value) {
  if (value is! Map) return null;
  final parts = value.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .where((entry) => entry.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  return parts.join(', ');
}

String? _networkPolicySummary(dynamic value) {
  if (value is! List) return null;
  final parts = value
      .map((entry) => _stringMapSummary(entry))
      .whereType<String>()
      .toList();
  if (parts.isEmpty) return null;
  return parts.join(' | ');
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((entry) => entry.toString())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

class PermissionResolvedMessage implements ServerMessage {
  final String toolUseId;
  const PermissionResolvedMessage({required this.toolUseId});
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
  final List<String> allowedDirs;
  final List<String> claudeModels;
  final List<String> codexModels;
  final String? bridgeVersion;
  const SessionListMessage({
    required this.sessions,
    this.allowedDirs = const [],
    this.claudeModels = const [],
    this.codexModels = const [],
    this.bridgeVersion,
  });
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

class FileContentMessage implements ServerMessage {
  final String filePath;
  final String content;
  final String? language;
  final String? error;
  final int? totalLines;
  final bool truncated;
  const FileContentMessage({
    required this.filePath,
    required this.content,
    this.language,
    this.error,
    this.totalLines,
    this.truncated = false,
  });
}

class ProjectHistoryMessage implements ServerMessage {
  final List<String> projects;
  const ProjectHistoryMessage({required this.projects});
}

/// Image change detected in a git diff.
class DiffImageChange {
  final String filePath;
  final bool isNew;
  final bool isDeleted;
  final bool isSvg;
  final int? oldSize;
  final int? newSize;
  final String? oldBase64;
  final String? newBase64;
  final String mimeType;
  final bool loadable;
  final bool autoDisplay;

  const DiffImageChange({
    required this.filePath,
    this.isNew = false,
    this.isDeleted = false,
    this.isSvg = false,
    this.oldSize,
    this.newSize,
    this.oldBase64,
    this.newBase64,
    required this.mimeType,
    this.loadable = false,
    this.autoDisplay = false,
  });

  factory DiffImageChange.fromJson(Map<String, dynamic> json) =>
      DiffImageChange(
        filePath: json['filePath'] as String,
        isNew: json['isNew'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
        isSvg: json['isSvg'] as bool? ?? false,
        oldSize: json['oldSize'] as int?,
        newSize: json['newSize'] as int?,
        oldBase64: json['oldBase64'] as String?,
        newBase64: json['newBase64'] as String?,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        loadable: json['loadable'] as bool? ?? false,
        autoDisplay: json['autoDisplay'] as bool? ?? false,
      );
}

class DiffResultMessage implements ServerMessage {
  final String diff;
  final String? error;
  final String? errorCode;
  final List<DiffImageChange> imageChanges;
  const DiffResultMessage({
    required this.diff,
    this.error,
    this.errorCode,
    this.imageChanges = const [],
  });
}

class DiffImageResultMessage implements ServerMessage {
  final String filePath;
  final String version;
  final String? base64;
  final String? mimeType;
  final String? error;

  /// For version="both": old/new base64 in a single response.
  final String? oldBase64;
  final String? newBase64;

  const DiffImageResultMessage({
    required this.filePath,
    required this.version,
    this.base64,
    this.mimeType,
    this.error,
    this.oldBase64,
    this.newBase64,
  });
}

class WorktreeListMessage implements ServerMessage {
  final List<WorktreeInfo> worktrees;
  final String? mainBranch;
  const WorktreeListMessage({required this.worktrees, this.mainBranch});
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

  /// Number of images attached to this user message.
  final int imageCount;

  /// ISO 8601 timestamp from the bridge server (may be null for older history).
  final String? timestamp;

  /// Image URLs (relative, e.g. "/images/{id}") from the bridge image store.
  final List<String> imageUrls;
  const UserInputMessage({
    required this.text,
    this.userMessageUuid,
    this.isSynthetic = false,
    this.isMeta = false,
    this.imageCount = 0,
    this.timestamp,
    this.imageUrls = const [],
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

  /// When true the agent was busy and the message was queued for the next turn.
  /// An automatic interrupt is triggered server-side so the agent picks it up
  /// promptly, but the client can show a brief "queued" indicator.
  final bool queued;
  const InputAckMessage({this.sessionId, this.queued = false});
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

class RenameResultMessage implements ServerMessage {
  final String sessionId;
  final String? name;
  final bool success;
  final String? error;
  const RenameResultMessage({
    required this.sessionId,
    this.name,
    required this.success,
    this.error,
  });
}

class ArchiveResultMessage implements ServerMessage {
  final String sessionId;
  final bool success;
  final String? error;
  const ArchiveResultMessage({
    required this.sessionId,
    required this.success,
    this.error,
  });
}

/// Response to a `refresh_branch` request with the current git branch.
class BranchUpdateMessage implements ServerMessage {
  final String sessionId;
  final String branch;
  const BranchUpdateMessage({required this.sessionId, required this.branch});
}

class PromptHistoryBackupResultMessage implements ServerMessage {
  final bool success;
  final String? backedUpAt;
  final String? error;
  const PromptHistoryBackupResultMessage({
    required this.success,
    this.backedUpAt,
    this.error,
  });
}

class PromptHistoryRestoreResultMessage implements ServerMessage {
  final bool success;
  final String? data;
  final String? appVersion;
  final int? dbVersion;
  final String? backedUpAt;
  final String? error;
  const PromptHistoryRestoreResultMessage({
    required this.success,
    this.data,
    this.appVersion,
    this.dbVersion,
    this.backedUpAt,
    this.error,
  });
}

class PromptHistoryBackupInfoMessage implements ServerMessage {
  final bool exists;
  final String? appVersion;
  final int? dbVersion;
  final String? backedUpAt;
  final int? sizeBytes;
  const PromptHistoryBackupInfoMessage({
    required this.exists,
    this.appVersion,
    this.dbVersion,
    this.backedUpAt,
    this.sizeBytes,
  });
}

class MessageImagesResultMessage implements ServerMessage {
  final String messageUuid;
  final List<ImageRef> images;
  const MessageImagesResultMessage({
    required this.messageUuid,
    required this.images,
  });
}

// ---- Git Operations (Phase 1-3) ----

class GitStageResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitStageResultMessage({required this.success, this.error});
}

class GitUnstageResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitUnstageResultMessage({required this.success, this.error});
}

class GitUnstageHunksResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitUnstageHunksResultMessage({required this.success, this.error});
}

class GitCommitResultMessage implements ServerMessage {
  final bool success;
  final String? commitHash;
  final String? message;
  final String? error;
  const GitCommitResultMessage({
    required this.success,
    this.commitHash,
    this.message,
    this.error,
  });
}

class GitPushResultMessage implements ServerMessage {
  final bool success;
  final String? remote;
  final String? branch;
  final String? error;
  const GitPushResultMessage({
    required this.success,
    this.remote,
    this.branch,
    this.error,
  });
}

class GitBranchRemoteStatus {
  final int ahead;
  final int behind;
  final bool hasUpstream;

  const GitBranchRemoteStatus({
    required this.ahead,
    required this.behind,
    required this.hasUpstream,
  });

  factory GitBranchRemoteStatus.fromJson(Map<String, dynamic> json) {
    return GitBranchRemoteStatus(
      ahead: json['ahead'] as int? ?? 0,
      behind: json['behind'] as int? ?? 0,
      hasUpstream: json['hasUpstream'] as bool? ?? false,
    );
  }
}

class GitStatusResultMessage implements ServerMessage {
  final List<String> staged;
  final List<String> unstaged;
  final List<String> untracked;
  const GitStatusResultMessage({
    required this.staged,
    required this.unstaged,
    required this.untracked,
  });
}

class GitBranchesResultMessage implements ServerMessage {
  final String current;
  final List<String> branches;
  final List<String> checkedOutBranches;
  final Map<String, GitBranchRemoteStatus> remoteStatusByBranch;
  final String? error;
  const GitBranchesResultMessage({
    required this.current,
    required this.branches,
    this.checkedOutBranches = const [],
    this.remoteStatusByBranch = const {},
    this.error,
  });
}

class GitCreateBranchResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitCreateBranchResultMessage({required this.success, this.error});
}

class GitCheckoutBranchResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitCheckoutBranchResultMessage({required this.success, this.error});
}

class GitRevertFileResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitRevertFileResultMessage({required this.success, this.error});
}

class GitRevertHunksResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitRevertHunksResultMessage({required this.success, this.error});
}

class GitFetchResultMessage implements ServerMessage {
  final bool success;
  final String? error;
  const GitFetchResultMessage({required this.success, this.error});
}

class GitPullResultMessage implements ServerMessage {
  final bool success;
  final String? message;
  final String? error;
  const GitPullResultMessage({required this.success, this.message, this.error});
}

class GitRemoteStatusResultMessage implements ServerMessage {
  final int ahead;
  final int behind;
  final String branch;
  final bool hasUpstream;
  const GitRemoteStatusResultMessage({
    required this.ahead,
    required this.behind,
    required this.branch,
    required this.hasUpstream,
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

  /// Number of images attached to this user message.
  final int imageCount;
  final List<AssistantContent> content;
  const PastMessage({
    required this.role,
    this.uuid,
    this.timestamp,
    this.isMeta = false,
    this.imageCount = 0,
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
      imageCount: json['imageCount'] as int? ?? 0,
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

  /// User-assigned session name (customTitle for Claude, thread_name for Codex).
  final String? name;
  final String? agentNickname;
  final String? agentRole;
  final String? summary;
  final String firstPrompt;
  final String? lastPrompt;
  final String created;
  final String modified;
  final String gitBranch;
  final String projectPath;
  final String? resumeCwd;
  final bool isSidechain;
  final String? codexApprovalPolicy;
  final String? executionMode;
  final bool planMode;
  final String? codexSandboxMode;
  final String? codexModel;
  final String? codexModelReasoningEffort;
  final bool? codexNetworkAccessEnabled;
  final String? codexWebSearchMode;

  const RecentSession({
    required this.sessionId,
    this.provider,
    this.name,
    this.agentNickname,
    this.agentRole,
    this.summary,
    required this.firstPrompt,
    this.lastPrompt,
    required this.created,
    required this.modified,
    required this.gitBranch,
    required this.projectPath,
    this.resumeCwd,
    required this.isSidechain,
    this.codexApprovalPolicy,
    this.executionMode,
    this.planMode = false,
    this.codexSandboxMode,
    this.codexModel,
    this.codexModelReasoningEffort,
    this.codexNetworkAccessEnabled,
    this.codexWebSearchMode,
  });

  ExecutionMode get resolvedExecutionMode => deriveExecutionMode(
    provider: provider,
    executionMode: executionMode,
    approvalPolicy: codexApprovalPolicy,
  );

  bool get resolvedPlanMode => planMode;

  String get permissionMode => legacyPermissionModeFromModes(
    provider == Provider.codex.value ? Provider.codex : Provider.claude,
    executionMode: resolvedExecutionMode,
    planMode: resolvedPlanMode,
  ).value;

  factory RecentSession.fromJson(Map<String, dynamic> json) {
    final codexSettings = json['codexSettings'] as Map<String, dynamic>?;
    return RecentSession(
      sessionId: json['sessionId'] as String,
      provider: json['provider'] as String?,
      name: json['name'] as String?,
      agentNickname: json['agentNickname'] as String?,
      agentRole: json['agentRole'] as String?,
      summary: json['summary'] as String?,
      firstPrompt: json['firstPrompt'] as String? ?? '',
      lastPrompt: json['lastPrompt'] as String?,
      created: json['created'] as String? ?? '',
      modified: json['modified'] as String? ?? '',
      gitBranch: json['gitBranch'] as String? ?? '',
      projectPath: json['projectPath'] as String? ?? '',
      resumeCwd: json['resumeCwd'] as String?,
      isSidechain: json['isSidechain'] as bool? ?? false,
      codexApprovalPolicy: codexSettings?['approvalPolicy'] as String?,
      executionMode:
          json['executionMode'] as String? ??
          deriveExecutionMode(
            provider: json['provider'] as String?,
            permissionMode: json['permissionMode'] as String?,
            approvalPolicy: codexSettings?['approvalPolicy'] as String?,
          ).value,
      planMode: derivePlanMode(
        planMode: json['planMode'] as bool?,
        permissionMode: json['permissionMode'] as String?,
      ),
      codexSandboxMode: codexSettings?['sandboxMode'] as String?,
      codexModel: sanitizeCodexModelName(codexSettings?['model'] as String?),
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

  /// Create a copy with an updated name. Use [clearName] to set name to null.
  RecentSession copyWithName({String? name, bool clearName = false}) {
    return RecentSession(
      sessionId: sessionId,
      provider: provider,
      name: clearName ? null : (name ?? this.name),
      agentNickname: agentNickname,
      agentRole: agentRole,
      summary: summary,
      firstPrompt: firstPrompt,
      lastPrompt: lastPrompt,
      created: created,
      modified: modified,
      gitBranch: gitBranch,
      projectPath: projectPath,
      resumeCwd: resumeCwd,
      isSidechain: isSidechain,
      codexApprovalPolicy: codexApprovalPolicy,
      executionMode: executionMode,
      planMode: planMode,
      codexSandboxMode: codexSandboxMode,
      codexModel: codexModel,
      codexModelReasoningEffort: codexModelReasoningEffort,
      codexNetworkAccessEnabled: codexNetworkAccessEnabled,
      codexWebSearchMode: codexWebSearchMode,
    );
  }
}

// ---- Session info (for multi-session) ----

class SessionInfo {
  final String id;
  final String? provider;
  final String projectPath;
  final String? claudeSessionId;

  /// User-assigned session name.
  final String? name;
  final String? agentNickname;
  final String? agentRole;
  final String status;
  final String createdAt;
  final String lastActivityAt;
  final String gitBranch;
  final String lastMessage;
  final String? worktreePath;
  final String? worktreeBranch;
  final String? permissionMode;
  final String? executionMode;
  final bool planMode;
  final String? model;
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
    this.name,
    this.agentNickname,
    this.agentRole,
    required this.status,
    required this.createdAt,
    required this.lastActivityAt,
    this.gitBranch = '',
    this.lastMessage = '',
    this.worktreePath,
    this.worktreeBranch,
    this.permissionMode,
    this.executionMode,
    this.planMode = false,
    this.model,
    this.codexApprovalPolicy,
    this.codexSandboxMode,
    this.codexModel,
    this.codexModelReasoningEffort,
    this.codexNetworkAccessEnabled,
    this.codexWebSearchMode,
    this.pendingPermission,
  });

  ExecutionMode get resolvedExecutionMode => deriveExecutionMode(
    provider: provider,
    executionMode: executionMode,
    permissionMode: permissionMode,
    approvalPolicy: codexApprovalPolicy,
  );

  bool get resolvedPlanMode =>
      planMode || permissionMode == PermissionMode.plan.value;

  String get effectivePermissionMode =>
      permissionMode ??
      legacyPermissionModeFromModes(
        provider == Provider.codex.value ? Provider.codex : Provider.claude,
        executionMode: resolvedExecutionMode,
        planMode: resolvedPlanMode,
      ).value;

  SessionInfo copyWith({
    String? status,
    String? name,
    bool clearName = false,
    String? lastMessage,
    String? permissionMode,
    String? executionMode,
    bool? planMode,
    String? model,
    String? codexApprovalPolicy,
    String? codexSandboxMode,
    String? codexModel,
    String? codexModelReasoningEffort,
    bool? codexNetworkAccessEnabled,
    String? codexWebSearchMode,
    PermissionRequestMessage? pendingPermission,
    bool clearPermission = false,
  }) {
    return SessionInfo(
      id: id,
      provider: provider,
      projectPath: projectPath,
      claudeSessionId: claudeSessionId,
      name: clearName ? null : (name ?? this.name),
      agentNickname: agentNickname,
      agentRole: agentRole,
      status: status ?? this.status,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
      gitBranch: gitBranch,
      lastMessage: lastMessage ?? this.lastMessage,
      worktreePath: worktreePath,
      worktreeBranch: worktreeBranch,
      permissionMode: permissionMode ?? this.permissionMode,
      executionMode: executionMode ?? this.executionMode,
      planMode: planMode ?? this.planMode,
      model: model ?? this.model,
      codexApprovalPolicy: codexApprovalPolicy ?? this.codexApprovalPolicy,
      codexSandboxMode: codexSandboxMode ?? this.codexSandboxMode,
      codexModel: codexModel ?? this.codexModel,
      codexModelReasoningEffort:
          codexModelReasoningEffort ?? this.codexModelReasoningEffort,
      codexNetworkAccessEnabled:
          codexNetworkAccessEnabled ?? this.codexNetworkAccessEnabled,
      codexWebSearchMode: codexWebSearchMode ?? this.codexWebSearchMode,
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
      name: json['name'] as String?,
      agentNickname: json['agentNickname'] as String?,
      agentRole: json['agentRole'] as String?,
      status: json['status'] as String? ?? 'idle',
      createdAt: json['createdAt'] as String? ?? '',
      lastActivityAt: json['lastActivityAt'] as String? ?? '',
      gitBranch: json['gitBranch'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      worktreePath: json['worktreePath'] as String?,
      worktreeBranch: json['worktreeBranch'] as String?,
      permissionMode: json['permissionMode'] as String?,
      executionMode:
          json['executionMode'] as String? ??
          deriveExecutionMode(
            provider: json['provider'] as String?,
            permissionMode: json['permissionMode'] as String?,
            approvalPolicy: codexSettings?['approvalPolicy'] as String?,
          ).value,
      planMode: derivePlanMode(
        planMode: json['planMode'] as bool?,
        permissionMode: json['permissionMode'] as String?,
      ),
      model: json['model'] as String?,
      codexApprovalPolicy: codexSettings?['approvalPolicy'] as String?,
      codexSandboxMode: codexSettings?['sandboxMode'] as String?,
      codexModel: sanitizeCodexModelName(codexSettings?['model'] as String?),
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

  String get type => _json['type'] as String;

  factory ClientMessage.start(
    String projectPath, {
    String? sessionId,
    bool? continueMode,
    String? permissionMode,
    String? executionMode,
    bool? planMode,
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
      'executionMode': ?executionMode,
      'planMode': ?planMode,
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
      'sandboxMode': ?sandboxMode,
      'modelReasoningEffort': ?modelReasoningEffort,
      'networkAccessEnabled': ?networkAccessEnabled,
      'webSearchMode': ?webSearchMode,
    });
  }

  factory ClientMessage.input(
    String text, {
    String? sessionId,
    List<Map<String, String>>? images,
    Map<String, String>? skill,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'input',
      'text': text,
      'sessionId': ?sessionId,
      if (images != null && images.isNotEmpty) 'images': images,
      'skill': ?skill,
    });
  }

  factory ClientMessage.pushRegister({
    required String token,
    required String platform,
    String? locale,
    bool? privacyMode,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'push_register',
    'token': token,
    'platform': platform,
    'locale': ?locale,
    'privacyMode': ?privacyMode,
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

  factory ClientMessage.setSessionMode({
    required String legacyMode,
    String? executionMode,
    bool? planMode,
    String? sessionId,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'set_permission_mode',
      'mode': legacyMode,
      'executionMode': ?executionMode,
      'planMode': ?planMode,
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

  factory ClientMessage.refreshBranch(String sessionId) =>
      ClientMessage._({'type': 'refresh_branch', 'sessionId': sessionId});

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

  /// Rename a session. For running sessions, sessionId is the bridge session id.
  /// For recent sessions, include provider, providerSessionId, and projectPath.
  factory ClientMessage.renameSession({
    required String sessionId,
    String? name,
    String? provider,
    String? providerSessionId,
    String? projectPath,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'rename_session',
      'sessionId': sessionId,
      'name': ?name,
      'provider': ?provider,
      'providerSessionId': ?providerSessionId,
      'projectPath': ?projectPath,
    });
  }

  factory ClientMessage.listRecentSessions({
    int? limit,
    int? offset,
    String? projectPath,
    String? provider,
    bool? namedOnly,
    String? searchQuery,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'list_recent_sessions',
      'limit': ?limit,
      'offset': ?offset,
      'projectPath': ?projectPath,
      'provider': ?provider,
      'namedOnly': ?namedOnly,
      'searchQuery': ?searchQuery,
    });
  }

  factory ClientMessage.resumeSession(
    String sessionId,
    String projectPath, {
    String? permissionMode,
    String? executionMode,
    bool? planMode,
    String? effort,
    int? maxTurns,
    double? maxBudgetUsd,
    String? fallbackModel,
    bool? forkSession,
    bool? persistSession,
    String? provider,
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
      'executionMode': ?executionMode,
      'planMode': ?planMode,
      'effort': ?effort,
      'maxTurns': ?maxTurns,
      'maxBudgetUsd': ?maxBudgetUsd,
      'fallbackModel': ?fallbackModel,
      'forkSession': ?forkSession,
      'persistSession': ?persistSession,
      'provider': ?provider,
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

  factory ClientMessage.readFile(
    String projectPath,
    String filePath, {
    int? maxLines,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'read_file',
    'projectPath': projectPath,
    'filePath': filePath,
    'maxLines': ?maxLines,
  });

  factory ClientMessage.listFiles(String projectPath) =>
      ClientMessage._({'type': 'list_files', 'projectPath': projectPath});

  factory ClientMessage.getDiff(String projectPath, {bool? staged}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'get_diff',
        'projectPath': projectPath,
        'staged': ?staged,
      });

  factory ClientMessage.getDiffImage(
    String projectPath,
    String filePath,
    String version,
  ) => ClientMessage._({
    'type': 'get_diff_image',
    'projectPath': projectPath,
    'filePath': filePath,
    'version': version,
  });

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

  factory ClientMessage.getMessageImages({
    required String claudeSessionId,
    required String messageUuid,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'get_message_images',
    'claudeSessionId': claudeSessionId,
    'messageUuid': messageUuid,
  });

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

  factory ClientMessage.backupPromptHistory({
    required String data,
    required String appVersion,
    required int dbVersion,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'backup_prompt_history',
    'data': data,
    'appVersion': appVersion,
    'dbVersion': dbVersion,
  });

  factory ClientMessage.restorePromptHistory() =>
      ClientMessage._({'type': 'restore_prompt_history'});

  factory ClientMessage.getPromptHistoryBackupInfo() =>
      ClientMessage._({'type': 'get_prompt_history_backup_info'});

  factory ClientMessage.archiveSession({
    required String sessionId,
    required String provider,
    required String projectPath,
  }) {
    return ClientMessage._(<String, dynamic>{
      'type': 'archive_session',
      'sessionId': sessionId,
      'provider': provider,
      'projectPath': projectPath,
    });
  }

  // ---- Git Operations (Phase 1-3) ----

  factory ClientMessage.gitStage(
    String projectPath, {
    List<String>? files,
    List<Map<String, dynamic>>? hunks,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'git_stage',
    'projectPath': projectPath,
    'files': ?files,
    'hunks': ?hunks,
  });

  factory ClientMessage.gitUnstage(String projectPath, {List<String>? files}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'git_unstage',
        'projectPath': projectPath,
        'files': ?files,
      });

  factory ClientMessage.gitUnstageHunks(
    String projectPath,
    List<Map<String, dynamic>> hunks,
  ) => ClientMessage._(<String, dynamic>{
    'type': 'git_unstage_hunks',
    'projectPath': projectPath,
    'hunks': hunks,
  });

  factory ClientMessage.gitCommit(
    String projectPath, {
    String? message,
    bool? autoGenerate,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'git_commit',
    'projectPath': projectPath,
    'message': ?message,
    'autoGenerate': ?autoGenerate,
  });

  factory ClientMessage.gitPush(String projectPath, {bool? forceLease}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'git_push',
        'projectPath': projectPath,
        'forceLease': ?forceLease,
      });

  factory ClientMessage.gitStatus(String projectPath) =>
      ClientMessage._({'type': 'git_status', 'projectPath': projectPath});

  factory ClientMessage.gitBranches(String projectPath, {String? query}) =>
      ClientMessage._(<String, dynamic>{
        'type': 'git_branches',
        'projectPath': projectPath,
        'query': ?query,
      });

  factory ClientMessage.gitCreateBranch(
    String projectPath,
    String name, {
    bool? checkout,
  }) => ClientMessage._(<String, dynamic>{
    'type': 'git_create_branch',
    'projectPath': projectPath,
    'name': name,
    'checkout': ?checkout,
  });

  factory ClientMessage.gitCheckoutBranch(String projectPath, String branch) =>
      ClientMessage._({
        'type': 'git_checkout_branch',
        'projectPath': projectPath,
        'branch': branch,
      });

  factory ClientMessage.gitRevertFile(String projectPath, List<String> files) =>
      ClientMessage._({
        'type': 'git_revert_file',
        'projectPath': projectPath,
        'files': files,
      });

  factory ClientMessage.gitRevertHunks(
    String projectPath,
    List<Map<String, dynamic>> hunks,
  ) => ClientMessage._({
    'type': 'git_revert_hunks',
    'projectPath': projectPath,
    'hunks': hunks,
  });

  factory ClientMessage.gitFetch(String projectPath) =>
      ClientMessage._({'type': 'git_fetch', 'projectPath': projectPath});

  factory ClientMessage.gitPull(String projectPath) =>
      ClientMessage._({'type': 'git_pull', 'projectPath': projectPath});

  factory ClientMessage.gitRemoteStatus(String projectPath) => ClientMessage._({
    'type': 'git_remote_status',
    'projectPath': projectPath,
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
  final List<Uint8List> imageBytesList;
  final List<String> imageUrls;
  MessageStatus status;

  /// Number of images attached to this user message (from history restoration).
  final int imageCount;

  /// UUID assigned by the SDK for this user message (set when tool_result arrives).
  String? messageUuid;
  @override
  final DateTime timestamp;
  UserChatEntry(
    this.text, {
    DateTime? timestamp,
    this.sessionId,
    List<Uint8List>? imageBytesList,
    List<String>? imageUrls,
    this.imageCount = 0,
    this.status = MessageStatus.sending,
    this.messageUuid,
  }) : imageBytesList = imageBytesList ?? const [],
       imageUrls = imageUrls ?? const [],
       timestamp = timestamp ?? DateTime.now();
}

class StreamingChatEntry implements ChatEntry {
  String text;
  @override
  final DateTime timestamp;
  StreamingChatEntry({this.text = '', DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

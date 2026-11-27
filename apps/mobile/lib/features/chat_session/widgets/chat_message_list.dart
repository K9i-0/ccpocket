import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart'
    show
        RenderBox,
        RenderProxyBox,
        RenderSliverMultiBoxAdaptor,
        RenderViewportBase,
        ScrollDirection,
        applyGrowthDirectionToAxisDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:markdown_kit/markdown_kit.dart';

import '../compaction_projection.dart';
import '../../session_transcript/session_transcript_screen.dart';
import '../../media_feedback/media_feedback_scope.dart';
import '../../../models/chat_display_filter.dart';
import '../../../models/messages.dart';
import '../../../providers/bridge_cubits.dart';
import '../../../services/bridge_service.dart';
import '../../../services/performance_probe_extension.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/codex_plan_update.dart';
import '../../../utils/diff_parser.dart';
import '../../../utils/platform_helper.dart';
import '../../../widgets/indexed_scroll_controller.dart';
import '../../../widgets/markdown/ccpocket_markdown.dart';
import '../../../widgets/message_bubble.dart';
import '../../generated_image_preview/generated_image_preview_mapper.dart';
import '../../generated_image_preview/generated_image_preview_item.dart';
import '../../generated_image_preview/generated_image_response_grouping.dart';
import '../../generated_image_preview/widgets/generated_image_chat_group.dart';
import '../../file_peek/file_peek_sheet.dart';
import '../../message_images/message_images_screen.dart';
import '../permission_transcript.dart';
import '../lite_mode_projection.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';
import '../state/streaming_state.dart';
import '../state/streaming_state_cubit.dart';
import 'maintain_reading_position_physics.dart';
import 'floating_composer_layout.dart';

@visibleForTesting
bool shouldShowForkForAssistant(List<ChatEntry> entries, int entryIndex) {
  if (entryIndex < 0 || entryIndex >= entries.length) return false;
  final entry = entries[entryIndex];
  if (entry is! ServerChatEntry || entry.message is! AssistantServerMessage) {
    return false;
  }

  for (var i = entryIndex + 1; i < entries.length; i++) {
    final next = entries[i];
    if (next is UserChatEntry) return false;
    if (next is ServerChatEntry) {
      final message = next.message;
      if (message is AssistantServerMessage) return false;
      if (message is ResultMessage) return true;
    }
  }
  return false;
}

@visibleForTesting
Set<int> forkableAssistantEntryIndices(List<ChatEntry> entries) {
  final result = <int>{};
  int? candidate;
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is UserChatEntry) {
      candidate = null;
      continue;
    }
    if (entry is! ServerChatEntry) continue;
    switch (entry.message) {
      case AssistantServerMessage():
        candidate = index;
        break;
      case ResultMessage():
        if (candidate != null) result.add(candidate);
        break;
      default:
        break;
    }
  }
  return result;
}

/// Claude results that do not end the work: a later result follows without
/// user input in between (Claude started a follow-up turn when a background
/// task reported back), or background agents are still running after the
/// latest one. Their completion chips would announce a finish too early.
/// Shells and monitors may run indefinitely, so they do not hide the chip.
@visibleForTesting
Set<int> intermediateResultEntryIndices(
  List<ChatEntry> entries, {
  required bool backgroundAgentsActive,
}) {
  final hidden = <int>{};
  int? lastResult;
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is UserChatEntry) {
      lastResult = null;
      continue;
    }
    if (entry is! ServerChatEntry) continue;
    final message = entry.message;
    if (message is! ResultMessage) continue;
    if (lastResult != null) hidden.add(lastResult);
    lastResult = message.subtype == 'success' ? index : null;
  }
  if (backgroundAgentsActive && lastResult != null) hidden.add(lastResult);
  return hidden;
}

@visibleForTesting
Set<int> successResultFallbackEntryIndices(List<ChatEntry> entries) {
  final fallbackIndices = <int>{};
  final assistantTexts = <String>[];
  ({int index, String text, List<String> assistantTexts})? pendingResult;

  bool isAlreadyShown(String resultText, List<String> texts) {
    final visibleAssistantText = texts.join('\n\n');
    return visibleAssistantText == resultText ||
        visibleAssistantText.endsWith('\n\n$resultText');
  }

  void resolvePendingResult({bool includeTrailingAssistants = false}) {
    final pending = pendingResult;
    if (pending == null) return;
    // Trailing assistants may be a late-arriving final answer, or a new turn
    // that started without a user entry (e.g. a background task
    // notification). Accept the result as shown when any prefix of the
    // trailing texts completes it, so later turns cannot un-hide it.
    final trailingCount = includeTrailingAssistants ? assistantTexts.length : 0;
    var shown = false;
    for (var count = 0; count <= trailingCount && !shown; count++) {
      shown = isAlreadyShown(pending.text, [
        ...pending.assistantTexts,
        ...assistantTexts.take(count),
      ]);
    }
    if (!shown) {
      fallbackIndices.add(pending.index);
    }
    pendingResult = null;
  }

  void finishTurn() {
    resolvePendingResult(includeTrailingAssistants: true);
    assistantTexts.clear();
  }

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is UserChatEntry) {
      finishTurn();
      continue;
    }
    if (entry is! ServerChatEntry) continue;
    switch (entry.message) {
      case AssistantServerMessage(:final message):
        final text = message.content
            .whereType<TextContent>()
            .map((content) => content.text)
            .join('\n\n')
            .trim();
        if (text.isNotEmpty) assistantTexts.add(text);
      case ResultMessage(:final subtype, :final result):
        // Result messages are turn boundaries even when old history omitted
        // the corresponding user entry. Only the final pending result may use
        // trailing assistant text as a late-arrival reconciliation.
        resolvePendingResult();
        if (subtype == 'success' && result?.trim().isNotEmpty == true) {
          pendingResult = (
            index: index,
            text: result!.trim(),
            assistantTexts: List.of(assistantTexts),
          );
        }
        assistantTexts.clear();
      default:
        break;
    }
  }
  finishTurn();
  return fallbackIndices;
}

@visibleForTesting
ToolUseContent? findLatestIncompleteToolUse(List<ChatEntry> entries) {
  const terminalStatuses = {'completed', 'failed', 'declined', 'cancelled'};
  final completedToolIds = <String>{};
  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is UserChatEntry) break;
    if (entry is! ServerChatEntry) continue;
    final message = entry.message;
    if (message is ResultMessage) break;
    if (message is ToolResultMessage) {
      completedToolIds.add(message.toolUseId);
      continue;
    }
    if (message is AssistantServerMessage) {
      final contents = message.message.content;
      var hasVisibleText = false;
      for (var j = contents.length - 1; j >= 0; j--) {
        final content = contents[j];
        if (content is TextContent && content.text.trim().isNotEmpty) {
          hasVisibleText = true;
          continue;
        }
        if (content is ToolUseContent) {
          if (isCodexUpdatePlanTool(content.name)) continue;
          final rawStatus = content.input['status'];
          if (rawStatus is String &&
              terminalStatuses.contains(rawStatus.toLowerCase())) {
            continue;
          }
          if (!completedToolIds.contains(content.id)) {
            return content;
          }
        }
      }
      // Once a newer assistant response has emitted text, any earlier
      // unclosed tool_use from a previous round is no longer active.
      if (hasVisibleText) break;
    }
  }
  return null;
}

String _truncateActivityHint(String text, {int maxChars = 48}) {
  return text.length > maxChars
      ? '${text.substring(0, maxChars - 3)}...'
      : text;
}

String _withTrailingEllipsis(String text) {
  final trimmed = text.trim();
  if (trimmed.endsWith('...') || trimmed.endsWith('…')) return trimmed;
  if (trimmed.endsWith('.')) return '$trimmed..';
  return '$trimmed...';
}

String _appendElapsedSuffix(String label, int? elapsedSeconds) {
  if (elapsedSeconds == null || elapsedSeconds < 2) return label;
  return '$label · ${elapsedSeconds}s';
}

@visibleForTesting
String formatAgentActivityLabel(ToolUseContent tool) {
  String? nonEmptyString(Object? value) {
    if (value is! String) return null;
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? null : collapsed;
  }

  String? extractBasename(Map<String, dynamic> input) {
    var raw = nonEmptyString(
      input['file_path'] ?? input['path'] ?? input['notebook_path'],
    );
    if (raw == null) {
      final changes = input['changes'];
      if (changes is List && changes.isNotEmpty) {
        final first = changes.first;
        if (first is Map) {
          raw = nonEmptyString(first['path']);
        }
      }
    }
    if (raw == null) return null;
    final normalized = raw
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'/+$'), '');
    final idx = normalized.lastIndexOf('/');
    final base = idx >= 0 ? normalized.substring(idx + 1) : normalized;
    return base.isEmpty ? null : base;
  }

  final name = tool.name;
  if (name == 'Bash') {
    final desc = nonEmptyString(tool.input['description']);
    if (desc != null) return 'Running: ${_truncateActivityHint(desc)}...';
    final cmd = nonEmptyString(tool.input['command'] ?? tool.input['cmd']);
    if (cmd != null) {
      return 'Running: ${_truncateActivityHint(cmd, maxChars: 36)}...';
    }
    return 'Running command...';
  }
  if (name == 'Read') {
    final base = extractBasename(tool.input);
    return base != null ? 'Reading $base...' : 'Reading file...';
  }
  if (name == 'FileChange' ||
      name == 'Write' ||
      name == 'Edit' ||
      name == 'MultiEdit' ||
      name == 'FileEdit' ||
      name == 'NotebookEdit' ||
      name == 'apply_patch') {
    final base = extractBasename(tool.input);
    return base != null ? 'Editing $base...' : 'Editing files...';
  }
  if (name == 'Grep') {
    final pattern = nonEmptyString(tool.input['pattern']);
    return pattern != null
        ? 'Searching "${_truncateActivityHint(pattern, maxChars: 30)}"...'
        : 'Searching files...';
  }
  if (name == 'Glob') {
    final pattern = nonEmptyString(tool.input['pattern']);
    return pattern != null
        ? 'Finding ${_truncateActivityHint(pattern, maxChars: 30)}...'
        : 'Searching files...';
  }
  if (name == 'WebSearch') {
    final query = nonEmptyString(tool.input['query']);
    return query != null
        ? 'Searching web: ${_truncateActivityHint(query, maxChars: 36)}...'
        : 'Searching web...';
  }
  if (name == 'WebFetch') {
    return 'Fetching URL...';
  }
  if (name == 'ImageGeneration') {
    return 'Generating image...';
  }
  if (name == 'TodoWrite') {
    final todos = tool.input['todos'];
    if (todos is List) {
      for (final item in todos) {
        if (item is Map && item['status'] == 'in_progress') {
          final active = nonEmptyString(item['activeForm'] ?? item['content']);
          if (active != null) {
            return _withTrailingEllipsis(_truncateActivityHint(active));
          }
        }
      }
    }
    return 'Updating tasks...';
  }
  if (name == 'Task' ||
      name == 'invoke_subagent' ||
      name == 'Agent' ||
      name == 'SubAgent') {
    final desc = nonEmptyString(
      tool.input['description'] ?? tool.input['role'],
    );
    if (desc != null) {
      return 'Subagent: ${_truncateActivityHint(desc, maxChars: 40)}...';
    }
    final subTool = nonEmptyString(tool.input['tool']);
    if (subTool == 'wait') return 'Waiting for subagents...';
    return 'Running subagent...';
  }
  if (name.startsWith('mcp__')) {
    final toolPart = name
        .split('__')
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    return 'Running ${toolPart ?? name}...';
  }
  if (name.startsWith('mcp:')) {
    final toolPart = name
        .substring(4)
        .split(RegExp(r'[:/]'))
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    return 'Running ${toolPart ?? name}...';
  }
  final trimmed = name.trim();
  return trimmed.isNotEmpty ? 'Running $trimmed...' : 'Working...';
}

@visibleForTesting
bool shouldShowLiveAgentActivityBar({
  required ProcessStatus status,
  required bool hasApproval,
  required bool isPreparingTool,
  required bool hasStreamingText,
  required bool hasThinkingText,
}) {
  if (status != ProcessStatus.running || hasApproval) return false;
  if (isPreparingTool) return true;
  return !hasStreamingText && !hasThinkingText;
}

@visibleForTesting
String? resolveLiveAgentActivityLabel({
  required ProcessStatus status,
  required bool hasApproval,
  required ToolUseContent? incompleteTool,
  required AgentActivityInfo? activity,
  required bool hasStreamingText,
  required bool hasThinkingText,
}) {
  if (status != ProcessStatus.running || hasApproval) return null;

  // 1. Model is actively streaming tool JSON arguments before assistant block commits.
  if (activity != null && activity.preparingTool && activity.toolName != null) {
    final syntheticInput = <String, dynamic>{
      if (activity.toolHint != null) ...{
        'file_path': activity.toolHint,
        'description': activity.toolHint,
        'query': activity.toolHint,
        'pattern': activity.toolHint,
      },
    };
    if (activity.toolHint != null) {
      return formatAgentActivityLabel(
        ToolUseContent(
          id: activity.toolUseId ?? '',
          name: activity.toolName!,
          input: syntheticInput,
        ),
      );
    }
    final baseLabel = formatAgentActivityLabel(
      ToolUseContent(
        id: activity.toolUseId ?? '',
        name: activity.toolName!,
        input: const {},
      ),
    );
    return baseLabel.startsWith('Running ')
        ? 'Preparing ${baseLabel.substring(8)}'
        : baseLabel;
  }

  // When text or thinking is visibly streaming in the bubble above, hide the bar.
  if (hasStreamingText || hasThinkingText) return null;

  // 2. Active incomplete tool call in transcript.
  if (incompleteTool != null) {
    final isSubagent =
        incompleteTool.name == 'Task' ||
        incompleteTool.name == 'Agent' ||
        incompleteTool.name == 'SubAgent' ||
        incompleteTool.name == 'invoke_subagent';
    String label;
    if (isSubagent && activity?.summary != null) {
      label = _withTrailingEllipsis(
        'Subagent: ${_truncateActivityHint(activity!.summary!)}',
      );
    } else if (incompleteTool.name.startsWith('mcp:') &&
        activity?.summary != null &&
        (activity!.toolUseId == null ||
            activity.toolUseId == incompleteTool.id)) {
      label = _withTrailingEllipsis(_truncateActivityHint(activity.summary!));
    } else {
      label = formatAgentActivityLabel(incompleteTool);
    }
    final matchingElapsed =
        activity != null &&
            (activity.toolUseId == null ||
                activity.toolUseId == incompleteTool.id)
        ? activity.elapsedSeconds
        : null;
    return _appendElapsedSuffix(label, matchingElapsed);
  }

  // 3. Ephemeral server-side activity (e.g. Lite/Performance mode, server WebSearch,
  //    classifier task_summary, subagent summary, or redacted thinking token count).
  if (activity != null) {
    if (activity.summary != null && activity.toolName != null) {
      final label = _withTrailingEllipsis(
        '${_truncateActivityHint(activity.summary!, maxChars: 42)} (${activity.toolName})',
      );
      return _appendElapsedSuffix(label, activity.elapsedSeconds);
    }
    if (activity.toolName != null) {
      final label = formatAgentActivityLabel(
        ToolUseContent(
          id: activity.toolUseId ?? '',
          name: activity.toolName!,
          input: activity.toolHint != null
              ? {
                  'file_path': activity.toolHint,
                  'description': activity.toolHint,
                  'query': activity.toolHint,
                  'pattern': activity.toolHint,
                }
              : const {},
        ),
      );
      return _appendElapsedSuffix(label, activity.elapsedSeconds);
    }
    if (activity.summary != null) {
      return _appendElapsedSuffix(
        _withTrailingEllipsis(_truncateActivityHint(activity.summary!)),
        activity.elapsedSeconds,
      );
    }
    final tokens = activity.thinkingTokens;
    if (tokens != null && tokens > 0) {
      final formatted = tokens >= 1000
          ? '${(tokens / 1000).toStringAsFixed(1)}k'
          : '$tokens';
      return 'Thinking ($formatted tokens)...';
    }
  }

  return 'Thinking...';
}

/// Tool-use IDs of `FileChange` results that duplicate an inline diff already
/// rendered by the preceding `FileChange` tool_use card (e.g. replayed history
/// or transcripts), excluding results with images or permission outcomes.
Set<String> redundantFileChangeToolUseIds(List<ChatEntry> entries) {
  final toolUseIdsWithInlineDiff = <String>{};
  for (final entry in entries) {
    if (entry case ServerChatEntry(
      message: AssistantServerMessage(:final message),
    )) {
      for (final content in message.content) {
        if (content is ToolUseContent &&
            content.name == 'FileChange' &&
            content.id.isNotEmpty &&
            synthesizeEditToolDiff('FileChange', content.input) != null) {
          toolUseIdsWithInlineDiff.add(content.id);
        }
      }
    }
  }
  if (toolUseIdsWithInlineDiff.isEmpty) return const <String>{};
  final hidden = <String>{};
  for (final entry in entries) {
    if (entry case ServerChatEntry(message: final ToolResultMessage result)) {
      if (toolUseIdsWithInlineDiff.contains(result.toolUseId) &&
          result.permissionOutcome == null &&
          result.images.isEmpty) {
        hidden.add(result.toolUseId);
      }
    }
  }
  return hidden;
}

/// Displays the chat message list with [ListView.builder] (reverse: true).
///
/// Reads entries directly from [ChatSessionCubit] state (SSOT).
/// With reverse list, offset 0 = bottom of chat, so new messages appear
/// immediately without scroll adjustment, and history prepend does not
/// shift the viewport.
/// Whether the primary focus is an editable (keyboard-driven) text field.
///
/// Read-only focus owners such as [SelectionArea] or [SelectableText] return
/// false so that scrolling or dragging overlays does not clear an in-progress
/// text selection.
bool isEditableTextFocused() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  final editable = focusContext.findAncestorStateOfType<EditableTextState>();
  return editable != null && !editable.widget.readOnly;
}

class ChatMessageList extends StatefulWidget {
  final String sessionId;
  final IndexedScrollController scrollController;
  final String? httpBaseUrl;
  final void Function(UserChatEntry)? onRetryMessage;
  final void Function(UserChatEntry)? onRewindMessage;
  final void Function(UserChatEntry, String)? onEditMessage;
  final void Function(UserChatEntry)? onRestoreFilesMessage;
  final void Function(AssistantServerMessage)? onForkMessage;
  final ValueNotifier<int>? collapseToolResults;
  final double bottomPadding;
  final bool isCodex;
  final bool liteMode;
  final ChatDisplayFilter? displayFilter;
  final bool isReadingHistory;
  final ValueChanged<String>? onFilePeekOpened;

  /// Project path for file peek (reading files from Bridge).
  final String? projectPath;

  /// When set (non-null), the list scrolls to the given [UserChatEntry].
  /// The notifier is reset to null after scrolling.
  final ValueNotifier<UserChatEntry?>? scrollToUserEntry;

  /// Notifies scroll tracking when lazy layout changes the reachable extent.
  final VoidCallback? onScrollMetricsChanged;

  const ChatMessageList({
    super.key,
    required this.sessionId,
    required this.scrollController,
    required this.httpBaseUrl,
    required this.onRetryMessage,
    this.onRewindMessage,
    this.onEditMessage,
    this.onRestoreFilesMessage,
    this.onForkMessage,
    required this.collapseToolResults,
    this.scrollToUserEntry,
    this.onScrollMetricsChanged,
    this.bottomPadding = 8,
    this.projectPath,
    this.isCodex = false,
    this.liteMode = false,
    this.displayFilter,
    this.isReadingHistory = false,
    this.onFilePeekOpened,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  static const _streamingEntryKey = ValueKey<String>('streaming');

  final _viewportKey = GlobalKey();
  late final MarkdownSelectionController _selectionController;
  bool _wasStreaming = false;
  int _streamingTurnId = 0;
  int _streamingStartEntryCount = 0;
  final Map<String, String> _handedOffDocIds = {};
  final _generatedImageItemCache =
      <GeneratedImageItemCacheKey, GeneratedImagePreviewItem>{};
  List<ChatEntry>? _projectionSource;
  bool? _projectionOlderHistory;
  bool? _projectionCompacting;
  ChatDisplayFilter? _projectionFilter;
  List<ChatEntry>? _projectedEntries;

  ChatDisplayFilter get _effectiveDisplayFilter =>
      widget.displayFilter ??
      (widget.liteMode ? ChatDisplayFilter.recommended : ChatDisplayFilter.all);

  /// Rows to display: compaction folding first, then display filter.
  List<ChatEntry> _displayEntries(ChatSessionState state) {
    final entries = state.entries;
    final compacting = state.status == ProcessStatus.compacting;
    final filter = _effectiveDisplayFilter;
    if (_projectedEntries == null ||
        !listEquals(_projectionSource, entries) ||
        _projectionOlderHistory != state.olderHistoryAvailable ||
        _projectionCompacting != compacting ||
        _projectionFilter != filter) {
      _projectionSource = entries;
      _projectionOlderHistory = state.olderHistoryAvailable;
      _projectionCompacting = compacting;
      _projectionFilter = filter;
      final folded = compactionVisibleEntries(
        entries,
        olderHistoryAvailable: state.olderHistoryAvailable,
        compacting: compacting,
      );
      _projectedEntries = filter.isFiltered
          ? liteModeEntries(folded, filter: filter)
          : folded;
    }
    return _projectedEntries!;
  }

  void _openTranscript() {
    openSessionTranscript(
      context,
      sessionId: widget.sessionId,
      httpBaseUrl: widget.httpBaseUrl,
      isCodex: widget.isCodex,
      liteMode: _effectiveDisplayFilter.isFiltered,
      displayFilter: _effectiveDisplayFilter,
    );
  }

  ChatSessionState? _derivedForState;
  List<ChatEntry>? _derivedEntries;
  List<ChatEntry>? _derivedSourceEntries;
  String? _derivedForHttpBaseUrl;
  ProcessStatus? _derivedForProcessStatus;
  bool? _derivedForBackgroundAgentsActive;
  String? _derivedForActivePermissionId;
  _ChatListDerivedData? _derivedData;
  _VisibleAnchor? _pendingAnchor;
  bool _anchorCorrectionScheduled = false;
  _VisibleAnchor? _measuredResizeAnchor;
  double _measuredResizeOffset = 0;
  bool _anchorMeasurementScheduled = false;
  bool _metricsNotificationScheduled = false;
  double? _streamingRowHeight;

  void _notifyScrollMetricsAfterLayout() {
    if (_metricsNotificationScheduled ||
        widget.onScrollMetricsChanged == null) {
      return;
    }
    _metricsNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsNotificationScheduled = false;
      if (mounted) widget.onScrollMetricsChanged?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectionController = MarkdownSelectionController(
      allowCrossDocumentSelection: false,
    );
    widget.scrollToUserEntry?.addListener(_onScrollToUserEntry);
    _attachLayoutAnchorCorrection();
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFilter =
        oldWidget.displayFilter ??
        (oldWidget.liteMode
            ? ChatDisplayFilter.recommended
            : ChatDisplayFilter.all);
    if (oldFilter != _effectiveDisplayFilter) {
      _derivedData = null;
      _pendingAnchor = null;
    }
    if (oldWidget.sessionId != widget.sessionId) {
      _handedOffDocIds.clear();
      _wasStreaming = false;
      _streamingStartEntryCount = 0;
      _selectionController.clear();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachLayoutAnchorCorrection(oldWidget.scrollController);
      _attachLayoutAnchorCorrection();
    }
    if (oldWidget.scrollToUserEntry != widget.scrollToUserEntry) {
      oldWidget.scrollToUserEntry?.removeListener(_onScrollToUserEntry);
      widget.scrollToUserEntry?.addListener(_onScrollToUserEntry);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _detachLayoutAnchorCorrection(widget.scrollController);
    widget.scrollToUserEntry?.removeListener(_onScrollToUserEntry);
    super.dispose();
  }

  void _attachLayoutAnchorCorrection() {
    final controller = widget.scrollController;
    controller.addListener(_scheduleAnchorMeasurement);
    controller.layoutAnchorCorrection = _pendingAnchorCorrection;
  }

  void _detachLayoutAnchorCorrection(IndexedScrollController controller) {
    controller.removeListener(_scheduleAnchorMeasurement);
    // Instance method tear-offs are equal but never identical, so compare
    // with `==`; `identical` would leave this State attached forever.
    if (controller.layoutAnchorCorrection == _pendingAnchorCorrection) {
      controller.layoutAnchorCorrection = null;
    }
  }

  void _onScrollToUserEntry() {
    final entry = widget.scrollToUserEntry?.value;
    if (entry == null) return;
    // Reset the notifier
    widget.scrollToUserEntry?.value = null;
    _scrollToUserEntry(entry);
  }

  // ---------------------------------------------------------------------------
  // Scroll to user entry
  // ---------------------------------------------------------------------------

  /// Scrolls the chat list to make the given [UserChatEntry] visible.
  ///
  /// Uses [IndexedScrollController.scrollToIndex] which handles both on-screen
  /// and off-screen items correctly with variable-height widgets.
  void _scrollToUserEntry(UserChatEntry entry) {
    final entries = _displayEntries(context.read<ChatSessionCubit>().state);
    final idx = entries.indexOf(entry);
    if (idx < 0) return;
    widget.scrollController.scrollToIndex(
      idx,
      preferPosition: IndexedScrollPosition.middle,
      duration: const Duration(milliseconds: 300),
    );
  }

  /// Records one measured, visible message before a state change. After the
  /// next layout, the same keyed message is restored to the same screen Y.
  /// This avoids relying on the lazy list's estimated maxScrollExtent.
  void _captureVisibleAnchor() {
    if (!widget.isReadingHistory ||
        !widget.scrollController.hasClients ||
        widget.scrollController.isAutoScrolling ||
        _anchorCorrectionScheduled) {
      return;
    }
    if (widget.scrollController.position.isScrollingNotifier.value) return;

    final best = _measureVisibleAnchor();
    if (best == null) return;

    _pendingAnchor = best;
    _anchorCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreVisibleAnchor(),
    );
  }

  _VisibleAnchor? _measureVisibleAnchor() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached || !viewport.hasSize) {
      return null;
    }

    _VisibleAnchor? best;
    var bestDistance = double.infinity;
    final viewportCenter = viewport.size.height / 2;
    for (final tagState in widget.scrollController.tagMap.values) {
      if (!tagState.mounted) continue;
      final renderObject = tagState.context.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize ||
          renderObject.size.height <= 0) {
        continue;
      }
      final top = renderObject
          .localToGlobal(Offset.zero, ancestor: viewport)
          .dy;
      final bottom = top + renderObject.size.height;
      if (bottom <= 0 || top >= viewport.size.height) continue;
      final distance = ((top + bottom) / 2 - viewportCenter).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        final isStreaming = tagState.widget.key == _streamingEntryKey;
        best = _VisibleAnchor(
          key: tagState.widget.key,
          bottom: _sliverChildBottomInViewport(renderObject) ?? bottom,
          streamingHeight: isStreaming ? _streamingRowHeight : null,
        );
      }
    }
    return best;
  }

  void _scheduleAnchorMeasurement() {
    if (_anchorMeasurementScheduled) return;
    _anchorMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorMeasurementScheduled = false;
      if (!mounted || !widget.scrollController.hasClients) return;
      _measuredResizeAnchor = widget.isReadingHistory
          ? _measureVisibleAnchor()
          : null;
      _measuredResizeOffset = widget.scrollController.offset;
    });
  }

  void _captureResizeAnchor() {
    final anchor = _measuredResizeAnchor;
    if (anchor == null ||
        _anchorCorrectionScheduled ||
        !widget.isReadingHistory ||
        !widget.scrollController.hasClients ||
        widget.scrollController.isAutoScrolling ||
        widget.scrollController.position.isScrollingNotifier.value) {
      return;
    }
    // Read only the cached geometry here. RenderBox sizes may not be read from
    // an unrelated ancestor's layout pass (and may already be partially new).
    _pendingAnchor = _VisibleAnchor(
      key: anchor.key,
      bottom:
          anchor.bottom +
          widget.scrollController.offset -
          _measuredResizeOffset,
    );
    _anchorCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreVisibleAnchor(),
    );
  }

  void _restoreVisibleAnchor() {
    _anchorCorrectionScheduled = false;
    final anchor = _pendingAnchor;
    _pendingAnchor = null;
    if (!mounted ||
        anchor == null ||
        !widget.isReadingHistory ||
        !widget.scrollController.hasClients ||
        widget.scrollController.isAutoScrolling ||
        widget.scrollController.position.isScrollingNotifier.value) {
      return;
    }

    final correction = _anchorCorrection(anchor);
    if (correction == null) return;
    if (correction.abs() <= 0.5) return;

    final position = widget.scrollController.position;
    final target = (position.pixels + correction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    widget.scrollController.jumpTo(target);
  }

  double? _pendingAnchorCorrection() {
    if (!mounted ||
        !widget.isReadingHistory ||
        !widget.scrollController.hasClients ||
        widget.scrollController.isAutoScrolling ||
        widget.scrollController.position.isScrollingNotifier.value) {
      return null;
    }
    final anchor = _pendingAnchor;
    if (anchor == null) return null;
    final correction = _anchorCorrection(anchor);
    final currentStreamingHeight = _streamingRowHeight;
    if (correction != null &&
        anchor.streamingHeight != null &&
        currentStreamingHeight != null) {
      _pendingAnchor = _VisibleAnchor(
        key: anchor.key,
        bottom: anchor.bottom,
        streamingHeight: currentStreamingHeight,
      );
    }
    return correction;
  }

  double? _anchorCorrection(_VisibleAnchor anchor) {
    final previousStreamingHeight = anchor.streamingHeight;
    if (previousStreamingHeight != null) {
      final currentStreamingHeight = _streamingRowHeight;
      return currentStreamingHeight == null
          ? null
          : currentStreamingHeight - previousStreamingHeight;
    }

    IndexedScrollTagState? matchingState;
    for (final state in widget.scrollController.tagMap.values) {
      if (state.mounted && state.widget.key == anchor.key) {
        matchingState = state;
        break;
      }
    }
    final renderObject = matchingState?.context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final newBottom = _sliverChildBottomInViewport(renderObject);
    return newBottom == null ? null : anchor.bottom - newBottom;
  }

  /// Measures the item's trailing edge without reading a descendant's size.
  ///
  /// This is called from the viewport's layout pass. A reverse vertical sliver
  /// can derive the item's bottom from its layout offset alone, which is safe
  /// at that point; walking the regular RenderBox transform would access child
  /// sizes outside their permitted layout scope.
  double? _sliverChildBottomInViewport(RenderBox renderObject) {
    RenderObject child = renderObject;
    while (child.parent != null &&
        child.parent is! RenderSliverMultiBoxAdaptor) {
      child = child.parent!;
    }
    final sliver = child.parent;
    if (child is! RenderBox || sliver is! RenderSliverMultiBoxAdaptor) {
      return null;
    }
    final geometry = sliver.geometry;
    if (geometry == null ||
        applyGrowthDirectionToAxisDirection(
              sliver.constraints.axisDirection,
              sliver.constraints.growthDirection,
            ) !=
            AxisDirection.up) {
      return null;
    }

    final transform = Matrix4.identity();
    RenderObject current = sliver;
    while (current is! RenderViewportBase) {
      final parent = current.parent;
      if (parent == null) return null;
      parent.applyPaintTransform(current, transform);
      current = parent;
    }
    final bottomWithinSliver =
        geometry.paintExtent - sliver.childMainAxisPosition(child);
    return MatrixUtils.transformPoint(
      transform,
      Offset(0, bottomWithinSliver),
    ).dy;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  void _openFilePeek(String filePath) {
    final projectPath = widget.projectPath;
    if (projectPath == null || projectPath.isEmpty) return;
    openFilePeek(
      context,
      bridge: context.read<BridgeService>(),
      projectPath: projectPath,
      filePath: filePath,
      projectFiles: context.read<FileListCubit>().state,
      onResolvedFilePath: widget.onFilePeekOpened,
    );
  }

  @override
  Widget build(BuildContext context) {
    chatListPerformanceProbe.recordBuild();
    _notifyScrollMetricsAfterLayout();
    final chatState = context.watch<ChatSessionCubit>().state;
    final hiddenToolUseIds = chatState.hiddenToolUseIds;
    final allEntries = _displayEntries(chatState);
    final activePermissionId = switch (chatState.approval) {
      ApprovalPermission(:final toolUseId) => toolUseId,
      _ => null,
    };

    // Watch only coarse streaming flags (not the full streaming text or
    // per-second activity updates) so the list rebuilds only when row
    // visibility transitions (to adjust itemCount) and NOT on every delta or
    // elapsed-seconds tick. Streaming content and live activity text are
    // rendered inside scoped child widgets.
    final streamingFlags = context
        .select<
          StreamingStateCubit,
          ({
            bool isStreaming,
            bool hasText,
            bool hasThinking,
            bool isPreparingTool,
          })
        >(
          (cubit) => (
            isStreaming: cubit.state.isStreaming,
            hasText: cubit.state.text.isNotEmpty,
            hasThinking: cubit.state.thinking.trim().isNotEmpty,
            isPreparingTool:
                cubit.state.activity != null &&
                cubit.state.activity!.preparingTool &&
                cubit.state.activity!.toolName != null,
          ),
        );
    final showThinking = _effectiveDisplayFilter.thinking;
    final hasVisibleThinking = showThinking && streamingFlags.hasThinking;
    final hasStreaming =
        streamingFlags.isStreaming &&
        (streamingFlags.hasText || hasVisibleThinking);
    final derivedData = _deriveData(
      chatState,
      allEntries,
      activePermissionId: activePermissionId,
    );
    final hasApproval = chatState.approval is! ApprovalNone;
    final hasActivityBar = shouldShowLiveAgentActivityBar(
      status: chatState.status,
      hasApproval: hasApproval,
      isPreparingTool: streamingFlags.isPreparingTool,
      hasStreamingText: streamingFlags.hasText,
      hasThinkingText: hasVisibleThinking,
    );
    final totalCount =
        allEntries.length + (hasStreaming ? 1 : 0) + (hasActivityBar ? 1 : 0);
    final entryKeys = _entryKeys(allEntries);
    if (!_wasStreaming && hasStreaming) {
      _streamingStartEntryCount = allEntries.length;
    } else if (_wasStreaming && !hasStreaming) {
      final lowerBound = _streamingStartEntryCount.clamp(0, allEntries.length);
      for (var i = allEntries.length - 1; i >= lowerBound; i--) {
        final entry = allEntries[i];
        if (entry is UserChatEntry) break;
        if (entry is ServerChatEntry &&
            entry.message is AssistantServerMessage &&
            (entry.message as AssistantServerMessage).message.content.any(
              (c) => c is TextContent,
            )) {
          _handedOffDocIds[entryKeys[i]] = 'streaming_turn_$_streamingTurnId';
          break;
        }
      }
      _streamingTurnId++;
    }
    _wasStreaming = hasStreaming;
    final streamingDocumentId = 'streaming_turn_$_streamingTurnId';
    final obscuredBottom = FloatingComposerStatus.obscuredBottomOf(context);
    final childIndexByEntryKey = <String, int>{
      for (var entryIndex = 0; entryIndex < allEntries.length; entryIndex++)
        entryKeys[entryIndex]: totalCount - 1 - entryIndex,
      if (hasStreaming) 'streaming': totalCount - 1 - allEntries.length,
      if (hasActivityBar) 'agent_activity_bar': 0,
    };
    final effectiveHiddenToolUseIds = {
      ...hiddenToolUseIds,
      ...derivedData.completedGeneratedImageToolUseIds,
      ...derivedData.redundantFileChangeToolUseIds,
    };

    return MultiBlocListener(
      listeners: [
        BlocListener<ChatSessionCubit, ChatSessionState>(
          listener: (_, _) => _captureVisibleAnchor(),
        ),
        BlocListener<StreamingStateCubit, StreamingState>(
          listenWhen: (previous, current) =>
              previous.isStreaming != current.isStreaming ||
              previous.text != current.text ||
              previous.thinking != current.thinking ||
              (previous.activity?.preparingTool == true &&
                      previous.activity?.toolName != null) !=
                  (current.activity?.preparingTool == true &&
                      current.activity?.toolName != null),
          listener: (_, _) => _captureVisibleAnchor(),
        ),
      ],
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          widget.onScrollMetricsChanged?.call();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Only unfocus when user drags the list (not programmatic scroll),
            // and only to dismiss the keyboard: a message's text selection
            // also holds focus, and unfocusing it would clear the selection.
            // A composer floating above an iPad floating keyboard keeps
            // the keyboard while the chat scrolls (closed by tapping the
            // chat or swiping the composer down instead).
            if (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle &&
                !isDesktopPlatform &&
                isEditableTextFocused() &&
                !FloatingComposerStatus.isFloatingOf(context)) {
              FocusScope.of(context).unfocus();
            }
            return false;
          },
          child: _ViewportResizeObserver(
            onBeforeResize: _captureResizeAnchor,
            onAfterLayout: _scheduleAnchorMeasurement,
            child: SizedBox(
              key: _viewportKey,
              child: CcpocketSelectionScope(
                controller: _selectionController,
                allowCrossDocumentSelection: false,
                isPlainTextDocument: (id) =>
                    id.startsWith('user_') || id.startsWith('plain:'),
                autoscroll: MarkdownSelectionAutoscrollConfig(
                  bottomPad: widget.bottomPadding + obscuredBottom,
                  useHostUnionGate: false,
                ),
                child: ListView.builder(
                  controller: widget.scrollController,
                  reverse: true,
                  physics: MaintainReadingPositionOnResizePhysics(
                    shouldMaintain: () => widget.isReadingHistory,
                  ),
                  // Reach the newest message above the frosted composer while
                  // older ones scroll behind it.
                  padding: EdgeInsets.only(
                    top: 36,
                    bottom: widget.bottomPadding + obscuredBottom,
                  ),
                  itemCount: totalCount,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    return childIndexByEntryKey[key.value];
                  },
                  itemBuilder: (context, index) {
                    // index 0 = newest entry (bottom of chat)
                    // Map to actual entry index:
                    final entryIndex = totalCount - 1 - index;

                    // Live activity row sits at the very bottom (index 0 in reverse)
                    if (hasActivityBar && entryIndex == totalCount - 1) {
                      return _AgentActivityBar(
                        key: const ValueKey<String>('agent_activity_bar'),
                        status: chatState.status,
                        hasApproval: hasApproval,
                        incompleteTool: derivedData.latestIncompleteToolUse,
                        hasStreamingText: streamingFlags.hasText,
                        hasThinkingText: hasVisibleThinking,
                      );
                    }

                    // Streaming entry sits just above the activity bar (or at index 0)
                    if (hasStreaming && entryIndex == allEntries.length) {
                      // Scoped BlocBuilder: only this widget rebuilds on streaming deltas
                      return IndexedScrollTag(
                        key: _streamingEntryKey,
                        controller: widget.scrollController,
                        index: entryIndex,
                        child: _LayoutSizeReporter(
                          onLayout: (size) => _streamingRowHeight = size.height,
                          child:
                              BlocBuilder<StreamingStateCubit, StreamingState>(
                                builder: (context, streamingState) {
                                  if (!streamingState.isStreaming) {
                                    return const SizedBox.shrink();
                                  }
                                  return ChatEntryWidget(
                                    entry: StreamingChatEntry(
                                      text: streamingState.text,
                                      thinking: showThinking
                                          ? streamingState.thinking
                                          : '',
                                    ),
                                    previous: null,
                                    httpBaseUrl: widget.httpBaseUrl,
                                    onRetryMessage: null,
                                    collapseToolResults: null,
                                    hiddenToolUseIds: const {},
                                    isCodex: widget.isCodex,
                                    onFileTap: _openFilePeek,
                                    onBeforeStreamingTextUpdate:
                                        _captureVisibleAnchor,
                                    documentId: streamingDocumentId,
                                    documentOrder: allEntries.length * 100,
                                  );
                                },
                              ),
                        ),
                      );
                    }

                    final entry = allEntries[entryIndex];
                    final previous = entryIndex > 0
                        ? allEntries[entryIndex - 1]
                        : null;
                    final onForkMessage =
                        widget.onForkMessage != null &&
                            derivedData.forkableAssistantEntryIndices.contains(
                              entryIndex,
                            )
                        ? widget.onForkMessage
                        : null;

                    final imageItems =
                        derivedData.imageItemsByAnchor[entryIndex];
                    final Widget child;
                    if (imageItems != null) {
                      child = GeneratedImageChatGroup(items: imageItems);
                    } else if (derivedData.imageGroupMemberIndices.contains(
                      entryIndex,
                    )) {
                      child = const SizedBox.shrink();
                    } else if (entry
                        case ServerChatEntry(
                          message: final ToolResultMessage result,
                        )
                        when derivedData.permissionTranscriptStatuses
                                .containsKey(result.toolUseId) &&
                            isSyntheticPermissionOutcome(result)) {
                      child = const SizedBox.shrink();
                    } else if (derivedData.intermediateResultEntryIndices
                            .contains(entryIndex) &&
                        // Keep a result whose text is not shown anywhere else.
                        !derivedData.successResultFallbackEntryIndices.contains(
                          entryIndex,
                        )) {
                      child = const SizedBox.shrink();
                    } else {
                      final permissionTranscriptStatus = switch (entry) {
                        ServerChatEntry(
                          message: PermissionRequestMessage(:final toolUseId),
                        ) =>
                          derivedData.permissionTranscriptStatuses[toolUseId],
                        _ => null,
                      };
                      child = ChatEntryWidget(
                        entry: entry,
                        previous: previous,
                        httpBaseUrl: widget.httpBaseUrl,
                        onRetryMessage: widget.onRetryMessage,
                        onRewindMessage: widget.onRewindMessage,
                        onEditMessage: widget.onEditMessage,
                        onRestoreFilesMessage: widget.onRestoreFilesMessage,
                        onForkMessage: onForkMessage,
                        collapseToolResults: widget.collapseToolResults,
                        resolvedPlanText: _hasExitPlanMode(entry)
                            ? derivedData.latestPlanText
                            : null,
                        showSuccessResultText: derivedData
                            .successResultFallbackEntryIndices
                            .contains(entryIndex),
                        permissionTranscriptStatus: permissionTranscriptStatus,
                        hiddenToolUseIds: effectiveHiddenToolUseIds,
                        onOpenTranscript: _openTranscript,
                        onFileTap: _openFilePeek,
                        onImageTap: (user) {
                          final claudeSessionId = context
                              .read<ChatSessionCubit>()
                              .state
                              .claudeSessionId;
                          final httpBaseUrl = widget.httpBaseUrl;
                          if (claudeSessionId == null ||
                              claudeSessionId.isEmpty ||
                              httpBaseUrl == null) {
                            return;
                          }
                          final feedback = MediaFeedbackBinding.maybeOf(
                            context,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MessageImagesScreen(
                                feedback: feedback,
                                bridge: context.read<BridgeService>(),
                                httpBaseUrl: httpBaseUrl,
                                claudeSessionId: claudeSessionId,
                                messageUuid: user.messageUuid!,
                                imageCount: user.imageCount,
                              ),
                            ),
                          );
                        },
                        isCodex: widget.isCodex,
                        documentId:
                            _handedOffDocIds[entryKeys[entryIndex]] ??
                            entryKeys[entryIndex],
                        documentOrder: entryIndex * 100,
                      );
                    }
                    // Wrap with IndexedScrollTag for scroll-to-index support.
                    // Use entryIndex (not reverse index) as the IndexedScrollTag index.
                    return IndexedScrollTag(
                      key: ValueKey(entryKeys[entryIndex]),
                      controller: widget.scrollController,
                      index: entryIndex,
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ChatListDerivedData _deriveData(
    ChatSessionState chatState,
    List<ChatEntry> entries, {
    required String? activePermissionId,
  }) {
    final cached = _derivedData;
    if (_derivedForHttpBaseUrl == widget.httpBaseUrl && cached != null) {
      if (identical(_derivedForState, chatState)) return cached;
      final previousEntries = _derivedEntries;
      if (previousEntries != null &&
          listEquals(previousEntries, entries) &&
          listEquals(_derivedSourceEntries, chatState.entries) &&
          _derivedForProcessStatus == chatState.status &&
          _derivedForBackgroundAgentsActive == chatState.hasBackgroundAgents &&
          _derivedForActivePermissionId == activePermissionId) {
        _derivedForState = chatState;
        return cached;
      }
    }

    final stopwatch = !kReleaseMode ? (Stopwatch()..start()) : null;
    final imageGroupMemberIndices = <int>{};
    final imageItemsByAnchor = <int, List<GeneratedImagePreviewItem>>{};
    for (final group in groupGeneratedImageResponses(entries)) {
      final items = generatedImageItemsFromToolResults(
        group.messages,
        httpBaseUrl: widget.httpBaseUrl,
        itemCache: _generatedImageItemCache,
      );
      if (items.isEmpty) continue;
      imageItemsByAnchor[group.anchorEntryIndex] = items;
      imageGroupMemberIndices.addAll(group.memberEntryIndices);
    }
    final next = _ChatListDerivedData(
      imageGroupMemberIndices: imageGroupMemberIndices,
      imageItemsByAnchor: imageItemsByAnchor,
      completedGeneratedImageToolUseIds: completedGeneratedImageToolUseIds(
        entries,
      ),
      redundantFileChangeToolUseIds: redundantFileChangeToolUseIds(entries),
      forkableAssistantEntryIndices: forkableAssistantEntryIndices(entries),
      successResultFallbackEntryIndices: successResultFallbackEntryIndices(
        entries,
      ),
      intermediateResultEntryIndices: widget.isCodex
          ? const <int>{}
          : intermediateResultEntryIndices(
              entries,
              backgroundAgentsActive: chatState.hasBackgroundAgents,
            ),
      permissionTranscriptStatuses: derivePermissionTranscriptStatuses(
        chatState.entries,
        processStatus: chatState.status,
        activeToolUseId: activePermissionId,
      ),
      latestPlanText: _findPlanFromWriteTool(chatState.entries),
      latestIncompleteToolUse: findLatestIncompleteToolUse(chatState.entries),
    );
    _derivedForState = chatState;
    _derivedEntries = entries;
    _derivedSourceEntries = chatState.entries;
    _derivedForHttpBaseUrl = widget.httpBaseUrl;
    _derivedForProcessStatus = chatState.status;
    _derivedForBackgroundAgentsActive = chatState.hasBackgroundAgents;
    _derivedForActivePermissionId = activePermissionId;
    _derivedData = next;
    stopwatch?.stop();
    if (stopwatch != null) {
      chatListPerformanceProbe.recordDerivedData(stopwatch.elapsed);
    }
    return next;
  }

  bool _hasExitPlanMode(ChatEntry entry) {
    return entry is ServerChatEntry &&
        entry.message is AssistantServerMessage &&
        (entry.message as AssistantServerMessage).message.content.any(
          (content) =>
              content is ToolUseContent && content.name == 'ExitPlanMode',
        );
  }

  String? _findPlanFromWriteTool(List<ChatEntry> entries) {
    for (var i = entries.length - 1; i >= 0; i--) {
      final entry = entries[i];
      if (entry is! ServerChatEntry ||
          entry.message is! AssistantServerMessage) {
        continue;
      }
      final message = entry.message as AssistantServerMessage;
      for (final content in message.message.content) {
        if (content is! ToolUseContent || content.name != 'Write') continue;
        final filePath = content.input['file_path']?.toString() ?? '';
        if (!filePath.contains('.claude/plans/')) continue;
        final plan = content.input['content']?.toString();
        if (plan != null && plan.isNotEmpty) return plan;
      }
    }
    return null;
  }

  List<String> _entryKeys(List<ChatEntry> entries) {
    final occurrenceByBase = <String, int>{};
    return entries.map((entry) {
      final base = _entryKeyBase(entry);
      final occurrence = occurrenceByBase.update(
        base,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      return '$base:$occurrence';
    }).toList();
  }

  String _entryKeyBase(ChatEntry entry) {
    return switch (entry) {
      ServerChatEntry(:final message) => switch (message) {
        final ToolResultMessage result
            when isSyntheticPermissionOutcome(result) =>
          'permission_outcome:${result.toolUseId}:${result.content.trim()}',
        ToolResultMessage(:final toolUseId) => 'tool_result:$toolUseId',
        AssistantServerMessage(:final messageUuid, :final message) =>
          messageUuid != null && messageUuid.isNotEmpty
              ? 'assistant_uuid:$messageUuid'
              : message.id.isNotEmpty
              ? 'assistant_id:${message.id}'
              : 'assistant_content:${_assistantContentKey(message.content)}',
        PermissionRequestMessage(:final toolUseId) => 'permission:$toolUseId',
        ToolUseSummaryMessage(:final summary, :final precedingToolUseIds) =>
          'tool_summary:$summary:${precedingToolUseIds.join(',')}',
        ResultMessage(:final subtype, :final sessionId, :final result) =>
          'result:$subtype:$sessionId:$result',
        ErrorMessage(:final errorCode, :final message) =>
          'error:$errorCode:$message',
        GuardianApprovalMessage(:final risk, :final reason) =>
          'guardian:$risk:$reason',
        StatusMessage(:final status) => 'status:$status',
        SystemMessage(:final subtype, :final tipCode) =>
          'system:$subtype:$tipCode',
        SessionRecapMessage(:final content) => 'recap:$content',
        _ => '${message.runtimeType}',
      },
      QuestionAnswerChatEntry(:final toolUseId) => 'question_answer:$toolUseId',
      UserChatEntry(
        :final messageUuid,
        :final clientMessageId,
        :final text,
        :final imageUrls,
        :final imageCount,
      ) =>
        clientMessageId != null && clientMessageId.isNotEmpty
            ? 'user_client:$clientMessageId'
            : messageUuid != null && messageUuid.isNotEmpty
            ? 'user_uuid:$messageUuid'
            : 'user_content:${Object.hash(text, Object.hashAll(imageUrls), imageCount)}',
      StreamingChatEntry() => 'streaming',
    };
  }

  int _assistantContentKey(List<AssistantContent> contents) {
    final signature = contents
        .map((content) {
          return switch (content) {
            TextContent(:final text) => 'text:$text',
            ThinkingContent(:final thinking) => 'thinking:$thinking',
            ToolUseContent(:final id, :final name, :final input) =>
              'tool:$id:$name:${jsonEncode(input)}',
          };
        })
        .join('|');
    return signature.hashCode;
  }
}

class _VisibleAnchor {
  final Key? key;
  final double bottom;
  final double? streamingHeight;

  const _VisibleAnchor({
    required this.key,
    required this.bottom,
    this.streamingHeight,
  });
}

class _LayoutSizeReporter extends SingleChildRenderObjectWidget {
  const _LayoutSizeReporter({required this.onLayout, required super.child});

  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutSizeReporterRenderBox(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _LayoutSizeReporterRenderBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _LayoutSizeReporterRenderBox extends RenderProxyBox {
  _LayoutSizeReporterRenderBox(this.onLayout);

  ValueChanged<Size> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size);
  }
}

class _ChatListDerivedData {
  final Set<int> imageGroupMemberIndices;
  final Map<int, List<GeneratedImagePreviewItem>> imageItemsByAnchor;
  final Set<String> completedGeneratedImageToolUseIds;
  final Set<String> redundantFileChangeToolUseIds;
  final Set<int> forkableAssistantEntryIndices;
  final Set<int> successResultFallbackEntryIndices;
  final Set<int> intermediateResultEntryIndices;
  final Map<String, PermissionTranscriptStatus> permissionTranscriptStatuses;
  final String? latestPlanText;
  final ToolUseContent? latestIncompleteToolUse;

  const _ChatListDerivedData({
    required this.imageGroupMemberIndices,
    required this.imageItemsByAnchor,
    required this.completedGeneratedImageToolUseIds,
    required this.redundantFileChangeToolUseIds,
    required this.forkableAssistantEntryIndices,
    required this.successResultFallbackEntryIndices,
    required this.intermediateResultEntryIndices,
    required this.permissionTranscriptStatuses,
    required this.latestPlanText,
    required this.latestIncompleteToolUse,
  });
}

class _AgentActivityBar extends StatelessWidget {
  final ProcessStatus status;
  final bool hasApproval;
  final ToolUseContent? incompleteTool;
  final bool hasStreamingText;
  final bool hasThinkingText;

  const _AgentActivityBar({
    super.key,
    required this.status,
    required this.hasApproval,
    required this.incompleteTool,
    required this.hasStreamingText,
    required this.hasThinkingText,
  });

  @override
  Widget build(BuildContext context) {
    final activity = context.select<StreamingStateCubit, AgentActivityInfo?>(
      (cubit) => cubit.state.activity,
    );
    final label = resolveLiveAgentActivityLabel(
      status: status,
      hasApproval: hasApproval,
      incompleteTool: incompleteTool,
      activity: activity,
      hasStreamingText: hasStreamingText,
      hasThinkingText: hasThinkingText,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }

    final appColors = Theme.of(context).extension<AppColors>()!;
    final color = appColors.subtleText;
    final staticSpinner =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 6,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              value: staticSpinner ? 0.7 : null,
              strokeWidth: 1.8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Captures the old, measured message before a resize changes line wrapping.
/// This surface stays at the same element position in every pane layout.
class _ViewportResizeObserver extends SingleChildRenderObjectWidget {
  const _ViewportResizeObserver({
    required this.onBeforeResize,
    required this.onAfterLayout,
    required super.child,
  });
  final VoidCallback onBeforeResize;
  final VoidCallback onAfterLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ViewportResizeRenderBox(onBeforeResize, onAfterLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    _ViewportResizeRenderBox renderObject,
  ) {
    renderObject.onBeforeResize = onBeforeResize;
    renderObject.onAfterLayout = onAfterLayout;
  }
}

class _ViewportResizeRenderBox extends RenderProxyBox {
  _ViewportResizeRenderBox(this.onBeforeResize, this.onAfterLayout);
  VoidCallback onBeforeResize;
  VoidCallback onAfterLayout;
  BoxConstraints? _previousConstraints;
  @override
  void performLayout() {
    if (_previousConstraints != null && _previousConstraints != constraints) {
      onBeforeResize();
    }
    _previousConstraints = constraints;
    super.performLayout();
    onAfterLayout();
  }
}

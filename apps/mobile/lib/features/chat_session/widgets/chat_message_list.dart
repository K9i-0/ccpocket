import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../widgets/message_bubble.dart';
import '../../message_images/message_images_screen.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';
import '../state/streaming_state.dart';
import '../state/streaming_state_cubit.dart';

/// Displays the chat message list with [AnimatedList] animations.
///
/// Owns the entry reconciliation logic that syncs the cubit's
/// `state.entries` (SSOT) with a local mutable list for [AnimatedList]'s
/// imperative API ([insertItem]/[removeItem]).
class ChatMessageList extends StatefulWidget {
  final String sessionId;
  final AutoScrollController scrollController;
  final String? httpBaseUrl;
  final void Function(UserChatEntry)? onRetryMessage;
  final void Function(UserChatEntry)? onRewindMessage;
  final ValueNotifier<int>? collapseToolResults;
  final ValueNotifier<String?>? editedPlanText;
  final bool allowPlanEditing;
  final String? pendingPlanToolUseId;
  final VoidCallback? onScrollToBottom;

  /// When set (non-null), the list scrolls to the given [UserChatEntry].
  /// The notifier is reset to null after scrolling.
  final ValueNotifier<UserChatEntry?>? scrollToUserEntry;

  const ChatMessageList({
    super.key,
    required this.sessionId,
    required this.scrollController,
    required this.httpBaseUrl,
    required this.onRetryMessage,
    this.onRewindMessage,
    required this.collapseToolResults,
    this.editedPlanText,
    this.allowPlanEditing = true,
    this.pendingPlanToolUseId,
    this.onScrollToBottom,
    this.scrollToUserEntry,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final List<ChatEntry> _entries = [];
  final _listKey = GlobalKey<AnimatedListState>();

  /// Disables animation during initial history load.
  bool _bulkLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bulkLoading = false;
    });
    widget.scrollToUserEntry?.addListener(_onScrollToUserEntry);
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollToUserEntry != widget.scrollToUserEntry) {
      oldWidget.scrollToUserEntry?.removeListener(_onScrollToUserEntry);
      widget.scrollToUserEntry?.addListener(_onScrollToUserEntry);
    }
  }

  @override
  void dispose() {
    widget.scrollToUserEntry?.removeListener(_onScrollToUserEntry);
    super.dispose();
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
  /// Uses [AutoScrollController.scrollToIndex] which handles both on-screen
  /// and off-screen items correctly with variable-height widgets.
  void _scrollToUserEntry(UserChatEntry entry) {
    final idx = _entries.indexOf(entry);
    if (idx < 0) return;
    widget.scrollController.scrollToIndex(
      idx,
      preferPosition: AutoScrollPosition.middle,
      duration: const Duration(milliseconds: 300),
    );
  }

  // ---------------------------------------------------------------------------
  // Entry reconciliation (AnimatedList ↔ cubit state)
  // ---------------------------------------------------------------------------

  /// Reconcile [_entries] with cubit entries.
  ///
  /// Handles three mutation patterns:
  /// 1. Append: new entries added at end (first element identical)
  /// 2. Prepend: history loaded at start (first element changed)
  /// 3. In-place update: same length (e.g., user message status change)
  void _reconcileEntries(
    List<ChatEntry> oldEntries,
    List<ChatEntry> newEntries,
  ) {
    if (identical(oldEntries, newEntries)) return;

    // Temporarily remove streaming entry if present
    final hasStreaming =
        _entries.isNotEmpty && _entries.last is StreamingChatEntry;
    StreamingChatEntry? streamingEntry;
    if (hasStreaming) {
      streamingEntry = _entries.removeLast() as StreamingChatEntry;
    }

    final oldLen = _entries.length;
    final newLen = newEntries.length;
    final diff = newLen - oldLen;

    if (diff > 0) {
      if (oldLen > 0 && identical(newEntries[0], oldEntries[0])) {
        // Append: update existing entries, then add new ones
        for (var i = 0; i < oldLen; i++) {
          _entries[i] = newEntries[i];
        }
        for (var i = oldLen; i < newLen; i++) {
          _entries.add(newEntries[i]);
          _listKey.currentState?.insertItem(
            _entries.length - 1,
            duration: _bulkLoading
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
        }
      } else {
        // Prepend: insert at beginning, then update shifted entries
        _entries.insertAll(0, newEntries.sublist(0, diff));
        for (var i = 0; i < diff; i++) {
          _listKey.currentState?.insertItem(i, duration: Duration.zero);
        }
        for (var i = diff; i < newLen; i++) {
          _entries[i] = newEntries[i];
        }
      }
    } else {
      // In-place update (same length or shrink)
      for (var i = 0; i < newLen && i < _entries.length; i++) {
        _entries[i] = newEntries[i];
      }
      // Remove excess entries when the list shrinks (e.g. replaceEntries
      // produced fewer entries than currently displayed).
      while (_entries.length > newLen) {
        final idx = _entries.length - 1;
        _entries.removeAt(idx);
        _listKey.currentState?.removeItem(
          idx,
          (context, animation) => const SizedBox.shrink(),
          duration: Duration.zero,
        );
      }
    }

    // Restore streaming entry
    if (streamingEntry != null) {
      _entries.add(streamingEntry);
    }

    setState(() {});
    widget.onScrollToBottom?.call();
  }

  // ---------------------------------------------------------------------------
  // Streaming entry management
  // ---------------------------------------------------------------------------

  void _onStreamingStateChange(StreamingState? prev, StreamingState next) {
    final wasStreaming = prev?.isStreaming ?? false;

    if (next.isStreaming) {
      if (_entries.isNotEmpty && _entries.last is StreamingChatEntry) {
        // Update existing streaming entry in place
        _entries[_entries.length - 1] = StreamingChatEntry(text: next.text);
      } else {
        // Add new streaming entry
        _entries.add(StreamingChatEntry(text: next.text));
        _listKey.currentState?.insertItem(
          _entries.length - 1,
          duration: Duration.zero,
        );
      }
      setState(() {});
      widget.onScrollToBottom?.call();
    } else if (wasStreaming && !next.isStreaming) {
      // Streaming ended → remove streaming entry
      if (_entries.isNotEmpty && _entries.last is StreamingChatEntry) {
        final idx = _entries.length - 1;
        _entries.removeAt(idx);
        _listKey.currentState?.removeItem(
          idx,
          (_, _) => const SizedBox.shrink(),
          duration: Duration.zero,
        );
        setState(() {});
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Plan text resolution
  // ---------------------------------------------------------------------------

  /// For entries with ExitPlanMode, search all entries for a Write tool
  /// targeting `.claude/plans/` to resolve the plan text.
  String? _resolvePlanText(ChatEntry entry) {
    if (entry is! ServerChatEntry) return null;
    final msg = entry.message;
    if (msg is! AssistantServerMessage) return null;
    final hasExitPlan = msg.message.content.any(
      (c) => c is ToolUseContent && c.name == 'ExitPlanMode',
    );
    if (!hasExitPlan) return null;
    return _findPlanFromWriteTool();
  }

  /// Search all entries in reverse for a Write tool targeting `.claude/plans/`.
  String? _findPlanFromWriteTool() {
    for (var i = _entries.length - 1; i >= 0; i--) {
      final entry = _entries[i];
      if (entry is! ServerChatEntry) continue;
      final msg = entry.message;
      if (msg is! AssistantServerMessage) continue;
      for (final c in msg.message.content) {
        if (c is! ToolUseContent || c.name != 'Write') continue;
        final filePath = c.input['file_path']?.toString() ?? '';
        if (!filePath.contains('.claude/plans/')) continue;
        final content = c.input['content']?.toString();
        if (content != null && content.isNotEmpty) return content;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatSessionCubit>().state;
    // Get hidden tool use IDs for subagent compression
    final hiddenToolUseIds = chatState.hiddenToolUseIds;

    return MultiBlocListener(
      listeners: [
        // Listen to entries changes → reconcile with AnimatedList
        BlocListener<ChatSessionCubit, ChatSessionState>(
          listenWhen: (prev, next) => !identical(prev.entries, next.entries),
          listener: (context, state) {
            // We need old entries for reconciliation — use _entries.length as proxy
            _reconcileEntries(
              _entries.toList(), // snapshot of current local entries
              state.entries,
            );
          },
        ),
        // Listen to streaming state separately (high-frequency updates)
        BlocListener<StreamingStateCubit, StreamingState>(
          listener: (context, state) {
            // We need previous state — track it manually
            _onStreamingStateChange(_prevStreamingState, state);
            _prevStreamingState = state;
          },
        ),
      ],
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Only unfocus when user drags the list (not programmatic scroll).
          // This prevents the keyboard from being dismissed during automatic
          // scroll-to-bottom triggered by streaming updates.
          if (notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: AnimatedList(
          key: _listKey,
          controller: widget.scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          initialItemCount: _entries.length,
          itemBuilder: (context, index, animation) {
            final entry = _entries[index];
            final previous = index > 0 ? _entries[index - 1] : null;
            Widget child = ChatEntryWidget(
              entry: entry,
              previous: previous,
              httpBaseUrl: widget.httpBaseUrl,
              onRetryMessage: widget.onRetryMessage,
              onRewindMessage: widget.onRewindMessage,
              collapseToolResults: widget.collapseToolResults,
              editedPlanText: widget.editedPlanText,
              resolvedPlanText: _resolvePlanText(entry),
              allowPlanEditing: widget.allowPlanEditing,
              pendingPlanToolUseId: widget.pendingPlanToolUseId,
              hiddenToolUseIds: hiddenToolUseIds,
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
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MessageImagesScreen(
                      bridge: context.read<BridgeService>(),
                      httpBaseUrl: httpBaseUrl,
                      claudeSessionId: claudeSessionId,
                      messageUuid: user.messageUuid!,
                      imageCount: user.imageCount,
                    ),
                  ),
                );
              },
            );
            // Wrap with AutoScrollTag for scroll-to-index support
            child = AutoScrollTag(
              key: ValueKey(_entryKey(entry, index)),
              controller: widget.scrollController,
              index: index,
              child: child,
            );
            if (_bulkLoading || animation.isCompleted) return child;
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        ),
      ),
    );
  }

  StreamingState? _prevStreamingState;

  String _entryKey(ChatEntry entry, int index) {
    return switch (entry) {
      ServerChatEntry(:final message) => switch (message) {
        ToolResultMessage(:final toolUseId) => 'tool_result:$toolUseId',
        AssistantServerMessage(:final messageUuid, :final message) =>
          messageUuid != null && messageUuid.isNotEmpty
              ? 'assistant_uuid:$messageUuid'
              : message.id.isNotEmpty
              ? 'assistant_id:${message.id}'
              : 'assistant_ts:${entry.timestamp.microsecondsSinceEpoch}:$index',
        PermissionRequestMessage(:final toolUseId) => 'permission:$toolUseId',
        ToolUseSummaryMessage() =>
          'tool_summary:${entry.timestamp.microsecondsSinceEpoch}:$index',
        _ =>
          '${message.runtimeType}:${entry.timestamp.microsecondsSinceEpoch}:$index',
      },
      UserChatEntry(:final messageUuid, :final text) =>
        messageUuid != null && messageUuid.isNotEmpty
            ? 'user_uuid:$messageUuid'
            : 'user_ts:${entry.timestamp.microsecondsSinceEpoch}:${text.hashCode}:$index',
      StreamingChatEntry() => 'streaming',
    };
  }
}

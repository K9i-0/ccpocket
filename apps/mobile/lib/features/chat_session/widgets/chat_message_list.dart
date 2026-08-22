import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        RenderBox,
        RenderSliverMultiBoxAdaptor,
        RenderViewportBase,
        ScrollDirection,
        applyGrowthDirectionToAxisDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../models/messages.dart';
import '../../../providers/bridge_cubits.dart';
import '../../../services/bridge_service.dart';
import '../../../services/performance_probe_extension.dart';
import '../../../widgets/message_bubble.dart';
import '../../generated_image_preview/generated_image_preview_mapper.dart';
import '../../generated_image_preview/generated_image_preview_item.dart';
import '../../generated_image_preview/generated_image_response_grouping.dart';
import '../../generated_image_preview/widgets/generated_image_chat_group.dart';
import '../../file_peek/file_peek_sheet.dart';
import '../../message_images/message_images_screen.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';
import '../state/streaming_state.dart';
import '../state/streaming_state_cubit.dart';
import 'anchor_maintaining_auto_scroll_controller.dart';
import 'maintain_reading_position_physics.dart';

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
    final visibleTexts = includeTrailingAssistants
        ? [...pending.assistantTexts, ...assistantTexts]
        : pending.assistantTexts;
    if (!isAlreadyShown(pending.text, visibleTexts)) {
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

/// Displays the chat message list with [ListView.builder] (reverse: true).
///
/// Reads entries directly from [ChatSessionCubit] state (SSOT).
/// With reverse list, offset 0 = bottom of chat, so new messages appear
/// immediately without scroll adjustment, and history prepend does not
/// shift the viewport.
class ChatMessageList extends StatefulWidget {
  final String sessionId;
  final AutoScrollController scrollController;
  final String? httpBaseUrl;
  final void Function(UserChatEntry)? onRetryMessage;
  final void Function(UserChatEntry)? onRewindMessage;
  final void Function(AssistantServerMessage)? onForkMessage;
  final ValueNotifier<int>? collapseToolResults;
  final double bottomPadding;
  final bool isCodex;
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
    this.onForkMessage,
    required this.collapseToolResults,
    this.scrollToUserEntry,
    this.onScrollMetricsChanged,
    this.bottomPadding = 8,
    this.projectPath,
    this.isCodex = false,
    this.isReadingHistory = false,
    this.onFilePeekOpened,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _viewportKey = GlobalKey();
  final _generatedImageItemCache =
      <GeneratedImageItemCacheKey, GeneratedImagePreviewItem>{};
  ChatSessionState? _derivedForState;
  List<ChatEntry>? _derivedEntries;
  String? _derivedForHttpBaseUrl;
  _ChatListDerivedData? _derivedData;
  _VisibleAnchor? _pendingAnchor;
  bool _anchorCorrectionScheduled = false;
  bool _metricsNotificationScheduled = false;

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
    widget.scrollToUserEntry?.addListener(_onScrollToUserEntry);
    _attachLayoutAnchorCorrection();
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _detachLayoutAnchorCorrection(widget.scrollController);
    widget.scrollToUserEntry?.removeListener(_onScrollToUserEntry);
    super.dispose();
  }

  void _attachLayoutAnchorCorrection() {
    final controller = widget.scrollController;
    if (controller is AnchorMaintainingAutoScrollController) {
      controller.layoutAnchorCorrection = _pendingAnchorCorrection;
    }
  }

  void _detachLayoutAnchorCorrection(AutoScrollController controller) {
    if (controller is AnchorMaintainingAutoScrollController) {
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
  /// Uses [AutoScrollController.scrollToIndex] which handles both on-screen
  /// and off-screen items correctly with variable-height widgets.
  void _scrollToUserEntry(UserChatEntry entry) {
    final entries = context.read<ChatSessionCubit>().state.entries;
    final idx = entries.indexOf(entry);
    if (idx < 0) return;
    widget.scrollController.scrollToIndex(
      idx,
      preferPosition: AutoScrollPosition.middle,
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
        widget.scrollController.position.isScrollingNotifier.value ||
        _anchorCorrectionScheduled) {
      return;
    }

    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached || !viewport.hasSize) return;

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
        best = _VisibleAnchor(
          key: tagState.widget.key,
          bottom: _sliverChildBottomInViewport(renderObject) ?? bottom,
        );
      }
    }
    if (best == null) return;

    _pendingAnchor = best;
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
    return anchor == null ? null : _anchorCorrection(anchor);
  }

  double? _anchorCorrection(_VisibleAnchor anchor) {
    AutoScrollTagState? matchingState;
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

  @override
  Widget build(BuildContext context) {
    chatListPerformanceProbe.recordBuild();
    _notifyScrollMetricsAfterLayout();
    final chatState = context.watch<ChatSessionCubit>().state;
    final hiddenToolUseIds = chatState.hiddenToolUseIds;
    final allEntries = chatState.entries;

    // Watch only the isStreaming flag (not the full streaming text) so the
    // list rebuilds when streaming starts/stops (to adjust itemCount) but NOT
    // on every text delta. The actual streaming text is rendered inside a
    // scoped BlocBuilder on the streaming item only.
    final hasStreaming = context.select<StreamingStateCubit, bool>(
      (cubit) => cubit.state.isStreaming,
    );
    final totalCount = allEntries.length + (hasStreaming ? 1 : 0);
    final entryKeys = _entryKeys(allEntries);
    final childIndexByEntryKey = <String, int>{
      for (var entryIndex = 0; entryIndex < allEntries.length; entryIndex++)
        entryKeys[entryIndex]: totalCount - 1 - entryIndex,
    };
    final derivedData = _deriveData(chatState, allEntries);
    final effectiveHiddenToolUseIds = {
      ...hiddenToolUseIds,
      ...derivedData.completedGeneratedImageToolUseIds,
    };

    return MultiBlocListener(
      listeners: [
        BlocListener<ChatSessionCubit, ChatSessionState>(
          listener: (_, _) => _captureVisibleAnchor(),
        ),
        BlocListener<StreamingStateCubit, StreamingState>(
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
            // Only unfocus when user drags the list (not programmatic scroll).
            if (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle) {
              FocusScope.of(context).unfocus();
            }
            return false;
          },
          child: SizedBox(
            key: _viewportKey,
            child: ListView.builder(
              controller: widget.scrollController,
              reverse: true,
              physics: MaintainReadingPositionOnResizePhysics(
                shouldMaintain: () => widget.isReadingHistory,
              ),
              padding: EdgeInsets.only(top: 36, bottom: widget.bottomPadding),
              itemCount: totalCount,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                return childIndexByEntryKey[key.value];
              },
              itemBuilder: (context, index) {
                // index 0 = newest entry (bottom of chat)
                // Map to actual entry index:
                final entryIndex = totalCount - 1 - index;

                // Streaming entry is at totalCount - 1 (index 0 in reverse)
                if (hasStreaming && entryIndex == allEntries.length) {
                  // Scoped BlocBuilder: only this widget rebuilds on streaming deltas
                  return BlocBuilder<StreamingStateCubit, StreamingState>(
                    builder: (context, streamingState) {
                      if (!streamingState.isStreaming) {
                        return const SizedBox.shrink();
                      }
                      return ChatEntryWidget(
                        entry: StreamingChatEntry(text: streamingState.text),
                        previous: null,
                        httpBaseUrl: widget.httpBaseUrl,
                        onRetryMessage: null,
                        collapseToolResults: null,
                        hiddenToolUseIds: const {},
                        isCodex: widget.isCodex,
                      );
                    },
                  );
                }

                final entry = allEntries[entryIndex];
                final previous = entryIndex > 0
                    ? allEntries[entryIndex - 1]
                    : null;
                final onForkMessage =
                    widget.isCodex &&
                        derivedData.forkableAssistantEntryIndices.contains(
                          entryIndex,
                        )
                    ? widget.onForkMessage
                    : null;

                final imageItems = derivedData.imageItemsByAnchor[entryIndex];
                final Widget child;
                if (imageItems != null) {
                  child = GeneratedImageChatGroup(items: imageItems);
                } else if (derivedData.imageGroupMemberIndices.contains(
                  entryIndex,
                )) {
                  child = const SizedBox.shrink();
                } else {
                  child = ChatEntryWidget(
                    entry: entry,
                    previous: previous,
                    httpBaseUrl: widget.httpBaseUrl,
                    onRetryMessage: widget.onRetryMessage,
                    onRewindMessage: widget.onRewindMessage,
                    onForkMessage: onForkMessage,
                    collapseToolResults: widget.collapseToolResults,
                    resolvedPlanText: _hasExitPlanMode(entry)
                        ? derivedData.latestPlanText
                        : null,
                    showSuccessResultText: derivedData
                        .successResultFallbackEntryIndices
                        .contains(entryIndex),
                    hiddenToolUseIds: effectiveHiddenToolUseIds,
                    onFileTap: (filePath) {
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
                    },
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
                    isCodex: widget.isCodex,
                  );
                }
                // Wrap with AutoScrollTag for scroll-to-index support.
                // Use entryIndex (not reverse index) as the AutoScrollTag index.
                return AutoScrollTag(
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
    );
  }

  _ChatListDerivedData _deriveData(
    ChatSessionState chatState,
    List<ChatEntry> entries,
  ) {
    final cached = _derivedData;
    if (_derivedForHttpBaseUrl == widget.httpBaseUrl && cached != null) {
      if (identical(_derivedForState, chatState)) return cached;
      final previousEntries = _derivedEntries;
      if (previousEntries != null && listEquals(previousEntries, entries)) {
        _derivedForState = chatState;
        return cached;
      }
    }

    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
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
      forkableAssistantEntryIndices: forkableAssistantEntryIndices(entries),
      successResultFallbackEntryIndices: successResultFallbackEntryIndices(
        entries,
      ),
      latestPlanText: _findPlanFromWriteTool(entries),
    );
    _derivedForState = chatState;
    _derivedEntries = entries;
    _derivedForHttpBaseUrl = widget.httpBaseUrl;
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
        _ => '${message.runtimeType}',
      },
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

  const _VisibleAnchor({required this.key, required this.bottom});
}

class _ChatListDerivedData {
  final Set<int> imageGroupMemberIndices;
  final Map<int, List<GeneratedImagePreviewItem>> imageItemsByAnchor;
  final Set<String> completedGeneratedImageToolUseIds;
  final Set<int> forkableAssistantEntryIndices;
  final Set<int> successResultFallbackEntryIndices;
  final String? latestPlanText;

  const _ChatListDerivedData({
    required this.imageGroupMemberIndices,
    required this.imageItemsByAnchor,
    required this.completedGeneratedImageToolUseIds,
    required this.forkableAssistantEntryIndices,
    required this.successResultFallbackEntryIndices,
    required this.latestPlanText,
  });
}

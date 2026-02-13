import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../hooks/use_scroll_tracking.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/bridge_service.dart';
import '../../services/chat_message_handler.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/approval_bar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/plan_detail_sheet.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/worktree_list_sheet.dart';
import '../../utils/diff_parser.dart';
import '../diff/diff_screen.dart';
import '../gallery/gallery_screen.dart';
import 'state/chat_session_cubit.dart';
import 'widgets/rewind_action_sheet.dart';
import 'widgets/rewind_message_list_sheet.dart';
import 'state/chat_session_state.dart';
import 'state/streaming_state_cubit.dart';
import 'widgets/branch_chip.dart';
import 'widgets/chat_input_with_overlays.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/plan_mode_chip.dart';
import 'widgets/reconnect_banner.dart';
import 'widgets/status_indicator.dart';

/// Outer widget that creates screen-scoped [ChatSessionCubit] and
/// [StreamingStateCubit] via [MultiBlocProvider], replacing Riverpod's
/// Family (autoDispose) pattern.
///
/// When [isPending] is true, shows a loading overlay until [session_created]
/// is received from the bridge, then swaps to the real session.
class ChatScreen extends StatefulWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;

  const ChatScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String _sessionId;
  late String? _worktreePath;
  late String? _gitBranch;
  late bool _isPending;
  StreamSubscription<ServerMessage>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _worktreePath = widget.worktreePath;
    _gitBranch = widget.gitBranch;
    _isPending = widget.isPending;

    if (_isPending) {
      _listenForSessionCreated();
    }
  }

  void _listenForSessionCreated() {
    final bridge = context.read<BridgeService>();
    _pendingSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        // Filter by projectPath to avoid picking up another session's event
        if (widget.projectPath != null &&
            msg.projectPath != null &&
            msg.projectPath != widget.projectPath) {
          return;
        }
        if (msg.sessionId != null && mounted) {
          setState(() {
            _sessionId = msg.sessionId!;
            _worktreePath = msg.worktreePath ?? _worktreePath;
            _gitBranch = msg.worktreeBranch ?? _gitBranch;
            _isPending = false;
          });
          _pendingSub?.cancel();
          _pendingSub = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(height: 16),
              Text('Creating session...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return _ChatScreenProviders(
      key: ValueKey(_sessionId),
      sessionId: _sessionId,
      projectPath: widget.projectPath,
      gitBranch: _gitBranch,
      worktreePath: _worktreePath,
    );
  }
}

/// Wrapper that creates screen-scoped cubits once per session.
class _ChatScreenProviders extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;

  const _ChatScreenProviders({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    final streamingCubit = StreamingStateCubit();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ChatSessionCubit(
            sessionId: sessionId,
            bridge: bridge,
            streamingCubit: streamingCubit,
          ),
        ),
        BlocProvider.value(value: streamingCubit),
      ],
      child: _ChatScreenBody(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
      ),
    );
  }
}

class _ChatScreenBody extends HookWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;

  const _ChatScreenBody({
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Custom hooks
    final lifecycleState = useAppLifecycleState();
    final isBackground =
        lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
    final scroll = useScrollTracking(sessionId);

    // Plan feedback controller (for plan approval rejection message)
    final planFeedbackController = useTextEditingController();

    // Chat input controller (managed here to preserve text across rebuilds)
    final chatInputController = useTextEditingController();

    // Collapse tool results notifier
    final collapseToolResults = useMemoized(() => ValueNotifier<int>(0));
    useEffect(() => collapseToolResults.dispose, const []);

    // Edited plan text (shared with PlanCard via ValueNotifier)
    final editedPlanText = useMemoized(() => ValueNotifier<String?>(null));
    useEffect(() => editedPlanText.dispose, const []);

    // Clear context toggle for plan approval
    final clearContext = useState(false);

    // Diff selection from DiffScreen navigation
    final diffSelectionFromNav = useState<DiffSelection?>(null);

    // --- Bloc state ---
    final sessionState = context.watch<ChatSessionCubit>().state;
    final bridgeState = context.watch<ConnectionCubit>().state;

    // --- Side effects subscription ---
    useEffect(() {
      final sub = context.read<ChatSessionCubit>().sideEffects.listen(
        (effects) => _executeSideEffects(
          effects,
          isBackground: isBackground,
          collapseToolResults: collapseToolResults,
          planFeedbackController: planFeedbackController,
          scrollToBottom: scroll.scrollToBottom,
        ),
      );
      return sub.cancel;
    }, [sessionId]);

    // --- Initial requests on mount ---
    useEffect(() {
      final bridge = context.read<BridgeService>();
      if (projectPath != null && projectPath!.isNotEmpty) {
        bridge.requestFileList(projectPath!);
      }
      bridge.requestSessionList();
      return null;
    }, [sessionId]);

    // --- App resume: verify WebSocket health + refresh history ---
    // If still connected, refresh history directly (BlocListener won't fire).
    // If disconnected, ensureConnected triggers reconnect → BlocListener
    // fires → refreshHistory is called there.
    useEffect(() {
      if (lifecycleState == AppLifecycleState.resumed) {
        final bridge = context.read<BridgeService>();
        bridge.ensureConnected();
        if (bridge.isConnected) {
          context.read<ChatSessionCubit>().refreshHistory();
        }
      }
      return null;
    }, [lifecycleState]);

    // --- Destructure state ---
    final status = sessionState.status;
    final approval = sessionState.approval;
    final inPlanMode = sessionState.inPlanMode;

    // Approval state pattern matching
    String? pendingToolUseId;
    PermissionRequestMessage? pendingPermission;
    String? askToolUseId;
    Map<String, dynamic>? askInput;

    switch (approval) {
      case ApprovalPermission(:final toolUseId, :final request):
        pendingToolUseId = toolUseId;
        pendingPermission = request;
        askToolUseId = null;
        askInput = null;
      case ApprovalAskUser(:final toolUseId, :final input):
        pendingToolUseId = null;
        pendingPermission = null;
        askToolUseId = toolUseId;
        askInput = input;
      case ApprovalNone():
        pendingToolUseId = null;
        pendingPermission = null;
        askToolUseId = null;
        askInput = null;
    }

    final isPlanApproval = pendingPermission?.toolName == 'ExitPlanMode';

    // Clear edited plan when approval state resets
    if (pendingToolUseId == null) {
      editedPlanText.value = null;
    }

    // --- Action callbacks ---
    void approveToolUse() {
      if (pendingToolUseId == null) return;
      final updatedInput = editedPlanText.value != null
          ? {'plan': editedPlanText.value!}
          : null;
      context.read<ChatSessionCubit>().approve(
        pendingToolUseId,
        updatedInput: updatedInput,
        clearContext: isPlanApproval && clearContext.value,
      );
      editedPlanText.value = null;
      planFeedbackController.clear();
      clearContext.value = false;
    }

    void rejectToolUse() {
      if (pendingToolUseId == null) return;
      final feedback = isPlanApproval
          ? planFeedbackController.text.trim()
          : null;
      context.read<ChatSessionCubit>().reject(
        pendingToolUseId,
        message: feedback != null && feedback.isNotEmpty ? feedback : null,
      );
      planFeedbackController.clear();
    }

    void approveAlwaysToolUse() {
      if (pendingToolUseId == null) return;
      HapticFeedback.mediumImpact();
      context.read<ChatSessionCubit>().approveAlways(pendingToolUseId);
    }

    void answerQuestion(String toolUseId, String result) {
      context.read<ChatSessionCubit>().answer(toolUseId, result);
    }

    // --- Build ---
    return BlocListener<ConnectionCubit, BridgeConnectionState>(
      listener: (context, state) {
        if (state == BridgeConnectionState.connected) {
          _retryFailedMessages(context, sessionId);
          context.read<ChatSessionCubit>().refreshHistory();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).maybePop();
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              actions: [
                // 1. Rewind
                IconButton(
                  key: const ValueKey('rewind_button'),
                  icon: const Icon(Icons.history, size: 18),
                  tooltip: 'Rewind',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => _showRewindMessageList(context),
                ),
                // 2. View Changes
                if (projectPath != null)
                  IconButton(
                    icon: const Icon(Icons.difference, size: 18),
                    tooltip: 'View Changes',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () => _openDiffScreen(
                      context,
                      worktreePath ?? projectPath!,
                      diffSelectionFromNav,
                      existingSelection: diffSelectionFromNav.value,
                    ),
                  ),
                // 3. Screenshot
                if (projectPath != null)
                  IconButton(
                    icon: const Icon(Icons.screenshot_monitor, size: 18),
                    tooltip: 'Screenshot',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () {
                      showScreenshotSheet(
                        context: context,
                        bridge: context.read<BridgeService>(),
                        projectPath: projectPath!,
                        sessionId: sessionId,
                      );
                    },
                  ),
                // 4. Gallery (session preview)
                IconButton(
                  key: const ValueKey('gallery_button'),
                  icon: const Icon(Icons.collections, size: 18),
                  tooltip: 'Gallery',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GalleryScreen(sessionId: sessionId),
                      ),
                    );
                  },
                ),
                // 5. Branch chip
                if (projectPath != null)
                  BranchChip(
                    branchName: gitBranch,
                    isWorktree: worktreePath != null,
                    onTap: () {
                      showWorktreeListSheet(
                        context: context,
                        bridge: context.read<BridgeService>(),
                        projectPath: projectPath!,
                        currentWorktreePath: worktreePath,
                      );
                    },
                  ),
                // 6. Plan mode chip
                if (inPlanMode) const PlanModeChip(),
                // 7. Status indicator
                StatusIndicator(status: status),
              ],
            ),
            body: Column(
              children: [
                if (bridgeState == BridgeConnectionState.reconnecting ||
                    bridgeState == BridgeConnectionState.disconnected)
                  ReconnectBanner(bridgeState: bridgeState),
                if (status == ProcessStatus.clearing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Clearing context...'),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      ChatMessageList(
                        sessionId: sessionId,
                        scrollController: scroll.controller,
                        httpBaseUrl: context.read<BridgeService>().httpBaseUrl,
                        onRetryMessage: (entry) {
                          context.read<ChatSessionCubit>().retryMessage(entry);
                        },
                        onRewindMessage: (entry) {
                          _showRewindActionSheet(context, entry);
                        },
                        collapseToolResults: collapseToolResults,
                        editedPlanText: editedPlanText,
                        onScrollToBottom: scroll.scrollToBottom,
                      ),
                      if (scroll.isScrolledUp)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            onPressed: () {
                              // Force scroll to bottom even when scrolled up
                              if (scroll.controller.hasClients) {
                                scroll.controller.animateTo(
                                  scroll.controller.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                    ],
                  ),
                ),
                if (askToolUseId != null && askInput != null)
                  AskUserQuestionWidget(
                    toolUseId: askToolUseId,
                    input: askInput,
                    onAnswer: answerQuestion,
                  ),
                if (pendingToolUseId != null)
                  ApprovalBar(
                    key: ValueKey('approval_$pendingToolUseId'),
                    appColors: appColors,
                    pendingPermission: pendingPermission,
                    isPlanApproval: isPlanApproval,
                    planFeedbackController: planFeedbackController,
                    onApprove: approveToolUse,
                    onReject: rejectToolUse,
                    onApproveAlways: approveAlwaysToolUse,
                    clearContext: clearContext.value,
                    onClearContextChanged: isPlanApproval
                        ? (v) => clearContext.value = v
                        : null,
                    onViewPlan: isPlanApproval
                        ? () async {
                            final originalText = _extractPlanText(
                              sessionState.entries,
                            );
                            if (originalText == null) return;
                            final current =
                                editedPlanText.value ?? originalText;
                            final edited = await showPlanDetailSheet(
                              context,
                              current,
                            );
                            if (edited != null) {
                              editedPlanText.value = edited;
                            }
                          }
                        : null,
                  ),
                if (approval is ApprovalNone)
                  ChatInputWithOverlays(
                    sessionId: sessionId,
                    status: status,
                    onScrollToBottom: scroll.scrollToBottom,
                    inputController: chatInputController,
                    initialDiffSelection: diffSelectionFromNav.value,
                    onDiffSelectionConsumed: () {
                      // Don't null — keep for AppBar navigation.
                      // The value is cleared via onDiffSelectionCleared.
                    },
                    onDiffSelectionCleared: () =>
                        diffSelectionFromNav.value = null,
                    onOpenDiffScreen: projectPath != null
                        ? (currentSelection) => _openDiffScreen(
                            context,
                            worktreePath ?? projectPath!,
                            diffSelectionFromNav,
                            existingSelection: currentSelection,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

Future<void> _openDiffScreen(
  BuildContext context,
  String projectPath,
  ValueNotifier<DiffSelection?> diffSelectionNotifier, {
  DiffSelection? existingSelection,
}) async {
  final selection = await Navigator.push<DiffSelection>(
    context,
    MaterialPageRoute(
      builder: (_) => DiffScreen(
        projectPath: projectPath,
        initialSelectedHunkKeys: existingSelection?.selectedHunkKeys,
      ),
    ),
  );
  if (selection != null && !selection.isEmpty) {
    diffSelectionNotifier.value = selection;
  } else if (selection != null && selection.isEmpty) {
    // User cleared all selections
    diffSelectionNotifier.value = null;
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required bool isBackground,
  required ValueNotifier<int> collapseToolResults,
  required TextEditingController planFeedbackController,
  required VoidCallback scrollToBottom,
}) {
  for (final effect in effects) {
    switch (effect) {
      case ChatSideEffect.heavyHaptic:
        HapticFeedback.heavyImpact();
      case ChatSideEffect.mediumHaptic:
        HapticFeedback.mediumImpact();
      case ChatSideEffect.lightHaptic:
        HapticFeedback.lightImpact();
      case ChatSideEffect.collapseToolResults:
        collapseToolResults.value++;
      case ChatSideEffect.clearPlanFeedback:
        planFeedbackController.clear();
      case ChatSideEffect.notifyApprovalRequired:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Approval Required',
            body: 'Tool approval needed',
            id: 1,
          );
        }
      case ChatSideEffect.notifyAskQuestion:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Claude is asking',
            body: 'Question needs your answer',
            id: 2,
          );
        }
      case ChatSideEffect.notifySessionComplete:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Session Complete',
            body: 'Session done',
            id: 3,
          );
        }
      case ChatSideEffect.scrollToBottom:
        scrollToBottom();
    }
  }
}

/// Walk entries in reverse to find the latest [AssistantServerMessage] that
/// contains an `ExitPlanMode` tool use, then extract the plan text.
///
/// Tries TextContent first; if it's too short (real SDK writes the plan to a
/// file via Write tool), searches ALL entries for a Write tool targeting
/// `.claude/plans/`.
String? _extractPlanText(List<ChatEntry> entries) {
  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is ServerChatEntry && entry.message is AssistantServerMessage) {
      final assistant = entry.message as AssistantServerMessage;
      final contents = assistant.message.content;
      final hasExitPlan = contents.any(
        (c) => c is ToolUseContent && c.name == 'ExitPlanMode',
      );
      if (hasExitPlan) {
        final textPlan = contents
            .whereType<TextContent>()
            .map((c) => c.text)
            .join('\n\n');
        if (textPlan.split('\n').length >= 10) return textPlan;
        // Fall back: search ALL entries for a Write tool targeting .claude/plans/
        final writtenPlan = findPlanFromWriteTool(entries);
        return writtenPlan ?? textPlan;
      }
    }
  }
  return null;
}

/// Search all entries for a Write tool that targets `.claude/plans/` and
/// return its `content` input.  The Write tool is often in a different
/// [AssistantServerMessage] than the ExitPlanMode tool use.
String? findPlanFromWriteTool(List<ChatEntry> entries) {
  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
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

void _showRewindMessageList(BuildContext context) {
  final cubit = context.read<ChatSessionCubit>();
  final messages = cubit.rewindableUserMessages;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RewindMessageListSheet(
      messages: messages,
      onMessageSelected: (msg) => _showRewindActionSheet(context, msg),
    ),
  );
}

void _showRewindActionSheet(BuildContext context, UserChatEntry message) {
  final cubit = context.read<ChatSessionCubit>();

  // Request dry-run preview
  if (message.messageUuid != null) {
    cubit.rewindDryRun(message.messageUuid!);
  }

  showModalBottomSheet<void>(
    context: context,
    builder: (_) {
      return StreamBuilder<ChatSessionState>(
        stream: cubit.stream,
        initialData: cubit.state,
        builder: (ctx, snapshot) {
          final preview = snapshot.data?.rewindPreview;

          return RewindActionSheet(
            userMessage: message,
            preview: preview,
            isLoadingPreview: preview == null,
            onRewind: (mode) {
              Navigator.of(ctx).pop();
              if (message.messageUuid != null) {
                cubit.rewind(message.messageUuid!, mode.value);
              }
            },
          );
        },
      );
    },
  );
}

void _retryFailedMessages(BuildContext context, String sessionId) {
  final cubit = context.read<ChatSessionCubit>();
  for (final entry in cubit.state.entries) {
    if (entry is UserChatEntry && entry.status == MessageStatus.failed) {
      cubit.retryMessage(entry);
    }
  }
}

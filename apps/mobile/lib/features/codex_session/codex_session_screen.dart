import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../hooks/use_scroll_tracking.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/bridge_service.dart';
import '../../services/chat_message_handler.dart';
import '../../services/draft_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/session_name_title.dart';
import '../../utils/debug_bundle_share.dart';
import '../../utils/diff_parser.dart';
import '../../widgets/new_session_sheet.dart'
    show permissionModeFromRaw, sandboxModeFromRaw;
import '../../widgets/approval_bar.dart';
import '../../widgets/bubbles/ask_user_question_widget.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/worktree_list_sheet.dart';
import '../../widgets/plan_detail_sheet.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../chat_session/state/chat_session_state.dart';
import '../../theme/app_theme.dart';
import '../chat_session/state/streaming_state_cubit.dart';
import '../chat_session/widgets/branch_chip.dart';
import '../chat_session/widgets/chat_input_with_overlays.dart';
import '../chat_session/widgets/chat_message_list.dart';
import '../chat_session/widgets/reconnect_banner.dart';
import '../chat_session/widgets/session_mode_bar.dart';
import '../chat_session/widgets/status_indicator.dart';
import '../../router/app_router.dart';
import '../claude_session/widgets/rewind_message_list_sheet.dart'
    show UserMessageHistorySheet;
import 'state/codex_session_cubit.dart';

/// Codex-specific chat screen.
///
/// Simpler than [ClaudeSessionScreen] — no rewind.
/// Shares UI components (`ChatMessageList`, `ChatInputWithOverlays`, etc.)
/// via [CodexSessionCubit] which extends [ChatSessionCubit].
@RoutePage()
class CodexSessionScreen extends StatefulWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialSandboxMode;
  final String? initialPermissionMode;

  /// Notifier from the parent that may already hold a [SystemMessage]
  /// with subtype `session_created` (race condition fix).
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  const CodexSessionScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialSandboxMode,
    this.initialPermissionMode,
    this.pendingSessionCreated,
  });

  @override
  State<CodexSessionScreen> createState() => _CodexSessionScreenState();
}

class _CodexSessionScreenState extends State<CodexSessionScreen> {
  late String _sessionId;
  late String? _projectPath;
  late String? _gitBranch;
  late String? _worktreePath;
  late bool _isPending;
  SandboxMode? _sandboxMode;
  StreamSubscription<ServerMessage>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _projectPath = widget.projectPath;
    _gitBranch = widget.gitBranch;
    _worktreePath = widget.worktreePath;
    _isPending = widget.isPending;
    _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);

    if (_isPending) {
      _listenForSessionCreated();
    }
  }

  void _listenForSessionCreated() {
    // Check if session_list_screen already captured the message (race fix).
    final buffered = widget.pendingSessionCreated?.value;
    if (buffered != null && buffered.sessionId != null) {
      _resolveSession(buffered);
      return;
    }
    // Also listen for future notification via the ValueNotifier.
    widget.pendingSessionCreated?.addListener(_onPendingSessionCreated);

    final bridge = context.read<BridgeService>();
    _pendingSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        if (widget.projectPath != null &&
            msg.projectPath != null &&
            msg.projectPath != widget.projectPath) {
          return;
        }
        if (msg.sessionId != null && mounted) {
          _resolveSession(msg);
        }
      }
    });
  }

  void _onPendingSessionCreated() {
    final msg = widget.pendingSessionCreated?.value;
    if (msg != null && msg.sessionId != null && mounted && _isPending) {
      _resolveSession(msg);
    }
  }

  void _resolveSession(SystemMessage msg) {
    widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
    final oldId = _sessionId;
    final newId = msg.sessionId!;
    // Migrate draft from pending ID to real session ID
    final draftService = context.read<DraftService>();
    draftService.migrateDraft(oldId, newId);
    draftService.migrateImageDraft(oldId, newId);
    setState(() {
      _sessionId = newId;
      _projectPath = msg.projectPath ?? _projectPath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _worktreePath = msg.worktreePath ?? _worktreePath;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
      _isPending = false;
    });
    _pendingSub?.cancel();
    _pendingSub = null;
  }

  @override
  void dispose() {
    widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
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

    return _CodexProviders(
      key: ValueKey(_sessionId),
      sessionId: _sessionId,
      projectPath: _projectPath,
      gitBranch: _gitBranch,
      worktreePath: _worktreePath,
      sandboxMode: _sandboxMode,
      permissionMode: permissionModeFromRaw(widget.initialPermissionMode),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider wrapper — creates CodexSessionCubit + StreamingStateCubit
// ---------------------------------------------------------------------------

class _CodexProviders extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final SandboxMode? sandboxMode;
  final PermissionMode? permissionMode;

  const _CodexProviders({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.sandboxMode,
    this.permissionMode,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    final streamingCubit = StreamingStateCubit();
    return MultiBlocProvider(
      providers: [
        // Register as ChatSessionCubit so shared widgets can find it.
        BlocProvider<ChatSessionCubit>(
          create: (_) => CodexSessionCubit(
            sessionId: sessionId,
            bridge: bridge,
            streamingCubit: streamingCubit,
            initialSandboxMode: sandboxMode,
            initialPermissionMode: permissionMode,
          ),
        ),
        BlocProvider.value(value: streamingCubit),
      ],
      child: _CodexChatBody(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat body — streamlined for Codex
// ---------------------------------------------------------------------------

class _CodexChatBody extends HookWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;

  const _CodexChatBody({
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

    // Chat input controller
    final chatInputController = useTextEditingController();
    final planFeedbackController = useTextEditingController();

    // --- Draft persistence: restore on mount, auto-save on change ---
    useEffect(() {
      final draftService = context.read<DraftService>();
      final draft = draftService.getDraft(sessionId);
      if (draft != null && draft.isNotEmpty) {
        chatInputController.text = draft;
        chatInputController.selection = TextSelection.collapsed(
          offset: draft.length,
        );
      }

      Timer? debounce;
      void onChanged() {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 500), () {
          draftService.saveDraft(sessionId, chatInputController.text);
        });
      }

      chatInputController.addListener(onChanged);
      return () {
        debounce?.cancel();
        // Flush current text on dispose (navigating away)
        draftService.saveDraft(sessionId, chatInputController.text);
        chatInputController.removeListener(onChanged);
      };
    }, [sessionId]);
    final editedPlanText = useMemoized(() => ValueNotifier<String?>(null));
    useEffect(() => editedPlanText.dispose, const []);
    final activePlanApprovalToolUseId = useRef<String?>(null);

    // Collapse tool results notifier (shared widget needs it)
    final collapseToolResults = useMemoized(() => ValueNotifier<int>(0));
    useEffect(() => collapseToolResults.dispose, const []);

    // Scroll-to-user-entry notifier (for message history jump)
    final scrollToUserEntry = useMemoized(
      () => ValueNotifier<UserChatEntry?>(null),
    );
    useEffect(() => scrollToUserEntry.dispose, const []);

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
          sessionId: sessionId,
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

    // Approval state pattern matching (Codex: permission + ask-user only)
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
    final pendingPlanToolUseId = isPlanApproval ? pendingToolUseId : null;
    if (activePlanApprovalToolUseId.value != pendingPlanToolUseId) {
      activePlanApprovalToolUseId.value = pendingPlanToolUseId;
      editedPlanText.value = null;
    }

    void approveToolUse() {
      if (pendingToolUseId == null) return;
      final updatedInput = isPlanApproval && editedPlanText.value != null
          ? {'plan': editedPlanText.value!}
          : null;
      context.read<ChatSessionCubit>().approve(
        pendingToolUseId,
        updatedInput: updatedInput,
      );
      editedPlanText.value = null;
      planFeedbackController.clear();
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
      editedPlanText.value = null;
      planFeedbackController.clear();
    }

    void approveWithClearContext() {
      if (pendingToolUseId == null) return;
      final updatedInput = isPlanApproval && editedPlanText.value != null
          ? {'plan': editedPlanText.value!}
          : null;
      context.read<ChatSessionCubit>().approve(
        pendingToolUseId,
        updatedInput: updatedInput,
        clearContext: true,
      );
      editedPlanText.value = null;
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
          _retryFailedMessages(context);
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
              titleSpacing: 0,
              title: SessionNameTitle(
                sessionId: sessionId,
                projectPath: projectPath,
              ),
              actions: [
                // Permission mode chip (moved from SessionModeBar)
                PermissionModeChip(
                  currentMode: sessionState.permissionMode,
                  onTap: () => showPermissionModeMenu(
                    context,
                    context.read<ChatSessionCubit>(),
                  ),
                ),
                // Sandbox mode chip (Codex only)
                if (context.read<ChatSessionCubit>().isCodex)
                  SandboxModeChip(
                    currentMode: sessionState.sandboxMode,
                    onTap: () => showSandboxModeMenu(
                      context,
                      context.read<ChatSessionCubit>(),
                    ),
                  ),
                // Branch chip
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
                // Status indicator
                StatusIndicator(
                  status: status,
                  inPlanMode: inPlanMode,
                  onLongPress: () =>
                      copyDebugBundleForAgent(context, sessionId),
                ),
                // Overflow menu
                PopupMenuButton<String>(
                  key: const ValueKey('session_overflow_menu'),
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'history':
                        _showUserMessageHistory(context, scrollToUserEntry);
                      case 'diff':
                        _openDiffScreen(
                          context,
                          worktreePath ?? projectPath!,
                          diffSelectionFromNav,
                          existingSelection: diffSelectionFromNav.value,
                        );
                      case 'screenshot':
                        showScreenshotSheet(
                          context: context,
                          bridge: context.read<BridgeService>(),
                          projectPath: projectPath!,
                          sessionId: sessionId,
                        );
                      case 'gallery':
                        context.router.push(GalleryRoute(sessionId: sessionId));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      key: ValueKey('menu_message_history'),
                      value: 'history',
                      child: ListTile(
                        leading: Icon(Icons.history, size: 20),
                        title: Text('Message History'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (projectPath != null)
                      const PopupMenuItem(
                        key: ValueKey('menu_view_changes'),
                        value: 'diff',
                        child: ListTile(
                          leading: Icon(Icons.difference, size: 20),
                          title: Text('View Changes'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (projectPath != null)
                      const PopupMenuItem(
                        key: ValueKey('menu_screenshot'),
                        value: 'screenshot',
                        child: ListTile(
                          leading: Icon(Icons.screenshot_monitor, size: 20),
                          title: Text('Screenshot'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      key: ValueKey('menu_gallery'),
                      value: 'gallery',
                      child: ListTile(
                        leading: Icon(Icons.collections, size: 20),
                        title: Text('Gallery'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (bridgeState == BridgeConnectionState.reconnecting ||
                    bridgeState == BridgeConnectionState.disconnected)
                  ReconnectBanner(bridgeState: bridgeState),
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
                        // No rewind for Codex
                        onRewindMessage: null,
                        editedPlanText: editedPlanText,
                        allowPlanEditing: pendingPlanToolUseId != null,
                        pendingPlanToolUseId: pendingPlanToolUseId,
                        scrollToUserEntry: scrollToUserEntry,
                        collapseToolResults: collapseToolResults,
                        onScrollToBottom: scroll.scrollToBottom,
                      ),
                      if (scroll.isScrolledUp)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            onPressed: () {
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
                    planApprovalUiMode: PlanApprovalUiMode.codex,
                    planFeedbackController: planFeedbackController,
                    onApprove: approveToolUse,
                    onReject: rejectToolUse,
                    onApproveAlways: approveAlwaysToolUse,
                    onApproveClearContext: isPlanApproval
                        ? approveWithClearContext
                        : null,
                    onViewPlan: isPlanApproval
                        ? () async {
                            final originalText = _extractPlanText(
                              pendingPermission,
                              sessionState.entries,
                            );
                            if (originalText == null) return;
                            final current =
                                editedPlanText.value ?? originalText;
                            final edited = await showPlanDetailSheet(
                              context,
                              current,
                              editable: true,
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
                    hintText: 'Message Codex...',
                    initialDiffSelection: diffSelectionFromNav.value,
                    onDiffSelectionConsumed: () {},
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
// Helpers
// ---------------------------------------------------------------------------

Future<void> _openDiffScreen(
  BuildContext context,
  String projectPath,
  ValueNotifier<DiffSelection?> diffSelectionNotifier, {
  DiffSelection? existingSelection,
}) async {
  final selection = await context.router.push<DiffSelection>(
    DiffRoute(
      projectPath: projectPath,
      initialSelectedHunkKeys: existingSelection?.selectedHunkKeys,
    ),
  );
  if (selection != null && !selection.isEmpty) {
    diffSelectionNotifier.value = selection;
  } else if (selection != null && selection.isEmpty) {
    diffSelectionNotifier.value = null;
  }
}

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required String sessionId,
  required bool isBackground,
  required TextEditingController planFeedbackController,
  required ValueNotifier<int> collapseToolResults,
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
            body: 'Codex tool approval needed',
            id: 1,
            payload: sessionId,
          );
        }
      case ChatSideEffect.notifyAskQuestion:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Codex is asking',
            body: 'Question needs your answer',
            id: 2,
            payload: sessionId,
          );
        }
      case ChatSideEffect.notifySessionComplete:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Session Complete',
            body: 'Codex session done',
            id: 3,
            payload: sessionId,
          );
        }
      case ChatSideEffect.scrollToBottom:
        scrollToBottom();
    }
  }
}

void _showUserMessageHistory(
  BuildContext context,
  ValueNotifier<UserChatEntry?> scrollToUserEntry,
) {
  final cubit = context.read<ChatSessionCubit>();
  final messages = cubit.allUserMessages;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => UserMessageHistorySheet(
      messages: messages,
      onScrollToMessage: (msg) {
        scrollToUserEntry.value = msg;
      },
      // No rewind for Codex sessions
    ),
  );
}

void _retryFailedMessages(BuildContext context) {
  final cubit = context.read<ChatSessionCubit>();
  for (final entry in cubit.state.entries) {
    if (entry is UserChatEntry && entry.status == MessageStatus.failed) {
      cubit.retryMessage(entry);
    }
  }
}

String? _extractPlanText(
  PermissionRequestMessage? pendingPermission,
  List<ChatEntry> entries,
) {
  final raw = pendingPermission?.input['plan'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw;
  }

  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is! ServerChatEntry) continue;
    final msg = entry.message;
    if (msg is! AssistantServerMessage) continue;

    final text = msg.message.content
        .whereType<TextContent>()
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    if (text.startsWith('Plan update:')) {
      return text;
    }
  }

  return null;
}

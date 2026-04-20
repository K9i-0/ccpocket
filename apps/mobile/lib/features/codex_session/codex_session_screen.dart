import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../constants/feature_flags.dart';
import '../../hooks/use_app_resume_callback.dart';
import '../../hooks/use_keyboard_scroll_adjustment.dart';
import '../../hooks/use_scroll_tracking.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../services/bridge_service.dart';
import '../../widgets/rename_session_dialog.dart';
import '../../services/chat_message_handler.dart';
import '../../services/draft_service.dart';
import '../../utils/composer_tokens.dart';
import '../../services/notification_service.dart';
import '../../widgets/session_name_title.dart';
import '../../utils/diff_parser.dart';
import '../../utils/terminal_launcher.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/new_session_sheet.dart'
    show permissionModeFromRaw, sandboxModeFromRaw;
import '../session_list/workspace_shell_screen.dart';
import '../../widgets/approval_bar.dart';
import '../../widgets/bubbles/ask_user_question_widget.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/plan_detail_sheet.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../chat_session/state/chat_session_state.dart';
import '../../theme/app_theme.dart';
import '../chat_session/state/streaming_state_cubit.dart';
import '../chat_session/widgets/chat_input_with_overlays.dart';
import '../chat_session/widgets/bottom_overlay_layout.dart';
import '../chat_session/widgets/chat_message_list.dart';
import '../chat_session/widgets/reconnect_banner.dart';
import '../chat_session/widgets/scroll_to_bottom_button.dart';
import '../chat_session/widgets/session_mode_bar.dart';
import '../chat_session/widgets/status_line_flexible_space.dart';
import '../explore/state/explore_state.dart';
import '../../router/app_router.dart';
import '../claude_session/widgets/rewind_message_list_sheet.dart'
    show UserMessageHistorySheet;
import 'state/codex_session_cubit.dart';

const _fileListRefreshToolNames = {
  'Edit',
  'FileEdit',
  'MultiEdit',
  'Write',
  'NotebookEdit',
  'Bash',
};

class _NoopListenable implements Listenable {
  const _NoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

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
  final String? initialApprovalPolicy;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

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
    this.initialApprovalPolicy,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  State<CodexSessionScreen> createState() => _CodexSessionScreenState();
}

@RoutePage(name: 'WorkspaceCodexSessionRoute')
class WorkspaceCodexSessionScreen extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialSandboxMode;
  final String? initialPermissionMode;
  final String? initialApprovalPolicy;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const WorkspaceCodexSessionScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialSandboxMode,
    this.initialPermissionMode,
    this.initialApprovalPolicy,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CodexSessionScreen(
      sessionId: sessionId,
      projectPath: projectPath,
      gitBranch: gitBranch,
      worktreePath: worktreePath,
      isPending: isPending,
      initialSandboxMode: initialSandboxMode,
      initialPermissionMode: initialPermissionMode,
      initialApprovalPolicy: initialApprovalPolicy,
      pendingSessionCreated: pendingSessionCreated,
      onBackToSessions: onBackToSessions,
      hideAppBarLeading: hideAppBarLeading,
    );
  }
}

class _CodexSessionScreenState extends State<CodexSessionScreen> {
  late String _sessionId;
  late String? _projectPath;
  late String? _gitBranch;
  late String? _worktreePath;
  late bool _isPending;
  var _explorerCurrentPath = '';
  List<String> _recentPeekedFiles = const [];
  SandboxMode? _sandboxMode;
  PermissionMode? _permissionMode;
  CodexApprovalPolicy? _codexApprovalPolicy;
  StreamSubscription<ServerMessage>? _pendingSub;
  StreamSubscription<ServerMessage>? _sandboxRestartSub;
  StreamSubscription<String>? _sessionStoppedSub;

  @override
  void initState() {
    super.initState();
    final bridge = context.read<BridgeService>();
    _sessionId = widget.sessionId;
    _projectPath = widget.projectPath;
    _gitBranch = widget.gitBranch;
    _worktreePath = widget.worktreePath;
    _isPending = widget.isPending;
    _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);
    _permissionMode = permissionModeFromRaw(widget.initialPermissionMode);
    _codexApprovalPolicy = codexApprovalPolicyFromRaw(
      widget.initialApprovalPolicy,
    );
    final explorerHistory = bridge.getExplorerHistory(_sessionId);
    _explorerCurrentPath = explorerHistory.currentPath;
    _recentPeekedFiles = explorerHistory.recentPeekedFiles;

    if (_isPending) {
      _listenForSessionCreated();
    }
    _listenForSandboxRestart();
    _listenForSessionStopped();
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

  /// Listen for sandbox mode restart events.
  /// When the bridge destroys the old session and creates a new one with
  /// a different sandbox mode, we switch to the new session seamlessly.
  void _listenForSandboxRestart() {
    final bridge = context.read<BridgeService>();
    _sandboxRestartSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage &&
          msg.subtype == 'session_created' &&
          msg.sourceSessionId == _sessionId &&
          msg.sessionId != null &&
          msg.sessionId != _sessionId &&
          !_isPending &&
          mounted) {
        _switchSession(msg);
      }
    });
  }

  /// Switch to a new session (e.g. after sandbox mode change).
  void _switchSession(SystemMessage msg) {
    final oldId = _sessionId;
    final newId = msg.sessionId!;
    final draftService = context.read<DraftService>();
    final bridge = context.read<BridgeService>();
    bridge.migrateExplorerHistory(oldId, newId);
    final explorerHistory = bridge.getExplorerHistory(newId);
    draftService.migrateDraft(oldId, newId);
    draftService.migrateImageDraft(oldId, newId);
    setState(() {
      _sessionId = newId;
      _projectPath = msg.projectPath ?? _projectPath;
      _worktreePath = msg.worktreePath ?? _worktreePath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _codexApprovalPolicy =
          codexApprovalPolicyFromRaw(msg.approvalPolicy) ??
          _codexApprovalPolicy;
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
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
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _codexApprovalPolicy =
          codexApprovalPolicyFromRaw(msg.approvalPolicy) ??
          _codexApprovalPolicy;
      _isPending = false;
    });
    _pendingSub?.cancel();
    _pendingSub = null;
  }

  void _listenForSessionStopped() {
    final bridge = context.read<BridgeService>();
    _sessionStoppedSub = bridge.stoppedSessions.listen((stoppedSessionId) {
      if (!mounted || stoppedSessionId != _sessionId) return;
      setState(() {
        _explorerCurrentPath = '';
        _recentPeekedFiles = const [];
      });
    });
  }

  void updateExplorerState({
    required String currentPath,
    required List<String> recentPeekedFiles,
  }) {
    context.read<BridgeService>().setExplorerHistory(
      _sessionId,
      currentPath: currentPath,
      recentPeekedFiles: recentPeekedFiles,
    );
    setState(() {
      _explorerCurrentPath = currentPath;
      _recentPeekedFiles = recentPeekedFiles;
    });
  }

  @override
  void didUpdateWidget(covariant CodexSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId &&
        oldWidget.projectPath == widget.projectPath &&
        oldWidget.worktreePath == widget.worktreePath &&
        oldWidget.gitBranch == widget.gitBranch &&
        oldWidget.isPending == widget.isPending &&
        oldWidget.initialPermissionMode == widget.initialPermissionMode &&
        oldWidget.initialSandboxMode == widget.initialSandboxMode &&
        oldWidget.initialApprovalPolicy == widget.initialApprovalPolicy) {
      return;
    }

    final explorerHistory = context.read<BridgeService>().getExplorerHistory(
      widget.sessionId,
    );
    setState(() {
      _sessionId = widget.sessionId;
      _projectPath = widget.projectPath;
      _worktreePath = widget.worktreePath;
      _gitBranch = widget.gitBranch;
      _isPending = widget.isPending;
      _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);
      _permissionMode = permissionModeFromRaw(widget.initialPermissionMode);
      _codexApprovalPolicy = codexApprovalPolicyFromRaw(
        widget.initialApprovalPolicy,
      );
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
  }

  @override
  void dispose() {
    widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
    _pendingSub?.cancel();
    _sandboxRestartSub?.cancel();
    _sessionStoppedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending) {
      final shell = WorkspaceShellScreen.maybeOf(context);
      return Scaffold(
        appBar: AppBar(
          leading: _sessionAppBarLeading(
            context,
            shell,
            onBackToSessions: widget.onBackToSessions,
            hideAppBarLeading: widget.hideAppBarLeading,
          ),
          automaticallyImplyLeading: false,
          leadingWidth: _sessionAppBarLeadingWidth(
            shell,
            onBackToSessions: widget.onBackToSessions,
            hideAppBarLeading: widget.hideAppBarLeading,
          ),
        ),
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
      explorerCurrentPath: _explorerCurrentPath,
      recentPeekedFiles: _recentPeekedFiles,
      sandboxMode: _sandboxMode,
      permissionMode: _permissionMode,
      codexApprovalPolicy: _codexApprovalPolicy,
      onBackToSessions: widget.onBackToSessions,
      hideAppBarLeading: widget.hideAppBarLeading,
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
  final String explorerCurrentPath;
  final List<String> recentPeekedFiles;
  final SandboxMode? sandboxMode;
  final PermissionMode? permissionMode;
  final CodexApprovalPolicy? codexApprovalPolicy;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const _CodexProviders({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.explorerCurrentPath = '',
    this.recentPeekedFiles = const [],
    this.sandboxMode,
    this.permissionMode,
    this.codexApprovalPolicy,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
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
            initialExplorerCurrentPath: explorerCurrentPath,
            initialRecentPeekedFiles: recentPeekedFiles,
            initialSandboxMode: sandboxMode,
            initialPermissionMode: permissionMode,
            initialCodexApprovalPolicy: codexApprovalPolicy,
          ),
        ),
        BlocProvider.value(value: streamingCubit),
      ],
      child: _CodexChatBody(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        onBackToSessions: onBackToSessions,
        hideAppBarLeading: hideAppBarLeading,
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
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const _CodexChatBody({
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final shell = WorkspaceShellScreen.maybeOf(context);
    final presentationListenable = shell?.presentationListenable;
    // Mutable branch state (refreshed from Bridge)
    final currentBranch = useState(gitBranch);

    // Custom hooks
    final lifecycleState = useAppLifecycleState();
    final isBackground =
        lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
    final scroll = useScrollTracking(sessionId);
    useKeyboardScrollAdjustment(scroll.controller);

    // Chat input controller
    final chatInputController = useMemoized(ComposerTextEditingController.new);
    useEffect(() => chatInputController.dispose, [chatInputController]);
    final planFeedbackController = useTextEditingController();
    final draftService = context.read<DraftService>();

    // --- Draft persistence: restore on mount, auto-save on change ---
    useEffect(() {
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
    // Collapse tool results notifier (shared widget needs it)
    final collapseToolResults = useMemoized(() => ValueNotifier<int>(0));
    useEffect(() => collapseToolResults.dispose, const []);

    // Scroll-to-user-entry notifier (for message history jump)
    final scrollToUserEntry = useMemoized(
      () => ValueNotifier<UserChatEntry?>(null),
    );
    useEffect(() => scrollToUserEntry.dispose, const []);

    // Diff selection from GitScreen navigation
    final diffSelectionFromNav = useState<DiffSelection?>(null);

    // --- Bloc state ---
    final chatSessionCubit = context.read<ChatSessionCubit>();
    final sessionState = context.watch<ChatSessionCubit>().state;
    final bridgeState = context.watch<ConnectionCubit>().state;

    // --- Side effects subscription ---
    useEffect(() {
      final sub = chatSessionCubit.sideEffects.listen(
        (effects) => _executeSideEffects(
          effects,
          sessionId: sessionId,
          isBackground: isBackground,
          approval: chatSessionCubit.state.approval,
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
      bridge.refreshBranch(sessionId);
      return null;
    }, [sessionId, projectPath]);

    useEffect(() {
      if (projectPath == null || projectPath!.isEmpty) return null;

      final bridge = context.read<BridgeService>();
      final sub = bridge.messagesForSession(sessionId).listen((msg) {
        if (msg case ToolResultMessage(
          :final toolName,
        ) when _fileListRefreshToolNames.contains(toolName)) {
          bridge.requestFileList(projectPath!);
        } else if (msg case ResultMessage(
          :final fileEdits,
        ) when (fileEdits ?? 0) > 0) {
          bridge.requestFileList(projectPath!);
        }
      });
      return sub.cancel;
    }, [sessionId, projectPath]);

    // --- Listen for branch updates ---
    useEffect(() {
      final sub = context.read<BridgeService>().messages.listen((msg) {
        if (msg is BranchUpdateMessage && msg.sessionId == sessionId) {
          currentBranch.value = msg.branch.isNotEmpty ? msg.branch : null;
        }
      });
      return sub.cancel;
    }, [sessionId]);

    // --- App resume: verify WebSocket health + refresh history ---
    // Only triggers on genuine resume from paused/detached, not from
    // inactive (e.g. Android notification shade).
    useAppResumeCallback(lifecycleState, () {
      final bridge = context.read<BridgeService>();
      bridge.ensureConnected();
      if (bridge.isConnected) {
        context.read<ChatSessionCubit>().refreshHistory();
      }
    });

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

    void approveToolUse() {
      if (pendingToolUseId == null) return;
      context.read<ChatSessionCubit>().approve(pendingToolUseId);
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
      planFeedbackController.clear();
    }

    void approveWithClearContext() {
      if (pendingToolUseId == null) return;
      context.read<ChatSessionCubit>().approve(
        pendingToolUseId,
        clearContext: true,
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
          _retryFailedMessages(context);
          context.read<ChatSessionCubit>().refreshHistory();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).maybePop();
          },
          // Cmd+Shift+P: cycle permission mode
          const SingleActivator(
            LogicalKeyboardKey.keyP,
            meta: true,
            shift: true,
          ): () {
            final cubit = context.read<ChatSessionCubit>();
            showExecutionModeMenu(context, cubit);
          },
          // Cmd+Enter: approve pending tool use
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
            if (pendingToolUseId != null) approveToolUse();
          },
        },
        child: Focus(
          autofocus: true,
          child: ListenableBuilder(
            listenable: presentationListenable ?? const _NoopListenable(),
            builder: (context, child) {
              final currentShell = WorkspaceShellScreen.maybeOf(context);
              final isSinglePane = currentShell?.isSinglePane ?? true;
              final leading = _sessionAppBarLeading(
                context,
                currentShell,
                onBackToSessions: onBackToSessions,
                hideAppBarLeading: hideAppBarLeading,
              );

              return Scaffold(
                appBar: AppBar(
                  leading: leading,
                  automaticallyImplyLeading: false,
                  leadingWidth: _sessionAppBarLeadingWidth(
                    currentShell,
                    onBackToSessions: onBackToSessions,
                    hideAppBarLeading: hideAppBarLeading,
                  ),
                  titleSpacing: isSinglePane
                      ? NavigationToolbar.kMiddleSpacing
                      : (leading == null ? 16 : 12),
                  title: SessionNameTitle(
                    sessionId: sessionId,
                    projectPath: projectPath,
                  ),
                  flexibleSpace: StatusLineFlexibleSpace(
                    status: status,
                    inPlanMode: inPlanMode,
                  ),
                  actions: [
                    if ((projectPath ?? '').isNotEmpty)
                      IconButton(
                        key: const ValueKey('appbar_explore_button'),
                        icon: Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Explore',
                        onPressed: () async {
                          final parentState = context
                              .findAncestorStateOfType<
                                _CodexSessionScreenState
                              >();
                          void handleResult(ExploreScreenResult result) {
                            if (!context.mounted) return;
                            parentState?.updateExplorerState(
                              currentPath: result.currentPath,
                              recentPeekedFiles: result.recentPeekedFiles,
                            );
                            final cubit = context.read<ChatSessionCubit>();
                            cubit.setExplorerCurrentPath(result.currentPath);
                            cubit.setRecentPeekedFiles(
                              result.recentPeekedFiles,
                            );
                          }

                          final shell = WorkspaceShellScreen.maybeOf(context);
                          final initialPath =
                              parentState?._explorerCurrentPath ??
                              sessionState.explorerCurrentPath;
                          final recentPeekedFiles =
                              parentState?._recentPeekedFiles ??
                              sessionState.recentPeekedFiles;
                          if (shell?.canOpenToolPane ?? false) {
                            shell!.openExplorePane(
                              sessionId: sessionId,
                              projectPath: projectPath!,
                              initialFiles: context.read<FileListCubit>().state,
                              initialPath: initialPath,
                              recentPeekedFiles: recentPeekedFiles,
                              onResultChanged: handleResult,
                            );
                            return;
                          }
                          final result = await context.router.push(
                            ExploreRoute(
                              sessionId: sessionId,
                              projectPath: projectPath!,
                              initialFiles: context.read<FileListCubit>().state,
                              initialPath: initialPath,
                              recentPeekedFiles: recentPeekedFiles,
                            ),
                          );
                          if (result is! ExploreScreenResult ||
                              !context.mounted) {
                            return;
                          }
                          handleResult(result);
                        },
                      ),
                    if ((projectPath ?? '').isNotEmpty)
                      IconButton(
                        key: const ValueKey('appbar_view_changes'),
                        icon: Icon(
                          Icons.difference,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () {
                          _openGitScreen(
                            context,
                            worktreePath ?? projectPath!,
                            diffSelectionFromNav,
                            sessionId: sessionId,
                            worktreePath: worktreePath,
                          );
                        },
                      ),
                    PopupMenuButton<String>(
                      key: const ValueKey('session_overflow_menu'),
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'history':
                            _showUserMessageHistory(context, scrollToUserEntry);
                          case 'screenshot':
                            if (projectPath == null) return;
                            showScreenshotSheet(
                              context: context,
                              bridge: context.read<BridgeService>(),
                              projectPath: projectPath!,
                              sessionId: sessionId,
                            );
                          case 'gallery':
                            context.router.push(
                              GalleryRoute(sessionId: sessionId),
                            );
                          case 'rename':
                            _renameSession(context, sessionId);
                          case 'terminal':
                            _openInTerminal(context, projectPath);
                        }
                      },
                      itemBuilder: (context) {
                        final terminalConfig = context
                            .read<SettingsCubit>()
                            .state
                            .terminalApp;
                        final l = AppLocalizations.of(context);
                        return [
                          const PopupMenuItem(
                            key: ValueKey('menu_rename'),
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined, size: 20),
                              title: Text('Rename'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            key: ValueKey('menu_message_history'),
                            value: 'history',
                            child: ListTile(
                              leading: Icon(Icons.chat_outlined, size: 20),
                              title: Text('Message History'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (projectPath != null)
                            const PopupMenuItem(
                              key: ValueKey('menu_screenshot'),
                              value: 'screenshot',
                              child: ListTile(
                                leading: Icon(
                                  Icons.screenshot_monitor,
                                  size: 20,
                                ),
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
                          if (FeatureFlags.current.isEnabled(
                                AppFeature.terminalAppIntegration,
                              ) &&
                              terminalConfig.isConfigured &&
                              projectPath != null)
                            PopupMenuItem(
                              key: const ValueKey('menu_terminal'),
                              value: 'terminal',
                              child: ListTile(
                                leading: const Icon(Icons.terminal, size: 20),
                                title: Text(l.openInTerminal),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ];
                      },
                    ),
                  ],
                ),
                body: child,
              );
            },
            child: Column(
              children: [
                if (bridgeState == BridgeConnectionState.reconnecting ||
                    bridgeState == BridgeConnectionState.disconnected)
                  ReconnectBanner(bridgeState: bridgeState),
                Expanded(
                  child: BottomOverlayLayout(
                    overlay:
                        askToolUseId == null &&
                            askInput == null &&
                            pendingToolUseId == null
                        ? null
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is UserScrollNotification) {
                                FocusScope.of(context).unfocus();
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              reverse: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (askToolUseId case final askId?
                                      when askInput != null)
                                    AskUserQuestionWidget(
                                      toolUseId: askId,
                                      input: askInput,
                                      agentName: 'Codex',
                                      onAnswer: answerQuestion,
                                      scrollable: false,
                                    ),
                                  if (pendingToolUseId != null)
                                    ApprovalBar(
                                      key: ValueKey(
                                        'approval_$pendingToolUseId',
                                      ),
                                      appColors: appColors,
                                      pendingPermission: pendingPermission,
                                      isPlanApproval: isPlanApproval,
                                      planApprovalUiMode:
                                          PlanApprovalUiMode.codex,
                                      planFeedbackController:
                                          planFeedbackController,
                                      onApprove: approveToolUse,
                                      onReject: rejectToolUse,
                                      onApproveAlways: approveAlwaysToolUse,
                                      onApproveClearContext: isPlanApproval
                                          ? approveWithClearContext
                                          : null,
                                      onViewPlan: isPlanApproval
                                          ? () {
                                              final originalText =
                                                  _extractPlanText(
                                                    pendingPermission,
                                                    sessionState.entries,
                                                  );
                                              if (originalText == null) return;
                                              showPlanDetailSheet(
                                                context,
                                                originalText,
                                              );
                                            }
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                    topOverlay: Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SessionModeBar(
                          onBeforeRestart: () async {
                            draftService.saveDraft(
                              sessionId,
                              chatInputController.text,
                            );
                          },
                        ),
                      ),
                    ),
                    floatingButtonBuilder: (overlayHeight) {
                      if (!scroll.isScrolledUp) return const SizedBox.shrink();
                      return Positioned(
                        right: 12,
                        bottom: overlayHeight + 12,
                        child: ScrollToBottomButton(
                          onPressed: () {
                            if (scroll.controller.hasClients) {
                              scroll.controller.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      );
                    },
                    contentBuilder: (overlayHeight) => ChatMessageList(
                      sessionId: sessionId,
                      scrollController: scroll.controller,
                      httpBaseUrl: context.read<BridgeService>().httpBaseUrl,
                      projectPath: projectPath,
                      onRetryMessage: (entry) {
                        context.read<ChatSessionCubit>().retryMessage(entry);
                      },
                      onRewindMessage: null,
                      scrollToUserEntry: scrollToUserEntry,
                      collapseToolResults: collapseToolResults,
                      bottomPadding: 8,
                      isCodex: true,
                      onFilePeekOpened: context
                          .read<ChatSessionCubit>()
                          .recordPeekedFile,
                    ),
                  ),
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
                    onOpenGitScreen: projectPath != null
                        ? (_) => _openGitScreen(
                            context,
                            worktreePath ?? projectPath!,
                            diffSelectionFromNav,
                            sessionId: sessionId,
                            worktreePath: worktreePath,
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

Widget? _sessionAppBarLeading(
  BuildContext context,
  WorkspaceShellScreenState? shell, {
  VoidCallback? onBackToSessions,
  bool hideAppBarLeading = false,
}) {
  if (hideAppBarLeading) {
    return null;
  }
  if (onBackToSessions != null) {
    return BackButton(
      key: const ValueKey('session_back_button'),
      onPressed: onBackToSessions,
    );
  }
  if (shell?.shouldShowLeftPaneButton ?? false) {
    final theme = Theme.of(context);
    final fabTheme = theme.floatingActionButtonTheme;
    return IconButton.filled(
      key: const ValueKey('show_left_pane_button'),
      onPressed: shell!.toggleLeftPaneVisibility,
      tooltip: 'Show sessions',
      style: IconButton.styleFrom(
        backgroundColor:
            fabTheme.backgroundColor ?? theme.colorScheme.primaryContainer,
        foregroundColor:
            fabTheme.foregroundColor ?? theme.colorScheme.onPrimaryContainer,
      ),
      icon: const Icon(Icons.chevron_right),
    );
  }
  return BackButton(
    key: const ValueKey('session_back_button'),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

double? _sessionAppBarLeadingWidth(
  WorkspaceShellScreenState? shell, {
  VoidCallback? onBackToSessions,
  bool hideAppBarLeading = false,
}) {
  if (hideAppBarLeading) {
    return null;
  }
  if (onBackToSessions != null) {
    return null;
  }
  return shell?.shouldShowLeftPaneButton ?? false ? 64 : null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _openGitScreen(
  BuildContext context,
  String projectPath,
  ValueNotifier<DiffSelection?> diffSelectionNotifier, {
  String? sessionId,
  String? worktreePath,
}) async {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitPane(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
      diffSelectionNotifier: diffSelectionNotifier,
    );
    return;
  }
  final selection = await context.router.push<DiffSelection>(
    GitRoute(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
    ),
  );
  if (selection != null) {
    diffSelectionNotifier.value = selection.isEmpty ? null : selection;
  }
}

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required String sessionId,
  required bool isBackground,
  required ApprovalState approval,
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
          final permission = _notificationPermissionFor(approval);
          if (permission != null) {
            NotificationService.instance.showApprovalNotification(
              permission,
              id: 1,
              payload: sessionId,
            );
          }
        }
      case ChatSideEffect.notifyAskQuestion:
        if (isBackground) {
          final permission = _notificationPermissionFor(approval);
          if (permission != null) {
            NotificationService.instance.showApprovalNotification(
              permission,
              id: 2,
              payload: sessionId,
            );
          }
        }
      case ChatSideEffect.notifySessionComplete:
        if (isBackground) {
          NotificationService.instance.showSessionCompleteNotification(
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

PermissionRequestMessage? _notificationPermissionFor(ApprovalState approval) {
  return switch (approval) {
    ApprovalPermission(:final request) => request,
    ApprovalAskUser(:final toolUseId, :final input) => PermissionRequestMessage(
      toolUseId: toolUseId,
      toolName: 'AskUserQuestion',
      input: input,
    ),
    ApprovalNone() => null,
    _ => null,
  };
}

Future<void> _openInTerminal(BuildContext context, String? projectPath) async {
  if (!FeatureFlags.current.isEnabled(AppFeature.terminalAppIntegration)) {
    return;
  }
  if (projectPath == null) return;
  final config = context.read<SettingsCubit>().state.terminalApp;
  if (!config.isConfigured) return;

  final bridge = context.read<BridgeService>();
  final url = bridge.lastUrl;
  final uri = url != null
      ? Uri.tryParse(
          url
              .replaceFirst('ws://', 'http://')
              .replaceFirst('wss://', 'https://'),
        )
      : null;
  final host = uri?.host ?? '';

  // Resolve SSH user from machine config
  String? sshUser;
  try {
    final machines = context.read<MachineManagerCubit>().state.machines;
    for (final item in machines) {
      if (item.machine.host == host) {
        sshUser = item.machine.sshUsername;
        break;
      }
    }
  } catch (_) {
    // MachineManagerCubit may not be available
  }

  final launched = await launchTerminalApp(
    config: config,
    host: host,
    sshUser: sshUser,
    projectPath: projectPath,
  );

  if (!launched && context.mounted) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.terminalAppNotInstalled)));
  }
}

Future<void> _renameSession(BuildContext context, String sessionId) async {
  final bridge = context.read<BridgeService>();
  final sessions = bridge.sessions;
  final session = sessions.where((s) => s.id == sessionId).firstOrNull;
  final newName = await showRenameSessionDialog(
    context,
    currentName: session?.name,
  );
  if (newName == null || !context.mounted) return;
  bridge.renameSession(
    sessionId: sessionId,
    name: newName.isEmpty ? null : newName,
  );
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

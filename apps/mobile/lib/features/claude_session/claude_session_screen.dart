import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../constants/feature_flags.dart';
import '../../hooks/use_app_resume_callback.dart';
import '../../hooks/use_keyboard_scroll_adjustment.dart';
import '../../hooks/use_scroll_tracking.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../services/chat_message_handler.dart';
import '../../services/draft_service.dart';
import '../../utils/composer_tokens.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import '../../utils/terminal_launcher.dart';
import '../session_list/workspace_shell_screen.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/approval_bar.dart';
import '../../widgets/bubbles/ask_user_question_widget.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/new_session_sheet.dart'
    show permissionModeFromRaw, sandboxModeFromRaw;
import '../../widgets/plan_detail_sheet.dart';
import '../../widgets/rename_session_dialog.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/session_name_title.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../chat_session/state/chat_session_state.dart';
import '../chat_session/state/streaming_state_cubit.dart';
import '../chat_session/widgets/bottom_overlay_layout.dart';
import '../chat_session/widgets/chat_input_with_overlays.dart';
import '../chat_session/widgets/chat_message_list.dart';
import '../chat_session/widgets/reconnect_banner.dart';
import '../chat_session/widgets/scroll_to_bottom_button.dart';
import '../chat_session/widgets/session_mode_bar.dart';
import '../chat_session/widgets/status_line_flexible_space.dart';
import '../explore/state/explore_state.dart';
import 'widgets/rewind_action_sheet.dart';
import 'widgets/rewind_message_list_sheet.dart' show UserMessageHistorySheet;
import 'widgets/usage_summary_bar.dart';

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

/// Outer widget that creates screen-scoped [ChatSessionCubit] and
/// [StreamingStateCubit] via [MultiBlocProvider], replacing Riverpod's
/// Family (autoDispose) pattern.
///
/// When [isPending] is true, shows a loading overlay until [session_created]
/// is received from the bridge, then swaps to the real session.
@RoutePage()
class ClaudeSessionScreen extends StatefulWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialPermissionMode;
  final String? initialSandboxMode;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  /// Notifier from the parent that may already hold a [SystemMessage]
  /// with subtype `session_created` (race condition fix).
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  const ClaudeSessionScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  State<ClaudeSessionScreen> createState() => _ClaudeSessionScreenState();
}

@RoutePage(name: 'WorkspaceClaudeSessionRoute')
class WorkspaceClaudeSessionScreen extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialPermissionMode;
  final String? initialSandboxMode;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const WorkspaceClaudeSessionScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClaudeSessionScreen(
      sessionId: sessionId,
      projectPath: projectPath,
      gitBranch: gitBranch,
      worktreePath: worktreePath,
      isPending: isPending,
      initialPermissionMode: initialPermissionMode,
      initialSandboxMode: initialSandboxMode,
      pendingSessionCreated: pendingSessionCreated,
      onBackToSessions: onBackToSessions,
      hideAppBarLeading: hideAppBarLeading,
    );
  }
}

class _ClaudeSessionScreenState extends State<ClaudeSessionScreen> {
  late String _sessionId;
  late String? _projectPath;
  late String? _worktreePath;
  late String? _gitBranch;
  late bool _isPending;
  var _explorerCurrentPath = '';
  List<String> _recentPeekedFiles = const [];
  PermissionMode? _permissionMode;
  SandboxMode? _sandboxMode;
  StreamSubscription<ServerMessage>? _pendingSub;
  StreamSubscription<ServerMessage>? _sessionSwitchSub;
  StreamSubscription<String>? _sessionStoppedSub;

  @override
  void initState() {
    super.initState();
    final bridge = context.read<BridgeService>();
    _sessionId = widget.sessionId;
    _projectPath = widget.projectPath;
    _worktreePath = widget.worktreePath;
    _gitBranch = widget.gitBranch;
    _isPending = widget.isPending;
    _permissionMode = permissionModeFromRaw(widget.initialPermissionMode);
    _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);
    final explorerHistory = bridge.getExplorerHistory(_sessionId);
    _explorerCurrentPath = explorerHistory.currentPath;
    _recentPeekedFiles = explorerHistory.recentPeekedFiles;

    if (_isPending) {
      _listenForSessionCreated();
    }
    _listenForSessionSwitch();
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
        // Filter by projectPath to avoid picking up another session's event
        if (widget.projectPath != null &&
            msg.projectPath != null &&
            msg.projectPath != widget.projectPath) {
          return;
        }
        if (msg.sessionId != null && mounted) {
          _resolveSession(msg);
        }
      } else if (msg is ErrorMessage && _isPending && mounted) {
        _pendingSub?.cancel();
        _pendingSub = null;
        widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
        final errorText = msg.message;
        context.router.maybePop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorText)));
      }
    });
  }

  void _onPendingSessionCreated() {
    final msg = widget.pendingSessionCreated?.value;
    if (msg != null && msg.sessionId != null && mounted && _isPending) {
      _resolveSession(msg);
    }
  }

  /// Listen for session switches (clear context, rewind, etc.).
  /// When the bridge destroys the old session and creates a new one with
  /// sourceSessionId pointing to this session, we switch seamlessly.
  void _listenForSessionSwitch() {
    final bridge = context.read<BridgeService>();
    _sessionSwitchSub = bridge.messages.listen((msg) {
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
      _worktreePath = msg.worktreePath ?? _worktreePath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
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

  /// Switch to a new session (e.g. after clear context / sandbox toggle).
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
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
  }

  @override
  void didUpdateWidget(covariant ClaudeSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId &&
        oldWidget.projectPath == widget.projectPath &&
        oldWidget.worktreePath == widget.worktreePath &&
        oldWidget.gitBranch == widget.gitBranch &&
        oldWidget.isPending == widget.isPending &&
        oldWidget.initialPermissionMode == widget.initialPermissionMode &&
        oldWidget.initialSandboxMode == widget.initialSandboxMode) {
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
      _permissionMode = permissionModeFromRaw(widget.initialPermissionMode);
      _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
  }

  @override
  void dispose() {
    widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
    _pendingSub?.cancel();
    _sessionSwitchSub?.cancel();
    _sessionStoppedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending) {
      final l = AppLocalizations.of(context);
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(l.creatingSession, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return _ChatScreenProviders(
      key: ValueKey(_sessionId),
      sessionId: _sessionId,
      projectPath: _projectPath,
      gitBranch: _gitBranch,
      worktreePath: _worktreePath,
      explorerCurrentPath: _explorerCurrentPath,
      recentPeekedFiles: _recentPeekedFiles,
      permissionMode: _permissionMode,
      sandboxMode: _sandboxMode,
      onBackToSessions: widget.onBackToSessions,
      hideAppBarLeading: widget.hideAppBarLeading,
    );
  }
}

/// Wrapper that creates screen-scoped cubits once per session.
class _ChatScreenProviders extends StatelessWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final String explorerCurrentPath;
  final List<String> recentPeekedFiles;
  final PermissionMode? permissionMode;
  final SandboxMode? sandboxMode;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const _ChatScreenProviders({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.explorerCurrentPath = '',
    this.recentPeekedFiles = const [],
    this.permissionMode,
    this.sandboxMode,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
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
            provider: Provider.claude,
            bridge: bridge,
            streamingCubit: streamingCubit,
            initialExplorerCurrentPath: explorerCurrentPath,
            initialRecentPeekedFiles: recentPeekedFiles,
            initialPermissionMode: permissionMode,
            initialSandboxMode: sandboxMode,
          ),
        ),
        BlocProvider.value(value: streamingCubit),
      ],
      child: _ChatScreenBody(
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

class _ChatScreenBody extends HookWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final VoidCallback? onBackToSessions;
  final bool hideAppBarLeading;

  const _ChatScreenBody({
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.onBackToSessions,
    this.hideAppBarLeading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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

    // Plan feedback controller (for plan approval rejection message)
    final planFeedbackController = useTextEditingController();

    // Chat input controller (managed here to preserve text across rebuilds)
    final chatInputController = useMemoized(ComposerTextEditingController.new);
    useEffect(() => chatInputController.dispose, [chatInputController]);
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

    // Collapse tool results notifier
    final collapseToolResults = useMemoized(() => ValueNotifier<int>(0));
    useEffect(() => collapseToolResults.dispose, const []);

    // Scroll-to-user-entry notifier (set by message history sheet)
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
    final tokenUsage = _collectTokenUsage(sessionState.entries);
    final toolUsage = _collectToolUsage(sessionState.entries);

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
    // If still connected, refresh history directly (BlocListener won't fire).
    // If disconnected, ensureConnected triggers reconnect → BlocListener
    // fires → refreshHistory is called there.
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

    // --- Action callbacks ---
    void approveToolUse() {
      if (pendingToolUseId == null) return;
      context.read<ChatSessionCubit>().approve(pendingToolUseId);
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
          // Cmd+Shift+P: cycle permission mode
          const SingleActivator(
            LogicalKeyboardKey.keyP,
            meta: true,
            shift: true,
          ): () {
            final cubit = context.read<ChatSessionCubit>();
            showPermissionModeMenu(context, cubit);
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
                                _ClaudeSessionScreenState
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
                        return [
                          PopupMenuItem(
                            key: const ValueKey('menu_rename'),
                            value: 'rename',
                            child: ListTile(
                              leading: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                              ),
                              title: Text(l.rename),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            key: const ValueKey('menu_message_history'),
                            value: 'history',
                            child: ListTile(
                              leading: const Icon(
                                Icons.chat_outlined,
                                size: 20,
                              ),
                              title: Text(l.messageHistory),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (projectPath != null)
                            PopupMenuItem(
                              key: const ValueKey('menu_screenshot'),
                              value: 'screenshot',
                              child: ListTile(
                                leading: const Icon(
                                  Icons.screenshot_monitor,
                                  size: 20,
                                ),
                                title: Text(l.screenshot),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          PopupMenuItem(
                            key: const ValueKey('menu_gallery'),
                            value: 'gallery',
                            child: ListTile(
                              leading: const Icon(Icons.collections, size: 20),
                              title: Text(l.gallery),
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
                UsageSummaryBar(
                  totalCost: sessionState.totalCost,
                  totalDuration: sessionState.totalDuration,
                  inputTokens: tokenUsage.inputTokens,
                  cachedInputTokens: tokenUsage.cachedInputTokens,
                  outputTokens: tokenUsage.outputTokens,
                  toolCalls: toolUsage.toolCalls,
                  fileEdits: toolUsage.fileEdits,
                ),
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
                                  if (askToolUseId != null && askInput != null)
                                    AskUserQuestionWidget(
                                      toolUseId: askToolUseId,
                                      input: askInput,
                                      agentName: 'Claude',
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
                      onRewindMessage: (entry) {
                        _showRewindActionSheet(context, entry);
                      },
                      collapseToolResults: collapseToolResults,
                      scrollToUserEntry: scrollToUserEntry,
                      bottomPadding: 8,
                      isCodex: false,
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
                    initialDiffSelection: diffSelectionFromNav.value,
                    onDiffSelectionConsumed: () {
                      // Don't null — keep for AppBar navigation.
                      // The value is cleared via onDiffSelectionCleared.
                    },
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
// Navigation helpers
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

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required String sessionId,
  required bool isBackground,
  required ApprovalState approval,
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
            body: 'Session done',
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
      onRewindMessage: (msg) => _showRewindActionSheet(context, msg),
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

({int inputTokens, int cachedInputTokens, int outputTokens}) _collectTokenUsage(
  List<ChatEntry> entries,
) {
  var inputTokens = 0;
  var cachedInputTokens = 0;
  var outputTokens = 0;

  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    final msg = entry.message;
    if (msg is! ResultMessage) continue;
    inputTokens += msg.inputTokens ?? 0;
    cachedInputTokens += msg.cachedInputTokens ?? 0;
    outputTokens += msg.outputTokens ?? 0;
  }

  return (
    inputTokens: inputTokens,
    cachedInputTokens: cachedInputTokens,
    outputTokens: outputTokens,
  );
}

({int toolCalls, int fileEdits}) _collectToolUsage(List<ChatEntry> entries) {
  var toolCalls = 0;
  var fileEdits = 0;

  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    final msg = entry.message;
    if (msg is! ResultMessage) continue;
    toolCalls += msg.toolCalls ?? 0;
    fileEdits += msg.fileEdits ?? 0;
  }

  return (toolCalls: toolCalls, fileEdits: fileEdits);
}

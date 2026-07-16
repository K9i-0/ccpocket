import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../utils/codex_plan_update.dart';
import '../../services/notification_service.dart';
import '../../widgets/session_name_title.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../../utils/diff_parser.dart';
import '../../utils/network_endpoint.dart';
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
import '../git/state/git_status_cubit.dart';
import '../git/state/git_view_cache_service.dart';
import '../../router/app_router.dart';
import '../claude_session/widgets/rewind_message_list_sheet.dart'
    show UserMessageHistorySheet;
import 'state/codex_session_cubit.dart';
import 'widgets/codex_goal_card.dart';
import 'widgets/codex_rewind_dialog.dart';
import 'widgets/tool_suggestion_card.dart';

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
/// Simpler than [ClaudeSessionScreen].
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
  final String? initialApprovalsReviewer;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

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
    this.initialApprovalsReviewer,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
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
  final String? initialApprovalsReviewer;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

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
    this.initialApprovalsReviewer,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
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
      initialApprovalsReviewer: initialApprovalsReviewer,
      pendingSessionCreated: pendingSessionCreated,
      onBackToSessions: onBackToSessions,
      hideSessionBackButton: hideSessionBackButton,
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
  String? _codexApprovalsReviewer;
  CodexPermissionsMode? _codexPermissionsMode;
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
    _codexApprovalsReviewer = widget.initialApprovalsReviewer;
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
      _codexApprovalsReviewer =
          msg.approvalsReviewer ?? _codexApprovalsReviewer;
      _codexPermissionsMode =
          codexPermissionsModeFromRaw(msg.codexPermissionsMode) ??
          _codexPermissionsMode;
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
      _codexApprovalsReviewer =
          msg.approvalsReviewer ?? _codexApprovalsReviewer;
      _codexPermissionsMode =
          codexPermissionsModeFromRaw(msg.codexPermissionsMode) ??
          _codexPermissionsMode;
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
        oldWidget.initialApprovalPolicy == widget.initialApprovalPolicy &&
        oldWidget.initialApprovalsReviewer == widget.initialApprovalsReviewer) {
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
      _codexApprovalsReviewer = widget.initialApprovalsReviewer;
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
      final chrome = _resolveSessionPaneChrome(context, shell);
      final leading = _sessionAppBarLeading(
        context,
        shell,
        chrome: chrome,
        onBackToSessions: widget.onBackToSessions,
        hideSessionBackButton: widget.hideSessionBackButton,
      );
      return Scaffold(
        appBar: chrome.wrapAppBar(
          AppBar(
            toolbarHeight: chrome.toolbarHeight,
            leading: chrome.wrapLeading(leading),
            automaticallyImplyLeading: false,
            leadingWidth: chrome.resolveLeadingWidth(
              hasLeading: leading != null,
              baseWidth: chrome.useMacOSAdaptiveChrome
                  ? kWorkspaceMacOSToolbarLeadingSlotWidth
                  : 64,
            ),
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
      codexApprovalsReviewer: _codexApprovalsReviewer,
      codexPermissionsMode: _codexPermissionsMode,
      onBackToSessions: widget.onBackToSessions,
      hideSessionBackButton: widget.hideSessionBackButton,
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
  final String? codexApprovalsReviewer;
  final CodexPermissionsMode? codexPermissionsMode;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

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
    this.codexApprovalsReviewer,
    this.codexPermissionsMode,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StreamingStateCubit()),
        // Register as ChatSessionCubit so shared widgets can find it.
        BlocProvider<ChatSessionCubit>(
          create: (context) => CodexSessionCubit(
            sessionId: sessionId,
            bridge: bridge,
            streamingCubit: context.read<StreamingStateCubit>(),
            initialExplorerCurrentPath: explorerCurrentPath,
            initialRecentPeekedFiles: recentPeekedFiles,
            initialSandboxMode: sandboxMode,
            initialPermissionMode: permissionMode,
            initialCodexApprovalPolicy: codexApprovalPolicy,
            initialCodexApprovalsReviewer: codexApprovalsReviewer,
            initialCodexPermissionsMode: codexPermissionsMode,
            initialProjectPath: projectPath,
          ),
        ),
      ],
      child: _CodexChatBody(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        onBackToSessions: onBackToSessions,
        hideSessionBackButton: hideSessionBackButton,
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
  final bool hideSessionBackButton;

  const _CodexChatBody({
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final bridge = context.read<BridgeService>();
    final shell = WorkspaceShellScreen.maybeOf(context);
    final presentationListenable = shell?.presentationListenable;
    // Mutable branch state (refreshed from Bridge)
    final currentBranch = useState(gitBranch);
    final showRemoteGitStatusBadge = context.select(
      (SettingsCubit cubit) => cubit.state.showRemoteGitStatusBadge,
    );

    // Custom hooks
    final lifecycleState = useAppLifecycleState();
    final isBackground =
        lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
    final isBackgroundRef = useRef(isBackground);
    isBackgroundRef.value = isBackground;
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
    final codexCliJoinCommand = useState(
      _latestCodexCliJoinCommand(bridge.cachedSessionMessages(sessionId)),
    );

    // --- Bloc state ---
    final chatSessionCubit = context.read<ChatSessionCubit>();
    final sessionState = context.watch<ChatSessionCubit>().state;
    final bridgeState = context.watch<ConnectionCubit>().state;
    final effectiveProjectPath = _firstNonEmptyProjectPath(
      projectPath,
      sessionState.projectPath,
    );
    final gitProjectPath = worktreePath ?? effectiveProjectPath;
    final gitBadgeTone = _gitBadgeToneOf(
      context,
      sessionId,
      gitProjectPath,
      showRemoteGitStatusBadge: showRemoteGitStatusBadge,
    );
    final parentState = context
        .findAncestorStateOfType<_CodexSessionScreenState>();
    final canCopyCodexCliJoinCommand =
        codexCliJoinCommand.value != null &&
        _hasSentUserMessage(sessionState.entries);
    void handleExploreResult(ExploreScreenResult result) {
      if (!context.mounted) return;
      parentState?.updateExplorerState(
        currentPath: result.currentPath,
        recentPeekedFiles: result.recentPeekedFiles,
      );
      final cubit = context.read<ChatSessionCubit>();
      cubit.setExplorerCurrentPath(result.currentPath);
      cubit.setRecentPeekedFiles(result.recentPeekedFiles);
    }

    void handleFilePeekOpened(String filePath) {
      if (!context.mounted) return;
      final currentPath =
          parentState?._explorerCurrentPath ?? sessionState.explorerCurrentPath;
      final recentPeekedFiles = updateRecentPeekedFiles(
        parentState?._recentPeekedFiles ?? sessionState.recentPeekedFiles,
        filePath,
      );
      parentState?.updateExplorerState(
        currentPath: currentPath,
        recentPeekedFiles: recentPeekedFiles,
      );
      context.read<ChatSessionCubit>().setRecentPeekedFiles(recentPeekedFiles);
    }

    useEffect(() {
      final shell = WorkspaceShellScreen.maybeOf(context);
      shell?.registerSessionToolPaneBindings(
        sessionId: sessionId,
        diffSelectionNotifier: diffSelectionFromNav,
        onExploreResultChanged: handleExploreResult,
        onFilePeekOpened: handleFilePeekOpened,
      );
      return () => shell?.unregisterSessionToolPaneBindings(sessionId);
    }, [sessionId]);

    useEffect(() {
      final sub = bridge.messagesForSession(sessionId).listen((msg) {
        if (msg case SystemMessage(
          sessionId: final messageSessionId?,
          :final codexCliJoin,
        ) when messageSessionId == sessionId) {
          final command = codexCliJoin?.command.trim();
          if (codexCliJoin?.isValid == true &&
              command != null &&
              command.isNotEmpty) {
            codexCliJoinCommand.value = command;
          }
        }
      });
      return sub.cancel;
    }, [sessionId]);

    // --- Side effects subscription ---
    useEffect(() {
      final sub = chatSessionCubit.sideEffects.listen(
        (effects) => _executeSideEffects(
          effects,
          sessionId: sessionId,
          isBackground: isBackgroundRef.value,
          approval: chatSessionCubit.state.approval,
          l: l,
          collapseToolResults: collapseToolResults,
          planFeedbackController: planFeedbackController,
          scrollToBottom: scroll.scrollToBottom,
        ),
      );
      return sub.cancel;
    }, [sessionId]);

    // --- Initial requests on mount ---
    useEffect(
      () {
        final bridge = context.read<BridgeService>();
        final path = gitProjectPath;
        if (!isBackground && effectiveProjectPath != null) {
          bridge.requestFileList(effectiveProjectPath);
        }
        if (!isBackground && path != null && path.isNotEmpty) {
          try {
            context.read<GitStatusCubit>().refresh(
              sessionId: sessionId,
              projectPath: path,
              includeRemote: showRemoteGitStatusBadge,
            );
          } catch (_) {}
        }
        if (!isBackground) {
          bridge.requestSessionList();
          bridge.refreshBranch(sessionId);
        }
        return null;
      },
      [
        sessionId,
        effectiveProjectPath,
        gitProjectPath,
        showRemoteGitStatusBadge,
      ],
    );

    useEffect(
      () {
        if (effectiveProjectPath == null) return null;

        final bridge = context.read<BridgeService>();
        GitStatusCubit? gitStatusCubit;
        GitViewCacheService? gitViewCache;
        try {
          gitStatusCubit = context.read<GitStatusCubit>();
          gitViewCache = context.read<GitViewCacheService>();
        } catch (_) {}
        final sub = bridge.messagesForSession(sessionId).listen((msg) {
          if (isBackgroundRef.value) return;
          if (msg case ToolResultMessage(
            :final toolName,
          ) when _fileListRefreshToolNames.contains(toolName)) {
            bridge.requestFileList(effectiveProjectPath);
          } else if (msg case ResultMessage(:final fileEdits)) {
            if ((fileEdits ?? 0) > 0) {
              bridge.requestFileList(effectiveProjectPath);
            }
            gitStatusCubit?.refresh(
              sessionId: sessionId,
              projectPath: gitProjectPath!,
              includeRemote: showRemoteGitStatusBadge,
            );
            gitViewCache?.refreshIfPresent(sessionId);
          }
        });
        return sub.cancel;
      },
      [
        sessionId,
        effectiveProjectPath,
        gitProjectPath,
        showRemoteGitStatusBadge,
      ],
    );

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
    // Only triggers on genuine resume from paused/hidden/detached, not from
    // inactive (e.g. Android notification shade).
    useAppResumeCallback(lifecycleState, () {
      final bridge = context.read<BridgeService>();
      bridge.ensureConnected();
      if (bridge.isConnected) {
        final cubit = context.read<ChatSessionCubit>();
        cubit.refreshHistory();
        cubit.requestGoal();
        if (effectiveProjectPath != null) {
          bridge.requestFileList(effectiveProjectPath);
        }
        if (gitProjectPath != null && gitProjectPath.isNotEmpty) {
          try {
            context.read<GitStatusCubit>().refresh(
              sessionId: sessionId,
              projectPath: gitProjectPath,
              includeRemote: showRemoteGitStatusBadge,
            );
          } catch (_) {}
        }
        bridge.requestSessionList();
        bridge.refreshBranch(sessionId);
      }
    });

    // --- Destructure state ---
    final status = sessionState.status;
    final approval = sessionState.approval;
    final inPlanMode = sessionState.inPlanMode;
    final queuedInput = sessionState.queuedInput;
    final currentGoal = _goalCardData(sessionState.goal);

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
    final isToolSuggestion = pendingPermission?.isToolSuggestion ?? false;

    Future<void> openToolSuggestionUrl(String rawUrl) async {
      final uri = Uri.tryParse(rawUrl);
      final launched =
          uri != null &&
          uri.hasAuthority &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.toolSuggestionOpenFailed)));
      }
    }

    void installSuggestedTool() {
      if (pendingToolUseId == null || pendingPermission == null) return;
      context.read<ChatSessionCubit>().installToolSuggestion(pendingToolUseId);
      final installUrl = pendingPermission.toolSuggestionInstallUrl;
      if (pendingPermission.toolSuggestionType == 'connector' &&
          installUrl != null &&
          installUrl.isNotEmpty) {
        unawaited(openToolSuggestionUrl(installUrl));
      }
    }

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
            showCodexPermissionsMenu(context, cubit);
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
              final chrome = _resolveSessionPaneChrome(context, currentShell);
              final leading = _sessionAppBarLeading(
                context,
                currentShell,
                chrome: chrome,
                onBackToSessions: onBackToSessions,
                hideSessionBackButton: hideSessionBackButton,
              );
              final showMessageHistoryAction = !isSinglePane;
              final double defaultTitleSpacing = isSinglePane
                  ? NavigationToolbar.kMiddleSpacing
                  : (leading == null ? 16 : 12);

              return Scaffold(
                appBar: chrome.wrapAppBar(
                  AppBar(
                    toolbarHeight: chrome.toolbarHeight,
                    leading: chrome.wrapLeading(leading),
                    automaticallyImplyLeading: false,
                    leadingWidth: chrome.resolveLeadingWidth(
                      hasLeading: leading != null,
                      baseWidth: chrome.useMacOSAdaptiveChrome
                          ? kWorkspaceMacOSToolbarLeadingSlotWidth
                          : 64.0,
                    ),
                    titleSpacing: chrome.resolveTitleSpacing(
                      hasLeading: leading != null,
                      fallback: defaultTitleSpacing,
                    ),
                    title: chrome.wrapTitle(
                      SessionNameTitle(
                        sessionId: sessionId,
                        projectPath: effectiveProjectPath,
                      ),
                    ),
                    flexibleSpace: StatusLineFlexibleSpace(
                      status: status,
                      inPlanMode: inPlanMode,
                    ),
                    actions: [
                      if (effectiveProjectPath != null)
                        IconButton(
                          key: const ValueKey('appbar_explore_button'),
                          icon: Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Explore',
                          onPressed: () async {
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
                                projectPath: effectiveProjectPath,
                                initialFiles: context
                                    .read<FileListCubit>()
                                    .state,
                                initialPath: initialPath,
                                recentPeekedFiles: recentPeekedFiles,
                                onResultChanged: handleExploreResult,
                              );
                              return;
                            }
                            final result = await context.router.push(
                              ExploreRoute(
                                sessionId: sessionId,
                                projectPath: effectiveProjectPath,
                                initialFiles: context
                                    .read<FileListCubit>()
                                    .state,
                                initialPath: initialPath,
                                recentPeekedFiles: recentPeekedFiles,
                              ),
                            );
                            if (result is! ExploreScreenResult ||
                                !context.mounted) {
                              return;
                            }
                            handleExploreResult(result);
                          },
                        ),
                      if (effectiveProjectPath != null)
                        IconButton(
                          key: const ValueKey('appbar_view_changes'),
                          icon: Badge(
                            isLabelVisible: gitBadgeTone != null,
                            backgroundColor: _gitBadgeColor(
                              context,
                              gitBadgeTone,
                            ),
                            smallSize: 8,
                            child: Icon(
                              Icons.difference,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            _openGitScreen(
                              context,
                              worktreePath ?? effectiveProjectPath,
                              diffSelectionFromNav,
                              sessionId: sessionId,
                              worktreePath: worktreePath,
                              onFilePeekOpened: handleFilePeekOpened,
                            );
                          },
                        ),
                      if (showMessageHistoryAction)
                        IconButton(
                          key: const ValueKey('appbar_message_history_button'),
                          icon: Icon(
                            Icons.history,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: l.messageHistory,
                          onPressed: () {
                            _showUserMessageHistory(
                              context,
                              scrollToUserEntry,
                              sessionId,
                              chatInputController,
                              draftService,
                            );
                          },
                        ),
                      if (canCopyCodexCliJoinCommand)
                        IconButton(
                          key: const ValueKey('appbar_copy_codex_join_button'),
                          icon: Icon(
                            Icons.terminal,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Copy Codex CLI join command',
                          onPressed: () => _copyCodexCliJoinCommand(
                            context,
                            codexCliJoinCommand.value!,
                          ),
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
                              _showUserMessageHistory(
                                context,
                                scrollToUserEntry,
                                sessionId,
                                chatInputController,
                                draftService,
                              );
                            case 'screenshot':
                              if (effectiveProjectPath == null) return;
                              showScreenshotSheet(
                                context: context,
                                bridge: context.read<BridgeService>(),
                                projectPath: effectiveProjectPath,
                                sessionId: sessionId,
                              );
                            case 'gallery':
                              _openGalleryScreen(context, sessionId: sessionId);
                            case 'rename':
                              _renameSession(context, sessionId);
                            case 'terminal':
                              _openInTerminal(context, effectiveProjectPath);
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
                            if (!showMessageHistoryAction)
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
                            if (effectiveProjectPath != null)
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
                                effectiveProjectPath != null)
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
                                  if (pendingToolUseId != null &&
                                      isToolSuggestion &&
                                      pendingPermission != null)
                                    ToolSuggestionCard(
                                      key: ValueKey(
                                        'tool_suggestion_$pendingToolUseId',
                                      ),
                                      appColors: appColors,
                                      permission: pendingPermission,
                                      onInstall: installSuggestedTool,
                                      onComplete: approveToolUse,
                                      onReject: rejectToolUse,
                                      onOpenUrl: (url) =>
                                          unawaited(openToolSuggestionUrl(url)),
                                    ),
                                  if (pendingToolUseId != null &&
                                      !isToolSuggestion)
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
                      projectPath: effectiveProjectPath,
                      onRetryMessage: null,
                      onRewindMessage: (entry) {
                        _showCodexRewindDialog(
                          context,
                          entry,
                          sessionId: sessionId,
                          inputController: chatInputController,
                          draftService: draftService,
                        );
                      },
                      onForkMessage: (message) {
                        unawaited(_forkCodexFromAssistant(context, message));
                      },
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
                  if (currentGoal != null)
                    CodexGoalCard(
                      goal: currentGoal,
                      onEdit: () => unawaited(
                        _showCodexGoalEditor(
                          context,
                          sessionState.goal?.objective ?? currentGoal.objective,
                        ),
                      ),
                      onTogglePaused: () =>
                          context.read<ChatSessionCubit>().toggleGoalPaused(),
                      onClear: () => unawaited(_confirmCodexGoalClear(context)),
                    ),
                if (approval is ApprovalNone)
                  if (queuedInput != null)
                    CodexQueuedInputPanel(
                      item: queuedInput,
                      isOfflinePending: ChatSessionCubit.isOfflineQueuedInput(
                        queuedInput,
                      ),
                      isDeliveryPending:
                          ChatSessionCubit.isDeliveryPendingQueuedInput(
                            queuedInput,
                          ),
                      onSteer:
                          ChatSessionCubit.isOfflineQueuedInput(queuedInput) ||
                              ChatSessionCubit.isDeliveryPendingQueuedInput(
                                queuedInput,
                              )
                          ? null
                          : () => context
                                .read<ChatSessionCubit>()
                                .steerQueuedInput(queuedInput),
                      onEdit: () => moveQueuedInputToComposer(
                        inputController: chatInputController,
                        item: queuedInput,
                        cancelQueuedInput: () => context
                            .read<ChatSessionCubit>()
                            .cancelQueuedInput(queuedInput),
                      ),
                      onCancel: () => context
                          .read<ChatSessionCubit>()
                          .cancelQueuedInput(queuedInput),
                    ),
                if (approval is ApprovalNone)
                  ChatInputWithOverlays(
                    sessionId: sessionId,
                    status: status,
                    onScrollToBottom: scroll.scrollToBottom,
                    inputController: chatInputController,
                    hintText: l.codexMessagePlaceholder,
                    inputBlocked: queuedInput != null,
                    initialDiffSelection: diffSelectionFromNav.value,
                    onDiffSelectionConsumed: () {},
                    onDiffSelectionCleared: () =>
                        diffSelectionFromNav.value = null,
                    onOpenGitScreen: effectiveProjectPath != null
                        ? (_) => _openGitScreen(
                            context,
                            worktreePath ?? effectiveProjectPath,
                            diffSelectionFromNav,
                            sessionId: sessionId,
                            worktreePath: worktreePath,
                            onFilePeekOpened: handleFilePeekOpened,
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
  required WorkspacePaneChrome chrome,
  VoidCallback? onBackToSessions,
  bool hideSessionBackButton = false,
}) {
  final l = AppLocalizations.of(context);
  if (!hideSessionBackButton && onBackToSessions != null) {
    return BackButton(
      key: const ValueKey('session_back_button'),
      onPressed: onBackToSessions,
    );
  }
  if (shell?.shouldShowLeftPaneButton ?? false) {
    final theme = Theme.of(context);
    final fabTheme = theme.floatingActionButtonTheme;
    return IconButton(
      key: const ValueKey('show_left_pane_button'),
      onPressed: shell!.toggleLeftPaneVisibility,
      tooltip: l.showSessions,
      style: chrome.useMacOSAdaptiveChrome
          ? chrome.compactButtonStyle()
          : IconButton.styleFrom(
              backgroundColor:
                  fabTheme.backgroundColor ??
                  theme.colorScheme.primaryContainer,
              foregroundColor:
                  fabTheme.foregroundColor ??
                  theme.colorScheme.onPrimaryContainer,
            ),
      icon: const Icon(Icons.chevron_right),
    );
  }
  if (hideSessionBackButton) {
    return null;
  }
  return BackButton(
    key: const ValueKey('session_back_button'),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

WorkspacePaneChrome _resolveSessionPaneChrome(
  BuildContext context,
  WorkspaceShellScreenState? shell,
) {
  return resolveWorkspacePaneChrome(
    platform: Theme.of(context).platform,
    isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
    isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
    slot: WorkspacePaneSlot.center,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

enum _GitBadgeTone { dirty, remote }

String? _firstNonEmptyProjectPath(String? primary, String? fallback) {
  if (primary?.trim().isNotEmpty == true) return primary;
  if (fallback?.trim().isNotEmpty == true) return fallback;
  return null;
}

_GitBadgeTone? _gitBadgeToneOf(
  BuildContext context,
  String sessionId,
  String? projectPath, {
  required bool showRemoteGitStatusBadge,
}) {
  if (projectPath == null || projectPath.isEmpty) return null;
  try {
    return context.select((GitStatusCubit cubit) {
      final entry = cubit.state.entryFor(sessionId);
      if (entry?.projectPath != projectPath) return null;
      if (entry?.showDirtyBadge == true) return _GitBadgeTone.dirty;
      if (entry?.showRemoteBadge(enabled: showRemoteGitStatusBadge) == true) {
        return _GitBadgeTone.remote;
      }
      return null;
    });
  } catch (_) {
    return null;
  }
}

Color? _gitBadgeColor(BuildContext context, _GitBadgeTone? tone) {
  final error = Theme.of(context).colorScheme.error;
  return switch (tone) {
    _GitBadgeTone.dirty => error,
    _GitBadgeTone.remote => error.withValues(alpha: 0.45),
    null => null,
  };
}

Future<void> _openGitScreen(
  BuildContext context,
  String projectPath,
  ValueNotifier<DiffSelection?> diffSelectionNotifier, {
  String? sessionId,
  String? worktreePath,
  ValueChanged<String>? onFilePeekOpened,
}) async {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitPane(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
      diffSelectionNotifier: diffSelectionNotifier,
      onFilePeekOpened: onFilePeekOpened,
    );
    return;
  }
  final selection = await context.router.push<DiffSelection>(
    GitRoute(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
      onFilePeekOpened: onFilePeekOpened,
    ),
  );
  if (selection != null) {
    diffSelectionNotifier.value = selection.isEmpty ? null : selection;
  }
}

void _openGalleryScreen(BuildContext context, {required String sessionId}) {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openSessionGalleryPane(sessionId: sessionId);
    return;
  }
  context.router.push(GalleryRoute(sessionId: sessionId));
}

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required String sessionId,
  required bool isBackground,
  required ApprovalState approval,
  required AppLocalizations l,
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
              l: l,
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
              l: l,
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
  final host = normalizeHostInput(uri?.host ?? '');

  // Resolve SSH user from machine config
  String? sshUser;
  try {
    final machines = context.read<MachineManagerCubit>().state.machines;
    for (final item in machines) {
      if (canonicalHostIdentity(item.machine.host) ==
          canonicalHostIdentity(host)) {
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
  String sessionId,
  TextEditingController inputController,
  DraftService draftService,
) {
  final cubit = context.read<ChatSessionCubit>();
  final messages = cubit.allUserMessages;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    builder: (_) => UserMessageHistorySheet(
      messages: messages,
      onScrollToMessage: (msg) {
        scrollToUserEntry.value = msg;
      },
      onRewindMessage: (msg) => _showCodexRewindDialog(
        context,
        msg,
        sessionId: sessionId,
        inputController: inputController,
        draftService: draftService,
      ),
    ),
  );
}

void _showCodexRewindDialog(
  BuildContext context,
  UserChatEntry message, {
  required String sessionId,
  required TextEditingController inputController,
  required DraftService draftService,
}) {
  final cubit = context.read<ChatSessionCubit>();

  if (message.messageUuid == null) return;

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return CodexRewindDialog(
        messageText: message.text,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          _restoreRewindMessageToComposer(
            inputController: inputController,
            draftService: draftService,
            sessionId: sessionId,
            text: message.text,
          );
          cubit.rewind(message.messageUuid!, 'conversation');
        },
      );
    },
  );
}

Future<void> _forkCodexFromAssistant(
  BuildContext context,
  AssistantServerMessage message,
) async {
  final cubit = context.read<ChatSessionCubit>();
  final l = AppLocalizations.of(context);
  final targetUuid = _previousUserUuidForAssistant(
    cubit.state.entries,
    message,
  );
  if (targetUuid == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.forkTargetNotFound)));
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l.forkConversationTitle),
        content: Text(l.forkConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.fork),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;

  cubit.forkSession(targetUuid);
}

String? _previousUserUuidForAssistant(
  List<ChatEntry> entries,
  AssistantServerMessage message,
) {
  final index = entries.indexWhere(
    (entry) => entry is ServerChatEntry && identical(entry.message, message),
  );
  if (index <= 0) return null;

  for (var i = index - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is UserChatEntry &&
        entry.messageUuid != null &&
        entry.messageUuid!.isNotEmpty) {
      return entry.messageUuid;
    }
  }
  return null;
}

void _restoreRewindMessageToComposer({
  required TextEditingController inputController,
  required DraftService draftService,
  required String sessionId,
  required String text,
}) {
  inputController.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  draftService.saveDraft(sessionId, text);
}

@visibleForTesting
void moveQueuedInputToComposer({
  required TextEditingController inputController,
  required QueuedInputItem item,
  required VoidCallback cancelQueuedInput,
}) {
  cancelQueuedInput();
  inputController.value = TextEditingValue(
    text: item.text,
    selection: TextSelection.collapsed(offset: item.text.length),
  );
}

class CodexQueuedInputPanel extends StatelessWidget {
  const CodexQueuedInputPanel({
    super.key,
    required this.item,
    required this.onSteer,
    required this.onEdit,
    required this.onCancel,
    this.isOfflinePending = false,
    this.isDeliveryPending = false,
  });

  final QueuedInputItem item;
  final VoidCallback? onSteer;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool isOfflinePending;
  final bool isDeliveryPending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final imageLabel = item.imageCount > 0
        ? ' · ${l.queuedInputImageCount(item.imageCount)}'
        : '';
    final title = isOfflinePending
        ? '${l.queuedInputForReconnect}$imageLabel'
        : isDeliveryPending
        ? '${l.queuedInputPendingDelivery}$imageLabel'
        : '${l.queuedInputForNextTurn}$imageLabel';

    return Material(
      key: const ValueKey('codex_queue_panel'),
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.schedule, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDeliveryPending)
                IconButton(
                  key: const ValueKey('codex_queue_steer_button'),
                  tooltip: l.tooltipSteerQueuedMessage,
                  icon: const Icon(Icons.subdirectory_arrow_left, size: 20),
                  onPressed: onSteer,
                ),
              IconButton(
                key: const ValueKey('codex_queue_edit_button'),
                tooltip: l.tooltipMoveQueuedMessageToInput,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                key: const ValueKey('codex_queue_cancel_button'),
                tooltip: l.tooltipCancelQueuedMessage,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

CodexGoalCardData? _goalCardData(CodexGoal? goal) {
  if (goal == null) return null;
  return CodexGoalCardData(
    objective: goal.objective,
    status: switch (goal.status) {
      CodexThreadGoalStatus.active => CodexGoalStatus.active,
      CodexThreadGoalStatus.paused => CodexGoalStatus.paused,
      CodexThreadGoalStatus.blocked => CodexGoalStatus.blocked,
      CodexThreadGoalStatus.usageLimited => CodexGoalStatus.usageLimited,
      CodexThreadGoalStatus.budgetLimited => CodexGoalStatus.budgetLimited,
      CodexThreadGoalStatus.complete => CodexGoalStatus.complete,
    },
  );
}

Future<void> _showCodexGoalEditor(
  BuildContext context,
  String objective,
) async {
  final formKey = GlobalKey<FormState>();
  var nextObjective = objective;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit goal'),
      content: Form(
        key: formKey,
        child: TextFormField(
          key: const ValueKey('goal_objective_field'),
          initialValue: objective,
          onChanged: (value) => nextObjective = value,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Objective',
            hintText: 'What should Codex keep pursuing?',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter a goal objective.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('goal_save_button'),
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.of(dialogContext).pop(true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved != true || !context.mounted) return;
  context.read<ChatSessionCubit>().setGoalObjective(nextObjective);
}

Future<void> _confirmCodexGoalClear(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear goal?'),
      content: const Text('Codex will stop pursuing this goal.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          key: const ValueKey('goal_clear_confirm_button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.read<ChatSessionCubit>().clearGoal();
  }
}

void _retryFailedMessages(BuildContext context) {
  final cubit = context.read<ChatSessionCubit>();
  for (final entry in cubit.state.entries) {
    if (entry is UserChatEntry && entry.status == MessageStatus.failed) {
      cubit.retryMessage(entry);
    }
  }
}

String? _latestCodexCliJoinCommand(List<ServerMessage> messages) {
  for (final msg in messages.reversed) {
    if (msg case SystemMessage(
      :final codexCliJoin,
    ) when codexCliJoin?.isValid == true) {
      return codexCliJoin!.command.trim();
    }
  }
  return null;
}

bool _hasSentUserMessage(List<ChatEntry> entries) {
  return entries.any(
    (entry) => entry is UserChatEntry && entry.status == MessageStatus.sent,
  );
}

Future<void> _copyCodexCliJoinCommand(
  BuildContext context,
  String command,
) async {
  await Clipboard.setData(ClipboardData(text: command));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Codex CLI join command copied')),
  );
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

    for (final content in msg.message.content) {
      if (content is ToolUseContent && isCodexUpdatePlanTool(content.name)) {
        final text = codexPlanUpdateTextFromInput(content.input);
        if (text != null) return text;
      }
    }

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

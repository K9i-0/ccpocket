import '../chat_session/widgets/lite_mode_controls.dart';
import '../explore/explore_screen.dart';
import '../file_browser/file_browser_reference.dart';

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../constants/feature_flags.dart';
import '../../hooks/use_app_resume_callback.dart';
import '../../hooks/use_scroll_tracking.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_display_filter.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../router/app_router.dart';
import '../workspace/widgets/workspace_session_route_adapter.dart';
import '../../router/session_stack_navigation.dart';
import '../../services/bridge_service.dart';
import '../../services/draft_service.dart';
import '../../utils/composer_tokens.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import '../session_list/workspace_shell_screen.dart';
import '../session_link/widgets/session_unavailable_view.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/approval_bar.dart';
import '../../widgets/bubbles/ask_user_question_widget.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/new_session_sheet.dart'
    show permissionModeFromRaw, sandboxModeFromRaw;
import '../../widgets/plan_detail_sheet.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/session_name_title.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../chat_session/state/chat_session_state.dart';
import '../chat_session/state/streaming_state_cubit.dart';
import '../chat_session/widgets/background_tasks_bar.dart';
import '../chat_session/widgets/bottom_overlay_layout.dart';
import '../chat_session/widgets/floating_composer_layout.dart';
import '../chat_session/widgets/chat_input_with_overlays.dart';
import '../chat_session/widgets/chat_message_list.dart';
import '../chat_session/widgets/fork_confirmation.dart';
import '../chat_session/widgets/queued_input_panel.dart';
import '../chat_session/widgets/reconnect_banner.dart';
import '../chat_session/widgets/scroll_to_bottom_button.dart';
import '../chat_session/widgets/session_file_list_scope.dart';
import '../chat_session/widgets/session_mode_bar.dart';
import '../chat_session/widgets/status_line_flexible_space.dart';
import '../explore/state/explore_state.dart';
import '../git/state/git_status_cubit.dart';
import '../github/widgets/empty_chat_github_button.dart';
import '../github/widgets/github_menu_item.dart';
import '../chat_session/session_handoff.dart';
import '../../widgets/duo/duo_control_strip.dart';
import '../workspace/widgets/workspace_pane_navigator.dart';
import 'widgets/rewind_action_sheet.dart';
import 'widgets/rewind_message_list_sheet.dart' show UserMessageHistorySheet;
import 'widgets/usage_summary_bar.dart';
import '../chat_session/session_screen_shared.dart';
import '../chat_session/session_screen_hooks.dart';

const _fileListRefreshToolNames = {
  'Edit',
  'FileEdit',
  'FileChange',
  'MultiEdit',
  'Write',
  'NotebookEdit',
  'Bash',
};

/// Outer widget that creates screen-scoped [ChatSessionCubit] and
/// [StreamingStateCubit] via [MultiBlocProvider], replacing Riverpod's
/// Family (autoDispose) pattern.
///
/// When [isPending] is true, shows a loading overlay until [session_created]
/// is received from the bridge, then swaps to the real session.
///
/// Antigravity sessions use this screen too ([provider]): their permission
/// modes map onto the Claude chip. [ChatSessionCubit]'s capability flags hide
/// what Antigravity does not support.
class ClaudeSessionScreen extends StatefulWidget {
  final String sessionId;

  /// [Provider.claude] or [Provider.antigravity].
  final Provider provider;
  final String? projectPath;
  final SessionWorkspaceInfo? workspace;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialPermissionMode;
  final String? initialSandboxMode;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

  /// Notifier from the parent that may already hold a [SystemMessage]
  /// with subtype `session_created` (race condition fix).
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  const ClaudeSessionScreen({
    super.key,
    required this.sessionId,
    this.provider = Provider.claude,
    this.projectPath,
    this.workspace,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  State<ClaudeSessionScreen> createState() => _ClaudeSessionScreenState();
}

@RoutePage(name: 'ClaudeSessionRoute')
class WorkspaceClaudeSessionScreen extends StatelessWidget {
  final String sessionId;

  /// [Provider.claude] or [Provider.antigravity].
  final Provider provider;
  final String? projectPath;
  final SessionWorkspaceInfo? workspace;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final String? initialPermissionMode;
  final String? initialSandboxMode;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

  const WorkspaceClaudeSessionScreen({
    super.key,
    required this.sessionId,
    this.provider = Provider.claude,
    this.projectPath,
    this.workspace,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSessionRouteAdapter(
      selection: WorkspaceSessionSelection(
        sessionId: sessionId,
        provider: provider,
        projectPath: projectPath,
        workspace: workspace,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        isPending: isPending,
        permissionMode: initialPermissionMode,
        sandboxMode: initialSandboxMode,
        pendingSessionCreated: pendingSessionCreated,
      ),
    );
  }
}

class _ClaudeSessionScreenState extends State<ClaudeSessionScreen> {
  late String _sessionId;
  late String? _projectPath;
  late SessionWorkspaceInfo? _workspace;
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
  final Object _sessionRouteOwner = Object();
  Object? _sessionRouteIdentity;

  @override
  void initState() {
    super.initState();
    final bridge = context.read<BridgeService>();
    _sessionId = widget.sessionId;
    _projectPath = widget.projectPath;
    _workspace = widget.workspace;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeIdentity = ModalRoute.of(context)?.settings;
    if (!identical(_sessionRouteIdentity, routeIdentity)) {
      final previousIdentity = _sessionRouteIdentity;
      if (previousIdentity != null) {
        SessionRouteRegistry.instance.remove(
          routeIdentity: previousIdentity,
          owner: _sessionRouteOwner,
        );
      }
      _sessionRouteIdentity = routeIdentity;
    }
    _syncSessionRouteIdentity();
  }

  void _syncSessionRouteIdentity() {
    final routeIdentity = _sessionRouteIdentity;
    if (routeIdentity == null) return;
    SessionRouteRegistry.instance.update(
      routeIdentity: routeIdentity,
      owner: _sessionRouteOwner,
      sessionId: _sessionId,
      provider: widget.provider.value,
    );
    final shell = WorkspaceShellScreen.maybeOf(context);
    if (shell != null) {
      shell.updateLiveSession(widget.sessionId, _sessionId);
    } else if (ModalRoute.of(context)?.isCurrent ?? false) {
      NotificationService.instance.setActiveSession(
        sessionId: _sessionId,
        provider: widget.provider.value,
      );
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
        if (msg.requestId != null && msg.requestId != _sessionId) return;
        // Filter by projectPath to avoid picking up another session's event
        if (widget.projectPath != null &&
            msg.projectPath != null &&
            msg.projectPath != widget.projectPath) {
          return;
        }
        if (msg.sessionId != null && mounted) {
          _resolveSession(msg);
        }
      } else if (msg is ErrorMessage &&
          msg.requestId == _sessionId &&
          _isPending &&
          mounted) {
        bridge.takeRequestError(_sessionId);
        _failPendingStart(msg.message);
      }
    });
    // The Bridge can reject a start before this page subscribes.
    final missedError = bridge.takeRequestError(_sessionId);
    if (missedError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isPending) _failPendingStart(missedError.message);
      });
    }
  }

  void _failPendingStart(String errorText) {
    _pendingSub?.cancel();
    _pendingSub = null;
    widget.pendingSessionCreated?.removeListener(_onPendingSessionCreated);
    if (widget.onBackToSessions case final onBack?) {
      onBack();
    } else {
      context.router.maybePop();
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorText)));
  }

  void _onPendingSessionCreated() {
    final msg = widget.pendingSessionCreated?.value;
    if (msg != null &&
        msg.sessionId != null &&
        (msg.requestId == null || msg.requestId == _sessionId) &&
        mounted &&
        _isPending) {
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
        if (msg.handoff) {
          // Another agent continues the task: this screen is replaced.
          openHandoffSession(
            context,
            msg,
            hostedByShell: widget.onBackToSessions != null,
          );
          return;
        }
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
      _workspace = msg.workspace ?? _workspace;
      _worktreePath = msg.worktreePath ?? _worktreePath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
      _isPending = false;
    });
    _syncSessionRouteIdentity();
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
    if (msg.forked) {
      bridge.copyExplorerHistory(oldId, newId);
    } else {
      bridge.migrateExplorerHistory(oldId, newId);
    }
    final explorerHistory = bridge.getExplorerHistory(newId);
    draftService.migrateDraft(oldId, newId);
    draftService.migrateImageDraft(oldId, newId);
    setState(() {
      _sessionId = newId;
      _projectPath = msg.projectPath ?? _projectPath;
      _workspace = msg.workspace ?? _workspace;
      _worktreePath = msg.worktreePath ?? _worktreePath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _permissionMode =
          permissionModeFromRaw(msg.permissionMode) ?? _permissionMode;
      _sandboxMode = sandboxModeFromRaw(msg.sandboxMode) ?? _sandboxMode;
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
    _syncSessionRouteIdentity();
  }

  @override
  void didUpdateWidget(covariant ClaudeSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId &&
        oldWidget.projectPath == widget.projectPath &&
        oldWidget.workspace == widget.workspace &&
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
      _workspace = widget.workspace;
      _worktreePath = widget.worktreePath;
      _gitBranch = widget.gitBranch;
      _isPending = widget.isPending;
      _permissionMode = permissionModeFromRaw(widget.initialPermissionMode);
      _sandboxMode = sandboxModeFromRaw(widget.initialSandboxMode);
      _explorerCurrentPath = explorerHistory.currentPath;
      _recentPeekedFiles = explorerHistory.recentPeekedFiles;
    });
    _syncSessionRouteIdentity();
  }

  @override
  void dispose() {
    final routeIdentity = _sessionRouteIdentity;
    if (routeIdentity != null) {
      SessionRouteRegistry.instance.remove(
        routeIdentity: routeIdentity,
        owner: _sessionRouteOwner,
      );
    }
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
      final chrome = resolveSessionPaneChrome(context, shell);
      final leading = sessionAppBarLeading(
        context,
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
      provider: widget.provider,
      projectPath: _projectPath,
      workspace: _workspace,
      gitBranch: _gitBranch,
      worktreePath: _worktreePath,
      explorerCurrentPath: _explorerCurrentPath,
      recentPeekedFiles: _recentPeekedFiles,
      permissionMode: _permissionMode,
      sandboxMode: _sandboxMode,
      onBackToSessions: widget.onBackToSessions,
      hideSessionBackButton: widget.hideSessionBackButton,
    );
  }
}

/// Wrapper that creates screen-scoped cubits once per session.
class _ChatScreenProviders extends StatelessWidget {
  final String sessionId;
  final Provider provider;
  final String? projectPath;
  final SessionWorkspaceInfo? workspace;
  final String? gitBranch;
  final String? worktreePath;
  final String explorerCurrentPath;
  final List<String> recentPeekedFiles;
  final PermissionMode? permissionMode;
  final SandboxMode? sandboxMode;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

  const _ChatScreenProviders({
    super.key,
    required this.sessionId,
    required this.provider,
    this.projectPath,
    this.workspace,
    this.gitBranch,
    this.worktreePath,
    this.explorerCurrentPath = '',
    this.recentPeekedFiles = const [],
    this.permissionMode,
    this.sandboxMode,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<BridgeService>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StreamingStateCubit()),
        BlocProvider(
          create: (context) => ChatSessionCubit(
            sessionId: sessionId,
            provider: provider,
            bridge: bridge,
            streamingCubit: context.read<StreamingStateCubit>(),
            initialExplorerCurrentPath: explorerCurrentPath,
            initialRecentPeekedFiles: recentPeekedFiles,
            initialPermissionMode: permissionMode,
            initialSandboxMode: sandboxMode,
            initialProjectPath: projectPath,
            initialWorktreePath: worktreePath,
            initialGitBranch: gitBranch,
          ),
        ),
      ],
      child: SessionFileListScope(
        bridge: bridge,
        fallbackProjectPath: projectPath,
        child: _ChatScreenBody(
          sessionId: sessionId,
          projectPath: projectPath,
          workspace: workspace,
          gitBranch: gitBranch,
          worktreePath: worktreePath,
          onBackToSessions: onBackToSessions,
          hideSessionBackButton: hideSessionBackButton,
        ),
      ),
    );
  }
}

class _ChatScreenBody extends HookWidget {
  final String sessionId;
  final String? projectPath;
  final SessionWorkspaceInfo? workspace;
  final String? gitBranch;
  final String? worktreePath;
  final VoidCallback? onBackToSessions;
  final bool hideSessionBackButton;

  const _ChatScreenBody({
    required this.sessionId,
    this.projectPath,
    this.workspace,
    this.gitBranch,
    this.worktreePath,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final shell = WorkspaceShellScreen.maybeOf(context);
    final presentationListenable = shell?.presentationListenable;

    // Mutable branch state (refreshed from Bridge)
    final currentBranch = useState(gitBranch);
    final showRemoteGitStatusBadge = context.select(
      (SettingsCubit cubit) => cubit.state.showRemoteGitStatusBadge,
    );
    final settingsCubit = context.read<SettingsCubit>();

    // Custom hooks
    final lifecycleState = useAppLifecycleState();
    final isBackground =
        lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
    final isBackgroundRef = useRef(isBackground);
    isBackgroundRef.value = isBackground;
    final scroll = useScrollTracking(sessionId);

    // Plan feedback controller (for plan approval rejection message)
    final planFeedbackController = useTextEditingController();

    // Chat input controller (managed here to preserve text across rebuilds)
    final chatInputController = useMemoized(ComposerTextEditingController.new);
    useEffect(() => chatInputController.dispose, [chatInputController]);
    final draftService = context.read<DraftService>();

    // --- Draft persistence: restore on mount, auto-save on change ---
    useComposerDraft(sessionId, draftService, chatInputController);

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
    final effectiveProjectPath = firstNonEmptyProjectPath(
      sessionState.projectPath,
      projectPath,
    );
    final effectiveWorktreePath = firstNonEmptyProjectPath(
      sessionState.worktreePath,
      worktreePath,
    );
    final gitProjectPath = effectiveWorktreePath ?? effectiveProjectPath;
    final gitBadgeTone = sessionGitBadgeToneOf(
      context,
      sessionId,
      gitProjectPath,
      showRemoteGitStatusBadge: showRemoteGitStatusBadge,
    );
    final parentState = context
        .findAncestorStateOfType<_ClaudeSessionScreenState>();
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
      final unregisterReference = FileBrowserReferences.register(
        context.read<BridgeService>(),
        sessionId,
        chatInputController.insertFileReference,
      );
      return () {
        unregisterReference();
        shell?.unregisterSessionToolPaneBindings(sessionId);
      };
    }, [sessionId]);

    final tokenUsage = _collectTokenUsage(sessionState.entries);
    final toolUsage = _collectToolUsage(sessionState.entries);

    // --- Side effects subscription ---
    useEffect(() {
      final sub = chatSessionCubit.sideEffects.listen(
        (effects) => executeSessionSideEffects(
          completionNotificationBody: 'Session done',
          effects,
          sessionId: sessionId,
          isBackground: isBackgroundRef.value,
          remoteNotificationsReady: settingsCubit.state.fcmReady,
          approval: chatSessionCubit.state.approval,
          l: l,
          collapseToolResults: collapseToolResults,
          planFeedbackController: planFeedbackController,
          isReadingHistory: scroll.isReadingHistoryNow,
        ),
      );
      return sub.cancel;
    }, [sessionId]);

    // --- Initial requests on mount ---
    useInitialSessionRequests(
      context,
      sessionId: sessionId,
      isBackground: isBackground,
      effectiveProjectPath: effectiveProjectPath,
      gitProjectPath: gitProjectPath,
      showRemoteGitStatusBadge: showRemoteGitStatusBadge,
    );

    useSessionFileRefresh(
      context,
      sessionId: sessionId,
      isBackgroundRef: isBackgroundRef,
      effectiveProjectPath: effectiveProjectPath,
      gitProjectPath: gitProjectPath,
      showRemoteGitStatusBadge: showRemoteGitStatusBadge,
      refreshToolNames: _fileListRefreshToolNames,
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
    // If still connected, refresh history directly (BlocListener won't fire).
    // If disconnected, ensureConnected triggers reconnect → BlocListener
    // fires → refreshHistory is called there.
    useAppResumeCallback(lifecycleState, () {
      final bridge = context.read<BridgeService>();
      bridge.ensureConnected();
      if (bridge.isConnected) {
        context.read<ChatSessionCubit>().refreshHistory();
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
    final supportsMessageEdit = context.select<ChatSessionCubit, bool>(
      (cubit) => cubit.supportsMessageEdit,
    );
    // Provider capabilities (Antigravity has no rewind, fork or usage bar).
    final supportsRewind = context.select<ChatSessionCubit, bool>(
      (cubit) => cubit.supportsRewind,
    );
    final supportsFork = context.select<ChatSessionCubit, bool>(
      (cubit) => cubit.supportsFork,
    );
    final showsUsageSummary = context.select<ChatSessionCubit, bool>(
      (cubit) => cubit.showsUsageSummary,
    );
    final queuedInput = sessionState.queuedInput;
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
            listenable: presentationListenable ?? const SessionNoopListenable(),
            builder: (context, child) {
              final currentShell = WorkspaceShellScreen.maybeOf(context);
              final isSinglePane = currentShell?.isSinglePane ?? true;
              final chrome = resolveSessionPaneChrome(context, currentShell);
              final leading = sessionAppBarLeading(
                context,
                onBackToSessions: onBackToSessions,
                hideSessionBackButton: hideSessionBackButton,
              );
              final showMessageHistoryAction = !isSinglePane;
              final double defaultTitleSpacing = isSinglePane
                  ? NavigationToolbar.kMiddleSpacing
                  : (leading == null ? 16 : 12);

              final pane = WorkspacePaneScope.maybeOf(context);
              return DuoAdaptiveScaffold(
                useStrip: true,
                publish: pane?.active ?? true,
                wrapAppBar: chrome.wrapAppBar,
                reserveBottomSlot: true,
                // The list's New is out of reach while a chat owns the strip.
                stripTools: [
                  if (currentShell?.canRequestNewSession ?? false)
                    IconButton(
                      key: const ValueKey('duo_new_session_button'),
                      icon: const Icon(Icons.edit_square),
                      tooltip: AppLocalizations.of(context).newSession,
                      onPressed: currentShell!.requestNewSession,
                    ),
                ],
                appBar: AppBar(
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
                      provider: context
                          .read<ChatSessionCubit>()
                          .effectiveProvider,
                      projectPath: effectiveProjectPath,
                      workspace: workspace,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              initialFiles: context.read<FileListCubit>().state,
                              initialPath: initialPath,
                              recentPeekedFiles: recentPeekedFiles,
                              onResultChanged: handleExploreResult,
                            );
                            return;
                          }
                          final result = await openExplorerScreen(
                            context,
                            sessionId: sessionId,
                            projectPath: effectiveProjectPath,
                            initialFiles: context.read<FileListCubit>().state,
                            initialPath: initialPath,
                            recentPeekedFiles: recentPeekedFiles,
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
                          backgroundColor: sessionGitBadgeColor(
                            context,
                            gitBadgeTone,
                          ),
                          smallSize: 8,
                          child: Icon(
                            Icons.difference,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () {
                          openSessionGitScreen(
                            context,
                            effectiveWorktreePath ?? effectiveProjectPath,
                            diffSelectionFromNav,
                            sessionId: sessionId,
                            worktreePath: effectiveWorktreePath,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        final handoffTarget = handoffTargetFromMenuValue(value);
                        if (handoffTarget != null) {
                          unawaited(
                            handoffSessionFromScreen(
                              context,
                              sessionId: sessionId,
                              source:
                                  chatSessionCubit.provider ?? Provider.claude,
                              target: handoffTarget,
                            ),
                          );
                          return;
                        }
                        switch (value) {
                          case 'display_mode':
                            showChatDisplayModeSheet(context, sessionId);
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
                          case gitHubSessionMenuValue:
                            if (effectiveProjectPath == null) return;
                            unawaited(
                              openGitHubScreenForSession(
                                context,
                                projectPath: effectiveProjectPath,
                                sessionId: sessionId,
                              ),
                            );
                          case 'gallery':
                            openSessionGalleryScreen(
                              context,
                              sessionId: sessionId,
                            );
                          case 'rename':
                            renameSessionFromScreen(context, sessionId);
                          case 'terminal':
                            openSessionInTerminal(
                              context,
                              effectiveProjectPath,
                            );
                        }
                      },
                      itemBuilder: (context) {
                        final terminalConfig = context
                            .read<SettingsCubit>()
                            .state
                            .terminalApp;
                        return [
                          PopupMenuItem(
                            key: const ValueKey('menu_display_mode'),
                            value: 'display_mode',
                            child: ListTile(
                              leading: const Icon(
                                Icons.bolt_outlined,
                                size: 20,
                              ),
                              title: Text(l.chatDisplayMode),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
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
                          if (effectiveProjectPath != null)
                            gitHubSessionMenuItem(context),
                          ...handoffSessionMenuItems(
                            context,
                            current:
                                chatSessionCubit.provider ?? Provider.claude,
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
                body: sessionState.sessionUnavailable
                    ? SessionUnavailableView(
                        onOpenRecentSessions:
                            onBackToSessions ??
                            () {
                              context.router.replaceAll([AdaptiveHomeRoute()]);
                            },
                      )
                    : child,
              );
            },
            child: Column(
              children: [
                if (showsUsageSummary)
                  UsageSummaryBar(
                    totalCost: sessionState.totalCost,
                    totalDuration: sessionState.totalDuration,
                    inputTokens: tokenUsage.inputTokens,
                    cachedInputTokens: tokenUsage.cachedInputTokens,
                    outputTokens: tokenUsage.outputTokens,
                    thoughtTokens: tokenUsage.thoughtTokens,
                    toolCalls: toolUsage.toolCalls,
                    fileEdits: toolUsage.fileEdits,
                    contextUsed:
                        sessionState.antigravitySettings?.contextUsage?.used,
                    contextSize:
                        sessionState.antigravitySettings?.contextUsage?.size,
                  ),
                if (bridgeState == BridgeConnectionState.reconnecting ||
                    bridgeState == BridgeConnectionState.disconnected)
                  ReconnectBanner(bridgeState: bridgeState),
                Expanded(
                  child: FloatingComposerLayout(
                    content: BottomOverlayLayout(
                      overlay:
                          askToolUseId == null &&
                              askInput == null &&
                              pendingToolUseId == null
                          ? null
                          : NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is UserScrollNotification &&
                                    notification.direction !=
                                        ScrollDirection.idle &&
                                    isEditableTextFocused()) {
                                  FocusScope.of(context).unfocus();
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                reverse: true,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (askToolUseId != null &&
                                        askInput != null)
                                      AskUserQuestionWidget(
                                        toolUseId: askToolUseId,
                                        input: askInput,
                                        agentName: context
                                            .read<ChatSessionCubit>()
                                            .effectiveProvider
                                            .label,
                                        onAnswer: answerQuestion,
                                      ),
                                    if (pendingToolUseId != null)
                                      ApprovalBar(
                                        key: ValueKey(
                                          'approval_$pendingToolUseId',
                                        ),
                                        appColors: appColors,
                                        pendingPermission: pendingPermission,
                                        isPlanApproval: isPlanApproval,
                                        useSessionApprovalLabel: context
                                            .read<ChatSessionCubit>()
                                            .isAntigravity,
                                        planFeedbackController:
                                            planFeedbackController,
                                        onApprove: approveToolUse,
                                        onReject: rejectToolUse,
                                        onApproveAlways: approveAlwaysToolUse,
                                        // Only Claude can start over from
                                        // the plan with a cleared context.
                                        onApproveClearContext:
                                            isPlanApproval &&
                                                context
                                                    .read<ChatSessionCubit>()
                                                    .isClaude
                                            ? approveWithClearContext
                                            : null,
                                        onViewPlan: isPlanApproval
                                            ? () {
                                                final originalText =
                                                    _extractPlanText(
                                                      sessionState.entries,
                                                      pendingPermission:
                                                          pendingPermission,
                                                    );
                                                if (originalText == null)
                                                  return;
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
                      topOverlay: sessionState.sessionContextLoaded
                          ? Positioned(
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
                            )
                          : null,
                      floatingButtonBuilder: (overlayHeight) {
                        if (!scroll.showScrollToLatest) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          right: 12,
                          bottom: overlayHeight + 12,
                          child: ScrollToBottomButton(
                            onPressed: scroll.goToLatest,
                          ),
                        );
                      },
                      content: Stack(
                        fit: StackFit.expand,
                        children: [
                          ChatMessageList(
                            displayFilter: context
                                .select<SettingsCubit, ChatDisplayFilter>(
                                  (cubit) => cubit.state
                                      .displayFilterForSession(sessionId),
                                ),
                            sessionId: sessionId,
                            scrollController: scroll.controller,
                            httpBaseUrl: context
                                .read<BridgeService>()
                                .httpBaseUrl,
                            projectPath: effectiveProjectPath,
                            onRetryMessage: (entry) {
                              context.read<ChatSessionCubit>().retryMessage(
                                entry,
                              );
                            },
                            // In-place edit replaces the legacy conversation
                            // rewind; file restore stays as its own action.
                            onRewindMessage:
                                supportsMessageEdit || !supportsRewind
                                ? null
                                : (entry) {
                                    _showRewindActionSheet(
                                      context,
                                      entry,
                                      sessionId: sessionId,
                                      inputController: chatInputController,
                                      draftService: draftService,
                                    );
                                  },
                            onEditMessage:
                                supportsMessageEdit &&
                                    status == ProcessStatus.idle
                                ? (entry, text) => context
                                      .read<ChatSessionCubit>()
                                      .editMessage(entry, text)
                                : null,
                            onRestoreFilesMessage:
                                supportsMessageEdit && supportsRewind
                                ? (entry) => _showRewindActionSheet(
                                    context,
                                    entry,
                                    sessionId: sessionId,
                                    inputController: chatInputController,
                                    draftService: draftService,
                                    availableModes: const [RewindMode.code],
                                  )
                                : null,
                            onForkMessage: supportsFork
                                ? (message) => unawaited(
                                    _forkClaudeFromAssistant(context, message),
                                  )
                                : null,
                            collapseToolResults: collapseToolResults,
                            scrollToUserEntry: scrollToUserEntry,
                            bottomPadding: 8,
                            isCodex: false,
                            isReadingHistory: scroll.isReadingHistory,
                            onScrollMetricsChanged:
                                scroll.onScrollMetricsChanged,
                            onFilePeekOpened: context
                                .read<ChatSessionCubit>()
                                .recordPeekedFile,
                          ),
                          Positioned.fill(
                            child: EmptyChatGitHubButton(
                              sessionId: sessionId,
                              projectPath: effectiveProjectPath,
                            ),
                          ),
                        ],
                      ),
                    ),
                    bars: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LiteModeActivityBar(sessionId: sessionId),
                        const SessionBackgroundTasksBar(),
                      ],
                    ),
                    composer: approval is ApprovalNone
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (queuedInput != null)
                                SessionQueuedInputPanel(
                                  item: queuedInput,
                                  inputController: chatInputController,
                                ),
                              ChatInputWithOverlays(
                                sessionId: sessionId,
                                workspace: workspace,
                                status: status,
                                hintText:
                                    context
                                        .read<ChatSessionCubit>()
                                        .isAntigravity
                                    ? AppLocalizations.of(context)
                                          .antigravityMessagePlaceholder
                                    : null,
                                onGoToLatest: scroll.goToLatest,
                                inputController: chatInputController,
                                inputBlocked: queuedInput != null,
                                initialDiffSelection:
                                    diffSelectionFromNav.value,
                                onDiffSelectionConsumed: () {
                                  // Don't null — keep for AppBar navigation.
                                  // The value is cleared via onDiffSelectionCleared.
                                },
                                onDiffSelectionCleared: () =>
                                    diffSelectionFromNav.value = null,
                                onOpenGitScreen: effectiveProjectPath != null
                                    ? (_) => openSessionGitScreen(
                                        context,
                                        effectiveWorktreePath ??
                                            effectiveProjectPath,
                                        diffSelectionFromNav,
                                        sessionId: sessionId,
                                        worktreePath: effectiveWorktreePath,
                                        onFilePeekOpened: handleFilePeekOpened,
                                      )
                                    : null,
                              ),
                            ],
                          )
                        : null,
                  ),
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

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

/// Walk entries in reverse to find the latest [AssistantServerMessage] that
/// contains an `ExitPlanMode` tool use, then extract the plan text.
///
/// Tries TextContent first; if it's too short (real SDK writes the plan to a
/// file via Write tool), searches ALL entries for a Write tool targeting
/// `.claude/plans/`.
String? _extractPlanText(
  List<ChatEntry> entries, {
  PermissionRequestMessage? pendingPermission,
}) {
  return extractPlanText(entries, pendingPermission: pendingPermission);
}

@visibleForTesting
String? extractPlanText(
  List<ChatEntry> entries, {
  PermissionRequestMessage? pendingPermission,
}) {
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
        if (writtenPlan != null) return writtenPlan;
        if (textPlan.trim().isNotEmpty) return textPlan;
        for (final c in contents) {
          if (c is ToolUseContent && c.name == 'ExitPlanMode') {
            final plan = c.input['plan']?.toString();
            if (plan != null && plan.isNotEmpty) return plan;
          }
        }
      }
    }
  }
  if (pendingPermission != null &&
      pendingPermission.toolName == 'ExitPlanMode') {
    final plan = pendingPermission.input['plan']?.toString();
    if (plan != null && plan.isNotEmpty) return plan;
  }
  for (var i = entries.length - 1; i >= 0; i--) {
    final entry = entries[i];
    if (entry is ServerChatEntry && entry.message is PermissionRequestMessage) {
      final perm = entry.message as PermissionRequestMessage;
      if (perm.toolName == 'ExitPlanMode') {
        final plan = perm.input['plan']?.toString();
        if (plan != null && plan.isNotEmpty) return plan;
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
      onRewindMessage: cubit.supportsMessageEdit || !cubit.supportsRewind
          ? null
          : (msg) => _showRewindActionSheet(
              context,
              msg,
              sessionId: sessionId,
              inputController: inputController,
              draftService: draftService,
            ),
    ),
  );
}

void _showRewindActionSheet(
  BuildContext context,
  UserChatEntry message, {
  required String sessionId,
  required TextEditingController inputController,
  required DraftService draftService,
  List<RewindMode> availableModes = RewindMode.values,
}) {
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
            availableModes: availableModes,
            userMessage: message,
            preview: preview,
            isLoadingPreview: preview == null,
            onRewind: (mode) {
              Navigator.of(ctx).pop();
              if (message.messageUuid != null) {
                if (mode != RewindMode.code) {
                  restoreRewindMessageToComposer(
                    inputController: inputController,
                    draftService: draftService,
                    sessionId: sessionId,
                    text: message.text,
                  );
                }
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

({int inputTokens, int cachedInputTokens, int outputTokens, int thoughtTokens})
_collectTokenUsage(List<ChatEntry> entries) {
  var inputTokens = 0;
  var cachedInputTokens = 0;
  var outputTokens = 0;
  var thoughtTokens = 0;

  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    final msg = entry.message;
    if (msg is! ResultMessage) continue;
    inputTokens += msg.inputTokens ?? 0;
    cachedInputTokens += msg.cachedInputTokens ?? 0;
    outputTokens += msg.outputTokens ?? 0;
    thoughtTokens += msg.thoughtTokens ?? 0;
  }

  return (
    inputTokens: inputTokens,
    cachedInputTokens: cachedInputTokens,
    outputTokens: outputTokens,
    thoughtTokens: thoughtTokens,
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

/// Fork from the end of the assistant turn that [message] belongs to.
Future<void> _forkClaudeFromAssistant(
  BuildContext context,
  AssistantServerMessage message,
) async {
  final cubit = context.read<ChatSessionCubit>();
  final targetUuid = message.messageUuid;
  if (targetUuid == null || targetUuid.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).forkTargetNotFound)),
    );
    return;
  }
  final confirmed = await confirmForkConversation(context);
  if (!confirmed || !context.mounted) return;
  cubit.forkSession(targetUuid);
}

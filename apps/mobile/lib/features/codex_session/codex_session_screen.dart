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
import '../../utils/debug_bundle_share.dart';
import '../../utils/diff_parser.dart';
import '../../widgets/screenshot_sheet.dart';
import '../../widgets/worktree_list_sheet.dart';
import '../claude_code_session/state/claude_code_session_cubit.dart';
import '../claude_code_session/state/streaming_state_cubit.dart';
import '../claude_code_session/widgets/branch_chip.dart';
import '../claude_code_session/widgets/chat_input_with_overlays.dart';
import '../claude_code_session/widgets/chat_message_list.dart';
import '../claude_code_session/widgets/reconnect_banner.dart';
import '../claude_code_session/widgets/status_indicator.dart';
import '../diff/diff_screen.dart';
import '../gallery/gallery_screen.dart';
import 'state/codex_session_cubit.dart';

/// Codex-specific chat screen.
///
/// Simpler than [ClaudeCodeSessionScreen] — no approval flow, no rewind, no plan mode.
/// Shares UI components (`ChatMessageList`, `ChatInputWithOverlays`, etc.)
/// via [CodexSessionCubit] which extends [ChatSessionCubit].
class CodexSessionScreen extends StatefulWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;

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
  StreamSubscription<ServerMessage>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _projectPath = widget.projectPath;
    _gitBranch = widget.gitBranch;
    _worktreePath = widget.worktreePath;
    _isPending = widget.isPending;

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
    setState(() {
      _sessionId = msg.sessionId!;
      _projectPath = msg.projectPath ?? _projectPath;
      _gitBranch = msg.worktreeBranch ?? _gitBranch;
      _worktreePath = msg.worktreePath ?? _worktreePath;
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

  const _CodexProviders({
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
        // Register as ChatSessionCubit so shared widgets can find it.
        BlocProvider<ChatSessionCubit>(
          create: (_) => CodexSessionCubit(
            sessionId: sessionId,
            bridge: bridge,
            streamingCubit: streamingCubit,
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
    // Custom hooks
    final lifecycleState = useAppLifecycleState();
    final isBackground =
        lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
    final scroll = useScrollTracking(sessionId);

    // Chat input controller
    final chatInputController = useTextEditingController();

    // Collapse tool results notifier (shared widget needs it)
    final collapseToolResults = useMemoized(() => ValueNotifier<int>(0));
    useEffect(() => collapseToolResults.dispose, const []);

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
              actions: [
                IconButton(
                  key: const ValueKey('codex_rewind_info_button'),
                  icon: const Icon(Icons.history, size: 18),
                  tooltip: 'Rewind (unsupported in Codex)',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Codex sessions currently do not support rewind.',
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  key: const ValueKey('codex_share_debug_bundle_button'),
                  icon: const Icon(Icons.bug_report, size: 18),
                  tooltip: 'Copy for Agent',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => copyDebugBundleForAgent(context, sessionId),
                ),
                // View Changes
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
                // Screenshot
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
                // Gallery
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
                StatusIndicator(status: status),
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
                // No approval bar, no AskUserQuestion — Codex auto-executes.
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
    diffSelectionNotifier.value = null;
  }
}

void _executeSideEffects(
  Set<ChatSideEffect> effects, {
  required bool isBackground,
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
        // No plan feedback in Codex — ignore.
        break;
      case ChatSideEffect.notifyApprovalRequired:
        // No approval in Codex — ignore.
        break;
      case ChatSideEffect.notifyAskQuestion:
        // No AskUserQuestion in Codex — ignore.
        break;
      case ChatSideEffect.notifySessionComplete:
        if (isBackground) {
          NotificationService.instance.show(
            title: 'Session Complete',
            body: 'Codex session done',
            id: 3,
          );
        }
      case ChatSideEffect.scrollToBottom:
        scrollToBottom();
    }
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

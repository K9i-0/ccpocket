import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import '../../services/bridge_service.dart';
import '../../services/chat_message_handler.dart';
import '../../services/notification_service.dart';
import '../../services/voice_input_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/approval_bar.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/file_mention_overlay.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/slash_command_overlay.dart';
import '../../widgets/slash_command_sheet.dart'
    show SlashCommand, SlashCommandSheet, fallbackSlashCommands;
import '../diff/diff_screen.dart';
import '../gallery/gallery_screen.dart';
import 'state/chat_session_notifier.dart';
import 'state/chat_session_state.dart';
import 'state/streaming_state.dart';
import 'widgets/chat_app_bar_title.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/cost_badge.dart';
import 'widgets/plan_mode_chip.dart';
import 'widgets/reconnect_banner.dart';
import 'widgets/session_switcher.dart';
import 'widgets/status_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;

  const ChatScreen({
    super.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  static final Map<String, double> _scrollOffsets = {};

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  final List<ChatEntry> _entries = [];
  final _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Slash command overlay
  OverlayEntry? _slashOverlay;
  final LayerLink _inputLayerLink = LayerLink();

  // File mention overlay
  OverlayEntry? _fileMentionOverlay;
  List<String> _projectFiles = [];

  // Voice input
  final VoiceInputService _voiceInput = VoiceInputService();
  bool _isVoiceAvailable = false;
  bool _isRecording = false;

  // Parallel sessions
  List<SessionInfo> _otherSessions = [];

  // Plan mode feedback
  final TextEditingController _planFeedbackController = TextEditingController();

  bool _hasInputText = false;

  // Scroll tracking
  bool _isScrolledUp = false;

  // Bulk loading flag (skip animation during history load)
  bool _bulkLoading = true;

  // Notifier to auto-collapse ToolResultBubbles on new assistant message
  final ValueNotifier<int> _collapseToolResults = ValueNotifier<int>(0);

  // Side effects subscription
  StreamSubscription<Set<ChatSideEffect>>? _sideEffectsSub;

  BridgeService get _bridge => ref.read(bridgeServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _inputController.addListener(_onInputChanged);

    // Request file list for @-mention autocomplete
    if (widget.projectPath != null && widget.projectPath!.isNotEmpty) {
      _bridge.requestFileList(widget.projectPath!);
    }
    // Initialize voice input
    _voiceInput.initialize().then((available) {
      if (mounted) setState(() => _isVoiceAvailable = available);
    });
    // Request session list
    _bridge.requestSessionList();
    // Enable animation after initial load & restore scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bulkLoading = false;
      final savedOffset = _scrollOffsets[widget.sessionId];
      if (savedOffset != null && _scrollController.hasClients) {
        _scrollController.jumpTo(savedOffset);
      }
      // Subscribe to side effects from notifier
      _sideEffectsSub = ref
          .read(chatSessionNotifierProvider(widget.sessionId).notifier)
          .sideEffects
          .listen(_executeSideEffects);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_scrollController.hasClients) {
      _scrollOffsets[widget.sessionId] = _scrollController.offset;
    }
    _removeSlashOverlay();
    _removeFileMentionOverlay();
    _sideEffectsSub?.cancel();
    _voiceInput.dispose();
    _collapseToolResults.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _planFeedbackController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  bool get _isBackground => _lifecycleState != AppLifecycleState.resumed;

  // ---------------------------------------------------------------------------
  // Entry reconciliation (AnimatedList ↔ notifier state)
  // ---------------------------------------------------------------------------

  /// Reconcile _entries with notifier entries.
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
    }

    // Restore streaming entry
    if (streamingEntry != null) {
      _entries.add(streamingEntry);
    }

    setState(() {});
    _scrollToBottom();
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
      _scrollToBottom();
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
  // Side effects
  // ---------------------------------------------------------------------------

  void _executeSideEffects(Set<ChatSideEffect> effects) {
    for (final effect in effects) {
      switch (effect) {
        case ChatSideEffect.heavyHaptic:
          HapticFeedback.heavyImpact();
        case ChatSideEffect.mediumHaptic:
          HapticFeedback.mediumImpact();
        case ChatSideEffect.lightHaptic:
          HapticFeedback.lightImpact();
        case ChatSideEffect.collapseToolResults:
          _collapseToolResults.value++;
        case ChatSideEffect.clearPlanFeedback:
          _planFeedbackController.clear();
        case ChatSideEffect.notifyApprovalRequired:
          if (_isBackground) {
            NotificationService.instance.show(
              title: 'Approval Required',
              body: 'Tool approval needed',
              id: 1,
            );
          }
        case ChatSideEffect.notifyAskQuestion:
          if (_isBackground) {
            NotificationService.instance.show(
              title: 'Claude is asking',
              body: 'Question needs your answer',
              id: 2,
            );
          }
        case ChatSideEffect.notifySessionComplete:
          if (_isBackground) {
            NotificationService.instance.show(
              title: 'Session Complete',
              body: 'Session done',
              id: 3,
            );
          }
        case ChatSideEffect.scrollToBottom:
          _scrollToBottom();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Input handling
  // ---------------------------------------------------------------------------

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
    final text = _inputController.text;
    final slashCommands = _currentSlashCommands;
    if (text.startsWith('/') && text.isNotEmpty) {
      final query = text.toLowerCase();
      final filtered = slashCommands
          .where((c) => c.command.toLowerCase().startsWith(query))
          .toList();
      if (filtered.isNotEmpty) {
        _showSlashOverlay(filtered);
      } else {
        _removeSlashOverlay();
      }
      _removeFileMentionOverlay();
    } else {
      _removeSlashOverlay();
      // Detect @mention: find the last '@' before cursor and extract query
      final mentionQuery = _extractMentionQuery(text);
      if (mentionQuery != null && _projectFiles.isNotEmpty) {
        final q = mentionQuery.toLowerCase();
        final filtered = _projectFiles
            .where((f) => f.toLowerCase().contains(q))
            .take(15)
            .toList();
        if (filtered.isNotEmpty) {
          _showFileMentionOverlay(filtered);
        } else {
          _removeFileMentionOverlay();
        }
      } else {
        _removeFileMentionOverlay();
      }
    }
  }

  /// Get slash commands: prefer notifier state, fall back to defaults.
  List<SlashCommand> get _currentSlashCommands {
    final commands = ref
        .read(chatSessionNotifierProvider(widget.sessionId))
        .slashCommands;
    return commands.isNotEmpty ? commands : fallbackSlashCommands;
  }

  /// Extract the file query after the last '@' before cursor position.
  /// Returns null if no active @-mention is being typed.
  String? _extractMentionQuery(String text) {
    final cursorPos = _inputController.selection.baseOffset;
    if (cursorPos < 0) return null;
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex < 0) return null;
    // '@' must be at start or preceded by whitespace
    if (atIndex > 0 && !RegExp(r'\s').hasMatch(beforeCursor[atIndex - 1])) {
      return null;
    }
    final query = beforeCursor.substring(atIndex + 1);
    // No spaces in the query (file paths don't have spaces)
    if (query.contains(' ')) return null;
    return query;
  }

  void _showSlashOverlay(List<SlashCommand> filtered) {
    _removeSlashOverlay();
    _slashOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 16,
        child: CompositedTransformFollower(
          link: _inputLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: SlashCommandOverlay(
            filteredCommands: filtered,
            onSelect: _onSlashCommandSelected,
            onDismiss: _removeSlashOverlay,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_slashOverlay!);
  }

  void _removeSlashOverlay() {
    _slashOverlay?.remove();
    _slashOverlay = null;
  }

  void _showFileMentionOverlay(List<String> filtered) {
    _removeFileMentionOverlay();
    _fileMentionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 16,
        child: CompositedTransformFollower(
          link: _inputLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: FileMentionOverlay(
            filteredFiles: filtered,
            onSelect: _onFileMentionSelected,
            onDismiss: _removeFileMentionOverlay,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_fileMentionOverlay!);
  }

  void _removeFileMentionOverlay() {
    _fileMentionOverlay?.remove();
    _fileMentionOverlay = null;
  }

  void _onFileMentionSelected(String filePath) {
    _removeFileMentionOverlay();
    final text = _inputController.text;
    final cursorPos = _inputController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;
    final afterCursor = text.substring(cursorPos);
    final newText = '${text.substring(0, atIndex)}@$filePath $afterCursor';
    _inputController.text = newText;
    final newCursor = atIndex + 1 + filePath.length + 1;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursor),
    );
  }

  void _onSlashCommandSelected(String command) {
    _removeSlashOverlay();
    // Place command in input field so the user can append arguments before sending.
    _inputController.text = '$command ';
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  // ---------------------------------------------------------------------------
  // Connection / retry
  // ---------------------------------------------------------------------------

  void _onConnectionChange(BridgeConnectionState state) {
    if (state == BridgeConnectionState.connected) {
      _retryFailedMessages();
    }
  }

  void _retryFailedMessages() {
    final notifier = ref.read(
      chatSessionNotifierProvider(widget.sessionId).notifier,
    );
    for (final entry in _entries) {
      if (entry is UserChatEntry && entry.status == MessageStatus.failed) {
        notifier.retryMessage(entry);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final scrolledUp = pos.pixels < pos.maxScrollExtent - 100;
    if (scrolledUp != _isScrolledUp) {
      setState(() => _isScrolledUp = scrolledUp);
    }
  }

  void _scrollToBottom() {
    if (_isScrolledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Voice input
  // ---------------------------------------------------------------------------

  void _toggleVoiceInput() {
    if (_isRecording) {
      _voiceInput.stopListening();
      setState(() => _isRecording = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _isRecording = true);
      _voiceInput.startListening(
        onResult: (text, isFinal) {
          setState(() => _inputController.text = text);
          if (isFinal) {
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          }
        },
        onDone: () {
          if (mounted) setState(() => _isRecording = false);
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Actions → Notifier
  // ---------------------------------------------------------------------------

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref
        .read(chatSessionNotifierProvider(widget.sessionId).notifier)
        .sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _approveToolUse() {
    final sessionState = ref.read(
      chatSessionNotifierProvider(widget.sessionId),
    );
    final approval = sessionState.approval;
    if (approval is ApprovalPermission) {
      final notifier = ref.read(
        chatSessionNotifierProvider(widget.sessionId).notifier,
      );
      notifier.approve(approval.toolUseId);
      _planFeedbackController.clear();
    }
  }

  void _rejectToolUse() {
    final sessionState = ref.read(
      chatSessionNotifierProvider(widget.sessionId),
    );
    final approval = sessionState.approval;
    if (approval is ApprovalPermission) {
      final notifier = ref.read(
        chatSessionNotifierProvider(widget.sessionId).notifier,
      );
      final isPlan = approval.request.toolName == 'ExitPlanMode';
      final feedback = isPlan ? _planFeedbackController.text.trim() : null;
      notifier.reject(
        approval.toolUseId,
        message: feedback != null && feedback.isNotEmpty ? feedback : null,
      );
      _planFeedbackController.clear();
    }
  }

  void _approveAlwaysToolUse() {
    final sessionState = ref.read(
      chatSessionNotifierProvider(widget.sessionId),
    );
    final approval = sessionState.approval;
    if (approval is ApprovalPermission) {
      HapticFeedback.mediumImpact();
      ref
          .read(chatSessionNotifierProvider(widget.sessionId).notifier)
          .approveAlways(approval.toolUseId);
    }
  }

  void _answerQuestion(String toolUseId, String result) {
    ref
        .read(chatSessionNotifierProvider(widget.sessionId).notifier)
        .answer(toolUseId, result);
  }

  void _stopSession() {
    HapticFeedback.mediumImpact();
    ref.read(chatSessionNotifierProvider(widget.sessionId).notifier).stop();
  }

  void _interruptSession() {
    HapticFeedback.mediumImpact();
    ref
        .read(chatSessionNotifierProvider(widget.sessionId).notifier)
        .interrupt();
  }

  void _showSlashCommandSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SlashCommandSheet(
        commands: _currentSlashCommands,
        onSelect: _onSlashCommandSelected,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Watch notifier state
    final sessionState = ref.watch(
      chatSessionNotifierProvider(widget.sessionId),
    );

    // Entry reconciliation
    ref.listen<ChatSessionState>(
      chatSessionNotifierProvider(widget.sessionId),
      (prev, next) => _reconcileEntries(prev?.entries ?? [], next.entries),
    );

    // Streaming state
    ref.listen<StreamingState>(
      streamingStateNotifierProvider(widget.sessionId),
      _onStreamingStateChange,
    );

    // Connection state
    ref.listen<AsyncValue<BridgeConnectionState>>(connectionStateProvider, (
      prev,
      next,
    ) {
      final state = next.valueOrNull;
      if (state != null) _onConnectionChange(state);
    });
    ref.watch(fileListProvider).whenData((files) => _projectFiles = files);
    ref.watch(sessionListProvider).whenData((sessions) {
      _otherSessions = sessions.where((s) => s.id != widget.sessionId).toList();
    });

    final bridgeState =
        ref.watch(connectionStateProvider).valueOrNull ??
        BridgeConnectionState.connected;

    // Destructure approval state
    final status = sessionState.status;
    final approval = sessionState.approval;
    final inPlanMode = sessionState.inPlanMode;
    final totalCost = sessionState.totalCost;

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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_slashOverlay != null) {
            _removeSlashOverlay();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: ChatAppBarTitle(
              sessionId: widget.sessionId,
              projectPath: widget.projectPath,
              gitBranch: widget.gitBranch,
            ),
            actions: [
              if (widget.projectPath != null)
                IconButton(
                  icon: const Icon(Icons.difference, size: 20),
                  tooltip: 'View Changes',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DiffScreen(projectPath: widget.projectPath),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.preview, size: 20),
                tooltip: 'Preview',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GalleryScreen(sessionId: widget.sessionId),
                    ),
                  );
                },
              ),
              if (inPlanMode) const PlanModeChip(),
              if (_otherSessions.isNotEmpty)
                SessionSwitcher(
                  otherSessions: _otherSessions,
                  onSessionSelected: (session) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          sessionId: session.id,
                          projectPath: session.projectPath,
                        ),
                      ),
                    );
                  },
                ),
              if (totalCost > 0) CostBadge(totalCost: totalCost),
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
                      listKey: _listKey,
                      scrollController: _scrollController,
                      entries: _entries,
                      bulkLoading: _bulkLoading,
                      httpBaseUrl: _bridge.httpBaseUrl,
                      onRetryMessage: (entry) {
                        ref
                            .read(
                              chatSessionNotifierProvider(
                                widget.sessionId,
                              ).notifier,
                            )
                            .retryMessage(entry);
                      },
                      collapseToolResults: _collapseToolResults,
                    ),
                    if (_isScrolledUp)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
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
                  onAnswer: _answerQuestion,
                ),
              if (status == ProcessStatus.waitingApproval &&
                  pendingToolUseId != null)
                Dismissible(
                  key: ValueKey('approval_$pendingToolUseId'),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _approveToolUse();
                    } else {
                      _rejectToolUse();
                    }
                    return false; // don't remove from tree, state handles it
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 24),
                    color: appColors.statusRunning.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.check_circle,
                      color: appColors.statusRunning,
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.cancel,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: ApprovalBar(
                    appColors: appColors,
                    pendingPermission: pendingPermission,
                    isPlanApproval: isPlanApproval,
                    planFeedbackController: _planFeedbackController,
                    onApprove: _approveToolUse,
                    onReject: _rejectToolUse,
                    onApproveAlways: _approveAlwaysToolUse,
                  ),
                ),
              if (askToolUseId == null &&
                  status != ProcessStatus.waitingApproval)
                ChatInputBar(
                  inputController: _inputController,
                  inputLayerLink: _inputLayerLink,
                  status: status,
                  hasInputText: _hasInputText,
                  isVoiceAvailable: _isVoiceAvailable,
                  isRecording: _isRecording,
                  onSend: _sendMessage,
                  onStop: _stopSession,
                  onInterrupt: _interruptSession,
                  onToggleVoice: _toggleVoiceInput,
                  onShowSlashCommands: _showSlashCommandSheet,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

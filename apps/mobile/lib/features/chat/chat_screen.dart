import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import '../../services/bridge_service_base.dart';
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
import 'widgets/chat_app_bar_title.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/cost_badge.dart';
import 'widgets/plan_mode_chip.dart';
import 'widgets/reconnect_banner.dart';
import 'widgets/session_switcher.dart';
import 'widgets/status_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final BridgeServiceBase? bridge;
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;

  const ChatScreen({
    super.key,
    this.bridge,
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
  List<SlashCommand> _slashCommands = List.of(fallbackSlashCommands);

  // File mention overlay
  OverlayEntry? _fileMentionOverlay;
  List<String> _projectFiles = [];
  StreamSubscription<List<String>>? _fileListSub;

  // Voice input
  final VoiceInputService _voiceInput = VoiceInputService();
  bool _isVoiceAvailable = false;
  bool _isRecording = false;

  // Parallel sessions
  List<SessionInfo> _otherSessions = [];
  StreamSubscription<List<SessionInfo>>? _sessionListSub;

  // Plan mode
  bool _inPlanMode = false;
  final TextEditingController _planFeedbackController = TextEditingController();

  ProcessStatus _status = ProcessStatus.starting;
  bool _hasInputText = false;
  String? _pendingToolUseId;
  PermissionRequestMessage? _pendingPermission;

  // Message handler (pure logic, no Flutter dependency)
  final ChatMessageHandler _messageHandler = ChatMessageHandler();

  // AskUserQuestion tracking
  String? _askToolUseId;
  Map<String, dynamic>? _askInput;

  // Cost tracking
  double _totalCost = 0;

  // Scroll tracking
  bool _isScrolledUp = false;

  // Bridge connection state
  BridgeConnectionState _bridgeState = BridgeConnectionState.connected;

  // Status refresh timer: re-queries get_history while status is "starting"
  // to handle lost broadcast messages or slow CLI initialization.
  Timer? _statusRefreshTimer;

  // Bulk loading flag (skip animation during history load)
  bool _bulkLoading = true;

  // Prevent duplicate past_history processing
  bool _pastHistoryLoaded = false;

  // Notifier to auto-collapse ToolResultBubbles on new assistant message
  final ValueNotifier<int> _collapseToolResults = ValueNotifier<int>(0);

  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;

  /// Bridge accessor: uses constructor-injected bridge (mock path) or provider.
  BridgeServiceBase get _bridge =>
      widget.bridge ?? ref.read(bridgeServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _inputController.addListener(_onInputChanged);
    _messageSub = _bridge
        .messagesForSession(widget.sessionId)
        .listen(_onServerMessage);

    // Mock path: manual subscriptions for connection, fileList, sessionList
    if (widget.bridge != null) {
      _connectionSub = widget.bridge!.connectionStatus.listen(
        _onConnectionChange,
      );
      _fileListSub = widget.bridge!.fileList.listen((files) {
        _projectFiles = files;
      });
      _sessionListSub = widget.bridge!.sessionList.listen((sessions) {
        setState(() {
          _otherSessions = sessions
              .where((s) => s.id != widget.sessionId)
              .toList();
        });
      });
    }

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
    // Consume buffered past history from resume_session
    final pastHistory = _bridge.pendingPastHistory;
    if (pastHistory != null) {
      _bridge.pendingPastHistory = null;
      _onServerMessage(pastHistory);
    }
    // Request in-memory history for this session
    _bridge.requestSessionHistory(widget.sessionId);
    // Start status refresh timer (re-queries if stuck at "starting")
    _startStatusRefreshTimer();
    // Enable animation after initial load & restore scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bulkLoading = false;
      final savedOffset = _scrollOffsets[widget.sessionId];
      if (savedOffset != null && _scrollController.hasClients) {
        _scrollController.jumpTo(savedOffset);
      }
    });
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_status != ProcessStatus.starting || !mounted) {
        _statusRefreshTimer?.cancel();
        _statusRefreshTimer = null;
        return;
      }
      _bridge.requestSessionHistory(widget.sessionId);
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
    _statusRefreshTimer?.cancel();
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _fileListSub?.cancel();
    _sessionListSub?.cancel();
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

  void _addEntry(ChatEntry entry) {
    _entries.add(entry);
    _listKey.currentState?.insertItem(
      _entries.length - 1,
      duration: _bulkLoading
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  void _onServerMessage(ServerMessage msg) {
    // Skip duplicate past_history (may arrive from both buffer and stream)
    if (msg is PastHistoryMessage && _pastHistoryLoaded) return;
    if (msg is PastHistoryMessage) _pastHistoryLoaded = true;

    final update = _messageHandler.handle(msg, isBackground: _isBackground);
    _applyUpdate(update, msg);
    _scrollToBottom();
  }

  void _applyUpdate(ChatStateUpdate update, ServerMessage originalMsg) {
    setState(() {
      if (update.status != null) {
        _status = update.status!;
        if (_status != ProcessStatus.starting) {
          _statusRefreshTimer?.cancel();
          _statusRefreshTimer = null;
        }
      }
      if (update.resetPending) {
        _pendingToolUseId = null;
        _pendingPermission = null;
      }
      if (update.resetAsk) {
        _askToolUseId = null;
        _askInput = null;
      }
      if (update.resetStreaming) {
        _messageHandler.currentStreaming = null;
      }
      if (update.pendingToolUseId != null) {
        _pendingToolUseId = update.pendingToolUseId;
      }
      if (update.pendingPermission != null) {
        _pendingPermission = update.pendingPermission;
      }
      if (update.askToolUseId != null) {
        _askToolUseId = update.askToolUseId;
        _askInput = update.askInput;
      }
      if (update.costDelta != null) _totalCost += update.costDelta!;
      if (update.inPlanMode != null) _inPlanMode = update.inPlanMode!;
      if (update.slashCommands != null) _slashCommands = update.slashCommands!;

      // Mark user messages as sent
      if (update.markUserMessagesSent) {
        for (final e in _entries) {
          if (e is UserChatEntry && e.status == MessageStatus.sending) {
            e.status = MessageStatus.sent;
          }
        }
        // Replace streaming entry if handler consumed it
        final streaming = _messageHandler.currentStreaming;
        if (streaming == null && originalMsg is AssistantServerMessage) {
          // Streaming was consumed — find and replace the entry
          final oldStreaming = _entries.whereType<StreamingChatEntry>();
          if (oldStreaming.isNotEmpty) {
            final idx = _entries.indexOf(oldStreaming.first);
            if (idx >= 0) {
              // Build display message (handler already enriched it)
              _entries[idx] = update.entriesToAdd.isNotEmpty
                  ? update.entriesToAdd.first
                  : ServerChatEntry(originalMsg);
              // Don't add again below
              return;
            }
          }
        }
      }

      // Prepend entries (past history)
      if (update.entriesToPrepend.isNotEmpty) {
        _entries.insertAll(0, update.entriesToPrepend);
        for (var i = 0; i < update.entriesToPrepend.length; i++) {
          _listKey.currentState?.insertItem(i, duration: Duration.zero);
        }
      }

      // Add entries
      for (final entry in update.entriesToAdd) {
        _addEntry(entry);
      }
    });

    // Execute side effects outside setState
    _executeSideEffects(update.sideEffects);
  }

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
          NotificationService.instance.show(
            title: 'Approval Required',
            body: 'Tool approval needed',
            id: 1,
          );
        case ChatSideEffect.notifyAskQuestion:
          NotificationService.instance.show(
            title: 'Claude is asking',
            body: 'Question needs your answer',
            id: 2,
          );
        case ChatSideEffect.notifySessionComplete:
          NotificationService.instance.show(
            title: 'Session Complete',
            body: 'Session done',
            id: 3,
          );
        case ChatSideEffect.scrollToBottom:
          _scrollToBottom();
      }
    }
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
    final text = _inputController.text;
    if (text.startsWith('/') && text.isNotEmpty) {
      final query = text.toLowerCase();
      final filtered = _slashCommands
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

  void _onConnectionChange(BridgeConnectionState state) {
    setState(() => _bridgeState = state);
    if (state == BridgeConnectionState.connected) {
      _retryFailedMessages();
    }
  }

  void _retryFailedMessages() {
    for (final entry in _entries) {
      if (entry is UserChatEntry && entry.status == MessageStatus.failed) {
        _retryMessage(entry);
      }
    }
  }

  void _retryMessage(UserChatEntry entry) {
    setState(() => entry.status = MessageStatus.sending);
    _bridge.send(
      ClientMessage.input(
        entry.text,
        sessionId: entry.sessionId ?? widget.sessionId,
      ),
    );
  }

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

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    final connected = _bridge.isConnected;
    final entry = UserChatEntry(
      text,
      sessionId: widget.sessionId,
      status: connected ? MessageStatus.sending : MessageStatus.failed,
    );
    setState(() {
      _messageHandler.currentStreaming = null;
      _addEntry(entry);
    });
    _bridge.send(ClientMessage.input(text, sessionId: widget.sessionId));
    _inputController.clear();
    _scrollToBottom();
  }

  void _approveToolUse() {
    if (_pendingToolUseId != null) {
      // Approving ExitPlanMode means plan is accepted → exit plan mode
      if (_isPlanApproval) {
        _inPlanMode = false;
      }
      _bridge.send(
        ClientMessage.approve(_pendingToolUseId!, sessionId: widget.sessionId),
      );
      setState(() {
        _pendingToolUseId = null;
        _pendingPermission = null;
        _planFeedbackController.clear();
      });
    }
  }

  void _rejectToolUse() {
    if (_pendingToolUseId != null) {
      final feedback = _isPlanApproval
          ? _planFeedbackController.text.trim()
          : null;
      _bridge.send(
        ClientMessage.reject(
          _pendingToolUseId!,
          message: feedback != null && feedback.isNotEmpty ? feedback : null,
          sessionId: widget.sessionId,
        ),
      );
      setState(() {
        _pendingToolUseId = null;
        _pendingPermission = null;
        _planFeedbackController.clear();
      });
    }
  }

  void _approveAlwaysToolUse() {
    if (_pendingToolUseId != null) {
      HapticFeedback.mediumImpact();
      _bridge.send(
        ClientMessage.approveAlways(
          _pendingToolUseId!,
          sessionId: widget.sessionId,
        ),
      );
      setState(() {
        _pendingToolUseId = null;
        _pendingPermission = null;
      });
    }
  }

  void _answerQuestion(String toolUseId, String result) {
    _bridge.send(
      ClientMessage.answer(toolUseId, result, sessionId: widget.sessionId),
    );
    setState(() {
      _askToolUseId = null;
      _askInput = null;
    });
  }

  void _stopSession() {
    HapticFeedback.mediumImpact();
    _bridge.stopSession(widget.sessionId);
    setState(() {
      _pendingToolUseId = null;
      _pendingPermission = null;
      _askToolUseId = null;
      _askInput = null;
      _messageHandler.currentStreaming = null;
      _inPlanMode = false;
    });
  }

  void _interruptSession() {
    HapticFeedback.mediumImpact();
    _bridge.interrupt(widget.sessionId);
    setState(() {
      _messageHandler.currentStreaming = null;
    });
  }

  void _showSlashCommandSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SlashCommandSheet(
        commands: _slashCommands,
        onSelect: _onSlashCommandSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Provider-based state (only when not using mock bridge)
    if (widget.bridge == null) {
      ref.listen<AsyncValue<BridgeConnectionState>>(connectionStateProvider, (
        prev,
        next,
      ) {
        final state = next.valueOrNull;
        if (state != null) _onConnectionChange(state);
      });
      ref.watch(fileListProvider).whenData((files) => _projectFiles = files);
      ref.watch(sessionListProvider).whenData((sessions) {
        _otherSessions = sessions
            .where((s) => s.id != widget.sessionId)
            .toList();
      });
    }

    final bridgeState = widget.bridge != null
        ? _bridgeState
        : (ref.watch(connectionStateProvider).valueOrNull ??
              BridgeConnectionState.connected);

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
              if (_inPlanMode) const PlanModeChip(),
              if (_otherSessions.isNotEmpty)
                SessionSwitcher(
                  otherSessions: _otherSessions,
                  onSessionSelected: (session) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          bridge: widget.bridge,
                          sessionId: session.id,
                          projectPath: session.projectPath,
                        ),
                      ),
                    );
                  },
                ),
              if (_totalCost > 0) CostBadge(totalCost: _totalCost),
              StatusIndicator(status: _status),
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
                      onRetryMessage: _retryMessage,
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
              if (_askToolUseId != null && _askInput != null)
                AskUserQuestionWidget(
                  toolUseId: _askToolUseId!,
                  input: _askInput!,
                  onAnswer: _answerQuestion,
                ),
              if (_status == ProcessStatus.waitingApproval &&
                  _pendingToolUseId != null)
                Dismissible(
                  key: ValueKey('approval_$_pendingToolUseId'),
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
                    pendingPermission: _pendingPermission,
                    isPlanApproval: _isPlanApproval,
                    planFeedbackController: _planFeedbackController,
                    onApprove: _approveToolUse,
                    onReject: _rejectToolUse,
                    onApproveAlways: _approveAlwaysToolUse,
                  ),
                ),
              if (_askToolUseId == null &&
                  _status != ProcessStatus.waitingApproval)
                ChatInputBar(
                  inputController: _inputController,
                  inputLayerLink: _inputLayerLink,
                  status: _status,
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

  bool get _isPlanApproval => _pendingPermission?.toolName == 'ExitPlanMode';
}

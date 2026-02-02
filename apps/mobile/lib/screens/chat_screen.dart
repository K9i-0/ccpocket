import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/messages.dart';
import '../services/bridge_service_base.dart';
import '../services/chat_message_handler.dart';
import '../services/notification_service.dart';
import '../services/voice_input_service.dart';
import '../theme/app_theme.dart';
import '../widgets/approval_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/file_mention_overlay.dart';
import '../widgets/message_bubble.dart';
import '../widgets/slash_command_overlay.dart';
import '../widgets/slash_command_sheet.dart'
    show
        SlashCommand,
        SlashCommandCategory,
        SlashCommandSheet,
        fallbackSlashCommands;

class ChatScreen extends StatefulWidget {
  final BridgeServiceBase bridge;
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;

  const ChatScreen({
    super.key,
    required this.bridge,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
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

  ProcessStatus _status = ProcessStatus.idle;
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

  // Bulk loading flag (skip animation during history load)
  bool _bulkLoading = true;

  // Prevent duplicate past_history processing
  bool _pastHistoryLoaded = false;

  // Notifier to auto-collapse ToolResultBubbles on new assistant message
  final ValueNotifier<int> _collapseToolResults = ValueNotifier<int>(0);

  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<BridgeConnectionState>? _connectionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _inputController.addListener(_onInputChanged);
    _messageSub = widget.bridge.messages.listen(_onServerMessage);
    _connectionSub = widget.bridge.connectionStatus.listen(_onConnectionChange);
    _fileListSub = widget.bridge.fileList.listen((files) {
      _projectFiles = files;
    });
    // Request file list for @-mention autocomplete
    if (widget.projectPath != null && widget.projectPath!.isNotEmpty) {
      widget.bridge.requestFileList(widget.projectPath!);
    }
    // Initialize voice input
    _voiceInput.initialize().then((available) {
      if (mounted) setState(() => _isVoiceAvailable = available);
    });
    // Subscribe to session list for parallel session indicator
    _sessionListSub = widget.bridge.sessionList.listen((sessions) {
      setState(() {
        _otherSessions = sessions
            .where((s) => s.id != widget.sessionId)
            .toList();
      });
    });
    widget.bridge.requestSessionList();
    // Consume buffered past history from resume_session
    final pastHistory = widget.bridge.pendingPastHistory;
    if (pastHistory != null) {
      widget.bridge.pendingPastHistory = null;
      _onServerMessage(pastHistory);
    }
    // Request in-memory history for this session
    widget.bridge.requestSessionHistory(widget.sessionId);
    // Enable animation after initial load & restore scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bulkLoading = false;
      final savedOffset = _scrollOffsets[widget.sessionId];
      if (savedOffset != null && _scrollController.hasClients) {
        _scrollController.jumpTo(savedOffset);
      }
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
      if (update.status != null) _status = update.status!;
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
    // '@' must be at start or preceded by a space
    if (atIndex > 0 && beforeCursor[atIndex - 1] != ' ') return null;
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
    final cmd = _slashCommands.where((c) => c.command == command).firstOrNull;

    // Project commands: place in input field for argument editing
    if (cmd != null && cmd.category == SlashCommandCategory.project) {
      _inputController.text = '$command ';
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
      return;
    }

    // Built-in/skill commands: send immediately
    _inputController.clear();
    setState(() {
      _messageHandler.currentStreaming = null;
      _addEntry(
        UserChatEntry(
          command,
          sessionId: widget.sessionId,
          status: MessageStatus.sending,
        ),
      );
    });
    widget.bridge.send(
      ClientMessage.input(command, sessionId: widget.sessionId),
    );
    _scrollToBottom();
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
    widget.bridge.send(
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
    final connected = widget.bridge.isConnected;
    final entry = UserChatEntry(
      text,
      sessionId: widget.sessionId,
      status: connected ? MessageStatus.sending : MessageStatus.failed,
    );
    setState(() {
      _messageHandler.currentStreaming = null;
      _addEntry(entry);
    });
    widget.bridge.send(ClientMessage.input(text, sessionId: widget.sessionId));
    _inputController.clear();
    _scrollToBottom();
  }

  void _approveToolUse() {
    if (_pendingToolUseId != null) {
      // Approving ExitPlanMode means plan is accepted → exit plan mode
      if (_isPlanApproval) {
        _inPlanMode = false;
      }
      widget.bridge.send(
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
      widget.bridge.send(
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
      widget.bridge.send(
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
    widget.bridge.send(
      ClientMessage.answer(toolUseId, result, sessionId: widget.sessionId),
    );
    setState(() {
      _askToolUseId = null;
      _askInput = null;
    });
  }

  void _stopSession() {
    HapticFeedback.mediumImpact();
    widget.bridge.stopSession(widget.sessionId);
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
    widget.bridge.interrupt(widget.sessionId);
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
            title: _buildAppBarTitle(),
            actions: [
              if (_inPlanMode) _buildPlanModeChip(appColors),
              if (_otherSessions.isNotEmpty) _buildSessionSwitcher(appColors),
              if (_totalCost > 0) _buildCostBadge(),
              _buildStatusIndicator(appColors),
            ],
          ),
          body: Column(
            children: [
              if (_bridgeState == BridgeConnectionState.reconnecting ||
                  _bridgeState == BridgeConnectionState.disconnected)
                _buildReconnectBanner(appColors),
              Expanded(
                child: Stack(
                  children: [
                    _buildMessageList(),
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
                  child: _buildApprovalBar(appColors),
                ),
              if (_askToolUseId == null &&
                  _status != ProcessStatus.waitingApproval)
                _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final projectPath = widget.projectPath;
    if (projectPath != null && projectPath.isNotEmpty) {
      final projectName = projectPath.split('/').last;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'project_name_${widget.sessionId}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (widget.gitBranch != null && widget.gitBranch!.isNotEmpty)
            Text(
              widget.gitBranch!,
              style: TextStyle(fontSize: 12, color: appColors.subtleText),
            ),
        ],
      );
    }
    return Text('Session ${widget.sessionId.substring(0, 8)}');
  }

  Widget _buildSessionSwitcher(AppColors appColors) {
    final approvalCount = _otherSessions
        .where((s) => s.status == 'waiting_approval')
        .length;
    return PopupMenuButton<String>(
      key: const ValueKey('session_switcher'),
      icon: Badge(
        isLabelVisible: approvalCount > 0,
        label: Text('$approvalCount'),
        backgroundColor: appColors.statusApproval,
        child: Text(
          '${_otherSessions.length + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: appColors.subtleText,
          ),
        ),
      ),
      tooltip: 'Switch session',
      onSelected: (sessionId) {
        final session = _otherSessions.firstWhere((s) => s.id == sessionId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bridge: widget.bridge,
              sessionId: sessionId,
              projectPath: session.projectPath,
            ),
          ),
        );
      },
      itemBuilder: (context) => _otherSessions.map((s) {
        final projectName = s.projectPath.split('/').last;
        final isApproval = s.status == 'waiting_approval';
        return PopupMenuItem<String>(
          value: s.id,
          child: Row(
            children: [
              if (isApproval)
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: appColors.statusApproval,
                )
              else
                Icon(Icons.terminal, size: 16, color: appColors.subtleText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isApproval ? FontWeight.w700 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                s.id.substring(0, 6),
                style: TextStyle(fontSize: 10, color: appColors.subtleText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCostBadge() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '\$${_totalCost.toStringAsFixed(4)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AppColors appColors) {
    final (color, label) = switch (_status) {
      ProcessStatus.idle => (appColors.statusIdle, 'Idle'),
      ProcessStatus.running => (appColors.statusRunning, 'Running'),
      ProcessStatus.waitingApproval => (appColors.statusApproval, 'Approval'),
    };
    return Padding(
      key: const ValueKey('status_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: _status == ProcessStatus.running
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanModeChip(AppColors appColors) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment, size: 12, color: cs.tertiary),
            const SizedBox(width: 4),
            Text(
              'Plan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        FocusScope.of(context).unfocus();
        return false;
      },
      child: AnimatedList(
        key: _listKey,
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        initialItemCount: _entries.length,
        itemBuilder: (context, index, animation) {
          final entry = _entries[index];
          final previous = index > 0 ? _entries[index - 1] : null;
          final child = ChatEntryWidget(
            entry: entry,
            previous: previous,
            httpBaseUrl: widget.bridge.httpBaseUrl,
            onRetryMessage: _retryMessage,
            collapseToolResults: _collapseToolResults,
          );
          if (_bulkLoading || animation.isCompleted) return child;
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  Widget _buildReconnectBanner(AppColors appColors) {
    final isReconnecting = _bridgeState == BridgeConnectionState.reconnecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
      child: Row(
        children: [
          if (isReconnecting)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.cloud_off,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          const SizedBox(width: 8),
          Text(
            isReconnecting ? 'Reconnecting...' : 'Disconnected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isPlanApproval => _pendingPermission?.toolName == 'ExitPlanMode';

  Widget _buildApprovalBar(AppColors appColors) {
    return ApprovalBar(
      appColors: appColors,
      pendingPermission: _pendingPermission,
      isPlanApproval: _isPlanApproval,
      planFeedbackController: _planFeedbackController,
      onApprove: _approveToolUse,
      onReject: _rejectToolUse,
      onApproveAlways: _approveAlwaysToolUse,
    );
  }

  Widget _buildInputBar() {
    return ChatInputBar(
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
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/messages.dart';
import '../services/bridge_service_base.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/slash_command_overlay.dart';
import '../widgets/slash_command_sheet.dart';

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

  ProcessStatus _status = ProcessStatus.idle;
  bool _hasInputText = false;
  String? _pendingToolUseId;
  PermissionRequestMessage? _pendingPermission;

  // Inline streaming
  StreamingChatEntry? _currentStreaming;

  // Thinking streaming (accumulated separately, merged into assistant message)
  String _currentThinkingText = '';

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
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
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
    setState(() {
      switch (msg) {
        case StatusMessage(:final status):
          _status = status;
          if (status == ProcessStatus.waitingApproval) {
            HapticFeedback.heavyImpact();
            if (_isBackground) {
              NotificationService.instance.show(
                title: 'Approval Required',
                body: 'Tool approval needed',
                id: 1,
              );
            }
          } else {
            _pendingToolUseId = null;
            _pendingPermission = null;
          }
        case ThinkingDeltaMessage(:final text):
          _currentThinkingText += text;
        case StreamDeltaMessage(:final text):
          if (_currentStreaming == null) {
            _currentStreaming = StreamingChatEntry(text: text);
            _addEntry(_currentStreaming!);
          } else {
            _currentStreaming!.text += text;
          }
        case AssistantServerMessage(:final message):
          // Mark pending user messages as sent
          for (final e in _entries) {
            if (e is UserChatEntry && e.status == MessageStatus.sending) {
              e.status = MessageStatus.sent;
            }
          }
          // Inject accumulated thinking text as ThinkingContent
          ServerMessage displayMsg = msg;
          if (_currentThinkingText.isNotEmpty) {
            final hasThinking = message.content.any(
              (c) => c is ThinkingContent,
            );
            if (!hasThinking) {
              final enrichedContent = <AssistantContent>[
                ThinkingContent(thinking: _currentThinkingText),
                ...message.content,
              ];
              displayMsg = AssistantServerMessage(
                message: AssistantMessage(
                  id: message.id,
                  role: message.role,
                  content: enrichedContent,
                  model: message.model,
                ),
              );
            }
            _currentThinkingText = '';
          }
          // Replace streaming entry with final assistant entry
          if (_currentStreaming != null) {
            final idx = _entries.indexOf(_currentStreaming!);
            if (idx >= 0) {
              _entries[idx] = ServerChatEntry(displayMsg);
            } else {
              _addEntry(ServerChatEntry(displayMsg));
            }
            _currentStreaming = null;
          } else {
            _addEntry(ServerChatEntry(displayMsg));
          }
          for (final content in message.content) {
            if (content is ToolUseContent) {
              if (content.name == 'AskUserQuestion') {
                _askToolUseId = content.id;
                _askInput = content.input;
                HapticFeedback.mediumImpact();
                if (_isBackground) {
                  NotificationService.instance.show(
                    title: 'Claude is asking',
                    body: 'Question needs your answer',
                    id: 2,
                  );
                }
              } else {
                _pendingToolUseId = content.id;
              }
            }
          }
        case PastHistoryMessage(:final messages):
          final pastEntries = <ChatEntry>[];
          for (final m in messages) {
            if (m.role == 'user') {
              final texts = m.content
                  .whereType<TextContent>()
                  .map((c) => c.text)
                  .toList();
              if (texts.isNotEmpty) {
                pastEntries.add(UserChatEntry(texts.join('\n')));
              }
            } else if (m.role == 'assistant') {
              pastEntries.add(
                ServerChatEntry(
                  AssistantServerMessage(
                    message: AssistantMessage(
                      id: '',
                      role: 'assistant',
                      content: m.content,
                      model: '',
                    ),
                  ),
                ),
              );
            }
          }
          // Bulk insert at beginning
          _entries.insertAll(0, pastEntries);
          for (var i = 0; i < pastEntries.length; i++) {
            _listKey.currentState?.insertItem(i, duration: Duration.zero);
          }
        case HistoryMessage(:final messages):
          for (final m in messages) {
            if (m is! StatusMessage) {
              _addEntry(ServerChatEntry(m));
            }
            if (m is StatusMessage) {
              _status = m.status;
            }
          }
        case SystemMessage():
          _addEntry(ServerChatEntry(msg));
        case PermissionRequestMessage(:final toolUseId):
          _addEntry(ServerChatEntry(msg));
          _pendingToolUseId = toolUseId;
          _pendingPermission = msg;
        case ResultMessage(:final subtype, :final cost):
          if (cost != null) _totalCost += cost;
          if (subtype == 'stopped') {
            _status = ProcessStatus.idle;
            _pendingToolUseId = null;
            _pendingPermission = null;
            _askToolUseId = null;
            _askInput = null;
            _currentStreaming = null;
          }
          HapticFeedback.lightImpact();
          if (_isBackground && subtype != 'stopped') {
            NotificationService.instance.show(
              title: 'Session Complete',
              body: cost != null
                  ? 'Session done (\$${cost.toStringAsFixed(4)})'
                  : 'Session done',
              id: 3,
            );
          }
          _addEntry(ServerChatEntry(msg));
        default:
          _addEntry(ServerChatEntry(msg));
      }
    });
    _scrollToBottom();
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
    final text = _inputController.text;
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
    } else {
      _removeSlashOverlay();
    }
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

  void _onSlashCommandSelected(String command) {
    _removeSlashOverlay();
    _inputController.clear();
    setState(() {
      _currentStreaming = null;
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
      _currentStreaming = null;
      _addEntry(entry);
    });
    widget.bridge.send(ClientMessage.input(text, sessionId: widget.sessionId));
    _inputController.clear();
    _scrollToBottom();
  }

  void _approveToolUse() {
    if (_pendingToolUseId != null) {
      widget.bridge.send(
        ClientMessage.approve(_pendingToolUseId!, sessionId: widget.sessionId),
      );
      setState(() {
        _pendingToolUseId = null;
        _pendingPermission = null;
      });
    }
  }

  void _rejectToolUse() {
    if (_pendingToolUseId != null) {
      widget.bridge.send(
        ClientMessage.reject(_pendingToolUseId!, sessionId: widget.sessionId),
      );
      setState(() {
        _pendingToolUseId = null;
        _pendingPermission = null;
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
      _currentStreaming = null;
    });
  }

  void _showSlashCommandSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SlashCommandSheet(
        onSelect: (command) {
          setState(() {
            _currentStreaming = null;
            _addEntry(UserChatEntry(command));
          });
          widget.bridge.send(
            ClientMessage.input(command, sessionId: widget.sessionId),
          );
          _scrollToBottom();
        },
      ),
    );
  }

  String _extractPermissionSummary(PermissionRequestMessage perm) {
    final input = perm.input;
    final summaryParts = <String>[];
    for (final key in ['command', 'file_path', 'path', 'pattern', 'url']) {
      if (input.containsKey(key)) {
        final val = input[key].toString();
        final display = val.length > 60 ? '${val.substring(0, 60)}...' : val;
        summaryParts.add(display);
      }
    }
    return summaryParts.isNotEmpty ? summaryParts.join(' | ') : perm.toolName;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
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
            _buildApprovalBar(appColors),
          _buildInputBar(),
        ],
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
    final summary = _pendingPermission != null
        ? (_isPlanApproval
              ? 'Review the plan above and approve or continue planning'
              : _extractPermissionSummary(_pendingPermission!))
        : 'Tool execution requires approval';
    final toolName = _isPlanApproval
        ? 'Plan Approval'
        : _pendingPermission?.toolName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            appColors.approvalBar,
            appColors.approvalBar.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          top: BorderSide(color: appColors.approvalBarBorder, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      (_isPlanApproval
                              ? Theme.of(context).colorScheme.primary
                              : appColors.permissionIcon)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isPlanApproval ? Icons.assignment : Icons.shield,
                  color: _isPlanApproval
                      ? Theme.of(context).colorScheme.primary
                      : appColors.permissionIcon,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolName ?? 'Approval Required',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_pendingPermission != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('reject_button'),
                  onPressed: _rejectToolUse,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_isPlanApproval ? 'Keep Planning' : 'Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('approve_button'),
                  onPressed: _approveToolUse,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_isPlanApproval ? 'Accept Plan' : 'Approve'),
                ),
              ),
            ],
          ),
          if (!_isPlanApproval) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('approve_always_button'),
                onPressed: _approveAlwaysToolUse,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: appColors.subtleText,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Allow for this session'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: const ValueKey('slash_command_button'),
              borderRadius: BorderRadius.circular(20),
              onTap: _showSlashCommandSheet,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CompositedTransformTarget(
              link: _inputLayerLink,
              child: TextField(
                key: const ValueKey('message_input'),
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: 'Message Claude...',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: cs.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: cs.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_status != ProcessStatus.idle && !_hasInputText)
            Container(
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                key: const ValueKey('stop_button'),
                onPressed: _stopSession,
                icon: Icon(Icons.stop_rounded, color: cs.onError, size: 20),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                key: const ValueKey('send_button'),
                onPressed: _sendMessage,
                icon: Icon(Icons.arrow_upward, color: cs.onPrimary, size: 20),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

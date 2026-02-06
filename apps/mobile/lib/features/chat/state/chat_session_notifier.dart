import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/messages.dart';
import '../../../providers/bridge_providers.dart';
import '../../../services/bridge_service.dart';
import '../../../services/chat_message_handler.dart';
import 'chat_session_state.dart';
import 'streaming_state.dart';

part 'chat_session_notifier.g.dart';

/// Manages the state of a single chat session.
///
/// Subscribes to [BridgeService.messagesForSession] and delegates message
/// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
/// applied to the immutable [ChatSessionState].
@riverpod
class ChatSessionNotifier extends _$ChatSessionNotifier {
  late final ChatMessageHandler _handler;
  late final BridgeService _bridge;
  StreamSubscription<ServerMessage>? _subscription;
  bool _pastHistoryLoaded = false;
  Timer? _statusRefreshTimer;

  @override
  ChatSessionState build(String sessionId) {
    _handler = ChatMessageHandler();
    _bridge = ref.watch(bridgeServiceProvider);

    // Subscribe to messages for this session
    _subscription = _bridge.messagesForSession(sessionId).listen(_onMessage);
    ref.onDispose(() {
      _statusRefreshTimer?.cancel();
      _subscription?.cancel();
      _sideEffectsController.close();
    });

    // Consume buffered past history from resume_session flow synchronously
    // so the initial state already contains past entries.
    var initialState = const ChatSessionState();
    final pastHistory = _bridge.pendingPastHistory;
    if (pastHistory != null) {
      _bridge.pendingPastHistory = null;
      _pastHistoryLoaded = true;
      final update = _handler.handle(pastHistory, isBackground: true);
      if (update.entriesToPrepend.isNotEmpty) {
        initialState = initialState.copyWith(entries: update.entriesToPrepend);
      }
    }

    // Request in-memory history from the bridge server
    _bridge.requestSessionHistory(sessionId);

    // Re-query history while status is "starting" to handle lost broadcasts
    _startStatusRefreshTimer();

    return initialState;
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.status != ProcessStatus.starting) {
        _statusRefreshTimer?.cancel();
        _statusRefreshTimer = null;
        return;
      }
      _bridge.requestSessionHistory(sessionId);
    });
  }

  // ---------------------------------------------------------------------------
  // Message processing
  // ---------------------------------------------------------------------------

  void _onMessage(ServerMessage msg) {
    // Prevent duplicate past_history processing
    if (msg is PastHistoryMessage) {
      if (_pastHistoryLoaded) return;
      _pastHistoryLoaded = true;
    }

    final update = _handler.handle(msg, isBackground: true);
    _applyUpdate(update, msg);
  }

  void _applyUpdate(ChatStateUpdate update, ServerMessage originalMsg) {
    final current = state;

    // --- Streaming state (separate provider) ---
    final streamingNotifier = ref.read(
      streamingStateNotifierProvider(sessionId).notifier,
    );

    if (update.resetStreaming) {
      _handler.currentStreaming = null;
      streamingNotifier.reset();
    }

    // Handle stream delta → streaming provider
    if (originalMsg is StreamDeltaMessage) {
      streamingNotifier.appendText(originalMsg.text);
      return; // No main state update needed for deltas
    }
    if (originalMsg is ThinkingDeltaMessage) {
      streamingNotifier.appendThinking(originalMsg.text);
      return;
    }

    // --- Build new entries list ---
    var entries = current.entries;
    var didModifyEntries = false;

    // When assistant message arrives and streaming was active, reset streaming
    if (originalMsg is AssistantServerMessage &&
        _handler.currentStreaming == null) {
      streamingNotifier.reset();
    }

    // Prepend entries (past history)
    if (update.entriesToPrepend.isNotEmpty) {
      entries = [...update.entriesToPrepend, ...entries];
      didModifyEntries = true;
    }

    // Mark user messages as sent
    if (update.markUserMessagesSent) {
      final updated = entries.map((e) {
        if (e is UserChatEntry && e.status == MessageStatus.sending) {
          return UserChatEntry(
            e.text,
            sessionId: e.sessionId,
            status: MessageStatus.sent,
            timestamp: e.timestamp,
          );
        }
        return e;
      }).toList();
      if (updated != entries) {
        entries = updated;
        didModifyEntries = true;
      }
    }

    // Add new entries (skip streaming entries — those go to StreamingState)
    final nonStreamingEntries = update.entriesToAdd
        .where((e) => e is! StreamingChatEntry)
        .toList();
    if (nonStreamingEntries.isNotEmpty) {
      entries = [...entries, ...nonStreamingEntries];
      didModifyEntries = true;
    }

    // --- Build new approval state ---
    ApprovalState approval = current.approval;
    if (update.resetPending && update.resetAsk) {
      approval = const ApprovalState.none();
    } else if (update.resetPending) {
      if (approval is ApprovalPermission) {
        approval = const ApprovalState.none();
      }
    } else if (update.resetAsk) {
      if (approval is ApprovalAskUser) {
        approval = const ApprovalState.none();
      }
    }

    if (update.pendingPermission != null) {
      approval = ApprovalState.permission(
        toolUseId: update.pendingToolUseId!,
        request: update.pendingPermission!,
      );
    }
    if (update.askToolUseId != null) {
      approval = ApprovalState.askUser(
        toolUseId: update.askToolUseId!,
        input: update.askInput ?? {},
      );
    }

    // Stop status refresh timer when status changes from starting
    if (update.status != null && update.status != ProcessStatus.starting) {
      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = null;
    }

    // --- Update hidden tool use IDs (for subagent summary compression) ---
    var hiddenToolUseIds = current.hiddenToolUseIds;
    if (update.toolUseIdsToHide.isNotEmpty) {
      hiddenToolUseIds = {...hiddenToolUseIds, ...update.toolUseIdsToHide};
    }

    // --- Apply state update ---
    state = current.copyWith(
      status: update.status ?? current.status,
      entries: didModifyEntries ? entries : current.entries,
      approval: approval,
      totalCost: current.totalCost + (update.costDelta ?? 0),
      inPlanMode: update.inPlanMode ?? current.inPlanMode,
      slashCommands: update.slashCommands ?? current.slashCommands,
      claudeSessionId: update.resultSessionId ?? current.claudeSessionId,
      hiddenToolUseIds: hiddenToolUseIds,
    );

    // --- Fire side effects ---
    if (update.sideEffects.isNotEmpty) {
      _sideEffectsController.add(update.sideEffects);
    }
  }

  // ---------------------------------------------------------------------------
  // Side effects stream
  // ---------------------------------------------------------------------------

  final _sideEffectsController =
      StreamController<Set<ChatSideEffect>>.broadcast();

  /// Stream of side effects that the UI layer must execute (haptics, etc.).
  Stream<Set<ChatSideEffect>> get sideEffects => _sideEffectsController.stream;

  // ---------------------------------------------------------------------------
  // Commands (Path B: UI → Notifier → Bridge)
  // ---------------------------------------------------------------------------

  /// Send a user message.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final entry = UserChatEntry(text, sessionId: sessionId);
    state = state.copyWith(entries: [...state.entries, entry]);
    _bridge.send(ClientMessage.input(text, sessionId: sessionId));
  }

  /// Approve a pending tool execution.
  /// If [updatedInput] is provided, the original tool input is merged with it.
  void approve(String toolUseId, {Map<String, dynamic>? updatedInput}) {
    _bridge.send(
      ClientMessage.approve(
        toolUseId,
        updatedInput: updatedInput,
        sessionId: sessionId,
      ),
    );
    state = state.copyWith(approval: const ApprovalState.none());
  }

  /// Approve a tool and always allow it in the future.
  void approveAlways(String toolUseId) {
    _bridge.send(ClientMessage.approveAlways(toolUseId, sessionId: sessionId));
    state = state.copyWith(approval: const ApprovalState.none());
  }

  /// Reject a pending tool execution.
  void reject(String toolUseId, {String? message}) {
    _bridge.send(
      ClientMessage.reject(toolUseId, message: message, sessionId: sessionId),
    );
    state = state.copyWith(
      approval: const ApprovalState.none(),
      inPlanMode: false,
    );
  }

  /// Answer an AskUserQuestion.
  void answer(String toolUseId, String result) {
    _bridge.send(ClientMessage.answer(toolUseId, result, sessionId: sessionId));
    state = state.copyWith(approval: const ApprovalState.none());
  }

  /// Interrupt the current operation.
  void interrupt() {
    _bridge.interrupt(sessionId);
  }

  /// Stop the session.
  void stop() {
    _bridge.stopSession(sessionId);
  }

  /// Retry a failed user message.
  void retryMessage(UserChatEntry entry) {
    state = state.copyWith(
      entries: state.entries.map((e) {
        if (identical(e, entry)) {
          return UserChatEntry(
            entry.text,
            sessionId: entry.sessionId ?? sessionId,
            status: MessageStatus.sending,
            timestamp: entry.timestamp,
          );
        }
        return e;
      }).toList(),
    );
    _bridge.send(
      ClientMessage.input(entry.text, sessionId: entry.sessionId ?? sessionId),
    );
  }
}

/// Manages the high-frequency streaming state for a chat session.
///
/// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
/// entire message list on every streaming delta.
@riverpod
class StreamingStateNotifier extends _$StreamingStateNotifier {
  @override
  StreamingState build(String sessionId) => const StreamingState();

  void appendText(String text) {
    state = state.copyWith(text: state.text + text, isStreaming: true);
  }

  void appendThinking(String text) {
    state = state.copyWith(thinking: state.thinking + text);
  }

  void reset() {
    state = const StreamingState();
  }
}

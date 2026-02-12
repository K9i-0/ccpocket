import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../services/chat_message_handler.dart';
import 'chat_session_state.dart';
import 'streaming_state_cubit.dart';

/// Manages the state of a single chat session.
///
/// Subscribes to [BridgeService.messagesForSession] and delegates message
/// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
/// applied to the immutable [ChatSessionState].
class ChatSessionCubit extends Cubit<ChatSessionState> {
  final String sessionId;
  final BridgeService _bridge;
  final StreamingStateCubit _streamingCubit;
  final ChatMessageHandler _handler = ChatMessageHandler();

  StreamSubscription<ServerMessage>? _subscription;
  bool _pastHistoryLoaded = false;
  Timer? _statusRefreshTimer;

  /// Tool use IDs that have been approved or rejected locally.
  /// Cleared when corresponding [ToolResultMessage] arrives or session
  /// completes ([ResultMessage]).
  final _respondedToolUseIds = <String>{};

  ChatSessionCubit({
    required this.sessionId,
    required BridgeService bridge,
    required StreamingStateCubit streamingCubit,
  }) : _bridge = bridge,
       _streamingCubit = streamingCubit,
       super(_buildInitialState(bridge)) {
    // Subscribe to messages for this session
    _subscription = _bridge.messagesForSession(sessionId).listen(_onMessage);

    // Request in-memory history from the bridge server
    _bridge.requestSessionHistory(sessionId);

    // Re-query history while status is "starting" to handle lost broadcasts
    _startStatusRefreshTimer();
  }

  static ChatSessionState _buildInitialState(BridgeService bridge) {
    var initialState = const ChatSessionState();
    final pastHistory = bridge.pendingPastHistory;
    if (pastHistory != null) {
      bridge.pendingPastHistory = null;
      final handler = ChatMessageHandler();
      final update = handler.handle(pastHistory, isBackground: true);
      if (update.entriesToPrepend.isNotEmpty) {
        initialState = initialState.copyWith(entries: update.entriesToPrepend);
      }
    }
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

    // --- Streaming state (separate cubit) ---
    if (update.resetStreaming) {
      _handler.currentStreaming = null;
      _streamingCubit.reset();
    }

    // Handle stream delta → streaming cubit
    if (originalMsg is StreamDeltaMessage) {
      _streamingCubit.appendText(originalMsg.text);
      return; // No main state update needed for deltas
    }
    if (originalMsg is ThinkingDeltaMessage) {
      _streamingCubit.appendThinking(originalMsg.text);
      return;
    }

    // --- Build new entries list ---
    var entries = current.entries;
    var didModifyEntries = false;

    // When assistant message arrives and streaming was active, reset streaming
    if (originalMsg is AssistantServerMessage &&
        _handler.currentStreaming == null) {
      _streamingCubit.reset();
    }

    // Prepend entries (past history)
    if (update.entriesToPrepend.isNotEmpty) {
      entries = [...update.entriesToPrepend, ...entries];
      didModifyEntries = true;
    }

    // Mark user messages as sent
    if (update.markUserMessagesSent) {
      var changed = false;
      final updated = entries.map((e) {
        if (e is UserChatEntry && e.status == MessageStatus.sending) {
          changed = true;
          return UserChatEntry(
            e.text,
            sessionId: e.sessionId,
            status: MessageStatus.sent,
            timestamp: e.timestamp,
          );
        }
        return e;
      }).toList();
      if (changed) {
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

    // --- Cleanup responded tool use IDs ---
    if (originalMsg is ToolResultMessage) {
      _respondedToolUseIds.remove(originalMsg.toolUseId);
    }
    if (originalMsg is ResultMessage) {
      _respondedToolUseIds.clear();
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
    emit(
      current.copyWith(
        status: update.status ?? current.status,
        entries: didModifyEntries ? entries : current.entries,
        approval: approval,
        totalCost: current.totalCost + (update.costDelta ?? 0),
        inPlanMode: update.inPlanMode ?? current.inPlanMode,
        slashCommands: update.slashCommands ?? current.slashCommands,
        claudeSessionId: update.resultSessionId ?? current.claudeSessionId,
        hiddenToolUseIds: hiddenToolUseIds,
      ),
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
  // Commands (Path B: UI → Cubit → Bridge)
  // ---------------------------------------------------------------------------

  /// Send a user message, optionally with an image attachment.
  void sendMessage(
    String text, {
    String? imageId,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) {
    if (text.trim().isEmpty && imageId == null && imageBytes == null) return;
    final entry = UserChatEntry(
      text,
      sessionId: sessionId,
      imageId: imageId,
      imageUrl: imageUrl,
      imageBytes: imageBytes,
    );
    emit(state.copyWith(entries: [...state.entries, entry]));

    // Send Base64 directly via WebSocket if image bytes are provided
    String? imageBase64;
    if (imageBytes != null) {
      imageBase64 = base64Encode(imageBytes);
    }

    _bridge.send(
      ClientMessage.input(
        text,
        sessionId: sessionId,
        imageId: imageId,
        imageBase64: imageBase64,
        mimeType: imageMimeType,
      ),
    );
  }

  /// Approve a pending tool execution.
  void approve(
    String toolUseId, {
    Map<String, dynamic>? updatedInput,
    bool clearContext = false,
  }) {
    _respondedToolUseIds.add(toolUseId);
    _bridge.send(
      ClientMessage.approve(
        toolUseId,
        updatedInput: updatedInput,
        clearContext: clearContext,
        sessionId: sessionId,
      ),
    );
    _emitNextApprovalOrNone(toolUseId);
  }

  /// Approve a tool and always allow it in the future.
  void approveAlways(String toolUseId) {
    _respondedToolUseIds.add(toolUseId);
    _bridge.send(ClientMessage.approveAlways(toolUseId, sessionId: sessionId));
    _emitNextApprovalOrNone(toolUseId);
  }

  /// Find next pending permission after resolving [resolvedToolUseId].
  ///
  /// Searches entries for PermissionRequestMessage that haven't been resolved
  /// by a corresponding ToolResultMessage.
  void _emitNextApprovalOrNone(String resolvedToolUseId) {
    final pendingPermissions = <String, PermissionRequestMessage>{};
    final resolvedIds = <String>{resolvedToolUseId, ..._respondedToolUseIds};

    for (final entry in state.entries) {
      if (entry is ServerChatEntry) {
        final msg = entry.message;
        if (msg is PermissionRequestMessage) {
          pendingPermissions[msg.toolUseId] = msg;
        } else if (msg is ToolResultMessage) {
          resolvedIds.add(msg.toolUseId);
        }
      }
    }

    // Remove resolved permissions
    for (final id in resolvedIds) {
      pendingPermissions.remove(id);
    }

    if (pendingPermissions.isNotEmpty) {
      final next = pendingPermissions.values.first;
      emit(
        state.copyWith(
          approval: ApprovalState.permission(
            toolUseId: next.toolUseId,
            request: next,
          ),
        ),
      );
    } else {
      emit(state.copyWith(approval: const ApprovalState.none()));
    }
  }

  /// Reject a pending tool execution.
  void reject(String toolUseId, {String? message}) {
    _respondedToolUseIds.add(toolUseId);
    _bridge.send(
      ClientMessage.reject(toolUseId, message: message, sessionId: sessionId),
    );
    emit(
      state.copyWith(approval: const ApprovalState.none(), inPlanMode: false),
    );
  }

  /// Answer an AskUserQuestion.
  void answer(String toolUseId, String result) {
    _bridge.send(ClientMessage.answer(toolUseId, result, sessionId: sessionId));
    emit(state.copyWith(approval: const ApprovalState.none()));
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
    emit(
      state.copyWith(
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
      ),
    );
    _bridge.send(
      ClientMessage.input(entry.text, sessionId: entry.sessionId ?? sessionId),
    );
  }

  @override
  Future<void> close() {
    _statusRefreshTimer?.cancel();
    _subscription?.cancel();
    _sideEffectsController.close();
    return super.close();
  }
}

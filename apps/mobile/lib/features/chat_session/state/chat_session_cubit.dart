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
  final Provider? provider;
  final BridgeService _bridge;
  final StreamingStateCubit _streamingCubit;
  final ChatMessageHandler _handler = ChatMessageHandler();

  StreamSubscription<ServerMessage>? _subscription;
  bool _pastHistoryLoaded = false;
  Timer? _statusRefreshTimer;

  /// Number of entries prepended from past_history, so that [replaceEntries]
  /// can preserve them while replacing in-memory history entries.
  int _pastEntryCount = 0;

  /// Tool use IDs that have been approved or rejected locally.
  /// Cleared when corresponding [ToolResultMessage] arrives or session
  /// completes ([ResultMessage]).
  final _respondedToolUseIds = <String>{};

  /// Whether this session is a Codex session.
  bool get isCodex => provider == Provider.codex;

  ChatSessionCubit({
    required this.sessionId,
    this.provider,
    required BridgeService bridge,
    required StreamingStateCubit streamingCubit,
    PermissionMode? initialPermissionMode,
    SandboxMode? initialSandboxMode,
  }) : _bridge = bridge,
       _streamingCubit = streamingCubit,
       super(
         ChatSessionState(
           permissionMode: initialPermissionMode ?? PermissionMode.defaultMode,
           sandboxMode: initialSandboxMode ?? SandboxMode.on,
           inPlanMode: initialPermissionMode == PermissionMode.plan,
         ),
       ) {
    // Subscribe to messages for this session
    _subscription = _bridge.messagesForSession(sessionId).listen(_onMessage);

    // Request in-memory history from the bridge server
    _bridge.requestSessionHistory(sessionId);

    // Re-query history while status is "starting" to handle lost broadcasts
    _startStatusRefreshTimer();
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

    // Handle rewind preview separately — store in dedicated state field
    if (msg is RewindPreviewMessage) {
      emit(state.copyWith(rewindPreview: msg));
      return;
    }

    final update = _handler.handle(msg, isBackground: true, isCodex: isCodex);
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
      _pastEntryCount += update.entriesToPrepend.length;
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
            imageBytesList: e.imageBytesList,
            imageUrls: e.imageUrls,
            imageCount: e.imageCount,
            status: MessageStatus.sent,
            messageUuid: e.messageUuid,
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

    // Mark user messages as failed (rejected by bridge)
    if (update.markUserMessagesFailed) {
      var changed = false;
      final updated = entries.map((e) {
        if (e is UserChatEntry && e.status == MessageStatus.sending) {
          changed = true;
          return UserChatEntry(
            e.text,
            sessionId: e.sessionId,
            imageBytesList: e.imageBytesList,
            imageUrls: e.imageUrls,
            imageCount: e.imageCount,
            status: MessageStatus.failed,
            messageUuid: e.messageUuid,
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

    // Apply UUID update from SDK echo (makes the user entry rewindable)
    if (update.userUuidUpdate != null) {
      final (:text, :uuid) = update.userUuidUpdate!;
      for (int i = entries.length - 1; i >= 0; i--) {
        final e = entries[i];
        if (e is UserChatEntry && e.messageUuid == null && e.text == text) {
          e.messageUuid = uuid;
          didModifyEntries = true;
          break;
        }
      }
    }

    // Add new entries (skip streaming entries — those go to StreamingState)
    final nonStreamingEntries = update.entriesToAdd
        .where((e) => e is! StreamingChatEntry)
        .toList();
    if (update.replaceEntries) {
      // History is a full snapshot — replace all non-past-history entries
      // to prevent duplicates when get_history is received multiple times.
      final pastEntries = entries.take(_pastEntryCount).toList();
      final existingNonPast = entries.skip(_pastEntryCount).toList();
      final historyCount = nonStreamingEntries.length;

      // Preserve live entries that the history snapshot may not contain.
      //
      // The server builds the snapshot from session.history at the time of
      // the get_history request. Live-broadcast messages that arrived at the
      // client AFTER that snapshot was taken would be lost by a blind
      // replace. If the client already has MORE non-past entries than the
      // history provides, the tail entries are live-only and must survive.
      //
      // Also preserve locally-added UserChatEntry (status: sending) that
      // the server history won't contain until the SDK echoes them back.
      final extraLiveEntries = <ChatEntry>[];
      if (existingNonPast.length > historyCount) {
        extraLiveEntries.addAll(existingNonPast.skip(historyCount));
      }
      // Preserve any "sending" user entries that aren't already in history
      // or extras (they were added by sendMessage() before the server
      // confirmed receipt).
      for (final e in existingNonPast) {
        if (e is UserChatEntry &&
            e.status == MessageStatus.sending &&
            !extraLiveEntries.contains(e)) {
          // Check whether this user entry is already covered by history
          final coveredByHistory = nonStreamingEntries.any(
            (h) => h is UserChatEntry && h.text == e.text,
          );
          if (!coveredByHistory) {
            extraLiveEntries.add(e);
          }
        }
      }

      entries = [...pastEntries, ...nonStreamingEntries, ...extraLiveEntries];
      didModifyEntries = true;
    } else if (nonStreamingEntries.isNotEmpty) {
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

    final nextEntries = didModifyEntries ? entries : current.entries;
    final usage = _calculateUsageTotals(nextEntries);

    // --- Apply state update ---
    emit(
      current.copyWith(
        status: update.status ?? current.status,
        entries: nextEntries,
        approval: approval,
        totalCost: usage.totalCost,
        totalDuration: usage.totalDuration,
        inPlanMode: update.inPlanMode ?? current.inPlanMode,
        slashCommands: update.slashCommands ?? current.slashCommands,
        claudeSessionId: update.claudeSessionId ?? current.claudeSessionId,
        hiddenToolUseIds: hiddenToolUseIds,
      ),
    );

    // --- Fire side effects ---
    if (update.sideEffects.isNotEmpty) {
      _sideEffectsController.add(update.sideEffects);
    }
  }

  _UsageTotals _calculateUsageTotals(List<ChatEntry> entries) {
    double totalCost = 0;
    double durationMs = 0;
    var hasDuration = false;

    for (final entry in entries) {
      if (entry is! ServerChatEntry) continue;
      final msg = entry.message;
      if (msg is! ResultMessage) continue;

      if (msg.cost != null) {
        totalCost += msg.cost!;
      }
      if (msg.duration != null && msg.duration! >= 0) {
        durationMs += msg.duration!;
        hasDuration = true;
      }
    }

    return _UsageTotals(
      totalCost: totalCost,
      totalDuration: hasDuration
          ? Duration(milliseconds: durationMs.round())
          : null,
    );
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

  /// Send a user message, optionally with image attachments.
  void sendMessage(
    String text, {
    List<({Uint8List bytes, String mimeType})>? images,
  }) {
    if (text.trim().isEmpty && (images == null || images.isEmpty)) return;
    final entry = UserChatEntry(
      text,
      sessionId: sessionId,
      imageBytesList: images?.map((i) => i.bytes).toList(),
    );
    emit(state.copyWith(entries: [...state.entries, entry]));

    // Encode images as Base64 for WebSocket transmission
    List<Map<String, String>>? imagePayloads;
    if (images != null && images.isNotEmpty) {
      imagePayloads = images
          .map((i) => {'base64': base64Encode(i.bytes), 'mimeType': i.mimeType})
          .toList();
    }

    _bridge.send(
      ClientMessage.input(text, sessionId: sessionId, images: imagePayloads),
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

  /// Change permission mode for Claude sessions.
  void setPermissionMode(PermissionMode mode) {
    emit(state.copyWith(permissionMode: mode));
    _bridge.send(
      ClientMessage.setPermissionMode(mode.value, sessionId: sessionId),
    );
  }

  /// Change sandbox mode for Codex sessions.
  /// Bridge applies this safely without forcing an in-place thread restart.
  void setSandboxMode(SandboxMode mode) {
    if (!isCodex) return;
    emit(state.copyWith(sandboxMode: mode));
    _bridge.send(
      ClientMessage.setSandboxMode(mode.value, sessionId: sessionId),
    );
  }

  /// Stop the session.
  void stop() {
    _bridge.stopSession(sessionId);
  }

  /// Request a dry-run preview of file rewind.
  void rewindDryRun(String targetUuid) {
    emit(state.copyWith(rewindPreview: null));
    _bridge.send(ClientMessage.rewindDryRun(sessionId, targetUuid));
  }

  /// Execute a rewind operation.
  /// [mode] is one of: "conversation", "code", "both".
  void rewind(String targetUuid, String mode) {
    _bridge.send(ClientMessage.rewind(sessionId, targetUuid, mode));
  }

  /// All user messages with a UUID (rewindable via the SDK).
  List<UserChatEntry> get rewindableUserMessages {
    return state.entries
        .whereType<UserChatEntry>()
        .where((e) => e.messageUuid != null)
        .toList();
  }

  /// All user messages in the session (for display in message history).
  List<UserChatEntry> get allUserMessages {
    return state.entries.whereType<UserChatEntry>().toList();
  }

  /// Re-fetch session history from the bridge server.
  ///
  /// Resets [_pastHistoryLoaded] so the next [PastHistoryMessage] is processed,
  /// restoring approval state that may have arrived while disconnected.
  void refreshHistory() {
    _pastHistoryLoaded = false;
    _pastEntryCount = 0;
    _bridge.requestSessionHistory(sessionId);
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

class _UsageTotals {
  final double totalCost;
  final Duration? totalDuration;

  const _UsageTotals({required this.totalCost, required this.totalDuration});
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger.dart';
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

  PermissionMode? _pendingPermissionRollback;
  ExecutionMode? _pendingExecutionRollback;
  CodexApprovalPolicy? _pendingCodexApprovalRollback;
  String? _pendingCodexApprovalsReviewerRollback;
  bool? _pendingPlanRollback;
  SandboxMode? _pendingSandboxRollback;

  /// Whether this session is a Codex session.
  bool get isCodex => provider == Provider.codex;

  ChatSessionCubit({
    required this.sessionId,
    this.provider,
    required BridgeService bridge,
    required StreamingStateCubit streamingCubit,
    String initialExplorerCurrentPath = '',
    List<String> initialRecentPeekedFiles = const [],
    PermissionMode? initialPermissionMode,
    SandboxMode? initialSandboxMode,
    CodexApprovalPolicy? initialCodexApprovalPolicy,
    String? initialCodexApprovalsReviewer,
  }) : _bridge = bridge,
       _streamingCubit = streamingCubit,
       super(
         ChatSessionState(
           permissionMode: initialPermissionMode ?? PermissionMode.defaultMode,
           executionMode: deriveExecutionMode(
             provider: provider?.value,
             permissionMode: initialPermissionMode?.value,
           ),
           codexApprovalPolicy: provider == Provider.codex
               ? (initialCodexApprovalPolicy == CodexApprovalPolicy.onFailure
                     ? CodexApprovalPolicy.onRequest
                     : initialCodexApprovalPolicy ??
                           codexApprovalPolicyFromLegacyExecutionMode(
                             deriveExecutionMode(
                               provider: provider?.value,
                               permissionMode: initialPermissionMode?.value,
                             ).value,
                           ))
               : CodexApprovalPolicy.onRequest,
           codexApprovalsReviewer:
               provider == Provider.codex &&
                   isCodexAutoReviewApprovalsReviewer(
                     initialCodexApprovalsReviewer,
                   )
               ? 'auto_review'
               : 'user',
           planMode: initialPermissionMode == PermissionMode.plan,
           sandboxMode:
               initialSandboxMode ??
               (provider == Provider.codex ? SandboxMode.on : SandboxMode.off),
           inPlanMode: initialPermissionMode == PermissionMode.plan,
           explorerCurrentPath: initialExplorerCurrentPath.trim(),
           recentPeekedFiles: initialRecentPeekedFiles
               .map((file) => file.trim())
               .where((file) => file.isNotEmpty)
               .take(10)
               .toList(),
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
    // Log errors prominently
    if (msg is ErrorMessage) {
      logger.error('[session:$sessionId] Error from bridge: ${msg.message}');
      _rollbackFailedModeChange(msg);
    }

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

    try {
      final update = _handler.handle(msg, isBackground: true, isCodex: isCodex);
      _applyUpdate(update, msg);
    } catch (e, st) {
      logger.error(
        '[session:$sessionId] Failed to handle message: '
        '${msg.runtimeType}',
        e,
        st,
      );
    }
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

    // Advance at most one user message status per server event.
    // This keeps FIFO behavior when multiple user messages are queued.
    //
    // - queued ack: first sending -> queued
    // - sent ack / assistant/result: first queued -> sent
    //   (fallback to first sending -> sent for non-queued path)
    if (update.markUserMessagesSent) {
      final targetStatus = update.markUserMessagesQueued
          ? MessageStatus.queued
          : MessageStatus.sent;
      int targetIndex = -1;
      if (update.markUserMessagesQueued) {
        targetIndex = entries.indexWhere(
          (e) => e is UserChatEntry && e.status == MessageStatus.sending,
        );
      } else {
        targetIndex = entries.indexWhere(
          (e) => e is UserChatEntry && e.status == MessageStatus.queued,
        );
        if (targetIndex == -1) {
          targetIndex = entries.indexWhere(
            (e) => e is UserChatEntry && e.status == MessageStatus.sending,
          );
        }
      }
      if (targetIndex != -1) {
        final entry = entries[targetIndex] as UserChatEntry;
        final updatedEntry = UserChatEntry(
          entry.text,
          sessionId: entry.sessionId,
          imageBytesList: entry.imageBytesList,
          imageUrls: entry.imageUrls,
          imageCount: entry.imageCount,
          status: targetStatus,
          messageUuid: entry.messageUuid,
          timestamp: entry.timestamp,
        );
        entries = [...entries];
        entries[targetIndex] = updatedEntry;
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

      // Preserve local data (image bytes, timestamps) from existing entries
      // that the server history does not contain.
      // Match by messageUuid (preferred) or text content (fallback for
      // entries whose UUID hasn't been assigned yet).
      final existingUserData = <String, UserChatEntry>{};
      for (final e in existingNonPast) {
        if (e is UserChatEntry) {
          if (e.messageUuid != null) {
            existingUserData[e.messageUuid!] = e;
          } else {
            existingUserData['text:${e.text}'] = e;
          }
        }
      }
      if (existingUserData.isNotEmpty) {
        for (int i = 0; i < entries.length; i++) {
          final e = entries[i];
          if (e is! UserChatEntry) continue;
          final existing =
              (e.messageUuid != null
                  ? existingUserData[e.messageUuid!]
                  : null) ??
              existingUserData['text:${e.text}'];
          if (existing == null) continue;
          final needsImages =
              e.imageBytesList.isEmpty && existing.imageBytesList.isNotEmpty;
          final needsTimestamp = existing.timestamp != e.timestamp;
          if (needsImages || needsTimestamp) {
            entries[i] = UserChatEntry(
              e.text,
              sessionId: e.sessionId,
              imageBytesList: needsImages
                  ? existing.imageBytesList
                  : e.imageBytesList,
              imageUrls: e.imageUrls,
              imageCount: e.imageCount,
              status: e.status,
              messageUuid: e.messageUuid,
              timestamp: existing.timestamp,
            );
          }
        }
      }

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
    final newClaudeSessionId =
        update.claudeSessionId ?? current.claudeSessionId;
    emit(
      current.copyWith(
        status: update.status ?? current.status,
        entries: nextEntries,
        approval: approval,
        totalCost: usage.totalCost,
        totalDuration: usage.totalDuration,
        inPlanMode: update.inPlanMode ?? current.inPlanMode,
        permissionMode: update.permissionMode ?? current.permissionMode,
        executionMode: update.executionMode ?? current.executionMode,
        codexApprovalPolicy:
            update.codexApprovalPolicy ?? current.codexApprovalPolicy,
        codexApprovalsReviewer:
            update.codexApprovalsReviewer ?? current.codexApprovalsReviewer,
        planMode: update.planMode ?? current.planMode,
        slashCommands: update.slashCommands ?? current.slashCommands,
        queuedInput: update.clearQueuedInput
            ? null
            : (update.queuedInput ?? current.queuedInput),
        claudeSessionId: newClaudeSessionId,
        hiddenToolUseIds: hiddenToolUseIds,
      ),
    );

    // Persist initial Claude settings when claudeSessionId is first known.
    if (update.claudeSessionId != null &&
        current.claudeSessionId == null &&
        provider != Provider.codex) {
      unawaited(
        _SessionSettingsHelper.save(update.claudeSessionId!, {
          'permissionMode': current.permissionMode.value,
          'sandboxMode': current.sandboxMode.value,
        }),
      );
    }

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

  void setExplorerCurrentPath(String path) {
    final normalized = path.trim();
    if (normalized == state.explorerCurrentPath) return;
    emit(state.copyWith(explorerCurrentPath: normalized));
  }

  void setRecentPeekedFiles(List<String> files) {
    final normalized = files
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .take(10)
        .toList();
    if (_listEquals(normalized, state.recentPeekedFiles)) return;
    emit(state.copyWith(recentPeekedFiles: normalized));
  }

  void recordPeekedFile(String path) {
    final next = updateRecentPeekedFiles(state.recentPeekedFiles, path);
    if (_listEquals(next, state.recentPeekedFiles)) return;
    emit(state.copyWith(recentPeekedFiles: next));
  }

  // ---------------------------------------------------------------------------
  // Commands (Path B: UI → Cubit → Bridge)
  // ---------------------------------------------------------------------------

  /// Send a user message, optionally with image attachments.
  void sendMessage(
    String text, {
    List<({Uint8List bytes, String mimeType})>? images,
  }) {
    if (text.trim().isEmpty && (images == null || images.isEmpty)) return;
    if (isCodex && state.queuedInput != null) return;

    final shouldAddLocalEntry = !isCodex || state.status == ProcessStatus.idle;
    if (shouldAddLocalEntry) {
      final entry = UserChatEntry(
        text,
        sessionId: sessionId,
        imageBytesList: images?.map((i) => i.bytes).toList(),
      );
      emit(state.copyWith(entries: [...state.entries, entry]));
    }

    // Encode images as Base64 for WebSocket transmission
    List<Map<String, String>>? imagePayloads;
    if (images != null && images.isNotEmpty) {
      imagePayloads = images
          .map((i) => {'base64': base64Encode(i.bytes), 'mimeType': i.mimeType})
          .toList();
    }

    final structuredMentions = isCodex
        ? _extractCodexStructuredInputs(text)
        : (
            skills: const <Map<String, String>>[],
            mentions: const <Map<String, String>>[],
          );

    _bridge.send(
      ClientMessage.input(
        text,
        sessionId: sessionId,
        images: imagePayloads,
        skill: structuredMentions.skills.isNotEmpty
            ? structuredMentions.skills.first
            : null,
        skills: structuredMentions.skills,
        mentions: structuredMentions.mentions,
      ),
    );
  }

  void updateQueuedInput(QueuedInputItem item, String text) {
    if (!isCodex || text.trim().isEmpty) return;
    final structuredMentions = _extractCodexStructuredInputs(text);
    _bridge.send(
      ClientMessage.updateQueuedInput(
        sessionId: sessionId,
        itemId: item.itemId,
        text: text,
        skills: structuredMentions.skills,
        mentions: structuredMentions.mentions,
      ),
    );
  }

  void steerQueuedInput(QueuedInputItem item) {
    if (!isCodex) return;
    _bridge.send(
      ClientMessage.steerQueuedInput(sessionId: sessionId, itemId: item.itemId),
    );
  }

  void cancelQueuedInput(QueuedInputItem item) {
    if (!isCodex) return;
    _bridge.send(
      ClientMessage.cancelQueuedInput(
        sessionId: sessionId,
        itemId: item.itemId,
      ),
    );
  }

  /// Approve a pending tool execution.
  void approve(String toolUseId, {bool clearContext = false}) {
    final isExitPlanApproval = _isExitPlanApproval(toolUseId);
    logger.info(
      '[session:$sessionId] approve toolUseId=$toolUseId'
      '${clearContext ? ' clearContext' : ''}',
    );
    _respondedToolUseIds.add(toolUseId);
    _bridge.send(
      ClientMessage.approve(
        toolUseId,
        clearContext: clearContext,
        sessionId: sessionId,
      ),
    );
    _emitNextApprovalOrNone(
      toolUseId,
      exitPlanModeResolved: isExitPlanApproval,
    );
  }

  /// Approve a tool and always allow it in the future.
  void approveAlways(String toolUseId) {
    final isExitPlanApproval = _isExitPlanApproval(toolUseId);
    _respondedToolUseIds.add(toolUseId);
    _bridge.send(ClientMessage.approveAlways(toolUseId, sessionId: sessionId));
    _emitNextApprovalOrNone(
      toolUseId,
      exitPlanModeResolved: isExitPlanApproval,
    );
  }

  /// Find next pending permission after resolving [resolvedToolUseId].
  ///
  /// Searches entries for PermissionRequestMessage that haven't been resolved
  /// by a corresponding ToolResultMessage.
  void _emitNextApprovalOrNone(
    String resolvedToolUseId, {
    bool exitPlanModeResolved = false,
  }) {
    final pendingPermissions = <String, PermissionRequestMessage>{};
    final resolvedIds = <String>{resolvedToolUseId, ..._respondedToolUseIds};

    for (final entry in state.entries) {
      if (entry is ServerChatEntry) {
        final msg = entry.message;
        if (msg is PermissionRequestMessage) {
          pendingPermissions[msg.toolUseId] = msg;
        } else if (msg is PermissionResolvedMessage) {
          resolvedIds.add(msg.toolUseId);
        } else if (msg is ToolResultMessage) {
          resolvedIds.add(msg.toolUseId);
        }
      }
    }

    // Remove resolved permissions
    for (final id in resolvedIds) {
      pendingPermissions.remove(id);
    }

    final resolvedPermissionMode = exitPlanModeResolved
        ? legacyPermissionModeFromModes(
            provider ?? Provider.claude,
            executionMode: state.executionMode,
            planMode: false,
          )
        : state.permissionMode;

    if (pendingPermissions.isNotEmpty) {
      final next = pendingPermissions.values.first;
      emit(
        state.copyWith(
          approval: ApprovalState.permission(
            toolUseId: next.toolUseId,
            request: next,
          ),
          permissionMode: resolvedPermissionMode,
          planMode: next.toolName == 'ExitPlanMode'
              ? true
              : (exitPlanModeResolved ? false : state.planMode),
          inPlanMode: next.toolName == 'ExitPlanMode'
              ? true
              : (exitPlanModeResolved ? false : state.inPlanMode),
        ),
      );
    } else {
      emit(
        state.copyWith(
          approval: const ApprovalState.none(),
          permissionMode: resolvedPermissionMode,
          planMode: exitPlanModeResolved ? false : state.planMode,
          inPlanMode: exitPlanModeResolved ? false : state.inPlanMode,
        ),
      );
    }
  }

  bool _isExitPlanApproval(String toolUseId) {
    final approval = state.approval;
    if (approval is ApprovalPermission &&
        approval.toolUseId == toolUseId &&
        approval.request.toolName == 'ExitPlanMode') {
      return true;
    }

    for (final entry in state.entries.reversed) {
      if (entry is! ServerChatEntry) continue;
      final msg = entry.message;
      if (msg is PermissionRequestMessage && msg.toolUseId == toolUseId) {
        return msg.toolName == 'ExitPlanMode';
      }
    }
    return false;
  }

  /// Reject a pending tool execution.
  void reject(String toolUseId, {String? message}) {
    logger.info(
      '[session:$sessionId] reject toolUseId=$toolUseId'
      '${message != null ? ' msg=$message' : ''}',
    );
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
    logger.info('[session:$sessionId] setPermissionMode=${mode.value}');
    _pendingPermissionRollback = state.permissionMode;
    emit(
      state.copyWith(
        permissionMode: mode,
        inPlanMode: mode == PermissionMode.plan,
      ),
    );
    _bridge.patchSessionPermissionMode(sessionId, mode.value);
    _bridge.send(
      ClientMessage.setPermissionMode(mode.value, sessionId: sessionId),
    );

    // Persist per-session so that future resumes use this mode.
    final claudeSid = state.claudeSessionId;
    if (claudeSid != null && claudeSid.isNotEmpty) {
      _SessionSettingsHelper.save(claudeSid, {'permissionMode': mode.value});
    }
  }

  void setSessionModes({ExecutionMode? executionMode, bool? planMode}) {
    final nextExecution = executionMode ?? state.executionMode;
    final nextPlanMode = planMode ?? state.planMode;
    final legacyMode = legacyPermissionModeFromModes(
      provider ?? Provider.claude,
      executionMode: nextExecution,
      planMode: nextPlanMode,
    );

    logger.info(
      '[session:$sessionId] setSessionModes '
      'execution=${nextExecution.value} plan=$nextPlanMode',
    );

    _pendingPermissionRollback = state.permissionMode;
    _pendingExecutionRollback = state.executionMode;
    _pendingPlanRollback = state.planMode;

    emit(
      state.copyWith(
        permissionMode: legacyMode,
        executionMode: nextExecution,
        planMode: nextPlanMode,
        inPlanMode: nextPlanMode,
      ),
    );
    _bridge.patchSessionModes(
      sessionId,
      permissionMode: legacyMode.value,
      executionMode: nextExecution.value,
      planMode: nextPlanMode,
    );
    _bridge.send(
      ClientMessage.setSessionMode(
        legacyMode: legacyMode.value,
        executionMode: nextExecution.value,
        planMode: nextPlanMode,
        sessionId: sessionId,
      ),
    );

    final claudeSid = state.claudeSessionId;
    if (claudeSid != null && claudeSid.isNotEmpty) {
      _SessionSettingsHelper.save(claudeSid, {
        'permissionMode': legacyMode.value,
        'executionMode': nextExecution.value,
        'planMode': nextPlanMode,
      });
    }
  }

  void setCodexApprovalPolicy(
    CodexApprovalPolicy policy, {
    String approvalsReviewer = 'user',
  }) {
    final normalizedReviewer =
        policy == CodexApprovalPolicy.onRequest &&
            isCodexAutoReviewApprovalsReviewer(approvalsReviewer)
        ? 'auto_review'
        : 'user';
    logger.info('[session:$sessionId] setCodexApprovalPolicy=${policy.value}');
    _pendingPermissionRollback = state.permissionMode;
    _pendingExecutionRollback = state.executionMode;
    _pendingCodexApprovalRollback = state.codexApprovalPolicy;
    _pendingCodexApprovalsReviewerRollback = state.codexApprovalsReviewer;
    _pendingPlanRollback = state.planMode;

    const legacyMode = PermissionMode.acceptEdits;
    final derivedExecution = policy == CodexApprovalPolicy.never
        ? ExecutionMode.fullAccess
        : ExecutionMode.defaultMode;

    emit(
      state.copyWith(
        permissionMode: legacyMode,
        executionMode: derivedExecution,
        codexApprovalPolicy: policy,
        codexApprovalsReviewer: normalizedReviewer,
        planMode: false,
        inPlanMode: false,
      ),
    );
    _bridge.patchSessionModes(
      sessionId,
      permissionMode: legacyMode.value,
      executionMode: derivedExecution.value,
      planMode: false,
      approvalPolicy: policy.value,
      approvalsReviewer: normalizedReviewer,
    );
    _bridge.send(
      ClientMessage.setSessionMode(
        legacyMode: legacyMode.value,
        executionMode: derivedExecution.value,
        approvalPolicy: policy.value,
        approvalsReviewer: normalizedReviewer,
        planMode: false,
        sessionId: sessionId,
      ),
    );
  }

  /// Change sandbox mode (Claude & Codex).
  /// Bridge destroys and resumes the session with new sandbox settings.
  void setSandboxMode(SandboxMode mode) {
    _pendingSandboxRollback = state.sandboxMode;
    emit(state.copyWith(sandboxMode: mode));
    if (isCodex) {
      _bridge.patchSessionSandboxMode(sessionId, mode.value);
    }
    _bridge.send(
      ClientMessage.setSandboxMode(mode.value, sessionId: sessionId),
    );
    // Persist per-session so that future resumes use this mode.
    final claudeSid = state.claudeSessionId;
    if (claudeSid != null && claudeSid.isNotEmpty) {
      _SessionSettingsHelper.save(claudeSid, {'sandboxMode': mode.value});
    }
  }

  void _rollbackFailedModeChange(ErrorMessage msg) {
    if (_isPermissionModeFailure(msg)) {
      final previous = _pendingPermissionRollback;
      _pendingPermissionRollback = null;
      if (previous != null) {
        emit(
          state.copyWith(
            permissionMode: previous,
            executionMode: _pendingExecutionRollback ?? state.executionMode,
            codexApprovalPolicy:
                _pendingCodexApprovalRollback ?? state.codexApprovalPolicy,
            codexApprovalsReviewer:
                _pendingCodexApprovalsReviewerRollback ??
                state.codexApprovalsReviewer,
            planMode: _pendingPlanRollback ?? (previous == PermissionMode.plan),
            inPlanMode:
                _pendingPlanRollback ?? (previous == PermissionMode.plan),
          ),
        );
        _bridge.patchSessionModes(
          sessionId,
          permissionMode: previous.value,
          executionMode:
              (_pendingExecutionRollback ?? state.executionMode).value,
          planMode: _pendingPlanRollback ?? (previous == PermissionMode.plan),
          approvalPolicy:
              (_pendingCodexApprovalRollback ?? state.codexApprovalPolicy)
                  .value,
          approvalsReviewer:
              _pendingCodexApprovalsReviewerRollback ??
              state.codexApprovalsReviewer,
        );
        final claudeSid = state.claudeSessionId;
        if (claudeSid != null && claudeSid.isNotEmpty) {
          _SessionSettingsHelper.save(claudeSid, {
            'permissionMode': previous.value,
            'executionMode':
                (_pendingExecutionRollback ?? state.executionMode).value,
            'planMode':
                _pendingPlanRollback ?? (previous == PermissionMode.plan),
          });
        }
      }
      _pendingExecutionRollback = null;
      _pendingCodexApprovalRollback = null;
      _pendingCodexApprovalsReviewerRollback = null;
      _pendingPlanRollback = null;
    }

    if (_isSandboxModeFailure(msg)) {
      final previous = _pendingSandboxRollback;
      _pendingSandboxRollback = null;
      if (previous != null) {
        emit(state.copyWith(sandboxMode: previous));
        if (isCodex) {
          _bridge.patchSessionSandboxMode(sessionId, previous.value);
        }
        final claudeSid = state.claudeSessionId;
        if (claudeSid != null && claudeSid.isNotEmpty) {
          _SessionSettingsHelper.save(claudeSid, {
            'sandboxMode': previous.value,
          });
        }
      }
    }
  }

  bool _isPermissionModeFailure(ErrorMessage msg) {
    return msg.errorCode == 'set_permission_mode_rejected' ||
        msg.errorCode == 'auto_mode_unavailable' ||
        msg.message.startsWith('Failed to set permission mode:') ||
        msg.message.startsWith(
          'Failed to restart session for permission mode change:',
        );
  }

  bool _isSandboxModeFailure(ErrorMessage msg) {
    return msg.errorCode == 'set_sandbox_mode_rejected' ||
        msg.message.startsWith('Failed to set sandbox mode:') ||
        msg.message.startsWith(
          'Failed to restart session for sandbox mode change:',
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

  ({List<Map<String, String>> skills, List<Map<String, String>> mentions})
  _extractCodexStructuredInputs(String text) {
    final skills = <Map<String, String>>[];
    final mentions = <Map<String, String>>[];
    final seenSkills = <String>{};
    final seenMentions = <String>{};
    final entityByToken = {
      for (final item in state.slashCommands) item.command: item,
    };
    final matches = RegExp(
      r'(?<![A-Za-z0-9_-])\$([A-Za-z0-9][A-Za-z0-9_-]*)',
    ).allMatches(text);
    for (final match in matches) {
      final token = '\$${match.group(1)!}';
      final item = entityByToken[token];
      if (item == null) continue;
      if (item.skillInfo != null) {
        final payload = item.skillInfo!.toJson();
        final key = '${payload['name']}|${payload['path']}';
        if (seenSkills.add(key)) skills.add(payload);
      } else if (item.appInfo != null) {
        final payload = item.appInfo!.toJson();
        final key = '${payload['name']}|${payload['path']}';
        if (seenMentions.add(key)) mentions.add(payload);
      }
    }
    return (skills: skills, mentions: mentions);
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

List<String> updateRecentPeekedFiles(
  List<String> current,
  String path, {
  int limit = 10,
}) {
  final normalized = path.trim();
  if (normalized.isEmpty) return current;
  final next = [normalized, ...current.where((file) => file != normalized)];
  return next.take(limit).toList();
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lightweight helper to persist per-session Claude settings.
///
/// Uses the same SharedPreferences key convention as
/// [SessionListScreen.saveClaudeSessionSettings] so the session list
/// can read them back when resuming.
class _SessionSettingsHelper {
  static const _prefix = 'claude_session_settings_';

  static Future<void> save(
    String sessionId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$sessionId';
      final raw = prefs.getString(key);
      Map<String, dynamic> existing = {};
      if (raw != null) {
        try {
          existing = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }
      final merged = <String, dynamic>{...existing, ...settings};
      await prefs.setString(key, jsonEncode(merged));
    } catch (_) {
      // SharedPreferences may not be available in test environments.
    }
  }
}

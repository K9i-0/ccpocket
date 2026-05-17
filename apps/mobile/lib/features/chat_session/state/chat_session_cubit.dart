import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  static const _uuid = Uuid();
  static const offlineQueuedInputPrefix = 'offline:';
  static const deliveryPendingQueuedInputPrefix = 'pending:';
  static const _deliveryPendingDelay = Duration(milliseconds: 600);

  final String sessionId;
  final Provider? provider;
  final BridgeService _bridge;
  final StreamingStateCubit _streamingCubit;
  final ChatMessageHandler _handler = ChatMessageHandler();

  StreamSubscription<ServerMessage>? _subscription;
  bool _pastHistoryLoaded = false;
  Timer? _statusRefreshTimer;
  final Map<String, Timer> _deliveryPendingTimers = {};
  final Map<String, QueuedInputItem> _deliveryPendingInputs = {};

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
  CodexPermissionsMode? _pendingCodexPermissionsModeRollback;
  bool? _pendingPlanRollback;
  SandboxMode? _pendingSandboxRollback;

  /// Whether this session is a Codex session.
  bool get isCodex => provider == Provider.codex;

  String _nextOptimisticCodexUserTurnUuid() {
    final userTurnCount = state.entries.whereType<UserChatEntry>().length;
    return 'codex:user-turn:${userTurnCount + 1}';
  }

  static bool isOfflineQueuedInput(QueuedInputItem? item) =>
      item?.itemId.startsWith(offlineQueuedInputPrefix) ?? false;

  static String? offlineQueuedClientMessageId(QueuedInputItem? item) {
    if (!isOfflineQueuedInput(item)) return null;
    return item!.itemId.substring(offlineQueuedInputPrefix.length);
  }

  static bool isDeliveryPendingQueuedInput(QueuedInputItem? item) =>
      item?.itemId.startsWith(deliveryPendingQueuedInputPrefix) ?? false;

  static String? deliveryPendingClientMessageId(QueuedInputItem? item) {
    if (!isDeliveryPendingQueuedInput(item)) return null;
    return item!.itemId.substring(deliveryPendingQueuedInputPrefix.length);
  }

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
    CodexPermissionsMode? initialCodexPermissionsMode,
    String? initialProjectPath,
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
           codexPermissionsMode: provider == Provider.codex
               ? (initialCodexPermissionsMode ??
                     (initialCodexApprovalPolicy != null ||
                             initialSandboxMode != null ||
                             initialCodexApprovalsReviewer != null
                         ? codexPermissionsModeFromSettings(
                             approvalPolicy: initialCodexApprovalPolicy?.value,
                             approvalsReviewer: initialCodexApprovalsReviewer,
                             sandboxMode: initialSandboxMode?.value,
                           )
                         : CodexPermissionsMode.defaultPermissions))
               : CodexPermissionsMode.defaultPermissions,
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
           projectPath: initialProjectPath,
         ),
       ) {
    // Subscribe to messages for this session
    _subscription = _bridge.messagesForSession(sessionId).listen(_onMessage);

    _restoreCachedRuntimeMessages();
    _restoreDeliveryPendingInput();

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

  void _restoreCachedRuntimeMessages() {
    final cachedMessages = _bridge.cachedSessionMessages(sessionId);
    if (cachedMessages.isEmpty) return;
    try {
      final history = HistoryMessage(messages: cachedMessages);
      final update = _handler.handle(
        history,
        isBackground: true,
        isCodex: isCodex,
      );
      _applyUpdate(update, history);
    } catch (e, st) {
      logger.error(
        '[session:$sessionId] Failed to restore cached runtime messages',
        e,
        st,
      );
    }
  }

  void _restoreDeliveryPendingInput() {
    if (!isCodex || state.queuedInput != null) return;
    final pending = _bridge.deliveryPendingInputForSession(
      sessionId,
      includeHidden: true,
    );
    final clientMessageId = deliveryPendingClientMessageId(pending);
    if (pending != null && clientMessageId != null) {
      _deliveryPendingInputs[clientMessageId] = pending;
    }
    final item = _bridge.deliveryPendingInputForSession(sessionId);
    if (item == null) return;
    emit(state.copyWith(queuedInput: item));
  }

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
      final clientMessageId = update.userStatusClientMessageId;
      if (clientMessageId != null) {
        targetIndex = entries.indexWhere(
          (e) => e is UserChatEntry && e.clientMessageId == clientMessageId,
        );
      } else if (update.markUserMessagesQueued) {
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
          clientMessageId: entry.clientMessageId,
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
      final clientMessageId = update.userStatusClientMessageId;
      final updated = entries.map((e) {
        if (e is UserChatEntry &&
            (clientMessageId != null
                ? e.clientMessageId == clientMessageId
                : e.status == MessageStatus.sending)) {
          changed = true;
          return UserChatEntry(
            e.text,
            sessionId: e.sessionId,
            clientMessageId: e.clientMessageId,
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
      final (
        :text,
        :uuid,
        :clientMessageId,
        :imageCount,
        :imageUrls,
        :timestamp,
      ) = update.userUuidUpdate!;
      var matchedUserEntry = false;
      for (int i = entries.length - 1; i >= 0; i--) {
        final e = entries[i];
        if (e is UserChatEntry &&
            ((e.messageUuid == uuid) ||
                (clientMessageId != null &&
                    e.clientMessageId == clientMessageId) ||
                (e.messageUuid == null &&
                    clientMessageId == null &&
                    e.text == text))) {
          matchedUserEntry = true;
          if (e.messageUuid != uuid) {
            e.messageUuid = uuid;
            didModifyEntries = true;
          }
          break;
        }
      }
      if (!matchedUserEntry) {
        entries = [
          ...entries,
          UserChatEntry(
            text,
            sessionId: sessionId,
            clientMessageId: clientMessageId,
            imageCount: imageCount,
            imageUrls: imageUrls,
            status: MessageStatus.sent,
            messageUuid: uuid,
            timestamp: timestamp == null
                ? null
                : DateTime.tryParse(timestamp)?.toLocal(),
          ),
        ];
        didModifyEntries = true;
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

      final extraLiveEntries = _entriesToPreserveAfterHistoryReplace(
        existingNonPast: existingNonPast,
        historyEntries: nonStreamingEntries,
      );

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
              clientMessageId: e.clientMessageId,
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
      final result = _appendEntriesDeduped(entries, nonStreamingEntries);
      entries = result.entries;
      didModifyEntries = result.didChange;
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

    var nextEntries = didModifyEntries ? entries : current.entries;

    // --- Apply state update ---
    final newClaudeSessionId =
        update.claudeSessionId ?? current.claudeSessionId;
    final newProjectPath = update.projectPath?.trim().isNotEmpty == true
        ? update.projectPath
        : current.projectPath;
    if (originalMsg
        case InputAckMessage(:final clientMessageId) ||
            InputRejectedMessage(:final clientMessageId)
        when clientMessageId != null) {
      _deliveryPendingTimers.remove(clientMessageId)?.cancel();
      _bridge.clearDeliveryPendingInput(
        sessionId,
        itemId: '$deliveryPendingQueuedInputPrefix$clientMessageId',
      );
    } else if (update.markUserMessagesSent) {
      for (final timer in _deliveryPendingTimers.values) {
        timer.cancel();
      }
      _deliveryPendingTimers.clear();
      _bridge.clearDeliveryPendingInput(sessionId);
    }

    var nextQueuedInput = update.clearQueuedInput
        ? null
        : (update.queuedInput ?? current.queuedInput);
    QueuedInputItem? deliveredPendingInput;
    String? deliveredPendingClientMessageId;
    if (originalMsg is InputAckMessage && originalMsg.queued == false) {
      final hiddenDeliveryPending = originalMsg.clientMessageId != null
          ? _deliveryPendingInputs.remove(originalMsg.clientMessageId)
          : null;
      final offlineMatch =
          offlineQueuedClientMessageId(nextQueuedInput) ==
          originalMsg.clientMessageId;
      final deliveryMatch =
          deliveryPendingClientMessageId(nextQueuedInput) ==
          originalMsg.clientMessageId;
      if (deliveryMatch) {
        deliveredPendingInput = nextQueuedInput;
        deliveredPendingClientMessageId = originalMsg.clientMessageId;
        if (originalMsg.clientMessageId != null) {
          _deliveryPendingInputs.remove(originalMsg.clientMessageId);
        }
      } else if (hiddenDeliveryPending != null) {
        deliveredPendingInput = hiddenDeliveryPending;
        deliveredPendingClientMessageId = originalMsg.clientMessageId;
      }
      if (offlineMatch || deliveryMatch) {
        nextQueuedInput = null;
      }
    }
    if (originalMsg is InputRejectedMessage) {
      if (originalMsg.clientMessageId != null) {
        _deliveryPendingInputs.remove(originalMsg.clientMessageId);
      }
      if (deliveryPendingClientMessageId(nextQueuedInput) ==
          originalMsg.clientMessageId) {
        nextQueuedInput = null;
      }
    }
    if (originalMsg is InputAckMessage && originalMsg.queued == true) {
      if (originalMsg.clientMessageId != null) {
        _deliveryPendingInputs.remove(originalMsg.clientMessageId);
      }
    }
    if (originalMsg is! InputAckMessage &&
        update.markUserMessagesSent &&
        isDeliveryPendingQueuedInput(nextQueuedInput)) {
      deliveredPendingInput = nextQueuedInput;
      deliveredPendingClientMessageId = deliveryPendingClientMessageId(
        nextQueuedInput,
      );
      nextQueuedInput = null;
      if (deliveredPendingClientMessageId != null) {
        _deliveryPendingInputs.remove(deliveredPendingClientMessageId);
      }
    } else if (originalMsg is! InputAckMessage &&
        update.markUserMessagesSent &&
        _deliveryPendingInputs.isNotEmpty) {
      final entry = _deliveryPendingInputs.entries.first;
      _deliveryPendingInputs.remove(entry.key);
      deliveredPendingInput = entry.value;
      deliveredPendingClientMessageId = entry.key;
    }
    if (deliveredPendingInput != null) {
      nextEntries = _appendDeliveredPendingInputEntry(
        nextEntries,
        deliveredPendingInput,
        deliveredPendingClientMessageId,
        beforeTrailingAssistant: originalMsg is AssistantServerMessage,
      );
    }
    if (isDeliveryPendingQueuedInput(current.queuedInput) &&
        current.queuedInput?.itemId != nextQueuedInput?.itemId) {
      _bridge.clearDeliveryPendingInput(
        sessionId,
        itemId: current.queuedInput!.itemId,
      );
    }
    final usage = _calculateUsageTotals(nextEntries);

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
        codexPermissionsMode:
            update.codexPermissionsMode ?? current.codexPermissionsMode,
        planMode: update.planMode ?? current.planMode,
        slashCommands: update.slashCommands ?? current.slashCommands,
        queuedInput: nextQueuedInput,
        claudeSessionId: newClaudeSessionId,
        projectPath: newProjectPath,
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

  List<ChatEntry> _entriesToPreserveAfterHistoryReplace({
    required List<ChatEntry> existingNonPast,
    required List<ChatEntry> historyEntries,
  }) {
    var lastMatchedExistingIndex = -1;
    var searchStart = 0;

    for (final historyEntry in historyEntries) {
      final matchIndex = _indexOfEquivalentEntry(
        existingNonPast,
        historyEntry,
        start: searchStart,
        allowWeakMatch: true,
      );
      if (matchIndex == -1) continue;
      lastMatchedExistingIndex = matchIndex;
      searchStart = matchIndex + 1;
    }

    final candidates = lastMatchedExistingIndex == -1
        ? existingNonPast.where(_isLocalUnconfirmedUserEntry)
        : existingNonPast.skip(lastMatchedExistingIndex + 1);
    final preserved = <ChatEntry>[];
    final covered = [...historyEntries];

    for (final candidate in candidates) {
      if (_indexOfEquivalentEntry(covered, candidate, allowWeakMatch: true) !=
          -1) {
        continue;
      }
      if (!_shouldPreserveEntryAcrossHistoryReplace(candidate)) continue;
      preserved.add(candidate);
      covered.add(candidate);
    }
    return preserved;
  }

  ({List<ChatEntry> entries, bool didChange}) _appendEntriesDeduped(
    List<ChatEntry> current,
    List<ChatEntry> additions,
  ) {
    var next = current;
    var didChange = false;

    for (final addition in additions) {
      final matchIndex = _indexOfEquivalentEntry(next, addition);
      if (matchIndex != -1) {
        final merged = _mergeEquivalentEntry(next[matchIndex], addition);
        if (!identical(merged, next[matchIndex])) {
          next = [...next];
          next[matchIndex] = merged;
          didChange = true;
        }
        continue;
      }
      if (!didChange) next = [...next];
      next.add(addition);
      didChange = true;
    }

    return (entries: next, didChange: didChange);
  }

  int _indexOfEquivalentEntry(
    List<ChatEntry> entries,
    ChatEntry target, {
    int start = 0,
    bool allowWeakMatch = false,
  }) {
    for (var i = start; i < entries.length; i++) {
      if (_entriesEquivalent(
        entries[i],
        target,
        allowWeakMatch: allowWeakMatch,
      )) {
        return i;
      }
    }
    return -1;
  }

  bool _entriesEquivalent(
    ChatEntry a,
    ChatEntry b, {
    bool allowWeakMatch = false,
  }) {
    final aKey = _entryStableKey(a);
    final bKey = _entryStableKey(b);
    if (aKey != null && bKey != null) return aKey == bKey;

    if (allowWeakMatch) {
      final aWeakKey = _entryWeakKey(a);
      final bWeakKey = _entryWeakKey(b);
      if (aWeakKey != null && bWeakKey != null) return aWeakKey == bWeakKey;
    }

    if (a is UserChatEntry && b is UserChatEntry) {
      // Older Bridge versions may not include clientMessageId in restored
      // history. Use text only as a last-resort match for local pending entries.
      return (a.status != MessageStatus.sent ||
              b.status != MessageStatus.sent) &&
          a.text == b.text &&
          a.imageCount == b.imageCount;
    }
    return false;
  }

  String? _entryStableKey(ChatEntry entry) {
    if (entry is UserChatEntry) {
      final uuid = entry.messageUuid;
      if (uuid != null && uuid.isNotEmpty) return 'user:uuid:$uuid';
      final clientMessageId = entry.clientMessageId;
      if (clientMessageId != null && clientMessageId.isNotEmpty) {
        return 'user:client:$clientMessageId';
      }
      return null;
    }
    if (entry is ServerChatEntry) {
      return _serverMessageStableKey(entry.message);
    }
    return null;
  }

  String? _entryWeakKey(ChatEntry entry) {
    if (entry is UserChatEntry) {
      return ['user', entry.text, entry.imageCount].join('\u0001');
    }
    if (entry is ServerChatEntry) {
      return _serverMessageWeakKey(entry.message);
    }
    return null;
  }

  String? _serverMessageStableKey(ServerMessage message) {
    switch (message) {
      case AssistantServerMessage(:final messageUuid, :final message):
        if (messageUuid != null && messageUuid.isNotEmpty) {
          return 'assistant:uuid:$messageUuid';
        }
        if (message.id.isNotEmpty) return 'assistant:id:${message.id}';
        return null;
      case ToolResultMessage(:final toolUseId):
        return 'tool_result:$toolUseId';
      case PermissionRequestMessage(:final toolUseId):
        return 'permission_request:$toolUseId';
      case PermissionResolvedMessage(:final toolUseId):
        return 'permission_resolved:$toolUseId';
      default:
        return null;
    }
  }

  String? _serverMessageWeakKey(ServerMessage message) {
    switch (message) {
      case SystemMessage(
        :final subtype,
        :final sessionId,
        :final claudeSessionId,
        :final provider,
        :final projectPath,
        :final permissionMode,
        :final executionMode,
        :final approvalPolicy,
        :final approvalsReviewer,
        :final codexPermissionsMode,
        :final sandboxMode,
        :final sourceSessionId,
        :final tipCode,
      ):
        return [
          'system',
          subtype,
          sessionId,
          claudeSessionId,
          provider,
          projectPath,
          permissionMode,
          executionMode,
          approvalPolicy,
          approvalsReviewer,
          codexPermissionsMode,
          sandboxMode,
          sourceSessionId,
          tipCode,
        ].join('\u0001');
      case AssistantServerMessage(:final message):
        return 'assistant:content:${_assistantContentSignature(message)}';
      case ResultMessage(
        :final subtype,
        :final sessionId,
        :final stopReason,
        :final result,
        :final error,
      ):
        return [
          'result',
          subtype,
          sessionId,
          stopReason,
          result,
          error,
        ].join('\u0001');
      case ErrorMessage(:final message, :final errorCode):
        return ['error', errorCode, message].join('\u0001');
      case ToolUseSummaryMessage(:final summary, :final precedingToolUseIds):
        return [
          'tool_use_summary',
          summary,
          ...precedingToolUseIds,
        ].join('\u0001');
      default:
        return null;
    }
  }

  String _assistantContentSignature(AssistantMessage message) {
    return message.content
        .map((content) {
          return switch (content) {
            TextContent(:final text) => 'text:$text',
            ThinkingContent(:final thinking) => 'thinking:$thinking',
            ToolUseContent(:final id, :final name) => 'tool_use:$id:$name',
          };
        })
        .join('\u0001');
  }

  bool _isLocalUnconfirmedUserEntry(ChatEntry entry) {
    return entry is UserChatEntry && entry.status != MessageStatus.sent;
  }

  bool _shouldPreserveEntryAcrossHistoryReplace(ChatEntry entry) {
    if (entry is UserChatEntry) return true;
    if (entry is ServerChatEntry) {
      return entry.message is! StatusMessage &&
          entry.message is! InputAckMessage &&
          entry.message is! InputRejectedMessage &&
          entry.message is! ConversationQueueMessage;
    }
    return false;
  }

  ChatEntry _mergeEquivalentEntry(ChatEntry existing, ChatEntry incoming) {
    if (existing is UserChatEntry && incoming is UserChatEntry) {
      final imageBytes = existing.imageBytesList.isNotEmpty
          ? existing.imageBytesList
          : incoming.imageBytesList;
      final imageUrls = incoming.imageUrls.isNotEmpty
          ? incoming.imageUrls
          : existing.imageUrls;
      final imageCount = incoming.imageCount > 0
          ? incoming.imageCount
          : existing.imageCount;
      return UserChatEntry(
        existing.text.isNotEmpty ? existing.text : incoming.text,
        sessionId: existing.sessionId ?? incoming.sessionId,
        clientMessageId: existing.clientMessageId ?? incoming.clientMessageId,
        imageBytesList: imageBytes,
        imageUrls: imageUrls,
        imageCount: imageCount,
        status: incoming.status == MessageStatus.sent
            ? MessageStatus.sent
            : existing.status,
        messageUuid: existing.messageUuid ?? incoming.messageUuid,
        timestamp: existing.timestamp,
      );
    }
    return existing;
  }

  List<ChatEntry> _appendDeliveredPendingInputEntry(
    List<ChatEntry> entries,
    QueuedInputItem? item,
    String? clientMessageId, {
    bool beforeTrailingAssistant = false,
  }) {
    if (item == null) return entries;
    final alreadyVisible = entries.any((entry) {
      if (entry is! UserChatEntry) return false;
      if (clientMessageId != null && entry.clientMessageId == clientMessageId) {
        return true;
      }
      return entry.text == item.text && entry.status == MessageStatus.sent;
    });
    if (alreadyVisible) return entries;
    final entry = UserChatEntry(
      item.text,
      sessionId: sessionId,
      clientMessageId: clientMessageId,
      imageCount: item.imageCount,
      status: MessageStatus.sent,
    );
    final trailingEntry = entries.lastOrNull;
    if (beforeTrailingAssistant &&
        trailingEntry is ServerChatEntry &&
        trailingEntry.message is AssistantServerMessage) {
      return [...entries.take(entries.length - 1), entry, entries.last];
    }
    return [...entries, entry];
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
    Iterable<String>? mentionablePaths,
  }) {
    if (text.trim().isEmpty && (images == null || images.isEmpty)) return;
    if (isCodex && state.queuedInput != null) return;

    final clientMessageId = _uuid.v4();
    final isOffline = !_bridge.isConnected;
    final baseSeq = isOffline
        ? _bridge.cachedSessionHistorySeq(sessionId)
        : null;
    final structuredMentions = isCodex
        ? _extractCodexStructuredInputs(
            text,
            mentionablePaths: mentionablePaths,
          )
        : (
            skills: const <Map<String, String>>[],
            mentions: const <Map<String, String>>[],
          );

    final shouldUseOfflineQueuePanel = isCodex && isOffline;
    final shouldAddLocalEntry =
        !isCodex ||
        (!shouldUseOfflineQueuePanel && state.status == ProcessStatus.idle);
    if (shouldAddLocalEntry) {
      final entry = UserChatEntry(
        text,
        sessionId: sessionId,
        clientMessageId: clientMessageId,
        imageBytesList: images?.map((i) => i.bytes).toList(),
        status: isOffline ? MessageStatus.queued : MessageStatus.sending,
        messageUuid: isCodex ? _nextOptimisticCodexUserTurnUuid() : null,
      );
      emit(state.copyWith(entries: [...state.entries, entry]));
    } else if (shouldUseOfflineQueuePanel) {
      emit(
        state.copyWith(
          queuedInput: QueuedInputItem(
            itemId: '$offlineQueuedInputPrefix$clientMessageId',
            text: text,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            imageCount: images?.length ?? 0,
            skills: structuredMentions.skills,
            mentions: structuredMentions.mentions,
          ),
        ),
      );
    }

    // Encode images as Base64 for WebSocket transmission
    List<Map<String, String>>? imagePayloads;
    if (images != null && images.isNotEmpty) {
      imagePayloads = images
          .map((i) => {'base64': base64Encode(i.bytes), 'mimeType': i.mimeType})
          .toList();
    }

    final deliveryPendingItem = isCodex && !isOffline
        ? QueuedInputItem(
            itemId: '$deliveryPendingQueuedInputPrefix$clientMessageId',
            text: text,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            imageCount: images?.length ?? 0,
            skills: structuredMentions.skills,
            mentions: structuredMentions.mentions,
          )
        : null;
    if (deliveryPendingItem != null) {
      _deliveryPendingInputs[clientMessageId] = deliveryPendingItem;
      _bridge.setDeliveryPendingInput(
        sessionId,
        deliveryPendingItem,
        visibleAfter: _deliveryPendingDelay,
      );
    }

    _bridge.send(
      ClientMessage.input(
        text,
        sessionId: sessionId,
        clientMessageId: clientMessageId,
        baseSeq: baseSeq,
        images: imagePayloads,
        skill: structuredMentions.skills.isNotEmpty
            ? structuredMentions.skills.first
            : null,
        skills: structuredMentions.skills,
        mentions: structuredMentions.mentions,
      ),
    );
    if (isCodex && !isOffline) {
      _scheduleDeliveryPendingQueue(
        clientMessageId: clientMessageId,
        item: deliveryPendingItem!,
      );
    }
  }

  void _scheduleDeliveryPendingQueue({
    required String clientMessageId,
    required QueuedInputItem item,
  }) {
    _deliveryPendingTimers[clientMessageId]?.cancel();
    _deliveryPendingTimers[clientMessageId] = Timer(_deliveryPendingDelay, () {
      _deliveryPendingTimers.remove(clientMessageId);
      if (isClosed || state.queuedInput != null) return;
      _bridge.showDeliveryPendingInput(sessionId, itemId: item.itemId);

      final entries = state.entries;
      final entryIndex = entries.indexWhere(
        (entry) =>
            entry is UserChatEntry &&
            entry.clientMessageId == clientMessageId &&
            entry.status == MessageStatus.sending,
      );
      final nextEntries = entryIndex == -1
          ? entries
          : [...entries.take(entryIndex), ...entries.skip(entryIndex + 1)];
      emit(state.copyWith(entries: nextEntries, queuedInput: item));
    });
  }

  void updateQueuedInput(QueuedInputItem item, String text) {
    if (!isCodex || text.trim().isEmpty) return;
    if (isDeliveryPendingQueuedInput(item)) return;
    final structuredMentions = _extractCodexStructuredInputs(text);
    final offlineClientMessageId = offlineQueuedClientMessageId(item);
    if (offlineClientMessageId != null) {
      final updated = QueuedInputItem(
        itemId: item.itemId,
        text: text,
        createdAt: item.createdAt,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        imageCount: item.imageCount,
        skills: structuredMentions.skills,
        mentions: structuredMentions.mentions,
      );
      emit(state.copyWith(queuedInput: updated));
      unawaited(
        _bridge.updateOfflinePendingInput(
          sessionId: sessionId,
          clientMessageId: offlineClientMessageId,
          text: text,
          skills: structuredMentions.skills,
          mentions: structuredMentions.mentions,
        ),
      );
      return;
    }
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
    if (!isCodex ||
        isOfflineQueuedInput(item) ||
        isDeliveryPendingQueuedInput(item)) {
      return;
    }
    _bridge.send(
      ClientMessage.steerQueuedInput(sessionId: sessionId, itemId: item.itemId),
    );
  }

  void cancelQueuedInput(QueuedInputItem item) {
    if (!isCodex) return;
    if (isDeliveryPendingQueuedInput(item)) {
      final clientMessageId = deliveryPendingClientMessageId(item);
      if (clientMessageId != null) {
        _deliveryPendingInputs.remove(clientMessageId);
      }
      _bridge.clearDeliveryPendingInput(sessionId, itemId: item.itemId);
      if (state.queuedInput?.itemId == item.itemId) {
        emit(state.copyWith(queuedInput: null));
      }
      return;
    }
    final offlineClientMessageId = offlineQueuedClientMessageId(item);
    if (offlineClientMessageId != null) {
      emit(state.copyWith(queuedInput: null));
      unawaited(
        _bridge.cancelOfflinePendingInput(
          sessionId: sessionId,
          clientMessageId: offlineClientMessageId,
        ),
      );
      return;
    }
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

  void setCodexPermissionsMode(CodexPermissionsMode mode) {
    final policy =
        approvalPolicyForCodexPermissionsMode(mode) ??
        state.codexApprovalPolicy;
    final approvalsReviewer =
        approvalsReviewerForCodexPermissionsMode(mode) ??
        state.codexApprovalsReviewer;
    final sandboxMode = sandboxModeForCodexPermissionsMode(mode);
    final derivedExecution = mode == CodexPermissionsMode.fullAccess
        ? ExecutionMode.fullAccess
        : ExecutionMode.defaultMode;
    const legacyMode = PermissionMode.acceptEdits;

    logger.info('[session:$sessionId] setCodexPermissionsMode=${mode.value}');
    _pendingPermissionRollback = state.permissionMode;
    _pendingExecutionRollback = state.executionMode;
    _pendingCodexApprovalRollback = state.codexApprovalPolicy;
    _pendingCodexApprovalsReviewerRollback = state.codexApprovalsReviewer;
    _pendingCodexPermissionsModeRollback = state.codexPermissionsMode;
    _pendingSandboxRollback = state.sandboxMode;
    _pendingPlanRollback = state.planMode;

    emit(
      state.copyWith(
        permissionMode: legacyMode,
        executionMode: derivedExecution,
        codexApprovalPolicy: policy,
        codexApprovalsReviewer: approvalsReviewer,
        codexPermissionsMode: mode,
        sandboxMode: sandboxMode ?? state.sandboxMode,
        planMode: false,
        inPlanMode: false,
      ),
    );
    _bridge.patchSessionModes(
      sessionId,
      permissionMode: legacyMode.value,
      executionMode: derivedExecution.value,
      planMode: false,
      approvalPolicy: mode == CodexPermissionsMode.custom ? null : policy.value,
      approvalsReviewer: mode == CodexPermissionsMode.custom
          ? null
          : approvalsReviewer,
      codexPermissionsMode: mode.value,
    );
    if (sandboxMode != null) {
      _bridge.patchSessionSandboxMode(sessionId, sandboxMode.value);
    }
    _bridge.send(
      ClientMessage.setSessionMode(
        legacyMode: legacyMode.value,
        executionMode: derivedExecution.value,
        approvalPolicy: mode == CodexPermissionsMode.custom
            ? null
            : policy.value,
        approvalsReviewer: mode == CodexPermissionsMode.custom
            ? null
            : approvalsReviewer,
        codexPermissionsMode: mode.value,
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
            codexPermissionsMode:
                _pendingCodexPermissionsModeRollback ??
                state.codexPermissionsMode,
            sandboxMode: _pendingSandboxRollback ?? state.sandboxMode,
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
          codexPermissionsMode:
              (_pendingCodexPermissionsModeRollback ??
                      state.codexPermissionsMode)
                  .value,
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

  void forkSession(String targetUuid) {
    _bridge.send(ClientMessage.forkSession(sessionId, targetUuid));
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
    final clientMessageId = _uuid.v4();
    final retrySessionId = entry.sessionId ?? sessionId;
    final isOffline = !_bridge.isConnected;
    emit(
      state.copyWith(
        entries: state.entries.map((e) {
          if (identical(e, entry)) {
            return UserChatEntry(
              entry.text,
              sessionId: retrySessionId,
              clientMessageId: clientMessageId,
              imageBytesList: entry.imageBytesList,
              imageUrls: entry.imageUrls,
              imageCount: entry.imageCount,
              status: isOffline ? MessageStatus.queued : MessageStatus.sending,
              messageUuid: entry.messageUuid,
              timestamp: entry.timestamp,
            );
          }
          return e;
        }).toList(),
      ),
    );
    _bridge.send(
      ClientMessage.input(
        entry.text,
        sessionId: retrySessionId,
        clientMessageId: clientMessageId,
        baseSeq: isOffline
            ? _bridge.cachedSessionHistorySeq(retrySessionId)
            : null,
      ),
    );
  }

  ({List<Map<String, String>> skills, List<Map<String, String>> mentions})
  _extractCodexStructuredInputs(
    String text, {
    Iterable<String>? mentionablePaths,
  }) {
    final skills = <Map<String, String>>[];
    final mentions = <Map<String, String>>[];
    final seenSkills = <String>{};
    final seenMentions = <String>{};
    final entityByToken = {
      for (final item in state.slashCommands) item.command: item,
    };
    final matches = RegExp(
      r'(?<![A-Za-z0-9_:/.-])\$([A-Za-z0-9][A-Za-z0-9_:/.-]*)',
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
    final pluginMatches = RegExp(
      r'(?<![A-Za-z0-9_:/.-])@([A-Za-z0-9][A-Za-z0-9_:/.-]*)',
    ).allMatches(text);
    for (final match in pluginMatches) {
      final token = '@${match.group(1)!}';
      final item = entityByToken[token];
      if (item?.pluginInfo == null) continue;
      final payload = item!.pluginInfo!.toJson();
      final key = '${payload['name']}|${payload['path']}';
      if (seenMentions.add(key)) mentions.add(payload);
    }
    final projectMentionPaths = _normalizeProjectMentionPaths(
      mentionablePaths ?? const <String>[],
    );
    if (projectMentionPaths.isNotEmpty) {
      final projectMatches = RegExp(
        r'(?<![A-Za-z0-9_:/.-])@(\S+)',
      ).allMatches(text);
      for (final match in projectMatches) {
        final rawPath = match.group(1)!;
        final token = '@$rawPath';
        if (entityByToken[token]?.pluginInfo != null) continue;

        final mentionPath = _resolveProjectMentionPath(
          rawPath,
          projectMentionPaths,
        );
        if (mentionPath == null) continue;

        final payloadPath = _resolveProjectMentionPayloadPath(
          mentionPath,
          state.projectPath,
        );
        final payload = {'name': mentionPath, 'path': payloadPath};
        final key = '${payload['name']}|${payload['path']}';
        if (seenMentions.add(key)) mentions.add(payload);
      }
    }
    return (skills: skills, mentions: mentions);
  }

  Set<String> _normalizeProjectMentionPaths(Iterable<String> paths) {
    final normalized = <String>{};
    for (final path in paths) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) continue;
      normalized.add(trimmed);
    }
    return normalized;
  }

  String? _resolveProjectMentionPath(String rawPath, Set<String> paths) {
    if (paths.contains(rawPath)) return rawPath;

    final stripped = rawPath.replaceFirst(RegExp(r'[,.;:!?]+$'), '');
    if (stripped != rawPath && paths.contains(stripped)) return stripped;

    if (!rawPath.endsWith('/') && paths.contains('$rawPath/')) {
      return '$rawPath/';
    }
    return null;
  }

  String _resolveProjectMentionPayloadPath(
    String mentionPath,
    String? projectPath,
  ) {
    if (mentionPath.startsWith('/') || projectPath == null) {
      return mentionPath;
    }
    final root = projectPath.trim();
    if (root.isEmpty) return mentionPath;
    return root.endsWith('/') ? '$root$mentionPath' : '$root/$mentionPath';
  }

  @override
  Future<void> close() {
    _statusRefreshTimer?.cancel();
    for (final timer in _deliveryPendingTimers.values) {
      timer.cancel();
    }
    _deliveryPendingTimers.clear();
    _deliveryPendingInputs.clear();
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

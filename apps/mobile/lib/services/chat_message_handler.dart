import '../core/logger.dart';
import '../models/messages.dart';
import '../widgets/slash_command_sheet.dart'
    show SlashCommand, SlashCommandCategory, buildSlashCommand, knownCommands;

/// Side effects that the widget layer must execute after a state update.
enum ChatSideEffect {
  heavyHaptic,
  mediumHaptic,
  lightHaptic,
  scrollToBottom,
  notifyApprovalRequired,
  notifyAskQuestion,
  notifySessionComplete,
  collapseToolResults,
  clearPlanFeedback,
}

/// Result of processing a single [ServerMessage].
class ChatStateUpdate {
  final ProcessStatus? status;
  final PermissionMode? permissionMode;
  final ExecutionMode? executionMode;
  final bool? planMode;
  final List<ChatEntry> entriesToAdd;
  final List<ChatEntry> entriesToPrepend;
  final String? pendingToolUseId;
  final PermissionRequestMessage? pendingPermission;
  final String? askToolUseId;
  final Map<String, dynamic>? askInput;
  final double? costDelta;
  final bool? inPlanMode;
  final List<SlashCommand>? slashCommands;
  final bool resetPending;
  final bool resetAsk;
  final bool resetStreaming;
  final bool markUserMessagesSent;
  final bool markUserMessagesFailed;

  /// When true, messages transition to [MessageStatus.queued] instead of
  /// [MessageStatus.sent].  The server accepted the message but the agent was
  /// busy — an interrupt has been triggered and the message will be processed
  /// on the next turn.
  final bool markUserMessagesQueued;
  final Set<ChatSideEffect> sideEffects;
  final String? claudeSessionId;

  /// Tool use IDs that should be hidden from display (replaced by a summary).
  final Set<String> toolUseIdsToHide;

  /// When true, [entriesToAdd] replaces all non-past-history entries instead of
  /// appending. Used by [_handleHistory] so that repeated history loads do not
  /// duplicate messages.
  final bool replaceEntries;

  /// UUID update for an existing user entry. When the SDK echoes back a
  /// user_input with a UUID, we update the locally-added UserChatEntry rather
  /// than creating a duplicate.
  final ({String text, String uuid})? userUuidUpdate;

  const ChatStateUpdate({
    this.status,
    this.permissionMode,
    this.executionMode,
    this.planMode,
    this.entriesToAdd = const [],
    this.entriesToPrepend = const [],
    this.pendingToolUseId,
    this.pendingPermission,
    this.askToolUseId,
    this.askInput,
    this.costDelta,
    this.inPlanMode,
    this.slashCommands,
    this.resetPending = false,
    this.resetAsk = false,
    this.resetStreaming = false,
    this.markUserMessagesSent = false,
    this.markUserMessagesFailed = false,
    this.markUserMessagesQueued = false,
    this.sideEffects = const {},
    this.claudeSessionId,
    this.toolUseIdsToHide = const {},
    this.replaceEntries = false,
    this.userUuidUpdate,
  });
}

/// How the app reacts when the Bridge returns `unsupported_message` for a
/// client message type it does not recognise.
enum UnsupportedAction {
  /// Silently log — no UI impact (default for background / auto features).
  suppress,

  /// Show an amber "Bridge update required" warning bubble.
  showUpdateHint,
}

/// Per-message-type overrides.  Types **not** listed here default to
/// [UnsupportedAction.suppress].
const _unsupportedActions = <String, UnsupportedAction>{
  // User-initiated actions that visibly fail if unsupported:
  'rewind': UnsupportedAction.showUpdateHint,
  'rewind_dry_run': UnsupportedAction.showUpdateHint,
  'take_screenshot': UnsupportedAction.showUpdateHint,
  'archive_session': UnsupportedAction.showUpdateHint,
  'read_file': UnsupportedAction.showUpdateHint,
  // Git Operations (Phase 1-3)
  'git_stage': UnsupportedAction.showUpdateHint,
  'git_unstage': UnsupportedAction.showUpdateHint,
  'git_unstage_hunks': UnsupportedAction.showUpdateHint,
  'git_commit': UnsupportedAction.showUpdateHint,
  'git_push': UnsupportedAction.showUpdateHint,
  'git_status': UnsupportedAction.showUpdateHint,
  'git_branches': UnsupportedAction.showUpdateHint,
  'git_create_branch': UnsupportedAction.showUpdateHint,
  'git_checkout_branch': UnsupportedAction.showUpdateHint,
  'git_revert_hunks': UnsupportedAction.showUpdateHint,
};

/// Processes [ServerMessage]s into [ChatStateUpdate]s.
///
/// Pure logic — no Flutter dependencies. Tracks streaming and thinking state
/// internally so the widget only needs to apply the returned updates.
class ChatMessageHandler {
  String currentThinkingText = '';
  StreamingChatEntry? currentStreaming;

  /// Whether a git_not_available tip has been shown in this session.
  /// Used to suppress duplicate git errors in the chat stream.
  bool _gitTipShown = false;

  ChatStateUpdate handle(
    ServerMessage msg, {
    required bool isBackground,
    bool isCodex = false,
  }) {
    switch (msg) {
      case StatusMessage(:final status):
        return _handleStatus(status, isBackground: isBackground);
      case ThinkingDeltaMessage(:final text):
        currentThinkingText += text;
        return const ChatStateUpdate();
      case StreamDeltaMessage(:final text):
        return _handleStreamDelta(text);
      case AssistantServerMessage(:final message):
        return _handleAssistant(
          msg,
          message,
          isBackground: isBackground,
          isCodex: isCodex,
        );
      case PastHistoryMessage(:final claudeSessionId, :final messages):
        return _handlePastHistory(messages, claudeSessionId: claudeSessionId);
      case HistoryMessage(:final messages):
        return _handleHistory(messages);
      case SystemMessage(
        :final subtype,
        :final slashCommands,
        :final skills,
        :final skillMetadata,
      ):
        return _handleSystem(
          msg,
          subtype,
          slashCommands,
          skills,
          skillMetadata,
        );
      case PermissionRequestMessage(
        :final toolUseId,
        :final toolName,
        :final input,
      ):
        logger.info(
          '[handler] permission_request: '
          'tool=$toolName id=$toolUseId',
        );
        if (toolName == 'AskUserQuestion' || toolName == 'McpElicitation') {
          return ChatStateUpdate(
            entriesToAdd: [ServerChatEntry(msg)],
            askToolUseId: toolUseId,
            askInput: input,
          );
        }
        return ChatStateUpdate(
          entriesToAdd: [ServerChatEntry(msg)],
          pendingToolUseId: toolUseId,
          pendingPermission: msg,
          inPlanMode: toolName == 'ExitPlanMode' ? true : null,
        );
      case PermissionResolvedMessage(:final toolUseId):
        logger.info('[handler] permission_resolved: id=$toolUseId');
        return ChatStateUpdate(entriesToAdd: [ServerChatEntry(msg)]);
      case ResultMessage(:final subtype, :final cost):
        return _handleResult(
          msg,
          subtype,
          cost,
          isBackground: isBackground,
          isCodex: isCodex,
        );
      case ToolUseSummaryMessage(:final precedingToolUseIds):
        return ChatStateUpdate(
          entriesToAdd: [ServerChatEntry(msg)],
          toolUseIdsToHide: precedingToolUseIds.toSet(),
        );
      case UserInputMessage(
        :final text,
        :final userMessageUuid,
        :final isSynthetic,
        :final isMeta,
      ):
        // Skip synthetic and meta messages (e.g. plan approval, Task agent
        // prompts, skill loading prompts).
        if (isSynthetic || isMeta) return const ChatStateUpdate();
        if (userMessageUuid != null) {
          // SDK echoed user message with UUID — update existing entry's UUID
          // so it becomes rewindable, instead of adding a duplicate.
          return ChatStateUpdate(
            userUuidUpdate: (text: text, uuid: userMessageUuid),
          );
        }
        // No UUID — add as new entry (fallback)
        return ChatStateUpdate(
          entriesToAdd: [UserChatEntry(text, status: MessageStatus.sent)],
        );
      case InputAckMessage(:final queued):
        return ChatStateUpdate(
          markUserMessagesSent: true,
          markUserMessagesQueued: queued,
        );
      case InputRejectedMessage():
        logger.warning('[handler] input_rejected');
        return const ChatStateUpdate(markUserMessagesFailed: true);
      case RenameResultMessage(:final success, :final error):
        if (!success) {
          logger.warning(
            '[handler] rename failed: ${error ?? "unknown reason"}',
          );
        }
        return const ChatStateUpdate();
      case ErrorMessage(:final message, :final errorCode):
        // Suppress duplicate git errors when the tip was already shown
        if (errorCode == 'git_not_available' && _gitTipShown) {
          return const ChatStateUpdate();
        }
        // New Bridge (≥ 1.23.0): includes errorCode + original message type
        if (errorCode == 'unsupported_message') {
          return _handleUnsupportedMessage(message);
        }
        // Old Bridge (< 1.23.0): no errorCode, string match fallback.
        // Type is unknown so always suppress.
        if (message == 'Invalid message format') {
          logger.warning(
            '[handler] old bridge: unsupported message (type unknown)',
          );
          return const ChatStateUpdate();
        }
        logger.error('[handler] error message: $message');
        return ChatStateUpdate(entriesToAdd: [ServerChatEntry(msg)]);
      default:
        return ChatStateUpdate(entriesToAdd: [ServerChatEntry(msg)]);
    }
  }

  /// Decide whether to suppress or show a hint for a message type the Bridge
  /// does not support.
  ChatStateUpdate _handleUnsupportedMessage(String messageType) {
    final action =
        _unsupportedActions[messageType] ?? UnsupportedAction.suppress;
    switch (action) {
      case UnsupportedAction.suppress:
        logger.info('[handler] suppressed unsupported: $messageType');
        return const ChatStateUpdate();
      case UnsupportedAction.showUpdateHint:
        logger.warning('[handler] unsupported (needs update): $messageType');
        return ChatStateUpdate(
          entriesToAdd: [
            ServerChatEntry(
              ErrorMessage(
                message:
                    'This feature requires a newer Bridge server.\n'
                    'Run: npm update -g @ccpocket/bridge',
                errorCode: 'bridge_update_required',
              ),
            ),
          ],
        );
    }
  }

  ChatStateUpdate _handleStatus(
    ProcessStatus status, {
    required bool isBackground,
  }) {
    final effects = <ChatSideEffect>{};
    final bool resetPending;
    if (status == ProcessStatus.waitingApproval) {
      effects.add(ChatSideEffect.heavyHaptic);
      if (isBackground) effects.add(ChatSideEffect.notifyApprovalRequired);
      resetPending = false;
    } else if (status == ProcessStatus.idle ||
        status == ProcessStatus.starting) {
      // Only reset pending on terminal states, not on transient 'running'
      // status. This prevents a race condition where
      // PermissionRequestMessage arrives before StatusMessage(waitingApproval)
      // and an intervening StatusMessage(running) would clear the pending state.
      resetPending = true;
    } else {
      resetPending = false;
    }
    return ChatStateUpdate(
      status: status,
      resetPending: resetPending,
      sideEffects: effects,
    );
  }

  ChatStateUpdate _handleStreamDelta(String text) {
    if (currentStreaming == null) {
      currentStreaming = StreamingChatEntry(text: text);
      return ChatStateUpdate(entriesToAdd: [currentStreaming!]);
    }
    currentStreaming!.text += text;
    return const ChatStateUpdate();
  }

  ChatStateUpdate _handleAssistant(
    AssistantServerMessage msg,
    AssistantMessage message, {
    required bool isBackground,
    required bool isCodex,
  }) {
    final effects = <ChatSideEffect>{ChatSideEffect.collapseToolResults};

    // Inject accumulated thinking text
    ServerMessage displayMsg = msg;
    if (currentThinkingText.isNotEmpty) {
      final hasThinking = message.content.any((c) => c is ThinkingContent);
      if (!hasThinking) {
        displayMsg = AssistantServerMessage(
          message: AssistantMessage(
            id: message.id,
            role: message.role,
            content: [
              ThinkingContent(thinking: currentThinkingText),
              ...message.content,
            ],
            model: message.model,
          ),
        );
      }
      currentThinkingText = '';
    }

    // Build entry — replace streaming if present
    final entry = ServerChatEntry(displayMsg);
    final replaceStreaming = currentStreaming;
    currentStreaming = null;

    // Extract tool use info
    String? askToolUseId;
    Map<String, dynamic>? askInput;
    String? pendingToolUseId;
    bool? inPlanMode;
    for (final content in message.content) {
      if (content is ToolUseContent) {
        if (content.name == 'AskUserQuestion') {
          askToolUseId = content.id;
          askInput = content.input;
          effects.add(ChatSideEffect.mediumHaptic);
          if (isBackground) effects.add(ChatSideEffect.notifyAskQuestion);
        } else {
          pendingToolUseId = content.id;
          if (content.name == 'EnterPlanMode') {
            inPlanMode = true;
          }
        }
      }
    }
    if (isCodex && inPlanMode == null && _isCodexPlanUpdateMessage(message)) {
      inPlanMode = true;
    }

    return ChatStateUpdate(
      entriesToAdd: [entry],
      resetStreaming: replaceStreaming != null,
      markUserMessagesSent: true,
      askToolUseId: askToolUseId,
      askInput: askInput,
      pendingToolUseId: pendingToolUseId,
      inPlanMode: inPlanMode,
      sideEffects: effects,
    );
  }

  ChatStateUpdate _handlePastHistory(
    List<PastMessage> messages, {
    String? claudeSessionId,
  }) {
    final entries = <ChatEntry>[];
    for (final m in messages) {
      final ts = m.timestamp != null
          ? DateTime.tryParse(m.timestamp!)?.toLocal()
          : null;
      if (m.role == 'user') {
        // Skip meta messages (e.g. skill loading prompts)
        if (m.isMeta) continue;
        final texts = m.content
            .whereType<TextContent>()
            .map((c) => c.text)
            .toList();
        if (texts.isNotEmpty || m.imageCount > 0) {
          final joined = texts.join('\n');
          entries.add(
            UserChatEntry(
              joined,
              timestamp: ts,
              status: MessageStatus.sent,
              messageUuid: m.uuid,
              imageCount: m.imageCount,
            ),
          );
        }
      } else if (m.role == 'assistant') {
        entries.add(
          ServerChatEntry(
            AssistantServerMessage(
              message: AssistantMessage(
                id: '',
                role: 'assistant',
                content: m.content,
                model: '',
              ),
              messageUuid: m.uuid,
            ),
            timestamp: ts,
          ),
        );
      }
    }
    return ChatStateUpdate(
      entriesToPrepend: entries,
      claudeSessionId: claudeSessionId,
    );
  }

  ChatStateUpdate _handleHistory(List<ServerMessage> messages) {
    final entries = <ChatEntry>[];
    ProcessStatus? lastStatus;
    List<SlashCommand>? commands;

    // Track pending permissions using a map to handle multiple concurrent requests.
    // Key: toolUseId, Value: PermissionRequestMessage
    final pendingPermissions = <String, PermissionRequestMessage>{};
    String? lastAskToolUseId;
    Map<String, dynamic>? lastAskInput;
    String? claudeSessionId;

    // Track last known timestamp from user messages so server entries
    // (which don't carry timestamps) inherit a realistic time instead of
    // DateTime.now(). Without this, the time gap between a user entry
    // (original timestamp) and a server entry (DateTime.now()) triggers
    // spurious timestamp labels in the chat UI.
    DateTime? lastKnownTs;

    for (final m in messages) {
      if (m is StatusMessage) {
        lastStatus = m.status;
      } else if (m is UserInputMessage) {
        // Skip synthetic and meta messages
        if (m.isSynthetic || m.isMeta) continue;
        // Convert user_input to UserChatEntry with UUID and timestamp
        final ts = m.timestamp != null
            ? DateTime.tryParse(m.timestamp!)?.toLocal()
            : null;
        if (ts != null) lastKnownTs = ts;
        entries.add(
          UserChatEntry(
            m.text,
            status: MessageStatus.sent,
            messageUuid: m.userMessageUuid,
            imageCount: m.imageCount,
            imageUrls: m.imageUrls,
            timestamp: ts,
          ),
        );
      } else {
        // Don't add internal metadata messages as visible entries
        if (m is! SystemMessage ||
            (m.subtype != 'supported_commands' &&
                m.subtype != 'session_created')) {
          entries.add(ServerChatEntry(m, timestamp: lastKnownTs));
        }
        // Restore slash commands from history (init, supported_commands, or
        // session_created with cached commands)
        if (m is SystemMessage &&
            (m.subtype == 'init' ||
                m.subtype == 'supported_commands' ||
                m.subtype == 'session_created')) {
          if (m.slashCommands.isNotEmpty) {
            commands = _buildCommandList(
              m.slashCommands,
              m.skills,
              m.skillMetadata,
            );
          }
          // Extract claudeSessionId for image loading etc.
          // Prefer full Claude CLI UUID over Bridge's 8-char ID.
          if (m.claudeSessionId != null) {
            claudeSessionId = m.claudeSessionId;
          } else if (m.sessionId != null) {
            claudeSessionId = m.sessionId;
          }
        }
        // Track pending permission request
        if (m is PermissionRequestMessage) {
          if (m.toolName == 'AskUserQuestion' ||
              m.toolName == 'McpElicitation') {
            // Codex sends AskUserQuestion as permission_request directly
            lastAskToolUseId = m.toolUseId;
            lastAskInput = m.input;
          } else {
            pendingPermissions[m.toolUseId] = m;
          }
        }
        // Track pending AskUserQuestion (tool_use in assistant message)
        if (m is AssistantServerMessage) {
          for (final content in m.message.content) {
            if (content is ToolUseContent &&
                content.name == 'AskUserQuestion') {
              lastAskToolUseId = content.id;
              lastAskInput = content.input;
            }
          }
        }
        if (m is PermissionResolvedMessage) {
          pendingPermissions.remove(m.toolUseId);
          if (lastAskToolUseId != null && m.toolUseId == lastAskToolUseId) {
            lastAskToolUseId = null;
            lastAskInput = null;
          }
        }
        // A tool_result means that permission was resolved.
        if (m is ToolResultMessage) {
          pendingPermissions.remove(m.toolUseId);
          if (lastAskToolUseId != null && m.toolUseId == lastAskToolUseId) {
            lastAskToolUseId = null;
            lastAskInput = null;
          }
        }
        // A result message means the turn completed
        if (m is ResultMessage) {
          pendingPermissions.clear();
          lastAskToolUseId = null;
          lastAskInput = null;
        }
      }
    }

    // Get the first pending permission (if any)
    final lastPermission = pendingPermissions.isNotEmpty
        ? pendingPermissions.values.first
        : null;

    // Only restore pending state if session is actually waiting
    final bool isWaiting = lastStatus == ProcessStatus.waitingApproval;
    return ChatStateUpdate(
      status: lastStatus,
      entriesToAdd: entries,
      replaceEntries: true,
      slashCommands: commands,
      pendingToolUseId: isWaiting ? lastPermission?.toolUseId : null,
      pendingPermission: isWaiting ? lastPermission : null,
      askToolUseId: isWaiting ? lastAskToolUseId : null,
      askInput: isWaiting ? lastAskInput : null,
      claudeSessionId: claudeSessionId,
    );
  }

  ChatStateUpdate _handleSystem(
    ServerMessage msg,
    String subtype,
    List<String> slashCommands,
    List<String> skills,
    List<CodexSkillMetadata> skillMetadata,
  ) {
    List<SlashCommand>? commands;
    PermissionMode? permissionMode;
    ExecutionMode? executionMode;
    bool? inPlanMode;
    bool? planMode;
    bool hasExecutionSignals(SystemMessage message) =>
        message.executionMode != null ||
        message.permissionMode != null ||
        message.approvalPolicy != null;
    bool hasPlanSignals(SystemMessage message) =>
        message.planMode != null || message.permissionMode != null;
    if ((subtype == 'init' ||
            subtype == 'session_created' ||
            subtype == 'supported_commands') &&
        slashCommands.isNotEmpty) {
      commands = _buildCommandList(slashCommands, skills, skillMetadata);
    }
    if (msg is SystemMessage && msg.permissionMode != null) {
      permissionMode = PermissionMode.values.cast<PermissionMode?>().firstWhere(
        (mode) => mode?.value == msg.permissionMode,
        orElse: () => null,
      );
      if (hasExecutionSignals(msg)) {
        executionMode = deriveExecutionMode(
          provider: msg.provider,
          executionMode: msg.executionMode,
          permissionMode: msg.permissionMode,
          approvalPolicy: msg.approvalPolicy,
        );
      }
      if (hasPlanSignals(msg)) {
        planMode = derivePlanMode(
          planMode: msg.planMode,
          permissionMode: msg.permissionMode,
        );
      }
      if (subtype == 'set_permission_mode' && permissionMode != null) {
        inPlanMode = planMode;
      }
    } else if (msg is SystemMessage) {
      if (hasExecutionSignals(msg)) {
        executionMode = deriveExecutionMode(
          provider: msg.provider,
          executionMode: msg.executionMode,
          permissionMode: msg.permissionMode,
          approvalPolicy: msg.approvalPolicy,
        );
      }
      if (hasPlanSignals(msg)) {
        planMode = derivePlanMode(
          planMode: msg.planMode,
          permissionMode: msg.permissionMode,
        );
      }
      if (subtype == 'set_permission_mode') {
        inPlanMode = planMode;
      }
    }
    // Extract claudeSessionId from session_created or init messages.
    // Prefer the full Claude CLI UUID (claudeSessionId) over the Bridge's
    // internal 8-char ID (sessionId) for JSONL file lookups.
    final sessionId = msg is SystemMessage
        ? (msg.claudeSessionId ?? msg.sessionId)
        : null;
    // Track git tip to suppress duplicate git errors later
    if (subtype == 'tip' &&
        msg is SystemMessage &&
        msg.tipCode == 'git_not_available') {
      _gitTipShown = true;
    }
    // Add init and tip as visible chat entries; session_created and
    // supported_commands are internal metadata messages.
    final addEntry = subtype == 'init' || subtype == 'tip';
    return ChatStateUpdate(
      entriesToAdd: addEntry ? [ServerChatEntry(msg)] : [],
      permissionMode: permissionMode,
      executionMode: executionMode,
      planMode: planMode,
      inPlanMode: inPlanMode,
      slashCommands: commands,
      claudeSessionId: sessionId,
    );
  }

  ChatStateUpdate _handleResult(
    ServerMessage msg,
    String subtype,
    double? cost, {
    required bool isBackground,
    required bool isCodex,
  }) {
    logger.info('[handler] result: subtype=$subtype cost=$cost');
    final effects = <ChatSideEffect>{ChatSideEffect.lightHaptic};
    final isStopped = subtype == 'stopped';
    if (isBackground && !isStopped) {
      effects.add(ChatSideEffect.notifySessionComplete);
    }
    if (isStopped) {
      currentStreaming = null;
      effects.add(ChatSideEffect.clearPlanFeedback);
    }
    return ChatStateUpdate(
      entriesToAdd: [ServerChatEntry(msg)],
      status: isStopped ? ProcessStatus.idle : null,
      costDelta: cost,
      resetPending: isStopped,
      resetAsk: isStopped,
      resetStreaming: isStopped,
      inPlanMode: isStopped
          ? false
          : (isCodex && subtype == 'success')
          ? false
          : null,
      markUserMessagesSent: true,
      sideEffects: effects,
    );
  }

  bool _isCodexPlanUpdateMessage(AssistantMessage message) {
    for (final content in message.content) {
      if (content is! TextContent) continue;
      final text = content.text.trimLeft();
      if (text.startsWith('Plan update:')) return true;
    }
    return false;
  }

  /// Build slash command list from server-provided names.
  ///
  /// Only includes commands reported by the CLI via `system.init`.
  /// Commands not in this list (e.g. /clear, /help, /plan) are CLI-interactive
  /// only and return "Unknown skill" when sent through the SDK.
  static List<SlashCommand> _buildCommandList(
    List<String> commands,
    List<String> skills,
    List<CodexSkillMetadata> skillMetadata,
  ) {
    final skillSet = skills.toSet();
    final knownNames = knownCommands.keys.toSet();
    // Build a lookup map from skill name to full metadata
    final metaMap = <String, CodexSkillMetadata>{};
    for (final meta in skillMetadata) {
      metaMap[meta.name] = meta;
    }
    return commands.map((name) {
      final category = skillSet.contains(name)
          ? SlashCommandCategory.skill
          : knownNames.contains(name)
          ? SlashCommandCategory.builtin
          : SlashCommandCategory.project;
      final meta = metaMap[name];
      return buildSlashCommand(name, category: category, skillMeta: meta);
    }).toList();
  }
}

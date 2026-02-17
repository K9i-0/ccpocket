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
  final Set<ChatSideEffect> sideEffects;
  final String? resultSessionId;

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
    this.sideEffects = const {},
    this.resultSessionId,
    this.toolUseIdsToHide = const {},
    this.replaceEntries = false,
    this.userUuidUpdate,
  });
}

/// Processes [ServerMessage]s into [ChatStateUpdate]s.
///
/// Pure logic — no Flutter dependencies. Tracks streaming and thinking state
/// internally so the widget only needs to apply the returned updates.
class ChatMessageHandler {
  String currentThinkingText = '';
  StreamingChatEntry? currentStreaming;

  ChatStateUpdate handle(ServerMessage msg, {required bool isBackground}) {
    switch (msg) {
      case StatusMessage(:final status):
        return _handleStatus(status, isBackground: isBackground);
      case ThinkingDeltaMessage(:final text):
        currentThinkingText += text;
        return const ChatStateUpdate();
      case StreamDeltaMessage(:final text):
        return _handleStreamDelta(text);
      case AssistantServerMessage(:final message):
        return _handleAssistant(msg, message, isBackground: isBackground);
      case PastHistoryMessage(:final messages):
        return _handlePastHistory(messages);
      case HistoryMessage(:final messages):
        return _handleHistory(messages);
      case SystemMessage(:final subtype, :final slashCommands, :final skills):
        return _handleSystem(msg, subtype, slashCommands, skills);
      case PermissionRequestMessage(
        :final toolUseId,
        :final toolName,
        :final input,
      ):
        if (toolName == 'AskUserQuestion') {
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
        );
      case ResultMessage(:final subtype, :final cost):
        return _handleResult(msg, subtype, cost, isBackground: isBackground);
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
      case InputAckMessage():
        return const ChatStateUpdate(markUserMessagesSent: true);
      case InputRejectedMessage():
        return const ChatStateUpdate(markUserMessagesFailed: true);
      default:
        return ChatStateUpdate(entriesToAdd: [ServerChatEntry(msg)]);
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

  ChatStateUpdate _handlePastHistory(List<PastMessage> messages) {
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
        if (texts.isNotEmpty) {
          final joined = texts.join('\n');
          entries.add(
            UserChatEntry(
              joined,
              timestamp: ts,
              status: MessageStatus.sent,
              messageUuid: m.uuid,
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
    return ChatStateUpdate(entriesToPrepend: entries);
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

    for (final m in messages) {
      if (m is StatusMessage) {
        lastStatus = m.status;
      } else if (m is UserInputMessage) {
        // Skip synthetic and meta messages
        if (m.isSynthetic || m.isMeta) continue;
        // Convert user_input to UserChatEntry with UUID
        entries.add(
          UserChatEntry(
            m.text,
            status: MessageStatus.sent,
            messageUuid: m.userMessageUuid,
          ),
        );
      } else {
        // Don't add internal metadata messages as visible entries
        if (m is! SystemMessage ||
            (m.subtype != 'supported_commands' &&
                m.subtype != 'session_created')) {
          entries.add(ServerChatEntry(m));
        }
        // Restore slash commands from history (init, supported_commands, or
        // session_created with cached commands)
        if (m is SystemMessage &&
            (m.subtype == 'init' ||
                m.subtype == 'supported_commands' ||
                m.subtype == 'session_created') &&
            m.slashCommands.isNotEmpty) {
          commands = _buildCommandList(m.slashCommands, m.skills);
        }
        // Track pending permission request
        if (m is PermissionRequestMessage) {
          pendingPermissions[m.toolUseId] = m;
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
    );
  }

  ChatStateUpdate _handleSystem(
    ServerMessage msg,
    String subtype,
    List<String> slashCommands,
    List<String> skills,
  ) {
    List<SlashCommand>? commands;
    if ((subtype == 'init' ||
            subtype == 'session_created' ||
            subtype == 'supported_commands') &&
        slashCommands.isNotEmpty) {
      commands = _buildCommandList(slashCommands, skills);
    }
    // Only add init as a visible chat entry; session_created and
    // supported_commands are internal metadata messages.
    final addEntry = subtype == 'init';
    return ChatStateUpdate(
      entriesToAdd: addEntry ? [ServerChatEntry(msg)] : [],
      slashCommands: commands,
    );
  }

  ChatStateUpdate _handleResult(
    ServerMessage msg,
    String subtype,
    double? cost, {
    required bool isBackground,
  }) {
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
      inPlanMode: isStopped ? false : null,
      markUserMessagesSent: true,
      sideEffects: effects,
    );
  }

  /// Build slash command list from server-provided names.
  ///
  /// Only includes commands reported by the CLI via `system.init`.
  /// Commands not in this list (e.g. /clear, /help, /plan) are CLI-interactive
  /// only and return "Unknown skill" when sent through the SDK.
  static List<SlashCommand> _buildCommandList(
    List<String> commands,
    List<String> skills,
  ) {
    final skillSet = skills.toSet();
    final knownNames = knownCommands.keys.toSet();
    return commands.map((name) {
      final category = skillSet.contains(name)
          ? SlashCommandCategory.skill
          : knownNames.contains(name)
          ? SlashCommandCategory.builtin
          : SlashCommandCategory.project;
      return buildSlashCommand(name, category: category);
    }).toList();
  }
}

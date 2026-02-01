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
  final Set<ChatSideEffect> sideEffects;
  final String? resultSessionId;

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
    this.sideEffects = const {},
    this.resultSessionId,
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
      case PermissionRequestMessage(:final toolUseId):
        return ChatStateUpdate(
          entriesToAdd: [ServerChatEntry(msg)],
          pendingToolUseId: toolUseId,
          pendingPermission: msg,
        );
      case ResultMessage(:final subtype, :final cost):
        return _handleResult(msg, subtype, cost, isBackground: isBackground);
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
    } else {
      resetPending = true;
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
      entriesToAdd: replaceStreaming == null ? [entry] : [],
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
      if (m.role == 'user') {
        final texts = m.content
            .whereType<TextContent>()
            .map((c) => c.text)
            .toList();
        if (texts.isNotEmpty) {
          entries.add(UserChatEntry(texts.join('\n')));
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
            ),
          ),
        );
      }
    }
    return ChatStateUpdate(entriesToPrepend: entries);
  }

  ChatStateUpdate _handleHistory(List<ServerMessage> messages) {
    final entries = <ChatEntry>[];
    ProcessStatus? lastStatus;
    for (final m in messages) {
      if (m is StatusMessage) {
        lastStatus = m.status;
      } else {
        entries.add(ServerChatEntry(m));
      }
    }
    return ChatStateUpdate(status: lastStatus, entriesToAdd: entries);
  }

  ChatStateUpdate _handleSystem(
    ServerMessage msg,
    String subtype,
    List<String> slashCommands,
    List<String> skills,
  ) {
    List<SlashCommand>? commands;
    if (subtype == 'init' && slashCommands.isNotEmpty) {
      commands = _buildCommandList(slashCommands, skills);
    }
    return ChatStateUpdate(
      entriesToAdd: [ServerChatEntry(msg)],
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
      sideEffects: effects,
    );
  }

  /// Build slash command list from server-provided names.
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

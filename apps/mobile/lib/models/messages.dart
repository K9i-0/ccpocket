import 'dart:convert';

// ---- Assistant content types ----

sealed class AssistantContent {
  factory AssistantContent.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'text' => TextContent(text: json['text'] as String),
      'tool_use' => ToolUseContent(
        id: json['id'] as String,
        name: json['name'] as String,
        input: Map<String, dynamic>.from(json['input'] as Map),
      ),
      _ => TextContent(text: '[Unknown content type: ${json['type']}]'),
    };
  }
}

class TextContent implements AssistantContent {
  final String text;
  const TextContent({required this.text});
}

class ToolUseContent implements AssistantContent {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  const ToolUseContent({
    required this.id,
    required this.name,
    required this.input,
  });
}

// ---- Assistant message ----

class AssistantMessage {
  final String id;
  final String role;
  final List<AssistantContent> content;
  final String model;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.model,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    final contentList = (json['content'] as List)
        .map((c) => AssistantContent.fromJson(c as Map<String, dynamic>))
        .toList();
    return AssistantMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: contentList,
      model: json['model'] as String? ?? '',
    );
  }
}

// ---- Process status ----

enum ProcessStatus {
  idle,
  running,
  waitingApproval;

  static ProcessStatus fromString(String value) {
    return switch (value) {
      'idle' => ProcessStatus.idle,
      'running' => ProcessStatus.running,
      'waiting_approval' => ProcessStatus.waitingApproval,
      _ => ProcessStatus.idle,
    };
  }
}

// ---- Server messages ----

sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'system' => SystemMessage(
        subtype: json['subtype'] as String? ?? '',
        sessionId: json['sessionId'] as String?,
        model: json['model'] as String?,
      ),
      'assistant' => AssistantServerMessage(
        message: AssistantMessage.fromJson(
          json['message'] as Map<String, dynamic>,
        ),
      ),
      'tool_result' => ToolResultMessage(
        toolUseId: json['toolUseId'] as String,
        content: json['content'] as String,
      ),
      'result' => ResultMessage(
        subtype: json['subtype'] as String? ?? '',
        result: json['result'] as String?,
        error: json['error'] as String?,
        cost: (json['cost'] as num?)?.toDouble(),
        duration: (json['duration'] as num?)?.toDouble(),
      ),
      'error' => ErrorMessage(message: json['message'] as String),
      'status' => StatusMessage(
        status: ProcessStatus.fromString(json['status'] as String),
      ),
      'history' => HistoryMessage(
        messages: (json['messages'] as List)
            .map((m) => ServerMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      ),
      _ => ErrorMessage(message: 'Unknown message type: ${json['type']}'),
    };
  }
}

class SystemMessage implements ServerMessage {
  final String subtype;
  final String? sessionId;
  final String? model;
  const SystemMessage({
    required this.subtype,
    this.sessionId,
    this.model,
  });
}

class AssistantServerMessage implements ServerMessage {
  final AssistantMessage message;
  const AssistantServerMessage({required this.message});
}

class ToolResultMessage implements ServerMessage {
  final String toolUseId;
  final String content;
  const ToolResultMessage({required this.toolUseId, required this.content});
}

class ResultMessage implements ServerMessage {
  final String subtype;
  final String? result;
  final String? error;
  final double? cost;
  final double? duration;
  const ResultMessage({
    required this.subtype,
    this.result,
    this.error,
    this.cost,
    this.duration,
  });
}

class ErrorMessage implements ServerMessage {
  final String message;
  const ErrorMessage({required this.message});
}

class StatusMessage implements ServerMessage {
  final ProcessStatus status;
  const StatusMessage({required this.status});
}

class HistoryMessage implements ServerMessage {
  final List<ServerMessage> messages;
  const HistoryMessage({required this.messages});
}

// ---- Client messages ----

class ClientMessage {
  final Map<String, dynamic> _json;
  ClientMessage._(this._json);

  factory ClientMessage.start(String projectPath) =>
      ClientMessage._({'type': 'start', 'projectPath': projectPath});

  factory ClientMessage.input(String text) =>
      ClientMessage._({'type': 'input', 'text': text});

  factory ClientMessage.approve(String id) =>
      ClientMessage._({'type': 'approve', 'id': id});

  factory ClientMessage.reject(String id) =>
      ClientMessage._({'type': 'reject', 'id': id});

  String toJson() => jsonEncode(_json);
}

// ---- Chat entry (for UI display) ----

sealed class ChatEntry {}

class ServerChatEntry implements ChatEntry {
  final ServerMessage message;
  const ServerChatEntry(this.message);
}

class UserChatEntry implements ChatEntry {
  final String text;
  const UserChatEntry(this.text);
}

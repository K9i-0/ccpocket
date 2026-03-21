import 'dart:convert';

import '../models/messages.dart';

/// Maps Claude Code CLI `--output-format stream-json` output (SDKMessage)
/// to the existing [ServerMessage] types used by the Flutter app.
///
/// The CLI outputs Newline-Delimited JSON (NDJSON) where each line is an
/// SDKMessage. This mapper translates those into the same ServerMessage types
/// that the Bridge Server would emit, allowing the rest of the app to work
/// unchanged.
///
/// Reference: https://code.claude.com/docs/en/headless
class SshMessageMapper {
  /// Parse a single JSON line from CLI stdout and convert to [ServerMessage].
  ///
  /// Returns `null` for messages that should be silently ignored
  /// (e.g. internal control messages that are handled separately).
  static ServerMessage? mapSdkMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) return null;

    return switch (type) {
      'system' => _mapSystemMessage(json),
      'stream_event' => _mapStreamEvent(json),
      'assistant' => _mapAssistantMessage(json),
      'user' => _mapUserMessage(json),
      'result' => _mapResultMessage(json),
      'tool_use_summary' => _mapToolUseSummary(json),
      'tool_progress' => null, // Silently ignore progress updates for now
      'auth_status' => null, // Auth is handled at SSH level
      'rate_limit_event' => _mapRateLimitEvent(json),
      'prompt_suggestion' => null, // Not used in current UI
      _ => null, // Unknown types are silently ignored
    };
  }

  /// Map `control_request` messages to [PermissionRequestMessage].
  ///
  /// The control protocol is used by the Claude Agent SDK internally.
  /// When running in SDK mode, the CLI sends `control_request` for
  /// permission checks, and expects `control_response` via stdin.
  ///
  /// Returns the request_id along with the mapped message so the caller
  /// can respond with the appropriate `control_response`.
  static (String requestId, PermissionRequestMessage message)?
      mapControlRequest(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type != 'control_request') return null;

    final requestId = json['request_id'] as String? ?? '';
    final request = json['request'] as Map<String, dynamic>?;
    if (request == null) return null;

    final subtype = request['subtype'] as String?;
    if (subtype != 'can_use_tool') return null;

    final toolName = request['tool_name'] as String? ?? '';
    final input = request['input'] as Map<String, dynamic>? ?? {};

    // Use request_id as toolUseId since it serves the same purpose
    return (
      requestId,
      PermissionRequestMessage(
        toolUseId: requestId,
        toolName: toolName,
        input: input,
      ),
    );
  }

  /// Build a `control_response` JSON string for approving a tool use.
  static String buildApproveResponse(String requestId) {
    return jsonEncode({
      'type': 'control_response',
      'request_id': requestId,
      'response': {
        'subtype': 'success',
        'response': {'behavior': 'allow'},
      },
    });
  }

  /// Build a `control_response` JSON string for denying a tool use.
  static String buildDenyResponse(String requestId, {String? message}) {
    return jsonEncode({
      'type': 'control_response',
      'request_id': requestId,
      'response': {
        'subtype': 'success',
        'response': {
          'behavior': 'deny',
          if (message != null) 'message': message,
        },
      },
    });
  }

  /// Build a user input message for sending via stdin.
  static String buildUserInput(String text, {List<Map<String, dynamic>>? images}) {
    final content = <Map<String, dynamic>>[];
    content.add({'type': 'text', 'text': text});

    if (images != null) {
      for (final img in images) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': img['mimeType'] ?? 'image/png',
            'data': img['data'] ?? '',
          },
        });
      }
    }

    return jsonEncode({
      'type': 'user',
      'message': {
        'role': 'user',
        'content': content.length == 1 ? text : content,
      },
    });
  }

  // ---- Private mapping methods ----

  static ServerMessage? _mapSystemMessage(Map<String, dynamic> json) {
    final subtype = json['subtype'] as String? ?? '';

    switch (subtype) {
      case 'init':
        return SystemMessage(
          subtype: 'session_created',
          sessionId: json['session_id'] as String?,
          claudeSessionId: json['session_id'] as String?,
          model: json['model'] as String?,
          provider: 'claude',
          projectPath: json['cwd'] as String?,
          permissionMode: json['permissionMode'] as String?,
          slashCommands:
              (json['slash_commands'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          skills:
              (json['skills'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );

      case 'status':
        // Map status subtypes to ProcessStatus
        final statusText = json['status'] as String? ?? '';
        return StatusMessage(status: ProcessStatus.fromString(statusText));

      case 'compact_boundary':
        return StatusMessage(status: ProcessStatus.compacting);

      case 'api_retry':
        final attempt = json['attempt'] as int? ?? 0;
        final maxRetries = json['max_retries'] as int? ?? 0;
        final error = json['error'] as String? ?? 'unknown';
        return ErrorMessage(
          message: 'API retry ($attempt/$maxRetries): $error',
          errorCode: 'api_retry',
        );

      default:
        return null; // Ignore unknown system subtypes
    }
  }

  static ServerMessage? _mapStreamEvent(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>?;
    if (event == null) return null;

    final eventType = event['type'] as String?;

    switch (eventType) {
      case 'content_block_delta':
        final delta = event['delta'] as Map<String, dynamic>?;
        if (delta == null) return null;

        final deltaType = delta['type'] as String?;
        switch (deltaType) {
          case 'text_delta':
            final text = delta['text'] as String? ?? '';
            return StreamDeltaMessage(text: text);
          case 'thinking_delta':
            final thinking = delta['thinking'] as String? ?? '';
            return ThinkingDeltaMessage(text: thinking);
          case 'input_json_delta':
            // Tool input streaming - ignore for now, we get the full input
            // in the assistant message
            return null;
          default:
            return null;
        }

      case 'message_start':
      case 'content_block_start':
      case 'content_block_stop':
      case 'message_delta':
      case 'message_stop':
        // These are structural events, not content. Ignore.
        return null;

      default:
        return null;
    }
  }

  static ServerMessage _mapAssistantMessage(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>? ?? {};
    final uuid = json['uuid'] as String?;

    return AssistantServerMessage(
      message: AssistantMessage.fromJson(message),
      messageUuid: uuid,
    );
  }

  static ServerMessage? _mapUserMessage(Map<String, dynamic> json) {
    final isSynthetic = json['isSynthetic'] as bool? ?? false;
    final message = json['message'] as Map<String, dynamic>? ?? {};
    final content = message['content'];
    final uuid = json['uuid'] as String?;

    // Check if this is a tool_result message
    if (content is List) {
      for (final block in content) {
        if (block is Map<String, dynamic> && block['type'] == 'tool_result') {
          final toolUseId = block['tool_use_id'] as String? ?? '';
          final resultContent = block['content'];
          final normalizedContent = _normalizeContent(resultContent);

          return ToolResultMessage(
            toolUseId: toolUseId,
            content: normalizedContent,
            userMessageUuid: uuid,
          );
        }
      }
    }

    // Regular user message (not tool_result) - emit as UserInputMessage
    if (!isSynthetic) {
      final textContent = _extractTextFromContent(content);
      return UserInputMessage(
        text: textContent,
        userMessageUuid: uuid,
        isSynthetic: false,
      );
    }

    return null; // Ignore synthetic user messages that aren't tool results
  }

  static ServerMessage _mapResultMessage(Map<String, dynamic> json) {
    final subtype = json['subtype'] as String? ?? '';
    final usage = json['usage'] as Map<String, dynamic>?;

    return ResultMessage(
      subtype: subtype,
      result: json['result'] as String?,
      error: _extractErrors(json),
      cost: (json['total_cost_usd'] as num?)?.toDouble(),
      duration: (json['duration_ms'] as num?)?.toDouble(),
      sessionId: json['session_id'] as String?,
      stopReason: json['stop_reason'] as String?,
      inputTokens: usage?['input_tokens'] as int?,
      cachedInputTokens: usage?['cache_read_input_tokens'] as int?,
      outputTokens: usage?['output_tokens'] as int?,
    );
  }

  static ServerMessage _mapToolUseSummary(Map<String, dynamic> json) {
    return ToolUseSummaryMessage(
      summary: json['summary'] as String? ?? '',
      precedingToolUseIds:
          (json['preceding_tool_use_ids'] as List?)?.cast<String>() ??
          const [],
    );
  }

  static ServerMessage _mapRateLimitEvent(Map<String, dynamic> json) {
    return ErrorMessage(
      message: 'Rate limit reached. Please wait before retrying.',
      errorCode: 'rate_limit',
    );
  }

  // ---- Helpers ----

  static String _normalizeContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text']?.toString() ?? '')
          .join('\n');
    }
    return content?.toString() ?? '';
  }

  static String _extractTextFromContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text']?.toString() ?? '')
          .join('\n');
    }
    return '';
  }

  static String? _extractErrors(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.map((e) => e.toString()).join('\n');
    }
    final error = json['error'];
    if (error is String) return error;
    return null;
  }
}

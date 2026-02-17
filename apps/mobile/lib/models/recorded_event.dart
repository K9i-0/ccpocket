import 'dart:convert';

/// A single recorded event from a Bridge Server recording session.
///
/// Each line in a `.jsonl` recording file corresponds to one [RecordedEvent].
/// Events can be either "outgoing" (server → client, i.e. [ServerMessage])
/// or "incoming" (client → server, i.e. user actions like approve/reject/input).
class RecordedEvent {
  const RecordedEvent({
    required this.timestamp,
    required this.direction,
    required this.message,
  });

  /// Timestamp of when the event was recorded.
  final DateTime timestamp;

  /// Direction of the message: "outgoing" (server→client) or "incoming" (client→server).
  final String direction;

  /// The raw JSON message payload.
  /// For outgoing events, this can be parsed via [ServerMessage.fromJson].
  /// For incoming events, this contains the ClientMessage fields (type, id, text, etc.).
  final Map<String, dynamic> message;

  /// Whether this is an outgoing (server → client) message.
  bool get isOutgoing => direction == 'outgoing';

  /// Whether this is an incoming (client → server) message.
  bool get isIncoming => direction == 'incoming';

  /// The message type (e.g. "assistant", "status", "approve", "input").
  String get type => message['type'] as String? ?? 'unknown';

  /// Parse a single JSONL line into a [RecordedEvent].
  factory RecordedEvent.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    return RecordedEvent(
      timestamp: DateTime.parse(json['ts'] as String),
      direction: json['direction'] as String,
      message: json['message'] as Map<String, dynamic>,
    );
  }

  /// Parse multiple JSONL lines into a list of [RecordedEvent]s.
  /// Empty lines and lines that fail to parse are skipped.
  static List<RecordedEvent> parseJsonLines(List<String> lines) {
    final events = <RecordedEvent>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        events.add(RecordedEvent.fromJsonLine(trimmed));
      } catch (_) {
        // Skip malformed lines
      }
    }
    return events;
  }

  /// Parse a full JSONL string (with newlines) into a list of [RecordedEvent]s.
  static List<RecordedEvent> parseJsonlString(String jsonl) {
    return parseJsonLines(jsonl.split('\n'));
  }
}

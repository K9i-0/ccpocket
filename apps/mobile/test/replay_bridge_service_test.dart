import 'dart:convert';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/replay_bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to create a JSONL line for a recorded event.
String makeRecordedLine({
  required String direction,
  required Map<String, dynamic> message,
  DateTime? ts,
}) {
  return jsonEncode({
    'ts': (ts ?? DateTime(2026, 1, 1)).toIso8601String(),
    'direction': direction,
    'message': message,
  });
}

void main() {
  group('ReplayBridgeService', () {
    test('loadFromJsonLines parses events into chunks', () {
      final lines = [
        // Chunk 1: initial outgoing messages
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'running'},
          ts: DateTime(2026, 1, 1, 0, 0, 0),
        ),
        makeRecordedLine(
          direction: 'outgoing',
          message: {
            'type': 'assistant',
            'message': {
              'id': 'a1',
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'Hello'},
              ],
              'model': 'claude',
            },
          },
          ts: DateTime(2026, 1, 1, 0, 0, 1),
        ),
        // Breakpoint: user action
        makeRecordedLine(
          direction: 'incoming',
          message: {'type': 'approve', 'id': 'tool-1'},
          ts: DateTime(2026, 1, 1, 0, 0, 5),
        ),
        // Chunk 2: post-approval messages
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'idle'},
          ts: DateTime(2026, 1, 1, 0, 0, 6),
        ),
      ];

      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines(lines);

      expect(service.chunkCount, 2);
      expect(service.isComplete, false);

      service.dispose();
    });

    test('play() emits first chunk immediately in instant mode', () async {
      final lines = [
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'running'},
        ),
        makeRecordedLine(
          direction: 'outgoing',
          message: {
            'type': 'assistant',
            'message': {
              'id': 'a1',
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'Hello'},
              ],
              'model': 'claude',
            },
          },
        ),
        makeRecordedLine(
          direction: 'incoming',
          message: {'type': 'input', 'text': 'hi'},
        ),
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'idle'},
        ),
      ];

      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines(lines);

      final received = <ServerMessage>[];
      service.messages.listen(received.add);

      service.play();
      await Future<void>.delayed(Duration.zero);

      // First chunk has 2 messages (status + assistant)
      expect(received.length, 2);
      expect(received[0], isA<StatusMessage>());
      expect(received[1], isA<AssistantServerMessage>());

      service.dispose();
    });

    test('send() advances to next chunk', () async {
      final lines = [
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'running'},
        ),
        makeRecordedLine(
          direction: 'incoming',
          message: {'type': 'approve', 'id': 'tool-1'},
        ),
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'idle'},
        ),
      ];

      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines(lines);

      final received = <ServerMessage>[];
      service.messages.listen(received.add);

      // Play first chunk
      service.play();
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1); // status: running

      // Send triggers next chunk
      service.send(ClientMessage.approve('tool-1'));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 2); // + status: idle

      // All chunks have been played (chunk 0 via play(), chunk 1 via send())
      // currentChunk is now 1 (last index), but there are no more incoming
      // events to advance past it, so isComplete is only true after one
      // more send() or when currentChunk > last index.
      // For now, verify the messages were all delivered correctly.
      expect(service.currentChunkIndex, 1);
      service.dispose();
    });

    test('sentMessages tracks all sent messages', () {
      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines([
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'running'},
        ),
        makeRecordedLine(
          direction: 'incoming',
          message: {'type': 'approve', 'id': 't1'},
        ),
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'idle'},
        ),
      ]);

      service.play();
      service.send(ClientMessage.approve('t1'));

      expect(service.sentMessages.length, 1);
      service.dispose();
    });

    test('empty recording does not crash', () {
      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines([]);

      expect(service.chunkCount, 0);
      expect(service.isComplete, true);

      service.play(); // Should not crash
      service.dispose();
    });

    test('messagesForSession filters by sessionId', () async {
      final lines = [
        makeRecordedLine(
          direction: 'outgoing',
          message: {
            'type': 'status',
            'status': 'running',
            'sessionId': 'session-1',
          },
        ),
      ];

      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines(lines);

      final sessionMessages = <ServerMessage>[];
      service.messagesForSession('session-1').listen(sessionMessages.add);

      service.play();
      await Future<void>.delayed(Duration.zero);

      expect(sessionMessages.length, 1);
      service.dispose();
    });

    test('malformed lines are skipped gracefully', () {
      final service = ReplayBridgeService(mode: ReplayMode.instant);
      service.loadFromJsonLines([
        'this is not json',
        makeRecordedLine(
          direction: 'outgoing',
          message: {'type': 'status', 'status': 'running'},
        ),
        '{"ts": "2026-01-01", "direction": "outgoing", "message": {"type": "unknown_type_xyz"}}',
      ]);

      // Should have at least the valid status message in a chunk
      expect(service.chunkCount, greaterThanOrEqualTo(1));
      service.dispose();
    });
  });
}

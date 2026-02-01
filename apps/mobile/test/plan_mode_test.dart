import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';

void main() {
  group('ClientMessage.interrupt', () {
    test('creates interrupt message without sessionId', () {
      final msg = ClientMessage.interrupt();
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'interrupt');
      expect(json.containsKey('sessionId'), isFalse);
    });

    test('creates interrupt message with sessionId', () {
      final msg = ClientMessage.interrupt(sessionId: 'sess-123');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'interrupt');
      expect(json['sessionId'], 'sess-123');
    });
  });

  group('Plan mode detection via ToolUseContent', () {
    test('EnterPlanMode tool use is detectable', () {
      final msg = ServerMessage.fromJson({
        'type': 'assistant',
        'message': {
          'id': 'msg-1',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Planning...'},
            {
              'type': 'tool_use',
              'id': 'tu-1',
              'name': 'EnterPlanMode',
              'input': {},
            },
          ],
          'model': 'claude-sonnet-4-20250514',
        },
      });
      expect(msg, isA<AssistantServerMessage>());
      final assistant = msg as AssistantServerMessage;
      final hasEnterPlan = assistant.message.content.any(
        (c) => c is ToolUseContent && c.name == 'EnterPlanMode',
      );
      expect(hasEnterPlan, isTrue);
    });

    test('ExitPlanMode tool use is detectable', () {
      final msg = ServerMessage.fromJson({
        'type': 'assistant',
        'message': {
          'id': 'msg-2',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Plan complete.'},
            {
              'type': 'tool_use',
              'id': 'tu-2',
              'name': 'ExitPlanMode',
              'input': {},
            },
          ],
          'model': 'claude-sonnet-4-20250514',
        },
      });
      expect(msg, isA<AssistantServerMessage>());
      final assistant = msg as AssistantServerMessage;
      final hasExitPlan = assistant.message.content.any(
        (c) => c is ToolUseContent && c.name == 'ExitPlanMode',
      );
      expect(hasExitPlan, isTrue);
    });

    test('ExitPlanMode permission request is plan approval', () {
      final msg = ServerMessage.fromJson({
        'type': 'permission_request',
        'toolUseId': 'tu-exit-1',
        'toolName': 'ExitPlanMode',
        'input': {},
      });
      expect(msg, isA<PermissionRequestMessage>());
      final perm = msg as PermissionRequestMessage;
      expect(perm.toolName, 'ExitPlanMode');
    });
  });

  group('ClientMessage.reject with feedback', () {
    test('creates reject with message for plan feedback', () {
      final msg = ClientMessage.reject(
        'tu-exit-1',
        message: 'Please add error handling to Phase 2',
        sessionId: 'sess-1',
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'reject');
      expect(json['id'], 'tu-exit-1');
      expect(json['message'], 'Please add error handling to Phase 2');
      expect(json['sessionId'], 'sess-1');
    });

    test('creates reject without message', () {
      final msg = ClientMessage.reject('tu-exit-1');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'reject');
      expect(json['id'], 'tu-exit-1');
      expect(json.containsKey('message'), isFalse);
    });
  });

  group('FileListMessage parsing', () {
    test('parses file_list message', () {
      final msg = ServerMessage.fromJson({
        'type': 'file_list',
        'files': ['lib/main.dart', 'pubspec.yaml'],
      });
      expect(msg, isA<FileListMessage>());
      final fl = msg as FileListMessage;
      expect(fl.files, ['lib/main.dart', 'pubspec.yaml']);
    });
  });
}

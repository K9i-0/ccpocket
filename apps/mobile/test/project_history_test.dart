import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';

void main() {
  group('ProjectHistoryMessage', () {
    test('parses from JSON', () {
      final json = {
        'type': 'project_history',
        'projects': ['/path/a', '/path/b'],
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<ProjectHistoryMessage>());
      final historyMsg = msg as ProjectHistoryMessage;
      expect(historyMsg.projects, ['/path/a', '/path/b']);
    });

    test('parses empty projects list', () {
      final json = {'type': 'project_history', 'projects': <String>[]};
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<ProjectHistoryMessage>());
      final historyMsg = msg as ProjectHistoryMessage;
      expect(historyMsg.projects, isEmpty);
    });
  });

  group('ClientMessage.listProjectHistory', () {
    test('serializes correctly', () {
      final msg = ClientMessage.listProjectHistory();
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'list_project_history');
    });
  });

  group('ClientMessage.removeProjectHistory', () {
    test('serializes correctly', () {
      final msg = ClientMessage.removeProjectHistory('/path/to/project');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'remove_project_history');
      expect(json['projectPath'], '/path/to/project');
    });
  });
}

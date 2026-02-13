import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/models/messages.dart';
import 'dart:convert';

void main() {
  group('ToolUseSummaryMessage', () {
    test('parses from JSON correctly', () {
      final json = {
        'type': 'tool_use_summary',
        'summary': 'Read 3 files and analyzed code',
        'precedingToolUseIds': ['tu-1', 'tu-2', 'tu-3'],
      };

      final msg = ServerMessage.fromJson(json);

      expect(msg, isA<ToolUseSummaryMessage>());
      final summary = msg as ToolUseSummaryMessage;
      expect(summary.summary, 'Read 3 files and analyzed code');
      expect(summary.precedingToolUseIds, ['tu-1', 'tu-2', 'tu-3']);
    });

    test('handles empty precedingToolUseIds', () {
      final json = {
        'type': 'tool_use_summary',
        'summary': 'Quick analysis completed',
        'precedingToolUseIds': <String>[],
      };

      final msg = ServerMessage.fromJson(json);

      expect(msg, isA<ToolUseSummaryMessage>());
      final summary = msg as ToolUseSummaryMessage;
      expect(summary.summary, 'Quick analysis completed');
      expect(summary.precedingToolUseIds, isEmpty);
    });

    test('handles missing precedingToolUseIds as empty list', () {
      final json = {'type': 'tool_use_summary', 'summary': 'Analyzed codebase'};

      final msg = ServerMessage.fromJson(json);

      expect(msg, isA<ToolUseSummaryMessage>());
      final summary = msg as ToolUseSummaryMessage;
      expect(summary.summary, 'Analyzed codebase');
      expect(summary.precedingToolUseIds, isEmpty);
    });
  });

  group('Codex thread options', () {
    test('ClientMessage.start serializes codex thread options', () {
      final msg = ClientMessage.start(
        '/tmp/project',
        provider: 'codex',
        modelReasoningEffort: 'high',
        networkAccessEnabled: true,
        webSearchMode: 'live',
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['modelReasoningEffort'], 'high');
      expect(json['networkAccessEnabled'], true);
      expect(json['webSearchMode'], 'live');
    });

    test('RecentSession parses codex thread options from codexSettings', () {
      final session = RecentSession.fromJson({
        'sessionId': 's1',
        'provider': 'codex',
        'firstPrompt': 'hello',
        'messageCount': 1,
        'created': '2026-02-13T00:00:00Z',
        'modified': '2026-02-13T00:00:00Z',
        'gitBranch': 'main',
        'projectPath': '/tmp/project',
        'isSidechain': false,
        'codexSettings': {
          'modelReasoningEffort': 'medium',
          'networkAccessEnabled': false,
          'webSearchMode': 'cached',
        },
      });

      expect(session.codexModelReasoningEffort, 'medium');
      expect(session.codexNetworkAccessEnabled, false);
      expect(session.codexWebSearchMode, 'cached');
    });
  });
}

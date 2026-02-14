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

    test('RecentSession parses resumeCwd for worktree resume target', () {
      final session = RecentSession.fromJson({
        'sessionId': 's2',
        'provider': 'codex',
        'firstPrompt': 'resume',
        'messageCount': 1,
        'created': '2026-02-13T00:00:00Z',
        'modified': '2026-02-13T00:00:00Z',
        'gitBranch': 'feature/x',
        'projectPath': '/tmp/project',
        'resumeCwd': '/tmp/project-worktrees/feature-x',
        'isSidechain': false,
      });

      expect(session.projectPath, '/tmp/project');
      expect(session.resumeCwd, '/tmp/project-worktrees/feature-x');
    });
  });

  group('Claude advanced options', () {
    test('ClientMessage.start serializes advanced Claude options', () {
      final msg = ClientMessage.start(
        '/tmp/project',
        provider: 'claude',
        model: 'claude-sonnet-4-5',
        effort: 'high',
        maxTurns: 8,
        maxBudgetUsd: 1.25,
        fallbackModel: 'claude-haiku-4-5',
        persistSession: false,
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['model'], 'claude-sonnet-4-5');
      expect(json['effort'], 'high');
      expect(json['maxTurns'], 8);
      expect(json['maxBudgetUsd'], 1.25);
      expect(json['fallbackModel'], 'claude-haiku-4-5');
      expect(json['persistSession'], false);
      expect(json.containsKey('forkSession'), isFalse);
    });

    test('ClientMessage.resumeSession serializes resume-only options', () {
      final msg = ClientMessage.resumeSession(
        'session-1',
        '/tmp/project',
        provider: 'claude',
        permissionMode: 'acceptEdits',
        model: 'claude-sonnet-4-5',
        effort: 'medium',
        maxTurns: 5,
        maxBudgetUsd: 0.5,
        fallbackModel: 'claude-haiku-4-5',
        forkSession: true,
        persistSession: true,
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'resume_session');
      expect(json['sessionId'], 'session-1');
      expect(json['permissionMode'], 'acceptEdits');
      expect(json['model'], 'claude-sonnet-4-5');
      expect(json['effort'], 'medium');
      expect(json['maxTurns'], 5);
      expect(json['maxBudgetUsd'], 0.5);
      expect(json['fallbackModel'], 'claude-haiku-4-5');
      expect(json['forkSession'], true);
      expect(json['persistSession'], true);
    });
  });

  group('Result message parsing', () {
    test('parses token and tool usage fields', () {
      final msg = ServerMessage.fromJson({
        'type': 'result',
        'subtype': 'success',
        'cost': 0.1234,
        'duration': 4567,
        'inputTokens': 1000,
        'cachedInputTokens': 250,
        'outputTokens': 333,
        'toolCalls': 9,
        'fileEdits': 3,
      });

      expect(msg, isA<ResultMessage>());
      final result = msg as ResultMessage;
      expect(result.inputTokens, 1000);
      expect(result.cachedInputTokens, 250);
      expect(result.outputTokens, 333);
      expect(result.toolCalls, 9);
      expect(result.fileEdits, 3);
    });
  });
}

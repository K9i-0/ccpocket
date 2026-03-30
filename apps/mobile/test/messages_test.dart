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

    test('RecentSession ignores placeholder codex model names', () {
      final session = RecentSession.fromJson({
        'sessionId': 's3',
        'provider': 'codex',
        'firstPrompt': 'resume',
        'created': '2026-02-13T00:00:00Z',
        'modified': '2026-02-13T00:00:00Z',
        'gitBranch': 'main',
        'projectPath': '/tmp/project',
        'isSidechain': false,
        'codexSettings': {'model': 'codex'},
      });

      expect(session.codexModel, isNull);
    });

    test('AssistantMessage ignores placeholder codex model names', () {
      final message = AssistantMessage.fromJson({
        'id': 'a1',
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'hello'},
        ],
        'model': 'codex',
      });

      expect(message.model, isEmpty);
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

  group('InputAck message parsing', () {
    test('parses queued=true', () {
      final msg = ServerMessage.fromJson({
        'type': 'input_ack',
        'sessionId': 's1',
        'queued': true,
      });

      expect(msg, isA<InputAckMessage>());
      final ack = msg as InputAckMessage;
      expect(ack.sessionId, 's1');
      expect(ack.queued, isTrue);
    });

    test('defaults queued to false when omitted', () {
      final msg = ServerMessage.fromJson({
        'type': 'input_ack',
        'sessionId': 's1',
      });

      expect(msg, isA<InputAckMessage>());
      final ack = msg as InputAckMessage;
      expect(ack.sessionId, 's1');
      expect(ack.queued, isFalse);
    });
  });

  // ---- Git Operations (Phase 1-3) ----

  group('GitStageResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_stage_result',
        'success': true,
      });
      expect(msg, isA<GitStageResultMessage>());
      expect((msg as GitStageResultMessage).success, isTrue);
      expect(msg.error, isNull);
    });

    test('parses failure with error', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_stage_result',
        'success': false,
        'error': 'file not found',
      });
      expect(msg, isA<GitStageResultMessage>());
      final r = msg as GitStageResultMessage;
      expect(r.success, isFalse);
      expect(r.error, 'file not found');
    });
  });

  group('GitUnstageResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_unstage_result',
        'success': true,
      });
      expect(msg, isA<GitUnstageResultMessage>());
      expect((msg as GitUnstageResultMessage).success, isTrue);
    });
  });

  group('GitUnstageHunksResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_unstage_hunks_result',
        'success': true,
      });
      expect(msg, isA<GitUnstageHunksResultMessage>());
      expect((msg as GitUnstageHunksResultMessage).success, isTrue);
    });
  });

  group('GitCommitResultMessage', () {
    test('parses success with hash and message', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_commit_result',
        'success': true,
        'commitHash': 'abc1234',
        'message': 'feat: add login',
      });
      expect(msg, isA<GitCommitResultMessage>());
      final r = msg as GitCommitResultMessage;
      expect(r.success, isTrue);
      expect(r.commitHash, 'abc1234');
      expect(r.message, 'feat: add login');
      expect(r.error, isNull);
    });

    test('parses failure', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_commit_result',
        'success': false,
        'error': 'Nothing to commit',
      });
      final r = msg as GitCommitResultMessage;
      expect(r.success, isFalse);
      expect(r.error, 'Nothing to commit');
    });
  });

  group('GitPushResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_push_result',
        'success': true,
        'remote': 'origin',
        'branch': 'feat/login',
      });
      final r = msg as GitPushResultMessage;
      expect(r.success, isTrue);
      expect(r.remote, 'origin');
      expect(r.branch, 'feat/login');
    });
  });

  group('GitStatusResultMessage', () {
    test('parses status with all categories', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_status_result',
        'staged': ['a.txt'],
        'unstaged': ['b.txt'],
        'untracked': ['c.txt'],
      });
      final r = msg as GitStatusResultMessage;
      expect(r.staged, ['a.txt']);
      expect(r.unstaged, ['b.txt']);
      expect(r.untracked, ['c.txt']);
    });

    test('handles missing arrays', () {
      final msg = ServerMessage.fromJson({'type': 'git_status_result'});
      final r = msg as GitStatusResultMessage;
      expect(r.staged, isEmpty);
      expect(r.unstaged, isEmpty);
      expect(r.untracked, isEmpty);
    });
  });

  group('GitBranchesResultMessage', () {
    test('parses branches list', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_branches_result',
        'current': 'main',
        'branches': ['main', 'feat/login', 'fix/bug'],
        'remoteStatusByBranch': {
          'feat/login': {'ahead': 2, 'behind': 1, 'hasUpstream': true},
        },
      });
      final r = msg as GitBranchesResultMessage;
      expect(r.current, 'main');
      expect(r.branches, ['main', 'feat/login', 'fix/bug']);
      expect(r.remoteStatusByBranch['feat/login']?.ahead, 2);
      expect(r.error, isNull);
    });

    test('parses error', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_branches_result',
        'current': '',
        'branches': <String>[],
        'error': 'not a git repo',
      });
      final r = msg as GitBranchesResultMessage;
      expect(r.error, 'not a git repo');
    });
  });

  group('GitCreateBranchResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_create_branch_result',
        'success': true,
      });
      expect((msg as GitCreateBranchResultMessage).success, isTrue);
    });

    test('parses failure', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_create_branch_result',
        'success': false,
        'error': 'branch exists',
      });
      final r = msg as GitCreateBranchResultMessage;
      expect(r.success, isFalse);
      expect(r.error, 'branch exists');
    });
  });

  group('GitCheckoutBranchResultMessage', () {
    test('parses success', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_checkout_branch_result',
        'success': true,
      });
      expect((msg as GitCheckoutBranchResultMessage).success, isTrue);
    });

    test('parses failure', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_checkout_branch_result',
        'success': false,
        'error': 'branch not found',
      });
      final r = msg as GitCheckoutBranchResultMessage;
      expect(r.success, isFalse);
      expect(r.error, 'branch not found');
    });
  });

  group('ClientMessage git operations serialization', () {
    test('gitStage with files', () {
      final msg = ClientMessage.gitStage('/p', files: ['a.txt', 'b.txt']);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_stage');
      expect(json['projectPath'], '/p');
      expect(json['files'], ['a.txt', 'b.txt']);
    });

    test('gitStage with hunks', () {
      final msg = ClientMessage.gitStage(
        '/p',
        hunks: [
          {'file': 'a.txt', 'hunkIndex': 0},
        ],
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_stage');
      expect(json['hunks'], [
        {'file': 'a.txt', 'hunkIndex': 0},
      ]);
    });

    test('gitUnstage', () {
      final msg = ClientMessage.gitUnstage('/p', files: ['a.txt']);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_unstage');
      expect(json['files'], ['a.txt']);
    });

    test('gitUnstageHunks', () {
      final msg = ClientMessage.gitUnstageHunks('/p', [
        {'file': 'a.txt', 'hunkIndex': 0},
      ]);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_unstage_hunks');
      expect(json['hunks'], [
        {'file': 'a.txt', 'hunkIndex': 0},
      ]);
    });

    test('gitCommit with message', () {
      final msg = ClientMessage.gitCommit('/p', message: 'feat: add x');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_commit');
      expect(json['message'], 'feat: add x');
    });

    test('gitCommit with autoGenerate', () {
      final msg = ClientMessage.gitCommit('/p', autoGenerate: true);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['autoGenerate'], isTrue);
    });

    test('gitPush', () {
      final msg = ClientMessage.gitPush('/p');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_push');
      expect(json['projectPath'], '/p');
    });

    test('gitPush with forceLease', () {
      final msg = ClientMessage.gitPush('/p', forceLease: true);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['forceLease'], isTrue);
    });

    test('gitStatus', () {
      final msg = ClientMessage.gitStatus('/p');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_status');
      expect(json['projectPath'], '/p');
    });

    test('gitBranches', () {
      final msg = ClientMessage.gitBranches('/p', query: 'feat');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_branches');
      expect(json['query'], 'feat');
    });

    test('gitCreateBranch', () {
      final msg = ClientMessage.gitCreateBranch('/p', 'feat/x', checkout: true);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_create_branch');
      expect(json['name'], 'feat/x');
      expect(json['checkout'], isTrue);
    });

    test('gitCheckoutBranch', () {
      final msg = ClientMessage.gitCheckoutBranch('/p', 'main');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_checkout_branch');
      expect(json['branch'], 'main');
    });

    test('gitRevertHunks', () {
      final msg = ClientMessage.gitRevertHunks('/p', [
        {'file': 'a.txt', 'hunkIndex': 1},
      ]);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_revert_hunks');
      expect(json['hunks'], [
        {'file': 'a.txt', 'hunkIndex': 1},
      ]);
    });

    test('getDiff with staged', () {
      final msg = ClientMessage.getDiff('/p', staged: true);
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'get_diff');
      expect(json['staged'], isTrue);
    });

    test('getDiff without staged (backward compat)', () {
      final msg = ClientMessage.getDiff('/p');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'get_diff');
      expect(json.containsKey('staged'), isFalse);
    });
  });
}

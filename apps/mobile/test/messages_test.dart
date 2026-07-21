import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/models/messages.dart';
import 'dart:convert';

void main() {
  test('serializes tool suggestion installation action', () {
    expect(
      jsonDecode(
        ClientMessage.installToolSuggestion(
          'approval-0',
          sessionId: 'session-1',
        ).toJson(),
      ),
      {
        'type': 'install_tool_suggestion',
        'toolUseId': 'approval-0',
        'sessionId': 'session-1',
      },
    );
  });

  test('parses structured tool suggestion state', () {
    final message =
        ServerMessage.fromJson({
              'type': 'permission_request',
              'toolUseId': 'approval-0',
              'toolName': 'ToolSuggestion',
              'input': {
                'toolName': 'GitHub',
                'toolType': 'plugin',
                'suggestReason': 'Inspect forks on GitHub.',
                'installState': 'needs_auth',
                'appsNeedingAuth': [
                  {
                    'id': 'github-app',
                    'name': 'GitHub',
                    'installUrl': 'https://example.com/connect',
                  },
                ],
              },
            })
            as PermissionRequestMessage;

    expect(message.isToolSuggestion, isTrue);
    expect(message.usesAskUserUi, isFalse);
    expect(message.suggestedToolName, 'GitHub');
    expect(message.toolSuggestionInstallState, 'needs_auth');
    expect(message.appsNeedingAuthentication.single.name, 'GitHub');
    expect(
      message.appsNeedingAuthentication.single.installUrl,
      'https://example.com/connect',
    );
  });

  test('parses Codex goal state and serializes goal actions', () {
    final message =
        ServerMessage.fromJson({
              'type': 'goal_state',
              'sessionId': 's1',
              'goal': {
                'threadId': 'thread-1',
                'objective': 'Ship Goal support',
                'status': 'usageLimited',
                'tokenBudget': 80000,
                'tokensUsed': 12400,
                'timeUsedSeconds': 1080,
                'createdAt': 1,
                'updatedAt': 2,
              },
            })
            as GoalStateMessage;

    expect(message.sessionId, 's1');
    expect(message.goal?.objective, 'Ship Goal support');
    expect(message.goal?.status, CodexThreadGoalStatus.usageLimited);
    expect(message.goal?.tokenBudget, 80000);
    expect(
      jsonDecode(
        ClientMessage.setGoal(
          sessionId: 's1',
          status: CodexThreadGoalStatus.paused,
        ).toJson(),
      ),
      {'type': 'set_goal', 'sessionId': 's1', 'status': 'paused'},
    );
    expect(jsonDecode(ClientMessage.clearGoal('s1').toJson()), {
      'type': 'clear_goal',
      'sessionId': 's1',
    });
  });

  test('parses structured Guardian approval notices', () {
    final message =
        ServerMessage.fromJson({
              'type': 'guardian_approval',
              'risk': 'high',
              'reason': 'The command changes files outside the workspace.',
              'authorization': 'high',
            })
            as GuardianApprovalMessage;

    expect(message.risk, GuardianApprovalRisk.high);
    expect(message.reason, 'The command changes files outside the workspace.');
    expect(message.authorization, 'high');
  });

  test('ReasoningEffort preserves model-advertised future values', () {
    final effort = reasoningEffortByValue('future-tier');

    expect(effort?.value, 'future-tier');
    expect(effort?.label, 'Future Tier');
    expect(reasoningEffortByValue('  '), isNull);
  });

  group('pathBasename', () {
    test('handles POSIX and Windows path separators', () {
      expect(pathBasename('/Users/me/project-a'), 'project-a');
      expect(pathBasename(r'C:\Users\me\project-b'), 'project-b');
      expect(pathBasename(r'C:\Users\me\project-b\'), 'project-b');
      expect(pathBasename('project-c'), 'project-c');
      expect(pathBasename(''), '');
    });
  });

  group('Codex permissions mode', () {
    test('derives only complete known presets', () {
      expect(
        codexPermissionsModeFromSettings(
          approvalPolicy: 'on-request',
          sandboxMode: 'workspace-write',
        ),
        CodexPermissionsMode.defaultPermissions,
      );
      expect(
        codexPermissionsModeFromSettings(
          approvalPolicy: 'on-request',
          approvalsReviewer: 'auto_review',
          sandboxMode: 'workspace-write',
        ),
        CodexPermissionsMode.autoReview,
      );
      expect(
        codexPermissionsModeFromSettings(
          approvalPolicy: 'never',
          sandboxMode: 'danger-full-access',
        ),
        CodexPermissionsMode.fullAccess,
      );
    });

    test('classifies read-only, mismatched, and unknown tuples as custom', () {
      expect(
        codexPermissionsModeFromSettings(
          approvalPolicy: 'on-request',
          sandboxMode: 'read-only',
        ),
        CodexPermissionsMode.custom,
      );
      expect(
        codexPermissionsModeFromSettings(
          approvalPolicy: 'never',
          sandboxMode: 'workspace-write',
        ),
        CodexPermissionsMode.custom,
      );
      expect(
        codexPermissionsModeFromSettings(
          codexPermissionsMode: 'future-mode',
          approvalPolicy: 'never',
          sandboxMode: 'danger-full-access',
        ),
        CodexPermissionsMode.custom,
      );
    });

    test(
      'session parsers derive complete settings but not partial metadata',
      () {
        final complete = SessionInfo.fromJson({
          'id': 'complete',
          'provider': 'codex',
          'projectPath': '/tmp/project',
          'status': 'idle',
          'createdAt': '',
          'lastActivityAt': '',
          'codexSettings': {
            'approvalPolicy': 'on-request',
            'sandboxMode': 'read-only',
          },
        });
        final partial = SessionInfo.fromJson({
          'id': 'partial',
          'provider': 'codex',
          'projectPath': '/tmp/project',
          'status': 'idle',
          'createdAt': '',
          'lastActivityAt': '',
          'codexSettings': {'approvalPolicy': 'on-request'},
        });

        expect(complete.codexPermissionsMode, 'custom');
        expect(partial.codexPermissionsMode, isNull);
      },
    );

    test('RecentSession follows the same complete and partial rules', () {
      Map<String, dynamic> recentJson(
        String id,
        Map<String, dynamic> codexSettings,
      ) => {
        'sessionId': id,
        'provider': 'codex',
        'firstPrompt': 'resume',
        'created': '2026-02-13T00:00:00Z',
        'modified': '2026-02-13T00:00:00Z',
        'gitBranch': 'main',
        'projectPath': '/tmp/project',
        'isSidechain': false,
        'codexSettings': codexSettings,
      };

      final complete = RecentSession.fromJson(
        recentJson('complete', {
          'approvalPolicy': 'on-request',
          'approvalsReviewer': 'auto_review',
          'sandboxMode': 'workspace-write',
        }),
      );
      final partial = RecentSession.fromJson(
        recentJson('partial', {'approvalsReviewer': 'auto_review'}),
      );

      expect(complete.codexPermissionsMode, 'autoReview');
      expect(partial.codexPermissionsMode, isNull);
    });
  });

  group('SystemMessage', () {
    test('parses Codex CLI join target', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'provider': 'codex',
        'sessionId': 'thr_123',
        'codexCliJoin': {
          'url': 'ws://127.0.0.1:8767',
          'command': 'codex resume thr_123 --remote ws://127.0.0.1:8767',
        },
      });

      expect(msg, isA<SystemMessage>());
      final system = msg as SystemMessage;
      expect(system.codexCliJoin?.url, 'ws://127.0.0.1:8767');
      expect(
        system.codexCliJoin?.command,
        'codex resume thr_123 --remote ws://127.0.0.1:8767',
      );
      expect(system.codexCliJoin?.isValid, isTrue);
    });
  });

  group('FileContentMessage', () {
    test('parses legacy text file content as text kind', () {
      final msg = ServerMessage.fromJson({
        'type': 'file_content',
        'filePath': 'README.md',
        'content': '# Hello',
        'language': 'markdown',
        'totalLines': 1,
      });

      expect(msg, isA<FileContentMessage>());
      final file = msg as FileContentMessage;
      expect(file.kind, 'text');
      expect(file.content, '# Hello');
      expect(file.language, 'markdown');
      expect(file.totalLines, 1);
      expect(file.base64, isNull);
    });

    test('parses image file content metadata', () {
      final msg = ServerMessage.fromJson({
        'type': 'file_content',
        'filePath': 'docs/image.png',
        'kind': 'image',
        'content': '',
        'base64': 'aGVsbG8=',
        'mimeType': 'image/png',
        'sizeBytes': 5,
      });

      expect(msg, isA<FileContentMessage>());
      final file = msg as FileContentMessage;
      expect(file.kind, 'image');
      expect(file.content, '');
      expect(file.base64, 'aGVsbG8=');
      expect(file.mimeType, 'image/png');
      expect(file.sizeBytes, 5);
    });
  });

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
    test('ClientMessage.clientCapabilities advertises supported messages', () {
      final msg = ClientMessage.clientCapabilities(appVersion: '1.72.1');

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'client_capabilities');
      expect(json['appVersion'], '1.72.1');
      expect(json['protocolVersion'], 1);
      expect(json['supportedServerMessages'], [
        'conversation_queue',
        'goal_state',
        'guardian_approval',
        'history_delta',
        'history_snapshot',
        'git_status_result',
        'prompt_history_status',
      ]);
    });

    test('ClientMessage.getHistoryDelta serializes sinceSeq', () {
      final msg = ClientMessage.getHistoryDelta('s1', sinceSeq: 42);

      expect(jsonDecode(msg.toJson()), {
        'type': 'get_history_delta',
        'sessionId': 's1',
        'sinceSeq': 42,
      });
    });

    test('ClientMessage.input serializes strict ack metadata', () {
      final msg = ClientMessage.input(
        'hello',
        sessionId: 's1',
        clientMessageId: 'cm-1',
        baseSeq: 7,
      );

      expect(jsonDecode(msg.toJson()), {
        'type': 'input',
        'text': 'hello',
        'sessionId': 's1',
        'clientMessageId': 'cm-1',
        'baseSeq': 7,
      });
    });

    test('ClientMessage.setCodexModel serializes model settings', () {
      final msg = ClientMessage.setCodexModel(
        'gpt-5.4-mini',
        modelReasoningEffort: 'low',
        sessionId: 's1',
      );

      expect(jsonDecode(msg.toJson()), {
        'type': 'set_codex_model',
        'model': 'gpt-5.4-mini',
        'modelReasoningEffort': 'low',
        'sessionId': 's1',
      });
    });

    test('ServerMessage parses history_delta', () {
      final msg = ServerMessage.fromJson({
        'type': 'history_delta',
        'sessionId': 's1',
        'fromSeq': 4,
        'toSeq': 5,
        'status': 'running',
        'messages': [
          {
            'seq': 5,
            'message': {'type': 'status', 'status': 'running'},
          },
        ],
      });

      expect(msg, isA<HistoryDeltaMessage>());
      final delta = msg as HistoryDeltaMessage;
      expect(delta.sessionId, 's1');
      expect(delta.fromSeq, 4);
      expect(delta.toSeq, 5);
      expect(delta.status, ProcessStatus.running);
      expect(delta.entries.single.seq, 5);
      expect(delta.entries.single.message, isA<StatusMessage>());
    });

    test('ServerMessage parses history_snapshot', () {
      final msg = ServerMessage.fromJson({
        'type': 'history_snapshot',
        'sessionId': 's1',
        'fromSeq': 10,
        'toSeq': 12,
        'reason': 'compacted',
        'messages': [
          {
            'seq': 12,
            'message': {'type': 'status', 'status': 'idle'},
          },
        ],
      });

      expect(msg, isA<HistorySnapshotMessage>());
      final snapshot = msg as HistorySnapshotMessage;
      expect(snapshot.fromSeq, 10);
      expect(snapshot.toSeq, 12);
      expect(snapshot.reason, 'compacted');
      expect(snapshot.entries.single.message, isA<StatusMessage>());
    });

    test('ClientMessage.start serializes codex thread options', () {
      final msg = ClientMessage.start(
        '/tmp/project',
        provider: 'codex',
        profile: 'ccpocket',
        modelReasoningEffort: 'high',
        networkAccessEnabled: true,
        webSearchMode: 'live',
        additionalWritableRoots: const ['/tmp/shared'],
        autoRename: true,
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['profile'], 'ccpocket');
      expect(json['modelReasoningEffort'], 'high');
      expect(json['networkAccessEnabled'], true);
      expect(json['webSearchMode'], 'live');
      expect(json['additionalWritableRoots'], ['/tmp/shared']);
      expect(json['autoRename'], true);
    });

    test('ClientMessage.resumeSession serializes codex add-dir roots', () {
      final msg = ClientMessage.resumeSession(
        'session-1',
        '/tmp/project',
        provider: 'codex',
        additionalWritableRoots: const ['/tmp/shared', '/tmp/tools'],
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'resume_session');
      expect(json['sessionId'], 'session-1');
      expect(json['additionalWritableRoots'], ['/tmp/shared', '/tmp/tools']);
    });

    test('ClientMessage.steerQueuedInput serializes codex queued item', () {
      final msg = ClientMessage.steerQueuedInput(
        sessionId: 'session-1',
        itemId: 'queued-1',
      );

      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'steer_queued_input');
      expect(json['sessionId'], 'session-1');
      expect(json['itemId'], 'queued-1');
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
          'profile': 'ccpocket',
          'modelReasoningEffort': 'medium',
          'serviceTier': 'fast',
          'networkAccessEnabled': false,
          'webSearchMode': 'cached',
          'additionalWritableRoots': ['/tmp/shared'],
        },
      });

      expect(session.codexProfile, 'ccpocket');
      expect(session.codexModelReasoningEffort, 'medium');
      expect(session.codexServiceTier, 'fast');
      expect(session.codexNetworkAccessEnabled, false);
      expect(session.codexWebSearchMode, 'cached');
      expect(session.codexAdditionalWritableRoots, ['/tmp/shared']);
    });

    test('SessionListMessage parses model metadata', () {
      final msg = ServerMessage.fromJson({
        'type': 'session_list',
        'sessions': const [],
        'allowedDirs': const [],
        'claudeModels': ['claude-opus-4-7', 'claude-haiku-4-6'],
        'claudeModelEfforts': {
          'claude-opus-4-7': ['low', 'medium', 'high', 'xhigh', 'max'],
          'claude-haiku-4-6': [],
        },
        'codexModels': ['gpt-5.5'],
        'codexModelReasoningEfforts': {
          'gpt-5.5': ['low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
        },
        'codexModelServiceTiers': {
          'gpt-5.5': ['fast'],
        },
        'codexProfiles': ['ccpocket', 'research'],
        'defaultCodexProfile': 'ccpocket',
      });

      expect(msg, isA<SessionListMessage>());
      final sessionList = msg as SessionListMessage;
      expect(sessionList.claudeModels, ['claude-opus-4-7', 'claude-haiku-4-6']);
      expect(sessionList.claudeModelEfforts['claude-opus-4-7'], [
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      ]);
      expect(sessionList.claudeModelEfforts['claude-haiku-4-6'], isEmpty);
      expect(sessionList.codexModels, ['gpt-5.5']);
      expect(sessionList.codexModelReasoningEfforts['gpt-5.5'], [
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
        'ultra',
      ]);
      expect(sessionList.codexModelServiceTiers['gpt-5.5'], ['fast']);
      expect(sessionList.codexProfiles, ['ccpocket', 'research']);
      expect(sessionList.defaultCodexProfile, 'ccpocket');
    });

    test('RecentSessionsMessage parses request metadata', () {
      final msg = ServerMessage.fromJson({
        'type': 'recent_sessions',
        'sessions': const [],
        'hasMore': true,
        'limit': 20,
        'offset': 40,
        'projectPath': '/tmp/project',
        'requestScope': 'project',
      });

      expect(msg, isA<RecentSessionsMessage>());
      final recentSessions = msg as RecentSessionsMessage;
      expect(recentSessions.hasMore, isTrue);
      expect(recentSessions.limit, 20);
      expect(recentSessions.offset, 40);
      expect(recentSessions.projectPath, '/tmp/project');
      expect(recentSessions.requestScope, 'project');
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

    test('RecentSession preserves raw Claude auto permission mode', () {
      final session = RecentSession.fromJson({
        'sessionId': 's-auto',
        'provider': 'claude',
        'firstPrompt': 'resume',
        'created': '2026-02-13T00:00:00Z',
        'modified': '2026-02-13T00:00:00Z',
        'gitBranch': 'main',
        'projectPath': '/tmp/project',
        'permissionMode': 'auto',
        'executionMode': 'default',
        'isSidechain': false,
      });

      expect(session.rawPermissionMode, 'auto');
      expect(session.effectivePermissionMode, 'auto');
      expect(session.resolvedExecutionMode, ExecutionMode.defaultMode);
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

    test('normalizes deprecated codex model to first available model', () {
      expect(
        normalizeCodexModelForAvailableList('gpt-5.2-codex', [
          'gpt-5.3-codex',
          'gpt-5.4-mini',
        ]),
        'gpt-5.3-codex',
      );
    });

    test('uses default codex list when available list is empty', () {
      expect(
        normalizeCodexModelForAvailableList('gpt-5.2-codex', const []),
        defaultCodexModels.first,
      );
    });

    test('skips deprecated entries when selecting replacement model', () {
      expect(
        normalizeCodexModelForAvailableList('gpt-5.2-codex', [
          'gpt-5.2-codex',
          'gpt-5.4-mini',
        ]),
        'gpt-5.4-mini',
      );
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
      expect(ack.clientMessageId, isNull);
      expect(ack.acceptedSeq, isNull);
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

    test('parses strict ack metadata', () {
      final msg = ServerMessage.fromJson({
        'type': 'input_ack',
        'sessionId': 's1',
        'clientMessageId': 'cm-1',
        'acceptedSeq': 12,
      });

      expect(msg, isA<InputAckMessage>());
      final ack = msg as InputAckMessage;
      expect(ack.clientMessageId, 'cm-1');
      expect(ack.acceptedSeq, 12);
    });
  });

  group('ConversationQueue message parsing', () {
    test('parses queued items', () {
      final msg = ServerMessage.fromJson({
        'type': 'conversation_queue',
        'sessionId': 's1',
        'limit': 1,
        'items': [
          {
            'itemId': 'q1',
            'text': 'Follow up',
            'createdAt': '2026-04-25T00:00:00.000Z',
            'imageCount': 1,
            'skills': [
              {'name': 'skill-a', 'path': '/tmp/skill-a'},
            ],
          },
        ],
      });

      expect(msg, isA<ConversationQueueMessage>());
      final queue = msg as ConversationQueueMessage;
      expect(queue.sessionId, 's1');
      expect(queue.limit, 1);
      expect(queue.items.single.itemId, 'q1');
      expect(queue.items.single.text, 'Follow up');
      expect(queue.items.single.imageCount, 1);
      expect(queue.items.single.skills.single['name'], 'skill-a');
    });

    test('parses queued input on session info', () {
      final session = SessionInfo.fromJson({
        'id': 's1',
        'provider': 'codex',
        'projectPath': '/tmp/project',
        'status': 'running',
        'createdAt': '',
        'lastActivityAt': '',
        'queuedInput': {
          'itemId': 'q1',
          'text': 'Queued',
          'createdAt': '2026-04-25T00:00:00.000Z',
        },
      });

      expect(session.queuedInput?.itemId, 'q1');
      expect(session.queuedInput?.text, 'Queued');
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
      });
      final r = msg as GitPushResultMessage;
      expect(r.success, isTrue);
      expect(r.error, isNull);
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

    test('gitCommit with sessionId', () {
      final msg = ClientMessage.gitCommit(
        '/p',
        sessionId: 's-1',
        autoGenerate: true,
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['sessionId'], 's-1');
      expect(json['autoGenerate'], isTrue);
    });

    test('gitPush', () {
      final msg = ClientMessage.gitPush('/p');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_push');
      expect(json['projectPath'], '/p');
    });

    test('gitBranches', () {
      final msg = ClientMessage.gitBranches('/p');
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_branches');
      expect(json['projectPath'], '/p');
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

    test('gitStatus with sessionId', () {
      final msg = ClientMessage.gitStatus(
        '/p',
        sessionId: 's1',
        includeRemote: true,
      );
      final json = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(json['type'], 'git_status');
      expect(json['projectPath'], '/p');
      expect(json['sessionId'], 's1');
      expect(json['includeRemote'], isTrue);
    });

    test('parses gitStatusResult', () {
      final msg = ServerMessage.fromJson({
        'type': 'git_status_result',
        'sessionId': 's1',
        'projectPath': '/p',
        'hasUncommittedChanges': true,
        'stagedCount': 1,
        'unstagedCount': 2,
        'untrackedCount': 3,
        'remoteStatusIncluded': true,
        'hasRemoteChanges': true,
        'commitsAhead': 4,
        'commitsBehind': 5,
        'hasUpstream': true,
        'branch': 'main',
      });

      expect(msg, isA<GitStatusResultMessage>());
      final status = msg as GitStatusResultMessage;
      expect(status.sessionId, 's1');
      expect(status.projectPath, '/p');
      expect(status.hasUncommittedChanges, isTrue);
      expect(status.stagedCount, 1);
      expect(status.unstagedCount, 2);
      expect(status.untrackedCount, 3);
      expect(status.remoteStatusIncluded, isTrue);
      expect(status.hasRemoteChanges, isTrue);
      expect(status.commitsAhead, 4);
      expect(status.commitsBehind, 5);
      expect(status.hasUpstream, isTrue);
      expect(status.branch, 'main');
    });
  });
}

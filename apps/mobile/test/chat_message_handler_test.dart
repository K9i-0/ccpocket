import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';

void main() {
  late ChatMessageHandler handler;

  setUp(() {
    handler = ChatMessageHandler();
  });

  group('ProcessStatus.fromString', () {
    test('parses starting', () {
      expect(ProcessStatus.fromString('starting'), ProcessStatus.starting);
    });

    test('parses idle', () {
      expect(ProcessStatus.fromString('idle'), ProcessStatus.idle);
    });

    test('parses running', () {
      expect(ProcessStatus.fromString('running'), ProcessStatus.running);
    });

    test('parses waiting_approval', () {
      expect(
        ProcessStatus.fromString('waiting_approval'),
        ProcessStatus.waitingApproval,
      );
    });

    test('unknown value defaults to idle', () {
      expect(ProcessStatus.fromString('unknown'), ProcessStatus.idle);
    });
  });

  group('StatusMessage handling', () {
    test('waitingApproval triggers heavy haptic', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.waitingApproval),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.waitingApproval);
      expect(update.sideEffects, contains(ChatSideEffect.heavyHaptic));
      expect(update.resetPending, isFalse);
    });

    test('waitingApproval in background sends notification', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.waitingApproval),
        isBackground: true,
      );
      expect(
        update.sideEffects,
        contains(ChatSideEffect.notifyApprovalRequired),
      );
    });

    test('idle status resets pending state', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.idle),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.idle);
      expect(update.resetPending, isTrue);
    });

    test('starting status resets pending state', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.starting),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.starting);
      expect(update.resetPending, isTrue);
      expect(update.sideEffects, isEmpty);
    });

    test('running status does NOT reset pending state', () {
      // Running is a transient state — pending permission should survive so
      // the approval bar stays visible when PermissionRequestMessage arrives
      // before StatusMessage(waitingApproval).
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.running),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.running);
      expect(update.resetPending, isFalse);
    });
  });

  group('ThinkingDelta handling', () {
    test('accumulates thinking text', () {
      handler.handle(
        const ThinkingDeltaMessage(text: 'Hello '),
        isBackground: false,
      );
      handler.handle(
        const ThinkingDeltaMessage(text: 'world'),
        isBackground: false,
      );
      expect(handler.currentThinkingText, 'Hello world');
    });
  });

  group('StreamDelta handling', () {
    test('first delta creates streaming entry', () {
      final update = handler.handle(
        const StreamDeltaMessage(text: 'Hi'),
        isBackground: false,
      );
      expect(update.entriesToAdd, hasLength(1));
      expect(handler.currentStreaming, isNotNull);
      expect(handler.currentStreaming!.text, 'Hi');
    });

    test('subsequent deltas append to existing streaming', () {
      handler.handle(const StreamDeltaMessage(text: 'Hi'), isBackground: false);
      final update = handler.handle(
        const StreamDeltaMessage(text: ' there'),
        isBackground: false,
      );
      expect(update.entriesToAdd, isEmpty);
      expect(handler.currentStreaming!.text, 'Hi there');
    });
  });

  group('AssistantMessage handling', () {
    test('triggers collapse tool results', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [const TextContent(text: 'Hello')],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.sideEffects, contains(ChatSideEffect.collapseToolResults));
      expect(update.markUserMessagesSent, isTrue);
    });

    test('injects accumulated thinking text', () {
      handler.handle(
        const ThinkingDeltaMessage(text: 'Thinking...'),
        isBackground: false,
      );
      handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [const TextContent(text: 'Response')],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      // Thinking text should be cleared after injection
      expect(handler.currentThinkingText, isEmpty);
    });

    test('detects AskUserQuestion tool use', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [
              const ToolUseContent(
                id: 'tu-ask',
                name: 'AskUserQuestion',
                input: {'questions': []},
              ),
            ],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.askToolUseId, 'tu-ask');
      expect(update.sideEffects, contains(ChatSideEffect.mediumHaptic));
    });

    test('detects EnterPlanMode', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [
              const ToolUseContent(
                id: 'tu-plan',
                name: 'EnterPlanMode',
                input: {},
              ),
            ],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.inPlanMode, isTrue);
      expect(update.pendingToolUseId, 'tu-plan');
    });
  });

  group('PastHistory handling', () {
    test('converts past messages to entries', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              content: [TextContent(text: 'Hello')],
            ),
            PastMessage(
              role: 'assistant',
              content: [TextContent(text: 'Hi')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, hasLength(2));
      expect(update.entriesToPrepend[0], isA<UserChatEntry>());
      expect(update.entriesToPrepend[1], isA<ServerChatEntry>());
    });

    test('past user messages have sent status (not sending)', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              content: [TextContent(text: 'Hello')],
            ),
          ],
        ),
        isBackground: false,
      );
      final userEntry = update.entriesToPrepend[0] as UserChatEntry;
      expect(userEntry.status, MessageStatus.sent);
    });
  });

  group('ResultMessage handling', () {
    test('stopped resets all state', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'stopped'),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.idle);
      expect(update.resetPending, isTrue);
      expect(update.resetAsk, isTrue);
      expect(update.resetStreaming, isTrue);
      expect(update.inPlanMode, isFalse);
      expect(update.sideEffects, contains(ChatSideEffect.clearPlanFeedback));
    });

    test('success adds cost delta', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'success', cost: 0.05),
        isBackground: false,
      );
      expect(update.costDelta, 0.05);
      expect(update.sideEffects, contains(ChatSideEffect.lightHaptic));
    });

    test('success in background sends notification', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'success', cost: 0.05),
        isBackground: true,
      );
      expect(
        update.sideEffects,
        contains(ChatSideEffect.notifySessionComplete),
      );
    });
  });

  group('History handling — pending state restoration', () {
    test('restores pending permission when status is waitingApproval', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            SystemMessage(subtype: 'session_created'),
            PermissionRequestMessage(
              toolUseId: 'tu-perm',
              toolName: 'Bash',
              input: {'command': 'rm -rf /'},
            ),
            StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.waitingApproval);
      expect(update.pendingToolUseId, 'tu-perm');
      expect(update.pendingPermission, isNotNull);
      expect(update.pendingPermission!.toolName, 'Bash');
    });

    test('does NOT restore permission when status is not waitingApproval', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            PermissionRequestMessage(
              toolUseId: 'tu-perm',
              toolName: 'Bash',
              input: {'command': 'ls'},
            ),
            StatusMessage(status: ProcessStatus.running),
          ],
        ),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.running);
      expect(update.pendingToolUseId, isNull);
      expect(update.pendingPermission, isNull);
    });

    test('clears pending permission after matching tool_result in history', () {
      final update = handler.handle(
        HistoryMessage(
          messages: [
            const PermissionRequestMessage(
              toolUseId: 'tu-perm',
              toolName: 'Bash',
              input: {'command': 'ls'},
            ),
            // tool_result with same toolUseId clears the permission
            const ToolResultMessage(toolUseId: 'tu-perm', content: 'ok'),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      // Permission was resolved by its tool_result, so don't restore it
      expect(update.pendingToolUseId, isNull);
      expect(update.pendingPermission, isNull);
    });

    test('does not clear permission when tool_result has different id', () {
      final update = handler.handle(
        HistoryMessage(
          messages: [
            const PermissionRequestMessage(
              toolUseId: 'tu-perm',
              toolName: 'Bash',
              input: {'command': 'ls'},
            ),
            // tool_result with different toolUseId does NOT clear the permission
            const ToolResultMessage(toolUseId: 'tu-other', content: 'ok'),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      // Permission is still pending because the tool_result was for a different tool
      expect(update.pendingToolUseId, 'tu-perm');
      expect(update.pendingPermission!.toolName, 'Bash');
    });

    test('restores AskUserQuestion state from history', () {
      final update = handler.handle(
        HistoryMessage(
          messages: [
            AssistantServerMessage(
              message: AssistantMessage(
                id: 'msg-1',
                role: 'assistant',
                content: [
                  const ToolUseContent(
                    id: 'tu-ask',
                    name: 'AskUserQuestion',
                    input: {
                      'questions': [
                        {'question': 'Which option?'},
                      ],
                    },
                  ),
                ],
                model: 'test',
              ),
            ),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      expect(update.askToolUseId, 'tu-ask');
      expect(update.askInput, isNotNull);
    });

    test('clears AskUserQuestion state after result in history', () {
      final update = handler.handle(
        HistoryMessage(
          messages: [
            AssistantServerMessage(
              message: AssistantMessage(
                id: 'msg-1',
                role: 'assistant',
                content: [
                  const ToolUseContent(
                    id: 'tu-ask',
                    name: 'AskUserQuestion',
                    input: {'questions': []},
                  ),
                ],
                model: 'test',
              ),
            ),
            const ResultMessage(subtype: 'success'),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      expect(update.askToolUseId, isNull);
      expect(update.askInput, isNull);
    });

    test('restores first pending permission when multiple are unresolved', () {
      // Both tu-old and tu-new are pending (tu-res doesn't match either)
      // The handler should return the first pending permission (FIFO)
      final update = handler.handle(
        HistoryMessage(
          messages: [
            const PermissionRequestMessage(
              toolUseId: 'tu-old',
              toolName: 'Read',
              input: {'file_path': '/foo'},
            ),
            const ToolResultMessage(toolUseId: 'tu-res', content: 'ok'),
            const PermissionRequestMessage(
              toolUseId: 'tu-new',
              toolName: 'Write',
              input: {'file_path': '/bar'},
            ),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      // First pending permission should be returned
      expect(update.pendingToolUseId, 'tu-old');
      expect(update.pendingPermission!.toolName, 'Read');
    });

    test('restores latest permission when earlier ones are resolved', () {
      // tu-old is resolved by its tool_result, only tu-new remains pending
      final update = handler.handle(
        HistoryMessage(
          messages: [
            const PermissionRequestMessage(
              toolUseId: 'tu-old',
              toolName: 'Read',
              input: {'file_path': '/foo'},
            ),
            const ToolResultMessage(toolUseId: 'tu-old', content: 'ok'),
            const PermissionRequestMessage(
              toolUseId: 'tu-new',
              toolName: 'Write',
              input: {'file_path': '/bar'},
            ),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      expect(update.pendingToolUseId, 'tu-new');
      expect(update.pendingPermission!.toolName, 'Write');
    });

    test('restores slash commands from supported_commands in history', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            SystemMessage(
              subtype: 'supported_commands',
              slashCommands: ['compact', 'review', 'plan'],
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands!.length, 3);
    });

    test('restores slash commands alongside pending state', () {
      final update = handler.handle(
        HistoryMessage(
          messages: [
            const SystemMessage(
              subtype: 'init',
              slashCommands: ['test-flutter', 'test-bridge'],
              skills: ['test-flutter'],
            ),
            const PermissionRequestMessage(
              toolUseId: 'tu-perm',
              toolName: 'Bash',
              input: {'command': 'echo hi'},
            ),
            const StatusMessage(status: ProcessStatus.waitingApproval),
          ],
        ),
        isBackground: false,
      );
      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands!.length, 2);
      expect(update.pendingToolUseId, 'tu-perm');
    });

    test('history sets replaceEntries to true to prevent duplicates', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [StatusMessage(status: ProcessStatus.idle)],
        ),
        isBackground: false,
      );
      expect(update.replaceEntries, isTrue);
    });
  });

  group('SystemMessage slash command handling', () {
    test('init with slashCommands populates commands and adds entry', () {
      final update = handler.handle(
        const SystemMessage(
          subtype: 'init',
          slashCommands: ['compact', 'review', 'test-flutter'],
          skills: ['test-flutter'],
        ),
        isBackground: false,
      );
      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands!.length, 3);
      expect(update.entriesToAdd, hasLength(1));
    });

    test('session_created with cached slashCommands populates commands', () {
      final update = handler.handle(
        const SystemMessage(
          subtype: 'session_created',
          slashCommands: ['compact', 'review', 'test-flutter'],
          skills: ['test-flutter'],
        ),
        isBackground: false,
      );
      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands!.length, 3);
      // session_created should NOT add a visible chat entry
      expect(update.entriesToAdd, isEmpty);
    });

    test('session_created without slashCommands does not set commands', () {
      final update = handler.handle(
        const SystemMessage(subtype: 'session_created'),
        isBackground: false,
      );
      expect(update.slashCommands, isNull);
      expect(update.entriesToAdd, isEmpty);
    });

    test('supported_commands populates commands without chat entry', () {
      final update = handler.handle(
        const SystemMessage(
          subtype: 'supported_commands',
          slashCommands: ['compact', 'review', 'plan'],
        ),
        isBackground: false,
      );
      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands!.length, 3);
      // supported_commands should NOT add a visible chat entry
      expect(update.entriesToAdd, isEmpty);
    });

    test('supported_commands with empty list does not set commands', () {
      final update = handler.handle(
        const SystemMessage(subtype: 'supported_commands'),
        isBackground: false,
      );
      expect(update.slashCommands, isNull);
      expect(update.entriesToAdd, isEmpty);
    });
  });

  group('ToolUseSummaryMessage handling', () {
    test('adds summary entry and marks tool uses to hide', () {
      final update = handler.handle(
        const ToolUseSummaryMessage(
          summary: 'Read package.json and analyzed dependencies',
          precedingToolUseIds: ['tu-1', 'tu-2'],
        ),
        isBackground: false,
      );

      expect(update.entriesToAdd, hasLength(1));
      expect(update.entriesToAdd[0], isA<ServerChatEntry>());
      expect(update.toolUseIdsToHide, {'tu-1', 'tu-2'});
    });

    test('handles empty precedingToolUseIds', () {
      final update = handler.handle(
        const ToolUseSummaryMessage(
          summary: 'Quick analysis completed',
          precedingToolUseIds: [],
        ),
        isBackground: false,
      );

      expect(update.entriesToAdd, hasLength(1));
      expect(update.toolUseIdsToHide, isEmpty);
    });
  });

  group('PermissionRequestMessage for AskUserQuestion', () {
    test('permission_request with toolName AskUserQuestion sets askToolUseId '
        'instead of pendingPermission', () {
      final update = handler.handle(
        const PermissionRequestMessage(
          toolUseId: 'tu-ask',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {'question': 'Which option?'},
            ],
          },
        ),
        isBackground: false,
      );
      // Should be treated as AskUserQuestion, NOT a regular permission
      expect(update.askToolUseId, 'tu-ask');
      expect(update.askInput, isNotNull);
      expect(update.pendingPermission, isNull);
      expect(update.pendingToolUseId, isNull);
    });

    test('assistant AskUserQuestion followed by permission_request '
        'does not overwrite askToolUseId with pendingPermission', () {
      // Step 1: assistant message with AskUserQuestion tool_use
      final update1 = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [
              const ToolUseContent(
                id: 'tu-ask',
                name: 'AskUserQuestion',
                input: {
                  'questions': [
                    {'question': 'Which option?'},
                  ],
                },
              ),
            ],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update1.askToolUseId, 'tu-ask');

      // Step 2: permission_request for the same AskUserQuestion
      final update2 = handler.handle(
        const PermissionRequestMessage(
          toolUseId: 'tu-ask',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {'question': 'Which option?'},
            ],
          },
        ),
        isBackground: false,
      );

      // The permission_request should also be treated as askUser,
      // not as a regular permission that overwrites the ask state.
      expect(update2.askToolUseId, 'tu-ask');
      expect(update2.pendingPermission, isNull);
      expect(update2.pendingToolUseId, isNull);
    });
  });

  group('PermissionRequestMessage.summary', () {
    test('extracts command from input', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'Bash',
        input: {'command': 'ls -la'},
      );
      expect(perm.summary, 'ls -la');
    });

    test('truncates long values', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'Read',
        input: {
          'file_path':
              '/very/long/path/that/exceeds/sixty/characters/definitely/yes/indeed/it/does/wow.dart',
        },
      );
      expect(perm.summary.length, lessThanOrEqualTo(63)); // 60 + "..."
    });

    test('falls back to toolName when no recognized keys', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'CustomTool',
        input: {'foo': 'bar'},
      );
      expect(perm.summary, 'CustomTool');
    });
  });

  group('PastHistory restoration — text, image, and text+image', () {
    test('restores text-only user message', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              uuid: 'uuid-1',
              content: [TextContent(text: 'Hello world')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, hasLength(1));
      final entry = update.entriesToPrepend[0] as UserChatEntry;
      expect(entry.text, 'Hello world');
      expect(entry.imageCount, 0);
      expect(entry.messageUuid, 'uuid-1');
      expect(entry.status, MessageStatus.sent);
    });

    test('restores image-only user message', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              uuid: 'uuid-2',
              imageCount: 1,
              content: [TextContent(text: '[Image attached]')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, hasLength(1));
      final entry = update.entriesToPrepend[0] as UserChatEntry;
      expect(entry.imageCount, 1);
      expect(entry.messageUuid, 'uuid-2');
      expect(entry.status, MessageStatus.sent);
    });

    test('restores text+image user message', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              uuid: 'uuid-3',
              imageCount: 2,
              content: [TextContent(text: 'Check this screenshot')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, hasLength(1));
      final entry = update.entriesToPrepend[0] as UserChatEntry;
      expect(entry.text, 'Check this screenshot');
      expect(entry.imageCount, 2);
      expect(entry.messageUuid, 'uuid-3');
      expect(entry.status, MessageStatus.sent);
    });

    test('skips meta user messages during restoration', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              isMeta: true,
              content: [TextContent(text: 'skill loading prompt')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, isEmpty);
    });
  });

  group('History restoration — text, image, and text+image', () {
    test('restores text-only user message from in-memory history', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            UserInputMessage(
              text: 'Hello world',
              userMessageUuid: 'uuid-1',
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      final userEntries = update.entriesToAdd
          .whereType<UserChatEntry>()
          .toList();
      expect(userEntries, hasLength(1));
      expect(userEntries[0].text, 'Hello world');
      expect(userEntries[0].imageCount, 0);
      expect(userEntries[0].messageUuid, 'uuid-1');
      expect(userEntries[0].status, MessageStatus.sent);
    });

    test('restores image-only user message from in-memory history', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            UserInputMessage(
              text: '[Image attached]',
              imageCount: 1,
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      final userEntries = update.entriesToAdd
          .whereType<UserChatEntry>()
          .toList();
      expect(userEntries, hasLength(1));
      expect(userEntries[0].imageCount, 1);
      expect(userEntries[0].status, MessageStatus.sent);
    });

    test('restores text+image user message from in-memory history', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            UserInputMessage(
              text: 'Check this screenshot',
              userMessageUuid: 'uuid-3',
              imageCount: 2,
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      final userEntries = update.entriesToAdd
          .whereType<UserChatEntry>()
          .toList();
      expect(userEntries, hasLength(1));
      expect(userEntries[0].text, 'Check this screenshot');
      expect(userEntries[0].imageCount, 2);
      expect(userEntries[0].messageUuid, 'uuid-3');
      expect(userEntries[0].status, MessageStatus.sent);
    });

    test('skips synthetic user messages during restoration', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            UserInputMessage(text: 'synthetic prompt', isSynthetic: true),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      final userEntries = update.entriesToAdd
          .whereType<UserChatEntry>()
          .toList();
      expect(userEntries, isEmpty);
    });

    test('skips meta user messages during restoration', () {
      final update = handler.handle(
        const HistoryMessage(
          messages: [
            UserInputMessage(text: 'meta prompt', isMeta: true),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        isBackground: false,
      );
      final userEntries = update.entriesToAdd
          .whereType<UserChatEntry>()
          .toList();
      expect(userEntries, isEmpty);
    });
  });

  group('Live user_input handling — UUID echo', () {
    test('user_input without UUID adds new entry', () {
      final update = handler.handle(
        const UserInputMessage(text: 'Hello'),
        isBackground: false,
      );
      expect(update.entriesToAdd, hasLength(1));
      final entry = update.entriesToAdd[0] as UserChatEntry;
      expect(entry.text, 'Hello');
      expect(entry.status, MessageStatus.sent);
    });

    test('user_input with UUID returns UUID update (no duplicate entry)', () {
      final update = handler.handle(
        const UserInputMessage(text: 'Hello', userMessageUuid: 'uuid-1'),
        isBackground: false,
      );
      expect(update.entriesToAdd, isEmpty);
      expect(update.userUuidUpdate, isNotNull);
      expect(update.userUuidUpdate!.text, 'Hello');
      expect(update.userUuidUpdate!.uuid, 'uuid-1');
    });

    test('synthetic user_input is skipped', () {
      final update = handler.handle(
        const UserInputMessage(text: 'synthetic', isSynthetic: true),
        isBackground: false,
      );
      expect(update.entriesToAdd, isEmpty);
      expect(update.userUuidUpdate, isNull);
    });

    test('meta user_input is skipped', () {
      final update = handler.handle(
        const UserInputMessage(text: 'meta', isMeta: true),
        isBackground: false,
      );
      expect(update.entriesToAdd, isEmpty);
      expect(update.userUuidUpdate, isNull);
    });
  });
}

import 'dart:async';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/anchor_maintaining_auto_scroll_controller.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/features/claude_session/claude_session_screen.dart';
import 'package:ccpocket/features/claude_session/widgets/usage_summary_bar.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/widgets/message_bubble.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/result_chip.dart';
import 'package:ccpocket/widgets/bubbles/thinking_bubble.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBridge extends BridgeService {
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  void emit(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) =>
      _taggedController.stream
          .where((pair) => pair.$2 == null || pair.$2 == sessionId)
          .map((pair) => pair.$1);

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void requestSessionContext(String sessionId) {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void retainSessionHistory(String sessionId) {}

  @override
  void releaseSessionHistory(String sessionId) {}

  @override
  void dispose() {
    _taggedController.close();
    _messageController.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Antigravity model/message parsing', () {
    test('ResultMessage parses thoughtTokens', () {
      final msg = ServerMessage.fromJson({
        'type': 'result',
        'subtype': 'success',
        'inputTokens': 1200,
        'outputTokens': 300,
        'thoughtTokens': 450,
      }) as ResultMessage;

      expect(msg.inputTokens, 1200);
      expect(msg.outputTokens, 300);
      expect(msg.thoughtTokens, 450);
    });

    test('AntigravitySettings.copyWith can clear thoughtLevel to null', () {
      const settings = AntigravitySettings(
        model: 'gemini-3.8-flash-high',
        baseModel: 'gemini-3.8-flash',
        thoughtLevel: 'high',
        thoughtLevels: ['high', 'low'],
      );

      expect(settings.copyWith(model: 'other').thoughtLevel, 'high');
      expect(
        settings
            .copyWith(
              baseModel: 'gpt-oss-120b',
              thoughtLevel: null,
              thoughtLevels: const [],
            )
            .thoughtLevel,
        isNull,
      );
    });

    test('ContextCompactionMessage and SessionTranscriptMessage parse provider antigravity', () {
      final compaction = ServerMessage.fromJson({
        'type': 'context_compaction',
        'id': 'cmp-1',
        'provider': 'antigravity',
        'trigger': 'auto',
        'preTokens': 90000,
        'postTokens': 12000,
      }) as ContextCompactionMessage;
      expect(compaction.provider, 'antigravity');
      expect(compaction.isAuto, isTrue);
      expect(compaction.preTokens, 90000);

      final transcript = ServerMessage.fromJson({
        'type': 'session_transcript',
        'sessionId': 's-agy',
        'requestId': 'transcript-1',
        'provider': 'antigravity',
        'startIndex': 0,
        'endIndex': 1,
        'total': 1,
        'messages': [
          {
            'role': 'compaction',
            'uuid': 'cmp-1',
            'provider': 'antigravity',
            'compaction': {'trigger': 'manual'},
          },
        ],
      }) as SessionTranscriptMessage;
      expect(transcript.provider, 'antigravity');
      expect(transcript.messages.single.compaction?.provider, 'antigravity');
    });
  });

  group('UsageSummaryBar and ResultChip thoughtTokens', () {
    testWidgets('UsageSummaryBar displays thoughtTokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: UsageSummaryBar(
              totalCost: 0,
              totalDuration: null,
              inputTokens: 1500,
              cachedInputTokens: 0,
              outputTokens: 300,
              thoughtTokens: 1200,
              toolCalls: 0,
              fileEdits: 0,
            ),
          ),
        ),
      );

      expect(find.text('in 1.5k / out 300 / thought 1.2k'), findsOneWidget);
    });

    testWidgets('ResultChip displays thoughtTokens when positive', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: ResultChip(
              message: ResultMessage(
                subtype: 'success',
                inputTokens: 100,
                outputTokens: 50,
                thoughtTokens: 25,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Done (100in/50out/25thought tok)'), findsOneWidget);
    });
  });

  group('Antigravity plan mode', () {
    test('extractPlanText falls back to pending ExitPlanMode permission', () {
      const pending = PermissionRequestMessage(
        toolUseId: 'plan-1',
        toolName: 'ExitPlanMode',
        input: {'plan': '# Plan\n1. Do the thing'},
      );
      expect(
        extractPlanText(const [], pendingPermission: pending),
        '# Plan\n1. Do the thing',
      );
      expect(
        extractPlanText([ServerChatEntry(pending)]),
        '# Plan\n1. Do the thing',
      );
    });

    test('reject on Antigravity ExitPlanMode keeps plan mode active', () async {
      final bridge = _TestBridge();
      final streaming = StreamingStateCubit();
      final cubit = ChatSessionCubit(
        sessionId: 'agy-1',
        provider: Provider.antigravity,
        bridge: bridge,
        streamingCubit: streaming,
        initialPermissionMode: PermissionMode.plan,
      );
      addTearDown(() async {
        await cubit.close();
        await streaming.close();
        bridge.dispose();
      });

      bridge.emit(
        const PermissionRequestMessage(
          toolUseId: 'plan-1',
          toolName: 'ExitPlanMode',
          input: {'plan': '# Plan'},
        ),
        sessionId: 'agy-1',
      );
      await Future<void>.delayed(Duration.zero);

      cubit.reject('plan-1', message: 'Adjust step 2');

      expect(cubit.state.permissionMode, PermissionMode.plan);
      expect(cubit.state.planMode, isTrue);
      expect(cubit.state.inPlanMode, isTrue);
    });

    test('setAntigravitySettings clears thoughtLevel when switching to non-thinking model', () async {
      final bridge = _TestBridge();
      final streaming = StreamingStateCubit();
      final cubit = ChatSessionCubit(
        sessionId: 'agy-2',
        provider: Provider.antigravity,
        bridge: bridge,
        streamingCubit: streaming,
      );
      addTearDown(() async {
        await cubit.close();
        await streaming.close();
        bridge.dispose();
      });

      bridge.emit(
        ServerMessage.fromJson({
          'type': 'system',
          'subtype': 'init',
          'sessionId': 'conv-2',
          'provider': 'antigravity',
          'antigravity': {
            'model': 'gemini-3.8-flash-high',
            'baseModel': 'gemini-3.8-flash',
            'thoughtLevel': 'high',
            'thoughtLevels': ['high', 'low'],
            'modelOptions': [
              {
                'id': 'gemini-3.8-flash',
                'name': 'Gemini 3.8 Flash',
                'thoughtLevels': ['high', 'low'],
              },
              {
                'id': 'gpt-oss-120b',
                'name': 'GPT-OSS 120B',
                'thoughtLevels': <String>[],
              },
            ],
          },
        }),
        sessionId: 'agy-2',
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.antigravitySettings?.thoughtLevel, 'high');

      cubit.setAntigravitySettings(model: 'gpt-oss-120b');

      expect(cubit.state.antigravitySettings?.baseModel, 'gpt-oss-120b');
      expect(cubit.state.antigravitySettings?.thoughtLevel, isNull);
      expect(cubit.state.antigravitySettings?.thoughtLevels, isEmpty);
    });
  });

  group('Live activity label and ChatMessageList activity bar', () {
    test('formatAgentActivityLabel formats labels per tool kind', () {
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: '1',
            name: 'Bash',
            input: {'command': 'ls', 'description': 'List files'},
          ),
        ),
        'Running: List files...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: '2', name: 'Bash', input: {'command': 'ls'}),
        ),
        'Running command...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: '3',
            name: 'Read',
            input: {'file_path': '/repo/lib/main.dart'},
          ),
        ),
        'Reading main.dart...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: '4',
            name: 'FileChange',
            input: {
              'changes': [
                {'path': 'lib/app.dart', 'kind': 'update', 'diff': ''},
              ],
            },
          ),
        ),
        'Editing app.dart...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: '5', name: 'Grep', input: {}),
        ),
        'Searching files...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: '6', name: 'WebSearch', input: {}),
        ),
        'Searching web...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: '7', name: 'WebFetch', input: {}),
        ),
        'Fetching URL...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: '8', name: 'invoke_subagent', input: {}),
        ),
        'Running subagent...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: '9',
            name: 'mcp__dart-mcp__run_tests',
            input: {},
          ),
        ),
        'Running run_tests...',
      );
    });

    test(
      'findLatestIncompleteToolUse skips completed tools and prior turns',
      () {
        final entries = <ChatEntry>[
          ServerChatEntry(
            const AssistantServerMessage(
              message: AssistantMessage(
                id: 'a0',
                role: 'assistant',
                model: 'antigravity',
                content: [
                  ToolUseContent(id: 'old-tool', name: 'Read', input: {}),
                ],
              ),
            ),
          ),
          ServerChatEntry(const ResultMessage(subtype: 'success')),
          UserChatEntry('Next turn'),
          ServerChatEntry(
            const AssistantServerMessage(
              message: AssistantMessage(
                id: 'a1',
                role: 'assistant',
                model: 'antigravity',
                content: [
                  ToolUseContent(
                    id: 't1',
                    name: 'Read',
                    input: {'file_path': 'a.dart'},
                  ),
                  ToolUseContent(
                    id: 't2',
                    name: 'Bash',
                    input: {'description': 'Run tests'},
                  ),
                ],
              ),
            ),
          ),
          ServerChatEntry(
            const ToolResultMessage(toolUseId: 't1', content: 'ok'),
          ),
        ];

        expect(findLatestIncompleteToolUse(entries)?.id, 't2');
      },
    );

    testWidgets(
      'ChatMessageList renders ThinkingBubble during thinking stream and activity bar',
      (tester) async {
        final bridge = _TestBridge();
        final streamingCubit = StreamingStateCubit();
        final chatCubit = ChatSessionCubit(
          sessionId: 'live-1',
          provider: Provider.antigravity,
          bridge: bridge,
          streamingCubit: streamingCubit,
        );
        final controller = AnchorMaintainingAutoScrollController();
        addTearDown(() async {
          controller.dispose();
          await chatCubit.close();
          await streamingCubit.close();
          bridge.dispose();
        });

        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [RepositoryProvider<BridgeService>.value(value: bridge)],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<ChatSessionCubit>.value(value: chatCubit),
                BlocProvider<StreamingStateCubit>.value(value: streamingCubit),
                BlocProvider<FileListCubit>(
                  create: (_) => FileListCubit(
                    const [],
                    const Stream<List<String>>.empty(),
                  ),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: Scaffold(
                  body: ChatMessageList(
                    sessionId: 'live-1',
                    scrollController: controller,
                    httpBaseUrl: null,
                    onRetryMessage: null,
                    collapseToolResults: null,
                  ),
                ),
              ),
            ),
          ),
        );

        // Running with no text yet -> shows activity bar with Thinking...
        bridge.emit(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 'live-1',
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('agent_activity_bar')),
          findsOneWidget,
        );
        expect(find.text('Thinking...'), findsOneWidget);

        // Thinking delta -> renders ThinkingBubble in streaming row and hides activity bar
        bridge.emit(
          const ThinkingDeltaMessage(text: 'Step 1\nStep 2\nStep 3'),
          sessionId: 'live-1',
        );
        await tester.pump();
        expect(find.byType(ThinkingBubble), findsOneWidget);
        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);

        // Text delta -> hides Thinking... activity bar to avoid duplicate indicator
        bridge.emit(
          const StreamDeltaMessage(text: 'Hello!'),
          sessionId: 'live-1',
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);

        // Uncompleted tool use while running -> shows tool activity label
        bridge.emit(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              model: 'antigravity',
              content: [
                ToolUseContent(
                  id: 'tool-1',
                  name: 'Read',
                  input: {'file_path': 'lib/foo.dart'},
                ),
              ],
            ),
          ),
          sessionId: 'live-1',
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('agent_activity_bar')),
          findsOneWidget,
        );
        expect(find.text('Reading foo.dart...'), findsOneWidget);

        // Waiting for approval -> hides activity bar
        bridge.emit(
          const PermissionRequestMessage(
            toolUseId: 'tool-1',
            toolName: 'Bash',
            input: {'command': 'rm -rf /tmp/x'},
          ),
          sessionId: 'live-1',
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);
      },
    );
  });
  group('ToolResultMessage rendering', () {
    testWidgets('hides redundant Read Done result bubble', (tester) async {
      expect(
        ServerMessageWidget.isVisible(
          const ToolResultMessage(
            toolUseId: 't1',
            toolName: 'Read',
            content: 'Done',
          ),
        ),
        isFalse,
      );

      expect(
        ServerMessageWidget.isVisible(
          const ToolResultMessage(
            toolUseId: 't1',
            toolName: 'Read',
            content: ' Done \n',
          ),
        ),
        isFalse,
      );

      expect(
        ServerMessageWidget.isVisible(
          const ToolResultMessage(
            toolUseId: 't2',
            toolName: 'Read',
            content: 'Something else',
          ),
        ),
        isTrue,
      );

      expect(
        ServerMessageWidget.isVisible(
          const ToolResultMessage(
            toolUseId: 't3',
            toolName: 'Bash',
            content: 'Done',
          ),
        ),
        isTrue,
      );
    });

    test('redundantFileChangeToolUseIds hides duplicate FileChange result only when tool_use already has diff', () {
      final entries = <ChatEntry>[
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'fc-replayed',
              role: 'assistant',
              content: [
                ToolUseContent(
                  id: 'fc-replayed',
                  name: 'FileChange',
                  input: {
                    'changes': [
                      {
                        'path': 'lib/main.dart',
                        'diff': '--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1 +1 @@\n-old\n+new',
                      },
                    ],
                  },
                ),
              ],
              model: 'gemini-3.1-pro',
            ),
          ),
        ),
        ServerChatEntry(
          const ToolResultMessage(
            toolUseId: 'fc-replayed',
            toolName: 'FileChange',
            content: '--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1 +1 @@\n-old\n+new',
          ),
        ),
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'fc-live',
              role: 'assistant',
              content: [
                ToolUseContent(
                  id: 'fc-live',
                  name: 'FileChange',
                  input: {
                    'changes': [
                      {'path': 'lib/live.dart'},
                    ],
                  },
                ),
              ],
              model: 'gemini-3.1-pro',
            ),
          ),
        ),
        ServerChatEntry(
          const ToolResultMessage(
            toolUseId: 'fc-live',
            toolName: 'FileChange',
            content:
                '--- a/lib/live.dart\n+++ b/lib/live.dart\n@@ -1 +1 @@\n-a\n+b',
          ),
        ),
      ];

      expect(redundantFileChangeToolUseIds(entries), equals({'fc-replayed'}));
    });
  });
}

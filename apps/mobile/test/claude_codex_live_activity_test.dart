import 'dart:async';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/widgets/indexed_scroll_controller.dart';
import 'package:ccpocket/features/chat_session/widgets/background_tasks_bar.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/features/chat_session/widgets/session_recap_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/performance_probe_extension.dart';
import 'package:ccpocket/theme/app_theme.dart';
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

  group('formatAgentActivityLabel & findLatestIncompleteToolUse', () {
    test('formats Claude and Codex tool labels cleanly', () {
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't1',
            name: 'Bash',
            input: {'cmd': 'npm run test:bridge'},
          ),
        ),
        'Running: npm run test:bridge...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't2',
            name: 'mcp:github/search_issues',
            input: {},
          ),
        ),
        'Running search_issues...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't3',
            name: 'Grep',
            input: {'pattern': 'sdkMessageToServerMessage'},
          ),
        ),
        'Searching "sdkMessageToServerMessage"...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't4',
            name: 'WebSearch',
            input: {'query': 'claude opus 4.7 adaptive thinking'},
          ),
        ),
        'Searching web: claude opus 4.7 adaptive thinking...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't5',
            name: 'Agent',
            input: {'description': 'Explore ACP gaps'},
          ),
        ),
        'Subagent: Explore ACP gaps...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't6',
            name: 'SubAgent',
            input: {'tool': 'wait'},
          ),
        ),
        'Waiting for subagents...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(
            id: 't7',
            name: 'TodoWrite',
            input: {
              'todos': [
                {
                  'content': 'Fix parallel tool results',
                  'activeForm': 'Fixing parallel tool results',
                  'status': 'in_progress',
                },
              ],
            },
          ),
        ),
        'Fixing parallel tool results...',
      );
      expect(
        formatAgentActivityLabel(
          const ToolUseContent(id: 't8', name: 'ImageGeneration', input: {}),
        ),
        'Generating image...',
      );
    });

    test('ignores UpdatePlan, terminal-status history tools, and superseded rounds', () {
      final entries = <ChatEntry>[
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a-plan',
              role: 'assistant',
              model: 'gpt-5',
              content: [
                ToolUseContent(
                  id: 'plan-1',
                  name: 'UpdatePlan',
                  input: {'plan': []},
                ),
              ],
            ),
          ),
        ),
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a-done',
              role: 'assistant',
              model: 'gpt-5',
              content: [
                ToolUseContent(
                  id: 'fc-1',
                  name: 'FileChange',
                  input: {'status': 'completed', 'changes': []},
                ),
              ],
            ),
          ),
        ),
      ];
      expect(findLatestIncompleteToolUse(entries), isNull);

      final superseded = <ChatEntry>[
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a-old',
              role: 'assistant',
              model: 'claude',
              content: [
                ToolUseContent(
                  id: 'old-read',
                  name: 'Read',
                  input: {'file_path': 'old.dart'},
                ),
              ],
            ),
          ),
        ),
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a-new',
              role: 'assistant',
              model: 'claude',
              content: [TextContent(text: 'Finished reading.')],
            ),
          ),
        ),
      ];
      expect(findLatestIncompleteToolUse(superseded), isNull);
    });
  });

  group('Claude & Codex live activity bar and session recap widget flow', () {
    testWidgets(
      'clears thinking stream on assistant tool_use commit and renders live agent_activity & recap',
      (tester) async {
        final bridge = _TestBridge();
        final streamingCubit = StreamingStateCubit();
        final chatCubit = ChatSessionCubit(
          sessionId: 'claude-live',
          provider: Provider.claude,
          bridge: bridge,
          streamingCubit: streamingCubit,
        );
        final controller = IndexedScrollController();

        addTearDown(() async {
          controller.dispose();
          await chatCubit.close();
          await streamingCubit.close();
          bridge.dispose();
        });

        await tester.pumpWidget(
          RepositoryProvider<BridgeService>.value(
            value: bridge,
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
                    sessionId: 'claude-live',
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

        bridge.emit(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Thinking...'), findsOneWidget);

        // Redacted thinking token estimate updates live bar
        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-live',
            activity: AgentActivityInfo(thinkingTokens: 1500),
          ),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Thinking (1.5k tokens)...'), findsOneWidget);

        // Thinking delta streams -> ThinkingBubble shown, bar hidden
        bridge.emit(
          const ThinkingDeltaMessage(text: 'Checking sdk-process.ts...'),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.byType(ThinkingBubble), findsOneWidget);
        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);

        // Tool JSON streaming starts (preparingTool: true) -> bar immediately shows Editing sdk-process.ts...
        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-live',
            activity: AgentActivityInfo(
              toolName: 'Edit',
              toolUseId: 'tu-1',
              toolHint: 'sdk-process.ts',
              preparingTool: true,
            ),
          ),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Editing sdk-process.ts...'), findsOneWidget);

        // Assistant commits thinking + tool_use WITHOUT any stream_delta text!
        // Must clear StreamingStateCubit (no duplicate ThinkingBubble) and keep bar visible!
        bridge.emit(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'a1',
              role: 'assistant',
              model: 'claude-opus-4-7',
              content: [
                ToolUseContent(
                  id: 'tu-1',
                  name: 'Edit',
                  input: {'file_path': 'packages/bridge/src/sdk-process.ts'},
                ),
              ],
            ),
          ),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.byType(ThinkingBubble), findsOneWidget);
        expect(streamingCubit.state.thinking, isEmpty);
        expect(find.text('Editing sdk-process.ts...'), findsOneWidget);

        // Tool progress with elapsed seconds -> appends · 6s
        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-live',
            activity: AgentActivityInfo(
              toolName: 'Edit',
              toolUseId: 'tu-1',
              elapsedSeconds: 6,
            ),
          ),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Editing sdk-process.ts... · 6s'), findsOneWidget);

        // Tool result arrives, classifier task_summary keeps user informed
        bridge.emit(
          const ToolResultMessage(toolUseId: 'tu-1', content: 'Updated'),
          sessionId: 'claude-live',
        );
        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-live',
            activity: AgentActivityInfo(summary: 'Verifying Bridge tests'),
          ),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Verifying Bridge tests...'), findsOneWidget);

        // Session recap arrives (away_summary / /recap)
        bridge.emit(
          const SessionRecapMessage(
            content: 'Added Claude and Codex live activity parity.',
            source: 'away_summary',
          ),
          sessionId: 'claude-live',
        );
        bridge.emit(
          const ResultMessage(subtype: 'success', result: 'Done'),
          sessionId: 'claude-live',
        );
        bridge.emit(
          const StatusMessage(status: ProcessStatus.idle),
          sessionId: 'claude-live',
        );
        await tester.pump(Duration.zero);
        await tester.pump();

        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);
        expect(find.byType(SessionRecapCard), findsOneWidget);
        expect(
          find.textContaining('Added Claude and Codex live activity parity.'),
          findsOneWidget,
        );
      },
    );

    test('BackgroundTasksBar formats summary alongside task description', () {
      expect(
        BackgroundTasksBar.taskLabel(
          const BackgroundTaskInfo(
            taskId: 't1',
            taskType: 'local_agent',
            description: 'Explore auth',
            summary: 'Checking JWT middleware',
          ),
        ),
        'Explore auth — Checking JWT middleware',
      );
    });

    testWidgets(
      'activity text and elapsed updates rebuild only the activity bar, not ChatMessageList',
      (tester) async {
        final bridge = _TestBridge();
        final streamingCubit = StreamingStateCubit();
        final chatCubit = ChatSessionCubit(
          sessionId: 'claude-perf',
          provider: Provider.claude,
          bridge: bridge,
          streamingCubit: streamingCubit,
        );
        final controller = IndexedScrollController();

        addTearDown(() async {
          controller.dispose();
          await chatCubit.close();
          await streamingCubit.close();
          bridge.dispose();
        });

        await tester.pumpWidget(
          RepositoryProvider<BridgeService>.value(
            value: bridge,
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
                    sessionId: 'claude-perf',
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

        bridge.emit(
          const StatusMessage(status: ProcessStatus.running),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Thinking...'), findsOneWidget);

        chatListPerformanceProbe.reset();

        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-perf',
            activity: AgentActivityInfo(thinkingTokens: 1200),
          ),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Thinking (1.2k tokens)...'), findsOneWidget);
        expect(chatListPerformanceProbe.summary()['buildCount'], 0);

        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-perf',
            activity: AgentActivityInfo(
              toolName: 'Bash',
              toolHint: 'flutter test',
              elapsedSeconds: 3,
            ),
          ),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Running: flutter test... · 3s'), findsOneWidget);
        expect(chatListPerformanceProbe.summary()['buildCount'], 0);

        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-perf',
            activity: AgentActivityInfo(
              toolName: 'Bash',
              toolHint: 'flutter test',
              elapsedSeconds: 4,
            ),
          ),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Running: flutter test... · 4s'), findsOneWidget);
        expect(chatListPerformanceProbe.summary()['buildCount'], 0);

        // Stream text hides the activity bar, then preparingTool reveals it
        // again; subsequent preparingTool hint changes must not rebuild the list.
        bridge.emit(
          const StreamDeltaMessage(text: 'Streaming answer'),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.byKey(const ValueKey('agent_activity_bar')), findsNothing);

        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-perf',
            activity: AgentActivityInfo(
              toolName: 'Edit',
              toolHint: 'first.dart',
              preparingTool: true,
            ),
          ),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Editing first.dart...'), findsOneWidget);

        chatListPerformanceProbe.reset();
        bridge.emit(
          const AgentActivityMessage(
            sessionId: 'claude-perf',
            activity: AgentActivityInfo(
              toolName: 'Edit',
              toolHint: 'second.dart',
              preparingTool: true,
            ),
          ),
          sessionId: 'claude-perf',
        );
        await tester.pump(Duration.zero);
        await tester.pump();
        expect(find.text('Editing second.dart...'), findsOneWidget);
        expect(chatListPerformanceProbe.summary()['buildCount'], 0);
      },
    );
  });
}

import 'package:ccpocket/features/chat_session/lite_mode_projection.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_response_grouping.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/chat_display_filter.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerChatEntry assistant(
  List<AssistantContent> content, {
  List<ImageRef> images = const [],
}) => ServerChatEntry(
  AssistantServerMessage(
    messageUuid: 'uuid',
    images: images,
    message: AssistantMessage(
      id: 'a',
      role: 'assistant',
      content: content,
      model: 'test',
    ),
  ),
  timestamp: DateTime(2026, 9, 30),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps prose, thinking, embedded/generated/attached images, and removes MCP screenshots', () {
    final user = UserChatEntry('make an image', imageUrls: ['/images/input']);
    const embeddedImage = ImageRef(
      id: 'embed',
      url: '/images/embed',
      mimeType: 'image/png',
    );
    final prose = assistant(
      [
        const TextContent(text: 'Checking the screen'),
        const ThinkingContent(thinking: 'internal'),
        const ThinkingContent(thinking: '   '),
        const ToolUseContent(
          id: 'screenshot',
          name: 'mcp__simulator__screenshot',
          input: {},
        ),
      ],
      images: const [embeddedImage],
    );
    final imageOnly = assistant(
      [const ToolUseContent(id: 'read', name: 'Read', input: {})],
      images: const [embeddedImage],
    );
    final imageGenInProgress = assistant([
      const ToolUseContent(
        id: 'generated',
        name: 'ImageGeneration',
        input: {'status': 'generating', 'revisedPrompt': 'apple'},
      ),
    ]);
    final screenshot = ServerChatEntry(
      const ToolResultMessage(
        toolUseId: 'screenshot',
        toolName: 'mcp__simulator__screenshot',
        content: '',
        images: [
          ImageRef(id: 'screen', url: '/images/screen', mimeType: 'image/png'),
        ],
      ),
    );
    final generated = ServerChatEntry(
      const ToolResultMessage(
        toolUseId: 'generated',
        toolName: 'ImageGeneration',
        content: '',
        images: [
          ImageRef(id: 'art', url: '/images/art', mimeType: 'image/png'),
        ],
      ),
    );
    final original = [
      user,
      prose,
      imageOnly,
      imageGenInProgress,
      screenshot,
      generated,
    ];
    final visible = liteModeEntries(original);
    expect(visible.length, 5);
    expect(visible.first, same(user));
    expect(visible[3], same(imageGenInProgress));
    expect(visible.last, same(generated));
    final projected =
        (visible[1] as ServerChatEntry).message as AssistantServerMessage;
    expect(projected.message.content, hasLength(2));
    expect(projected.message.content[0], isA<TextContent>());
    expect(projected.message.content[1], isA<ThinkingContent>());
    expect(projected.images, const [embeddedImage]);
    expect(projected.messageUuid, 'uuid');
    expect(visible[1].timestamp, prose.timestamp);
    final projectedImageOnly =
        (visible[2] as ServerChatEntry).message as AssistantServerMessage;
    expect(projectedImageOnly.message.content, isEmpty);
    expect(projectedImageOnly.images, const [embeddedImage]);
    expect((prose.message as AssistantServerMessage).message.content.length, 4);
    expect(original[4], same(screenshot));
    expect(
      groupGeneratedImageResponses(visible).single.messages.single,
      generated.message,
    );
  });

  test(
    'hides question tool calls but retains plans, outcomes and completion',
    () {
      final plan = assistant([
        const ToolUseContent(id: 'plan', name: 'ExitPlanMode', input: {}),
      ]);
      final question = assistant([
        const ToolUseContent(id: 'ask', name: 'AskUserQuestion', input: {}),
      ]);
      final permission = ServerChatEntry(
        const ToolResultMessage(
          toolUseId: 'p',
          content: 'Denied',
          permissionOutcome: PermissionOutcome.rejected,
        ),
      );
      final error = ServerChatEntry(const ErrorMessage(message: 'Failed'));
      final result = ServerChatEntry(
        const ResultMessage(subtype: 'success', result: 'Done'),
      );
      final imageFailure = ServerChatEntry(
        const ToolResultMessage(
          toolUseId: 'image',
          toolName: 'ImageGeneration',
          content: 'Image generation failed',
        ),
      );
      final visible = liteModeEntries([
        plan,
        question,
        permission,
        error,
        result,
        imageFailure,
      ]);
      expect(visible.length, 5);
      expect(visible, [plan, permission, error, result, imageFailure]);
    },
  );

  test('large tool-only history produces no empty transcript rows', () {
    final entries = List<ChatEntry>.generate(
      2000,
      (i) => i.isEven
          ? assistant([ToolUseContent(id: '$i', name: 'Read', input: const {})])
          : ServerChatEntry(
              ToolResultMessage(toolUseId: '${i - 1}', content: 'output'),
            ),
    );
    final summary = ServerChatEntry(
      const ToolUseSummaryMessage(summary: 'many tools'),
    );
    entries.add(summary);
    // Recommended preset keeps subagent summaries while omitting Read/results.
    expect(liteModeEntries(entries), [same(summary)]);
    // Disabling subagents produces an empty transcript.
    expect(
      liteModeEntries(
        entries,
        filter: ChatDisplayFilter.recommended.copyWith(subagents: false),
      ),
      isEmpty,
    );
    expect(entries.length, 2001);
  });

  test('supports per-category display filters', () {
    final mixed = assistant([
      const ThinkingContent(thinking: 'step by step'),
      const ToolUseContent(
        id: 'todo',
        name: 'TodoWrite',
        input: {
          'todos': [
            {'content': 'Ship', 'status': 'in_progress'},
          ],
        },
      ),
      const ToolUseContent(id: 'plan', name: 'UpdatePlan', input: {}),
      const ToolUseContent(id: 'tc', name: 'TaskCreate', input: {}),
      const ToolUseContent(id: 'sub', name: 'Agent', input: {}),
      const ToolUseContent(id: 'edit', name: 'Edit', input: {}),
      const ToolUseContent(id: 'fc', name: 'FileChange', input: {}),
      const ToolUseContent(id: 'bash', name: 'Bash', input: {'command': 'ls'}),
      const TextContent(text: 'Done'),
    ]);
    final toolResult = ServerChatEntry(
      const ToolResultMessage(
        toolUseId: 'bash',
        toolName: 'Bash',
        content: 'ok',
      ),
    );

    // Recommended keeps thinking, tasks, subagents and prose.
    final recommended = liteModeEntries([mixed, toolResult]);
    expect(recommended, hasLength(1));
    final recContent =
        ((recommended.single as ServerChatEntry).message
                as AssistantServerMessage)
            .message
            .content;
    expect(
      recContent.map(
        (c) => c is ToolUseContent ? c.name : c.runtimeType.toString(),
      ),
      [
        'ThinkingContent',
        'TodoWrite',
        'UpdatePlan',
        'TaskCreate',
        'Agent',
        'TextContent',
      ],
    );

    // Turning thinking and tasks off hides them.
    final noThinkingOrTasks = liteModeEntries(
      [mixed, toolResult],
      filter: ChatDisplayFilter.recommended.copyWith(
        tasks: false,
        thinking: false,
      ),
    );
    final ntContent =
        ((noThinkingOrTasks.single as ServerChatEntry).message
                as AssistantServerMessage)
            .message
            .content;
    expect(
      ntContent.map(
        (c) => c is ToolUseContent ? c.name : c.runtimeType.toString(),
      ),
      ['Agent', 'TextContent'],
    );

    // Enabling codeEdits keeps Edit & FileChange without Bash or tool results.
    final withEdits = liteModeEntries([
      mixed,
      toolResult,
    ], filter: ChatDisplayFilter.recommended.copyWith(codeEdits: true));
    final editContent =
        ((withEdits.single as ServerChatEntry).message
                as AssistantServerMessage)
            .message
            .content;
    expect(editContent.whereType<ToolUseContent>().map((t) => t.name), [
      'TodoWrite',
      'UpdatePlan',
      'TaskCreate',
      'Agent',
      'Edit',
      'FileChange',
    ]);

    // Enabling toolResults keeps ToolResultMessage.
    final withResults = liteModeEntries([
      mixed,
      toolResult,
    ], filter: ChatDisplayFilter.recommended.copyWith(toolResults: true));
    expect(withResults, hasLength(2));
    expect(withResults.last, same(toolResult));

    // All preset returns original list untouched.
    final allEntries = [mixed, toolResult];
    expect(
      liteModeEntries(allEntries, filter: ChatDisplayFilter.all),
      same(allEntries),
    );
  });

  test(
    'migrates legacy liteMode preference and persists custom filters',
    () async {
      SharedPreferences.setMockInitialValues({'settings_lite_mode': true});
      final prefs = await SharedPreferences.getInstance();
      final migrated = SettingsCubit(prefs);
      expect(migrated.state.chatDisplayFilter, ChatDisplayFilter.recommended);
      expect(migrated.state.liteMode, true);

      final custom = ChatDisplayFilter.recommended.copyWith(codeEdits: true);
      migrated.setChatDisplayFilter(custom);
      expect(migrated.state.chatDisplayFilter.preset, ChatDisplayPreset.custom);
      expect(migrated.state.liteMode, true);

      migrated.setChatDisplayPreset(ChatDisplayPreset.all);
      expect(migrated.state.chatDisplayFilter, ChatDisplayFilter.all);
      expect(migrated.state.liteMode, false);

      // Switching back to custom restores the remembered custom filter.
      migrated.setChatDisplayPreset(ChatDisplayPreset.custom);
      expect(migrated.state.chatDisplayFilter, custom);
      await migrated.close();

      // Persists across restarts.
      final restored = SettingsCubit(prefs);
      expect(restored.state.chatDisplayFilter, custom);
      expect(restored.state.displayFilterForSession('s1'), custom);
      restored.setSessionLiteMode('s1', false);
      expect(
        restored.state.displayFilterForSession('s1'),
        ChatDisplayFilter.all,
      );
      restored.setSessionLiteMode('s1', true);
      expect(
        restored.state.displayFilterForSession('s1'),
        ChatDisplayFilter.recommended,
      );
      await restored.close();
    },
  );

  test('keeps answered question panels in performance mode', () {
    final questionText = assistant([
      const TextContent(text: 'Which sound should the garden use?'),
    ]);
    final questionCall = assistant([
      const ToolUseContent(
        id: 'ask-1',
        name: 'AskUserQuestion',
        input: {
          'questions': [
            {'question': 'Which sound should the garden use?'},
          ],
        },
      ),
    ]);
    final answer = QuestionAnswerChatEntry(
      'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
      toolUseId: 'ask-1',
      clientMessageId: 'question-answer:ask-1',
      transcript: const QuestionAnswerTranscript(
        plainText: 'Question: Which sound should the garden use?\nAnswer: Forest birdsong',
        questions: [
          AnsweredQuestion(
            question: 'Which sound should the garden use?',
            options: [
              AnsweredQuestionOption(
                label: 'Forest birdsong',
                description: 'Morning birds',
                selected: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(liteModeEntries([questionText, questionCall, answer]), [
      same(questionText),
      same(answer),
    ]);
  });

  test('default, session overrides and inheritance survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = SettingsCubit(prefs);
    expect(cubit.state.liteModeForSession('a'), false);
    cubit.setLiteMode(true);
    cubit.setSessionLiteMode('a', false);
    cubit.setSessionLiteMode('b', true);
    expect(cubit.state.liteModeForSession('a'), false);
    expect(cubit.state.liteModeForSession('c'), true);
    await cubit.close();
    final restored = SettingsCubit(prefs);
    expect(restored.state.liteModeForSession('a'), false);
    expect(restored.state.liteModeForSession('b'), true);
    restored.setLiteMode(false);
    expect(restored.state.liteModeForSession('b'), true);
    expect(restored.state.liteModeForSession('c'), false);
    restored.setSessionLiteMode('b', null);
    expect(restored.state.liteModeForSession('b'), false);
    expect(prefs.containsKey('settings_session_lite_mode:b'), false);
    await restored.close();
  });
}

import 'package:ccpocket/features/chat_session/lite_mode_projection.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_response_grouping.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerChatEntry assistant(List<AssistantContent> content) => ServerChatEntry(
  AssistantServerMessage(
    messageUuid: 'uuid',
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

  test('keeps prose and generated/attached images, removes MCP screenshots and thinking', () {
    final user = UserChatEntry('make an image', imageUrls: ['/images/input']);
    final prose = assistant([
      const TextContent(text: 'Checking the screen'),
      const ThinkingContent(thinking: 'internal'),
      const ToolUseContent(
        id: 'screenshot',
        name: 'mcp__simulator__screenshot',
        input: {},
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
    final original = [user, prose, screenshot, generated];
    final visible = liteModeEntries(original);
    expect(visible.length, 3);
    expect(visible.first, same(user));
    expect(visible.last, same(generated));
    final projected =
        (visible[1] as ServerChatEntry).message as AssistantServerMessage;
    expect(projected.message.content.single, isA<TextContent>());
    expect(projected.messageUuid, 'uuid');
    expect(visible[1].timestamp, prose.timestamp);
    expect((prose.message as AssistantServerMessage).message.content.length, 3);
    expect(original[2], same(screenshot));
    expect(
      groupGeneratedImageResponses(visible).single.messages.single,
      generated.message,
    );
  });

  test(
    'retains questions, plans, permission outcomes, errors and completion',
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
      expect(visible.length, 6);
      expect(visible.skip(2), [permission, error, result, imageFailure]);
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
    entries.add(
      ServerChatEntry(const ToolUseSummaryMessage(summary: 'many tools')),
    );
    expect(liteModeEntries(entries), isEmpty);
    expect(entries.length, 2001);
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

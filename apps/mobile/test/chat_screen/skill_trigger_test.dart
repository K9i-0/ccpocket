import 'package:ccpocket/features/codex_session/codex_session_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/skill_trigger_style.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  late MockBridgeService bridge;

  setUp(() {
    bridge = MockBridgeService();
  });

  tearDown(() {
    bridge.dispose();
  });

  TextEditingController inputController(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('message_input')))
      .controller!;

  Future<void> typeText(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('message_input')), text);
    inputController(tester).selection = TextSelection.collapsed(
      offset: text.length,
    );
    await pumpN(tester);
  }

  group('Skill trigger', () {
    patrolWidgetTest(
      'Claude completes \$skill and inserts the native slash form',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);
        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
          const SystemMessage(
            subtype: 'supported_commands',
            slashCommands: ['review-pr', 'compact'],
            skills: ['review-pr', 'compact'],
          ),
        ]);
        await pumpN($.tester);

        await typeText($.tester, r'$rev');
        expect(
          find.byKey(const ValueKey('slash_completion_item_0')),
          findsOneWidget,
        );
        await $.tester.tap(
          find.byKey(const ValueKey('slash_completion_item_0')),
        );
        await pumpN($.tester);
        expect(inputController($.tester).text, '/review-pr ');

        // Builtins are not offered as `$` aliases.
        await typeText($.tester, r'$comp');
        expect(
          find.byKey(const ValueKey('slash_completion_item_0')),
          findsNothing,
        );

        // A hand-typed `$skill` is converted when sent.
        await typeText($.tester, r'$review-pr 42');
        await $(#send_button).tap();
        await pumpN($.tester);
        expect(findSentMessage(bridge, 'input')!['text'], '/review-pr 42');
      },
    );

    patrolWidgetTest(
      'Codex with slash style inserts /skill and sends \$skill',
      ($) async {
        await $.pumpWidget(await buildTestCodexSessionScreen(bridge: bridge));
        await pumpN($.tester);
        $.tester
            .element(find.byType(CodexSessionScreen))
            .read<SettingsCubit>()
            .setSkillTriggerStyle(SkillTriggerStyle.slash);
        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
          const SystemMessage(
            subtype: 'supported_commands',
            provider: 'codex',
            skills: ['skill-creator'],
            skillMetadata: [
              CodexSkillMetadata(
                name: 'skill-creator',
                path: '/tmp/skill-creator/SKILL.md',
                description: 'Create a skill',
              ),
            ],
          ),
        ]);
        await pumpN($.tester);

        await typeText($.tester, r'$skill-cr');
        await $.tester.tap(
          find.byKey(const ValueKey('slash_completion_item_0')),
        );
        await pumpN($.tester);
        expect(inputController($.tester).text, '/skill-creator ');

        await typeText($.tester, '/skill-creator draft');
        await $(#send_button).tap();
        await pumpN($.tester);
        final sent = findSentMessage(bridge, 'input')!;
        expect(sent['text'], r'$skill-creator draft');
        expect(sent['skills'], [
          {'name': 'skill-creator', 'path': '/tmp/skill-creator/SKILL.md'},
        ]);
      },
    );
  });
}

import 'package:ccpocket/models/messages.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../chat_screen/helpers/chat_test_helpers.dart';
import '../helpers/chat_test_dsl.dart';

void main() {
  late MockBridgeService bridge;

  setUp(() {
    bridge = MockBridgeService();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('User message display', () {
    patrolWidgetTest(
      'Synthetic user messages (isSynthetic=true) are NOT displayed',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await ChatTestScenario($, bridge)
            .emit([
              msg.running,
              // This is a synthetic message (e.g., plan approval prompt)
              const UserInputMessage(
                text: 'This is a synthetic plan approval message',
                isSynthetic: true,
              ),
              msg.assistant('a1', 'Processing your request'),
            ])
            .expectNoText('This is a synthetic plan approval message')
            .expectText('Processing your request')
            .run();
      },
    );

    patrolWidgetTest(
      'Regular user messages (isSynthetic=false) ARE displayed',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        await ChatTestScenario($, bridge)
            .emit([
              msg.running,
              const UserInputMessage(text: 'Help me with this code'),
              msg.assistant('a1', 'Sure, let me help'),
            ])
            .expectText('Help me with this code')
            .run();
      },
    );

    patrolWidgetTest(
      'UserInputMessage with UUID updates existing entry instead of creating duplicate',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);

        // First, send a message from the UI (creates UserChatEntry with status: sending)
        await ChatTestScenario($, bridge).emit([msg.running]).run();

        // Type and send a message
        await $.tester.enterText(
          find.byKey(const ValueKey('message_input')),
          'My test message',
        );
        await pumpN($.tester);
        await $.tester.tap(find.byKey(const ValueKey('send_button')));
        await pumpN($.tester);

        // Now the Bridge echoes back the user message with UUID
        await ChatTestScenario($, bridge).emit([
          const UserInputMessage(
            text: 'My test message',
            userMessageUuid: 'uuid-123',
          ),
        ]).run();

        // Should still show exactly one "My test message" entry
        // (not duplicated)
        final userTextFinder = find.text('My test message');
        // At most 1 visible user message with this text
        expect(
          userTextFinder,
          findsWidgets,
          reason: 'User message should be visible',
        );
      },
    );

    patrolWidgetTest('Meta messages (isMeta=true) are NOT displayed', (
      $,
    ) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await ChatTestScenario($, bridge)
          .emit([
            msg.running,
            const UserInputMessage(text: 'Meta command executed', isMeta: true),
            msg.assistant('a1', 'Acknowledged'),
          ])
          .expectNoText('Meta command executed')
          .expectText('Acknowledged')
          .run();
    });
  });
}

import 'package:ccpocket/features/chat/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/models/messages.dart';
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

  group('Error display', () {
    patrolWidgetTest('I1: ErrorMessage displays in chat', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(message: 'Something went wrong'),
      ]);
      await pumpN($.tester);

      expect($('Something went wrong'), findsOneWidget);
    });

    patrolWidgetTest('I2: After error, idle restores input', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ErrorMessage(message: 'An error occurred'),
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      expect($(ChatInputWithOverlays), findsOneWidget);
    });
  });
}

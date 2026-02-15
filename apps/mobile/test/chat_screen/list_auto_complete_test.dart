import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
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

  /// Helper: get the TextField controller text.
  String getInputText(PatrolTester $) {
    final textField = $.tester.widget<TextField>(
      find.byKey(const ValueKey('message_input')),
    );
    return textField.controller?.text ?? '';
  }

  /// Helper: simulate typing by setting controller value directly.
  /// This is needed because enterText replaces text entirely and doesn't
  /// trigger the same listener flow as incremental typing.
  void setInputText(PatrolTester $, String text) {
    final textField = $.tester.widget<TextField>(
      find.byKey(const ValueKey('message_input')),
    );
    textField.controller!.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Simulates typing a newline at the current cursor position.
  void typeNewline(PatrolTester $) {
    final textField = $.tester.widget<TextField>(
      find.byKey(const ValueKey('message_input')),
    );
    final ctrl = textField.controller!;
    final pos = ctrl.selection.baseOffset;
    final text = ctrl.text;
    ctrl.value = TextEditingValue(
      text: '${text.substring(0, pos)}\n${text.substring(pos)}',
      selection: TextSelection.collapsed(offset: pos + 1),
    );
  }

  group('List auto-complete in ClaudeCodeSessionScreen', () {
    patrolWidgetTest('numbered list continuation works in real input', (
      $,
    ) async {
      await $.pumpWidget(
        await buildTestClaudeCodeSessionScreen(bridge: bridge),
      );
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      setInputText($, '1. first item');
      await pumpN($.tester);

      typeNewline($);
      await pumpN($.tester);

      expect(getInputText($), '1. first item\n2. ');
    });

    patrolWidgetTest('bullet list continuation works in real input', ($) async {
      await $.pumpWidget(
        await buildTestClaudeCodeSessionScreen(bridge: bridge),
      );
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      setInputText($, '- todo item');
      await pumpN($.tester);

      typeNewline($);
      await pumpN($.tester);

      expect(getInputText($), '- todo item\n- ');
    });

    patrolWidgetTest('empty list item cancels list', ($) async {
      await $.pumpWidget(
        await buildTestClaudeCodeSessionScreen(bridge: bridge),
      );
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      setInputText($, '1. ');
      await pumpN($.tester);

      typeNewline($);
      await pumpN($.tester);

      expect(getInputText($), '');
    });

    patrolWidgetTest('plain text does not trigger auto-complete', ($) async {
      await $.pumpWidget(
        await buildTestClaudeCodeSessionScreen(bridge: bridge),
      );
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.idle),
      ]);
      await pumpN($.tester);

      setInputText($, 'just some text');
      await pumpN($.tester);

      typeNewline($);
      await pumpN($.tester);

      expect(getInputText($), 'just some text\n');
    });
  });
}

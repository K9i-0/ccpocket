import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/hooks/use_list_auto_complete.dart';

void main() {
  group('useListAutoComplete', () {
    late TextEditingController controller;

    /// Builds a minimal widget tree that activates the hook.
    Widget buildHarness(TextEditingController ctrl) {
      return MaterialApp(
        home: Scaffold(
          body: HookBuilder(
            builder: (context) {
              useListAutoComplete(ctrl);
              return TextField(controller: ctrl, maxLines: 6);
            },
          ),
        ),
      );
    }

    /// Simulates typing a newline at the current cursor position.
    void typeNewline(TextEditingController ctrl) {
      final pos = ctrl.selection.baseOffset;
      final text = ctrl.text;
      final newText = '${text.substring(0, pos)}\n${text.substring(pos)}';
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + 1),
      );
    }

    /// Sets the controller text with cursor at the end.
    void setText(TextEditingController ctrl, String text) {
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('continues numbered list: "1. foo" + newline → "2. "', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '1. foo');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '1. foo\n2. ');
      expect(controller.selection.baseOffset, '1. foo\n2. '.length);
    });

    testWidgets(
      'continues numbered list with larger numbers: "9. bar" → "10. "',
      (tester) async {
        await tester.pumpWidget(buildHarness(controller));
        setText(controller, '9. bar');
        await tester.pump();

        typeNewline(controller);
        await tester.pump();

        expect(controller.text, '9. bar\n10. ');
        expect(controller.selection.baseOffset, '9. bar\n10. '.length);
      },
    );

    testWidgets('continues hyphen bullet list: "- foo" + newline → "- "', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '- foo');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '- foo\n- ');
      expect(controller.selection.baseOffset, '- foo\n- '.length);
    });

    testWidgets('continues asterisk bullet list: "* foo" + newline → "* "', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '* foo');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '* foo\n* ');
      expect(controller.selection.baseOffset, '* foo\n* '.length);
    });

    testWidgets('preserves indentation: "  - foo" + newline → "  - "', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '  - foo');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '  - foo\n  - ');
      expect(controller.selection.baseOffset, '  - foo\n  - '.length);
    });

    testWidgets(
      'cancels empty numbered list: "3. " + newline → removes prefix',
      (tester) async {
        await tester.pumpWidget(buildHarness(controller));
        setText(controller, '3. ');
        await tester.pump();

        typeNewline(controller);
        await tester.pump();

        expect(controller.text, '');
        expect(controller.selection.baseOffset, 0);
      },
    );

    testWidgets('cancels empty bullet list: "- " + newline → removes prefix', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '- ');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '');
      expect(controller.selection.baseOffset, 0);
    });

    testWidgets('does nothing for plain text: "hello" + newline → "hello\\n"', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, 'hello');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, 'hello\n');
      expect(controller.selection.baseOffset, 'hello\n'.length);
    });

    testWidgets('works with multiline: second list item continues', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '1. first\n2. second');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '1. first\n2. second\n3. ');
      expect(
        controller.selection.baseOffset,
        '1. first\n2. second\n3. '.length,
      );
    });

    testWidgets('cancels empty item in multiline preserves previous lines', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      setText(controller, '1. first\n2. ');
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      expect(controller.text, '1. first\n');
      expect(controller.selection.baseOffset, '1. first\n'.length);
    });

    testWidgets('newline in middle of text does not trigger', (tester) async {
      await tester.pumpWidget(buildHarness(controller));
      // Place cursor after "hello" (not at end of a list item)
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      typeNewline(controller);
      await tester.pump();

      // Should not modify beyond the newline insertion
      expect(controller.text, 'hello\n world');
    });
  });
}

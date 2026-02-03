import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/screens/compose_screen.dart';

void main() {
  Widget wrap({String initialText = ''}) {
    return MaterialApp(home: ComposeScreen(initialText: initialText));
  }

  group('ComposeScreen', () {
    testWidgets('renders with initial text', (tester) async {
      await tester.pumpWidget(wrap(initialText: 'hello world'));

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('compose_text_field')),
      );
      expect(textField.controller?.text, 'hello world');
    });

    testWidgets('renders empty when no initial text', (tester) async {
      await tester.pumpWidget(wrap());

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('compose_text_field')),
      );
      expect(textField.controller?.text, '');
    });

    testWidgets('send button is disabled when text is empty', (tester) async {
      await tester.pumpWidget(wrap());

      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('compose_send_button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('send button is enabled when text is present', (tester) async {
      await tester.pumpWidget(wrap(initialText: 'some text'));

      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('compose_send_button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('send button returns ComposeResult with send=true', (
      tester,
    ) async {
      ComposeResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<ComposeResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ComposeScreen(initialText: 'test prompt'),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Navigate to compose screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap send
      await tester.tap(find.byKey(const ValueKey('compose_send_button')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.text, 'test prompt');
      expect(result!.send, isTrue);
    });

    testWidgets('close button returns ComposeResult with send=false', (
      tester,
    ) async {
      ComposeResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<ComposeResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ComposeScreen(initialText: 'draft text'),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Navigate to compose screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap close (X) button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.text, 'draft text');
      expect(result!.send, isFalse);
    });

    testWidgets('text field supports multiline input', (tester) async {
      await tester.pumpWidget(wrap());

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('compose_text_field')),
      );
      expect(textField.maxLines, isNull);
      expect(textField.expands, isTrue);
      expect(textField.keyboardType, TextInputType.multiline);
    });

    testWidgets('text field has autofocus', (tester) async {
      await tester.pumpWidget(wrap());

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('compose_text_field')),
      );
      expect(textField.autofocus, isTrue);
    });

    testWidgets('send button enables after typing text', (tester) async {
      await tester.pumpWidget(wrap());

      // Initially disabled
      var button = tester.widget<IconButton>(
        find.byKey(const ValueKey('compose_send_button')),
      );
      expect(button.onPressed, isNull);

      // Type text
      await tester.enterText(
        find.byKey(const ValueKey('compose_text_field')),
        'new text',
      );
      await tester.pump();

      // Now enabled
      button = tester.widget<IconButton>(
        find.byKey(const ValueKey('compose_send_button')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}

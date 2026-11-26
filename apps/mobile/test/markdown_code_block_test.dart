import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

AssistantServerMessage _messageWithText(String text) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: 'msg-code-block',
      role: 'assistant',
      content: [TextContent(text: text)],
      model: 'claude-opus-4-5-20251101',
    ),
  );
}

void main() {
  group('AssistantBubble Codex plan update rendering', () {
    testWidgets('renders structured UpdatePlan as checklist', (tester) async {
      const message = AssistantServerMessage(
        message: AssistantMessage(
          id: 'msg-update-plan',
          role: 'assistant',
          content: [
            ToolUseContent(
              id: 'update_plan_1',
              name: 'UpdatePlan',
              input: {
                'title': 'Plan update',
                'explanation': 'Initial plan drafted',
                'todos': [
                  {
                    'content': 'Gather requirements',
                    'status': 'in_progress',
                    'activeForm': '',
                  },
                ],
              },
            ),
          ],
          model: 'codex',
        ),
      );

      await tester.pumpWidget(_wrap(const AssistantBubble(message: message)));

      expect(find.text('Plan update'), findsOneWidget);
      expect(find.text('Initial plan drafted'), findsOneWidget);
      expect(find.text('Gather requirements'), findsOneWidget);
    });

    testWidgets('renders legacy Plan update text as checklist', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AssistantBubble(
            message: _messageWithText(
              'Plan update: Initial draft\n'
              '1. [in progress] Gather requirements',
            ),
          ),
        ),
      );

      expect(find.text('Plan update'), findsOneWidget);
      expect(find.text('Initial draft'), findsOneWidget);
      expect(find.text('Gather requirements'), findsOneWidget);
    });
  });

  group('AssistantBubble fenced code block rendering', () {
    testWidgets('shows language label for explicit fence language', (
      tester,
    ) async {
      const markdown = '```dart\nfinal value = 42;\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_dart')),
        findsOneWidget,
      );
      expect(
        find.textContaining('final value = 42;', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(MarkdownSelectionScope), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('applies syntax highlight colors to the rendered code', (
      tester,
    ) async {
      const markdown = '```typescript\n// note\nconst n: number = 28;\n```';

      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );
      await tester.pumpAndSettle();

      final paragraph = tester
          .widgetList<SelectableParagraph>(find.byType(SelectableParagraph))
          .firstWhere((p) => p.text.toPlainText().contains('const n'));
      final colors = <Color?>{};
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && (span.text?.isNotEmpty ?? false)) {
          colors.add(span.style?.color);
        }
        return true;
      });
      expect(colors.length, greaterThan(2));
    });

    testWidgets('normalizes sh language label to bash', (tester) async {
      const markdown = '```sh\necho hello\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_bash')),
        findsOneWidget,
      );
      expect(
        find.textContaining('echo hello', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('normalizes js language label to javascript', (tester) async {
      const markdown = '```js\nconst value = 1;\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_javascript')),
        findsOneWidget,
      );
      expect(
        find.textContaining('const value = 1;', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('normalizes py language label to python', (tester) async {
      const markdown = '```py\nprint("hello")\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_python')),
        findsOneWidget,
      );
      expect(
        find.textContaining('print("hello")', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('normalizes yml language label to yaml', (tester) async {
      const markdown = '```yml\nname: ccpocket\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_yaml')),
        findsOneWidget,
      );
      expect(
        find.textContaining('name: ccpocket', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('hides language label when fence has no language', (
      tester,
    ) async {
      const markdown = '```\njust plain block\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      expect(
        find.byKey(const ValueKey('code_block_language_text')),
        findsNothing,
      );
      expect(
        find.textContaining('just plain block', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders compact header bar with language on left and copy button on right',
      (tester) async {
        const markdown = '```dart\nfinal value = 42;\n```';
        await tester.pumpWidget(
          _wrap(AssistantBubble(message: _messageWithText(markdown))),
        );

        final languageRect = tester.getRect(
          find.byKey(const ValueKey('code_block_language_dart')),
        );
        final copyRect = tester.getRect(
          find.byKey(const ValueKey('code_block_copy_button_dart')),
        );
        final codeRect = tester.getRect(
          find.textContaining('final value = 42;', findRichText: true),
        );

        expect(languageRect.left, lessThan(copyRect.left));
        expect(copyRect.height, lessThanOrEqualTo(34));
        expect(copyRect.bottom, lessThan(codeRect.top));
      },
    );
  });

  group('AssistantBubble copy behavior with code blocks', () {
    testWidgets('copy button copies only fenced code content', (tester) async {
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      const markdown = 'Before\n\n```bash\necho hello\n```\n\nAfter';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      await tester.tap(
        find.byKey(const ValueKey('code_block_copy_button_bash')),
      );
      await tester.pumpAndSettle();

      expect(clipboardContent, equals('echo hello'));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets(
      'copy buttons target their own code block when multiple exist',
      (tester) async {
        String? clipboardContent;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final args = methodCall.arguments as Map;
              clipboardContent = args['text'] as String?;
            }
            return null;
          },
        );

        const markdown =
            '```dart\nfinal one = 1;\n```\n\n```bash\necho target\n```';
        await tester.pumpWidget(
          _wrap(AssistantBubble(message: _messageWithText(markdown))),
        );

        await tester.tap(
          find.byKey(const ValueKey('code_block_copy_button_bash')),
        );
        await tester.pumpAndSettle();

        expect(clipboardContent, equals('echo target'));
        expect(find.text('Copied'), findsOneWidget);
      },
    );

    testWidgets('selectable code has no competing long-press ancestor', (
      tester,
    ) async {
      const markdown = '```bash\necho selectable text\n```';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      final codeBlock = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'code_block_container_bash_',
            ),
      );
      final selectable = find.descendant(
        of: codeBlock,
        matching: find.textContaining(
          'echo selectable text',
          findRichText: true,
        ),
      );
      expect(selectable, findsOneWidget);
      expect(
        find.ancestor(
          of: selectable,
          matching: find.byType(MarkdownSelectionScope),
        ),
        findsOneWidget,
      );
      final longPressAncestors = tester
          .widgetList<GestureDetector>(
            find.ancestor(
              of: selectable,
              matching: find.byType(GestureDetector),
            ),
          )
          .where((gesture) => gesture.onLongPress != null);

      expect(longPressAncestors, isEmpty);
    });

    testWidgets('copy button copies entire assistant text content', (
      tester,
    ) async {
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      const markdown = 'Before\n\n```bash\necho hello\n```\n\nAfter';
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _messageWithText(markdown))),
      );

      await tester.tap(find.byKey(const ValueKey('copy_button')));
      await tester.pumpAndSettle();

      expect(clipboardContent, equals(markdown));
      expect(find.text('Copied'), findsOneWidget);
    });
  });
}

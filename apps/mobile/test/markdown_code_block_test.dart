import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      expect(find.textContaining('final value = 42;'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
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
      expect(find.textContaining('echo hello'), findsOneWidget);
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
      expect(find.textContaining('const value = 1;'), findsOneWidget);
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
      expect(find.textContaining('print("hello")'), findsOneWidget);
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
      expect(find.textContaining('name: ccpocket'), findsOneWidget);
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
      expect(find.textContaining('just plain block'), findsOneWidget);
    });
  });

  group('AssistantBubble copy behavior with code blocks', () {
    testWidgets('long press on code block copies only fenced code content', (
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

      await tester.longPress(
        find.byKey(const ValueKey('code_block_copy_target_bash')),
      );
      await tester.pumpAndSettle();

      expect(clipboardContent, equals('echo hello'));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets(
      'long press copies only tapped code block when multiple exist',
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

        await tester.longPress(
          find.byKey(const ValueKey('code_block_copy_target_bash')),
        );
        await tester.pumpAndSettle();

        expect(clipboardContent, equals('echo target'));
        expect(find.text('Copied'), findsOneWidget);
      },
    );

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

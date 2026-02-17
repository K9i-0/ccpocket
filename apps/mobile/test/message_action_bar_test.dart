import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/message_action_bar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

AssistantServerMessage _textMessage(String text) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: 'msg-1',
      role: 'assistant',
      content: [TextContent(text: text)],
      model: 'claude-opus-4-5-20251101',
    ),
  );
}

AssistantServerMessage _toolOnlyMessage() {
  return const AssistantServerMessage(
    message: AssistantMessage(
      id: 'msg-2',
      role: 'assistant',
      content: [
        ToolUseContent(
          id: 'tu-1',
          name: 'Read',
          input: {'file_path': 'a.dart'},
        ),
      ],
      model: 'claude-opus-4-5-20251101',
    ),
  );
}

void _mockClipboard(WidgetTester tester, List<String?> captured) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments as Map;
        captured.add(args['text'] as String?);
      }
      return null;
    },
  );
}

void main() {
  group('MessageActionBar', () {
    testWidgets('renders copy, plain text toggle, and share buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(MessageActionBar(textToCopy: 'hello', onTogglePlainText: () {})),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('copy button copies text and shows snackbar', (tester) async {
      final captured = <String?>[];
      _mockClipboard(tester, captured);

      await tester.pumpWidget(
        _wrap(
          MessageActionBar(
            textToCopy: 'test content',
            onTogglePlainText: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('copy_button')));
      await tester.pumpAndSettle();

      expect(captured, contains('test content'));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('plain text toggle calls onTogglePlainText', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        _wrap(
          MessageActionBar(
            textToCopy: 'test',
            onTogglePlainText: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('plain_text_toggle')));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('toggle icon uses primary color when active', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MessageActionBar(
            textToCopy: 'test',
            isPlainTextMode: true,
            onTogglePlainText: () {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.text_fields));
      final primaryColor = AppTheme.darkTheme.colorScheme.primary;
      expect(icon.color, equals(primaryColor));
    });

    testWidgets('toggle icon uses subtleText color when inactive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageActionBar(
            textToCopy: 'test',
            isPlainTextMode: false,
            onTogglePlainText: () {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.text_fields));
      final subtleText = AppTheme.darkTheme.extension<AppColors>()!.subtleText;
      expect(icon.color, equals(subtleText));
    });
  });

  group('AssistantBubble with MessageActionBar', () {
    testWidgets('shows action bar when message has TextContent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _textMessage('Hello world'))),
      );

      expect(find.byType(MessageActionBar), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('does not show action bar for tool-only messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _toolOnlyMessage())),
      );

      expect(find.byType(MessageActionBar), findsNothing);
    });

    testWidgets('plain text toggle switches to SelectableText', (tester) async {
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _textMessage('# Hello'))),
      );

      // Initially shows MarkdownBody (not plain SelectableText)
      expect(find.byType(MarkdownBody), findsOneWidget);

      // Tap plain text toggle
      await tester.tap(find.byKey(const ValueKey('plain_text_toggle')));
      await tester.pumpAndSettle();

      // MarkdownBody is gone, raw markdown text visible in SelectableText
      expect(find.byType(MarkdownBody), findsNothing);
      expect(find.widgetWithText(SelectableText, '# Hello'), findsOneWidget);
    });

    testWidgets('plain text toggle switches back to MarkdownBody', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AssistantBubble(message: _textMessage('**Bold text**'))),
      );

      // Toggle ON → MarkdownBody disappears
      await tester.tap(find.byKey(const ValueKey('plain_text_toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsNothing);
      expect(
        find.widgetWithText(SelectableText, '**Bold text**'),
        findsOneWidget,
      );

      // Toggle OFF → MarkdownBody returns
      await tester.tap(find.byKey(const ValueKey('plain_text_toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('copy button copies all text content', (tester) async {
      final captured = <String?>[];
      _mockClipboard(tester, captured);

      final msg = AssistantServerMessage(
        message: AssistantMessage(
          id: 'msg-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'First'),
            const ToolUseContent(
              id: 'tu-1',
              name: 'Read',
              input: {'file_path': 'a.dart'},
            ),
            const TextContent(text: 'Second'),
          ],
          model: 'claude-opus-4-5-20251101',
        ),
      );

      await tester.pumpWidget(_wrap(AssistantBubble(message: msg)));

      await tester.tap(find.byKey(const ValueKey('copy_button')));
      await tester.pumpAndSettle();

      expect(captured.last, equals('First\n\nSecond'));
    });
  });
}

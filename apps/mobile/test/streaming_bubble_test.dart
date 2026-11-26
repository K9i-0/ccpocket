import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_spacing.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';
import 'package:ccpocket/widgets/bubbles/streaming_bubble.dart';
import 'package:ccpocket/widgets/bubbles/thinking_bubble.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

void main() {
  testWidgets('autolinks localhost URLs in streamed markdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StreamingBubble(
          text: 'open http://localhost:3013/dashboard',
        ),
      ),
    );

    final markdown = tester.widget<MarkdownView>(find.byType(MarkdownView));
    expect(
      markdown.parserOptions.inlineRules
          .whereType<SingleLabelHostAutolinkRule>(),
      isNotEmpty,
    );
  });

  testWidgets('coalesces rapid markdown updates and renders the latest text', (
    tester,
  ) async {
    var beforeTextUpdateCalls = 0;

    Future<void> pumpBubble(String text) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StreamingBubble(
            text: text,
            onBeforeTextUpdate: () => beforeTextUpdateCalls++,
          ),
        ),
      );
    }

    await pumpBubble('first');
    final initialTheme = tester
        .widget<MarkdownView>(find.byType(MarkdownView))
        .theme;

    await pumpBubble('first second');
    var markdown = tester.widget<MarkdownView>(find.byType(MarkdownView));
    expect(markdown.data, 'first');
    expect(markdown.theme, initialTheme);

    await tester.pump(const Duration(milliseconds: 12));
    await pumpBubble('first second latest');
    markdown = tester.widget<MarkdownView>(find.byType(MarkdownView));
    expect(markdown.data, 'first');
    expect(beforeTextUpdateCalls, 0);

    await tester.pump(const Duration(milliseconds: 20));
    markdown = tester.widget<MarkdownView>(find.byType(MarkdownView));
    expect(markdown.data, 'first second latest');
    expect(beforeTextUpdateCalls, 1);
  });

  testWidgets('renders a large delta immediately', (tester) async {
    final largeDelta = List.filled(128, 'x').join();

    Future<void> pumpBubble(String text) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StreamingBubble(text: text),
        ),
      );
    }

    await pumpBubble('first');
    await pumpBubble('first$largeDelta');

    final markdown = tester.widget<MarkdownView>(find.byType(MarkdownView));
    expect(markdown.data, 'first$largeDelta');
  });

  testWidgets('cancels a pending markdown update when disposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StreamingBubble(text: 'first'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StreamingBubble(text: 'second'),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 32));

    expect(tester.takeException(), isNull);
  });

  group('block-level markdown reuse', () {
    // Reuse one ThemeData so pumps model a stable app tree.
    final theme = AppTheme.lightTheme;

    Future<void> pumpBubble(WidgetTester tester, String text) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: StreamingBubble(text: text)),
          ),
        ),
      );
      // Flush the coalescing timer.
      await tester.pump(const Duration(milliseconds: 40));
    }

    List<MarkdownBlockRenderer> blocks(WidgetTester tester) => tester
        .widgetList<MarkdownBlockRenderer>(find.byType(MarkdownBlockRenderer))
        .where((b) => b.baseOffsetInBlock == 0 && b.listDepth == 0)
        .toList();

    testWidgets('only rebuilds the growing trailing block', (tester) async {
      const prefix =
          '# Title\n\nFirst paragraph.\n\n- one\n\n- two\n\n'
          '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n';
      var text = '${prefix}Grow';
      await pumpBubble(tester, text);
      markdownPerformanceProbe.reset();

      var previous = blocks(tester);
      expect(previous, hasLength(5));

      const updates = 6;
      for (var i = 0; i < updates; i++) {
        text = '$text ing$i';
        await pumpBubble(tester, text);
        final current = blocks(tester);
        expect(current, hasLength(previous.length));
        for (var b = 0; b < current.length - 1; b++) {
          expect(
            identical(current[b], previous[b]),
            isTrue,
            reason: 'completed block $b must be reused on update $i',
          );
        }
        expect(identical(current.last, previous.last), isFalse);
        previous = current;
      }

      expect(markdownPerformanceProbe.streamingBlockBuilds, updates);
      expect(
        markdownPerformanceProbe.streamingBlockReuses,
        greaterThanOrEqualTo(updates * 4),
      );
    });

    testWidgets('spaces blocks with MarkdownThemeData blockSpacing', (
      tester,
    ) async {
      await pumpBubble(tester, 'one\n\ntwo\n\nthree');

      expect(find.byType(MarkdownBlockRenderer), findsNWidgets(3));
      final column = tester.widget<Column>(
        find
            .ancestor(
              of: find.byType(MarkdownBlockRenderer).first,
              matching: find.byType(Column),
            )
            .first,
      );
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      expect(column.mainAxisSize, MainAxisSize.min);
      final mdTheme = tester
          .widget<MarkdownView>(find.byType(MarkdownView))
          .theme!;
      final spacers = column.children.whereType<SizedBox>().toList();
      expect(spacers, hasLength(2));
      for (final spacer in spacers) {
        expect(spacer.height, mdTheme.blockSpacing);
      }
    });

    testWidgets('rebuilds a block when an indented continuation arrives', (
      tester,
    ) async {
      await pumpBubble(tester, '- item\n\nnext');
      expect(find.text('next', findRichText: true), findsOneWidget);

      await pumpBubble(tester, '- item\n\n  continued');
      expect(find.text('continued', findRichText: true), findsOneWidget);
    });

    testWidgets('renders text with reference definitions cleanly', (
      tester,
    ) async {
      const text = 'See [docs][d].\n\nMore.\n\n[d]: https://example.com';
      await pumpBubble(tester, text);
      expect(
        find.textContaining('See docs.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('More.', findRichText: true), findsOneWidget);
    });

    testWidgets('lays out identically to non-streaming CcpocketMarkdown', (
      tester,
    ) async {
      const text =
          '# Title\n\nSome **bold** and `code`.\n\n- one\n\n- two\n\n'
          '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n'
          '| h | v |\n|---|---|\n| 1 | 2 |\n\n> quote\n\n---\n\nDone.';
      await pumpBubble(tester, text);
      final streamingSize = tester.getSize(find.byType(CcpocketMarkdown));

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppSpacing.bubbleMarginV,
                  horizontal: AppSpacing.bubbleMarginH,
                ),
                child: CcpocketMarkdown(data: text),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(CcpocketMarkdown)), streamingSize);
    });
  });

  group('streaming thinking display', () {
    testWidgets('renders ThinkingBubble with isStreaming while text is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: StreamingBubble(
              text: '',
              thinking: 'Line 1\n\nLine 2\nLine 3\n\n',
            ),
          ),
        ),
      );

      final thinkingBubble = tester.widget<ThinkingBubble>(
        find.byType(ThinkingBubble),
      );
      expect(thinkingBubble.isStreaming, isTrue);
      expect(find.text('Thinking...'), findsOneWidget);
      expect(find.text('Line 2\nLine 3'), findsOneWidget);
      expect(find.byType(CcpocketMarkdown), findsNothing);
    });

    testWidgets(
      'stops ThinkingBubble streaming indicator once text starts arriving',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: StreamingBubble(
                text: 'Answer starts here',
                thinking: 'Step 1\nStep 2\nStep 3',
              ),
            ),
          ),
        );

        final thinkingBubble = tester.widget<ThinkingBubble>(
          find.byType(ThinkingBubble),
        );
        expect(thinkingBubble.isStreaming, isFalse);
        expect(find.text('Thinking'), findsOneWidget);
        expect(find.byType(CcpocketMarkdown), findsOneWidget);
      },
    );

    test(
      'buildThinkingPreview shows tail 2 non-empty lines while streaming',
      () {
        const thinking = 'first line\n\nsecond line\n   \nthird line\n\n';
        expect(
          buildThinkingPreview(thinking, isStreaming: true),
          'second line\nthird line',
        );
        expect(
          buildThinkingPreview('a' * 100, isStreaming: false),
          '${'a' * 80}...',
        );
      },
    );
  });
}

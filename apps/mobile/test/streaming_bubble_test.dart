import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_spacing.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';
import 'package:ccpocket/widgets/bubbles/streaming_bubble.dart';
import 'package:ccpocket/widgets/link_hover_underline.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

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

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(
      markdown.inlineSyntaxes!.whereType<SingleLabelHostAutolinkSyntax>(),
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
    final initialStyle = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet;

    await pumpBubble('first second');
    var markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first');
    expect(identical(markdown.styleSheet, initialStyle), isTrue);

    await tester.pump(const Duration(milliseconds: 12));
    await pumpBubble('first second latest');
    markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first');
    expect(beforeTextUpdateCalls, 0);

    await tester.pump(const Duration(milliseconds: 20));
    markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
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

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
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

    List<MarkdownBody> bodies(WidgetTester tester) =>
        tester.widgetList<MarkdownBody>(find.byType(MarkdownBody)).toList();

    testWidgets('only rebuilds the growing trailing block', (tester) async {
      const prefix =
          '# Title\n\nFirst paragraph.\n\n- one\n\n- two\n\n'
          '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n';
      var text = '${prefix}Grow';
      await pumpBubble(tester, text);
      markdownPerformanceProbe.reset();

      var previous = bodies(tester);
      expect(previous.map((b) => b.data), [
        '# Title\n\n',
        'First paragraph.\n\n',
        '- one\n\n- two\n\n',
        '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n',
        'Grow',
      ]);

      const updates = 6;
      for (var i = 0; i < updates; i++) {
        text = '$text ing$i';
        await pumpBubble(tester, text);
        final current = bodies(tester);
        expect(current, hasLength(previous.length));
        for (var b = 0; b < current.length - 1; b++) {
          expect(
            identical(current[b], previous[b]),
            isTrue,
            reason: 'completed block $b must be reused on update $i',
          );
        }
        expect(current.last.data, text.substring(prefix.length));
        expect(identical(current.last, previous.last), isFalse);
        previous = current;
      }

      expect(markdownPerformanceProbe.streamingBlockBuilds, updates);
      expect(
        markdownPerformanceProbe.streamingBlockReuses,
        greaterThanOrEqualTo(updates * 4),
      );
    });

    testWidgets('spaces blocks like MarkdownBody block spacing', (
      tester,
    ) async {
      await pumpBubble(tester, 'one\n\ntwo\n\nthree');

      expect(find.byType(MarkdownBody), findsNWidgets(3));
      final column = tester.widget<Column>(
        find
            .ancestor(
              of: find.byType(MarkdownBody).first,
              matching: find.byType(Column),
            )
            .first,
      );
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      expect(column.mainAxisSize, MainAxisSize.min);
      final style = bodies(tester).first.styleSheet!;
      final spacers = column.children.whereType<SizedBox>().toList();
      expect(spacers, hasLength(2));
      for (final spacer in spacers) {
        expect(spacer.height, style.blockSpacing);
      }
    });

    testWidgets('rebuilds a block when an indented continuation arrives', (
      tester,
    ) async {
      await pumpBubble(tester, '- item\n\nnext');
      var current = bodies(tester);
      expect(current.map((b) => b.data), ['- item\n\n', 'next']);

      await pumpBubble(tester, '- item\n\n  continued');
      current = bodies(tester);
      expect(current.map((b) => b.data), ['- item\n\n  continued']);
    });

    testWidgets('renders text with reference definitions as one block', (
      tester,
    ) async {
      const text = 'See [docs][d].\n\nMore.\n\n[d]: https://example.com';
      await pumpBubble(tester, text);
      expect(bodies(tester).single.data, text);
    });

    testWidgets('lays out like a single MarkdownBody of the same text', (
      tester,
    ) async {
      const text =
          '# Title\n\nSome **bold** and `code`.\n\n- one\n\n- two\n\n'
          '```dart\nfinal a = 1;\n\nfinal b = 2;\n```\n\n'
          '| h | v |\n|---|---|\n| 1 | 2 |\n\n> quote\n\n---\n\nDone.';
      await pumpBubble(tester, text);
      expect(find.byType(MarkdownBody), findsNWidgets(8));
      final split = tester.getSize(find.byType(LinkHoverUnderline));

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubbleMarginV,
                  horizontal: AppSpacing.bubbleMarginH,
                ),
                child: Builder(
                  builder: (context) => LinkHoverUnderline(
                    child: MarkdownBody(
                      data: text,
                      styleSheet: buildMarkdownStyle(context),
                      inlineSyntaxes: [
                        ...colorCodeInlineSyntaxes,
                        ...localhostAutolinkInlineSyntaxes,
                      ],
                      builders: markdownBuilders,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(LinkHoverUnderline)), split);
    });
  });
}

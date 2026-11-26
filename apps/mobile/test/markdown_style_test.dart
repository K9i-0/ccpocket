import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SingleLabelHostAutolinkRule', () {
    final parser = GfmMarkdownParser(
      options: const MarkdownParserOptions(
        inlineRules: localhostAutolinkInlineRules,
      ),
    );

    List<MarkdownInline> parseInlines(String source) {
      final doc = parser.parse(source);
      return (doc.blocks.single as ParagraphBlock).inlines;
    }

    List<LinkInline> linksIn(String source) {
      final result = <LinkInline>[];
      void visit(List<MarkdownInline> nodes) {
        for (final node in nodes) {
          switch (node) {
            case LinkInline():
              result.add(node);
            case EmphasisInline(:final children):
            case StrongInline(:final children):
            case StrikethroughInline(:final children):
            case UnderlineInline(:final children):
            case SubscriptInline(:final children):
            case SuperscriptInline(:final children):
            case KeyboardInline(:final children):
              visit(children);
            default:
              break;
          }
        }
      }

      visit(parseInlines(source));
      return result;
    }

    test('links localhost URLs with a port and path', () {
      final inlines = parseInlines('open http://localhost:3013/dashboard now');
      expect(inlines, [
        const TextInline('open '),
        const LinkInline(
          destination: 'http://localhost:3013/dashboard',
          children: [TextInline('http://localhost:3013/dashboard')],
          isAutolink: true,
        ),
        const TextInline(' now'),
      ]);
    });

    test('links bare localhost and other single-label hosts', () {
      final links = linksIn(
        'http://localhost and https://devbox:8443/?q=1#top',
      );
      expect(links.map((l) => l.destination).toList(), [
        'http://localhost',
        'https://devbox:8443/?q=1#top',
      ]);
    });

    test('excludes trailing punctuation and unbalanced parentheses', () {
      final wrapped = parseInlines('(see http://localhost:3013/dashboard).');
      expect(wrapped, [
        const TextInline('(see '),
        const LinkInline(
          destination: 'http://localhost:3013/dashboard',
          children: [TextInline('http://localhost:3013/dashboard')],
          isAutolink: true,
        ),
        const TextInline(').'),
      ]);

      final sentence = parseInlines('Go to http://localhost.');
      expect(sentence, [
        const TextInline('Go to '),
        const LinkInline(
          destination: 'http://localhost',
          children: [TextInline('http://localhost')],
          isAutolink: true,
        ),
        const TextInline('.'),
      ]);
    });

    test('leaves dotted domains to the GFM autolink extension', () {
      final links = linksIn('https://example.com:8080/x');
      expect(links, hasLength(1));
      expect(links.single.destination, 'https://example.com:8080/x');
    });

    test('does not link inside inline code or explicit links', () {
      final codeInlines = parseInlines('`http://localhost:3000`');
      expect(codeInlines, [const InlineCodeInline('http://localhost:3000')]);

      final explicitLinks = linksIn('[app](http://localhost:3000)');
      expect(explicitLinks, hasLength(1));
      expect(explicitLinks.single.destination, 'http://localhost:3000');
      expect(extractInlineRenderedText(explicitLinks.single), 'app');
    });

    test('does not turn an invalid authority into a partial link', () {
      for (final source in [
        'http://localhost:123456/path',
        'http://localhost:abc/path',
        'http://user@localhost/path',
      ]) {
        expect(linksIn(source), isEmpty, reason: source);
      }
    });

    test(
      'preserves uppercase schemes, query strings and balanced parentheses',
      () {
        const url = 'HTTP://localhost:3000/path(a)?x=1&y=2#result';
        final inlines = parseInlines(url);
        expect(inlines, hasLength(1));
        final link = inlines.single as LinkInline;
        expect(link.destination, url);
        expect(extractInlineRenderedText(link), url);
      },
    );

    test('does not create nested links in an explicit link label', () {
      final links = linksIn('[http://localhost:3000](https://example.com)');
      expect(links, hasLength(1));
      expect(links.single.destination, 'https://example.com');
      expect(links.single.children, [
        const TextInline('http://localhost:3000'),
      ]);
    });

    test('does not link when glued to a preceding word', () {
      expect(linksIn('xhttp://localhost:3000'), isEmpty);
    });
  });

  group('buildMarkdownTheme & CcpocketMarkdown', () {
    testWidgets(
      'uses subtle neutral pill background for inline code in light and dark themes',
      (tester) async {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          late MarkdownThemeData resolvedTheme;
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: theme,
              home: Builder(
                builder: (context) {
                  resolvedTheme = buildMarkdownTheme(context);
                  return const CcpocketMarkdown(
                    data:
                        'before **strong_text** `inline_code` *em_text* after',
                  );
                },
              ),
            ),
          );

          final codeBg = resolvedTheme.inlineCodeStyle.backgroundColor;
          expect(codeBg.a, greaterThan(0));
          expect(codeBg.a, lessThan(0.15));
          expect(resolvedTheme.inlineCodeStyle.fontWeight, FontWeight.w500);

          final richText = tester.widget<RichText>(
            find.bySubtype<RichText>().first,
          );
          final inlineCodeSpan = _findCodeTextSpan(
            richText.text,
            'inline_code',
          );
          expect(inlineCodeSpan, isNotNull);
          expect(inlineCodeSpan!.style?.fontWeight, FontWeight.w500);

          final strongSpan = _findTextSpan(richText.text, 'strong_text');
          final baseStyle = theme.textTheme.bodyMedium!;
          expect(strongSpan, isNotNull);
          expect(strongSpan!.style?.fontWeight, FontWeight.w700);
          expect(strongSpan.style?.fontFamily, baseStyle.fontFamily);

          final emphasisSpan = _findTextSpan(richText.text, 'em_text');
          expect(emphasisSpan, isNotNull);
          expect(emphasisSpan!.style?.fontStyle, FontStyle.italic);

          // Native hover underline style retires LinkHoverUnderline.
          expect(
            resolvedTheme.linkHoverStyle.decoration,
            TextDecoration.underline,
          );

          // Checked task-list checkboxes use theme primary / onPrimary so they
          // remain crisp and high-contrast in both light and dark themes.
          expect(
            resolvedTheme.listCheckboxFillColor,
            theme.colorScheme.primary,
          );
          expect(
            resolvedTheme.listCheckboxCheckColor,
            theme.colorScheme.onPrimary,
          );
        }
      },
    );
  });

  group('highlightToTextSpans', () {
    setUp(() {
      resetHighlightCacheForTesting();
      markdownPerformanceProbe.reset();
    });

    testWidgets(
      'falls back safely when TypeScript syntax highlighting throws',
      (tester) async {
        await initializeMarkdownSyntaxHighlight();

        final source = '''
/**
 * Formats a value for display.
 */
export const formatValue = (value: string): string => value.trim();
''';

        late List<TextSpan> spans;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                spans = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: const TextStyle(),
                  language: 'typescript',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(_flattenText(spans), source);
      },
    );

    testWidgets(
      'includes fontFamily, fontSize, and color in highlight cache key',
      (tester) async {
        late List<TextSpan> first;
        late List<TextSpan> second;
        late List<TextSpan> third;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                const source = 'echo hello';
                first = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  language: 'bash',
                );
                second = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: const TextStyle(
                    fontFamily: 'IoskeleyMono',
                    fontSize: 16,
                    color: Colors.amber,
                  ),
                  language: 'bash',
                );
                third = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: const TextStyle(
                    fontFamily: 'IoskeleyMono',
                    fontSize: 16,
                    color: Colors.amber,
                  ),
                  language: 'bash',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(identical(first, second), isFalse);
        expect(identical(second, third), isTrue);
        expect(highlightCacheLengthForTesting, 2);
      },
    );

    testWidgets(
      'isolates unclosed streaming code blocks from the shared LRU cache',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                // Completed block populates shared LRU cache.
                highlightToTextSpans(
                  context: context,
                  source: 'final done = 1;',
                  baseStyle: const TextStyle(fontSize: 12),
                  language: 'dart',
                  isStreaming: false,
                );
                // Many incremental streaming tokens do NOT pollute shared LRU.
                for (var i = 0; i < 100; i++) {
                  highlightToTextSpans(
                    context: context,
                    source: 'final streaming = $i;',
                    baseStyle: const TextStyle(fontSize: 12),
                    language: 'dart',
                    isStreaming: true,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(highlightCacheLengthForTesting, 1);
      },
    );
  });
}

CodeTextSpan? _findCodeTextSpan(InlineSpan span, String text) {
  if (span is CodeTextSpan && span.text == text) return span;
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _findCodeTextSpan(child, text);
      if (found != null) return found;
    }
  }
  return null;
}

TextSpan? _findTextSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text) return span;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _findTextSpan(child, text);
      if (found != null) return found;
    }
  }
  return null;
}

String _flattenText(List<TextSpan> spans) {
  final buffer = StringBuffer();

  void visit(TextSpan span) {
    if (span.text != null) {
      buffer.write(span.text);
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) {
        visit(child);
      }
    }
  }

  for (final span in spans) {
    visit(span);
  }

  return buffer.toString();
}

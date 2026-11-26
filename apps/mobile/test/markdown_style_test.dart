import 'package:ccpocket/features/file_peek/file_peek_sheet.dart';
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
      'highlights TypeScript with JSDoc cleanly and preserves exact text',
      (tester) async {
        const source = '''
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
                  baseStyle: const TextStyle(color: Color(0xFF18181B)),
                  language: 'typescript',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(_flattenText(spans), source);
        expect(spans.length, greaterThan(1));
        expect(_distinctColors(spans).length, greaterThan(2));
      },
    );

    testWidgets(
      'applies distinct light and dark token palettes aligned with theme brightness',
      (tester) async {
        const source = '''
// Greet user
final greeting = 'hello';
int count = 42;
''';
        const baseStyle = TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: Color(0xFF888888),
        );

        late List<TextSpan> lightSpans;
        late List<TextSpan> darkSpans;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                lightSpans = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: baseStyle,
                  language: 'dart',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                darkSpans = highlightToTextSpans(
                  context: context,
                  source: source,
                  baseStyle: baseStyle,
                  language: 'dart',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(_flattenText(lightSpans), source);
        expect(_flattenText(darkSpans), source);

        final lightKeyword = _findSpanContaining(lightSpans, 'final');
        final darkKeyword = _findSpanContaining(darkSpans, 'final');
        final lightString = _findSpanContaining(lightSpans, "'hello'");
        final darkString = _findSpanContaining(darkSpans, "'hello'");
        final lightComment = _findSpanContaining(lightSpans, '// Greet user');
        final darkComment = _findSpanContaining(darkSpans, '// Greet user');

        expect(lightKeyword?.style?.color, isNot(baseStyle.color));
        expect(darkKeyword?.style?.color, isNot(baseStyle.color));
        expect(lightKeyword?.style?.color, isNot(darkKeyword?.style?.color));
        expect(lightString?.style?.color, isNot(darkString?.style?.color));
        expect(lightComment?.style?.fontStyle, FontStyle.italic);
        expect(darkComment?.style?.fontStyle, FontStyle.italic);
        expect(lightKeyword?.style?.fontFamily, 'JetBrainsMono');
        expect(darkKeyword?.style?.fontSize, 13);
        expect(highlightCacheLengthForTesting, 2);
      },
    );

    testWidgets(
      'preserves exact source length across common languages and aliases',
      (tester) async {
        const samples = <String, String>{
          'dart': 'class Foo { final int x = 1; }\n',
          'ts': 'export type Id = string | number;\n',
          'tsx': 'export const App = () => <div>Hello</div>;\n',
          'js': 'const fn = (a) => a + 1;\n',
          'jsx': 'const el = <span className="a">ok</span>;\n',
          'py': 'def greet(name: str) -> str:\n    return f"hi {name}"\n',
          'sh': '#!/usr/bin/env bash\necho "hello"\n',
          'zsh': 'export PATH="\$HOME/bin:\$PATH"\n',
          'json': '{"key": [1, true, null, "val"]}\n',
          'yml': 'name: ccpocket\nversion: 1\n',
          'toml': '[package]\nname = "ccpocket"\n',
          'html': '<div class="card"><p>Text</p></div>\n',
          'css': '.card { color: #fff; padding: 8px; }\n',
          'rs': 'fn main() { println!("hi"); }\n',
          'go': 'package main\nfunc main() {}\n',
          'java': 'public class A { static int x = 0; }\n',
          'kt': 'data class User(val name: String)\n',
          'swift': 'struct Point { let x: Int }\n',
          'sql': 'SELECT id, name FROM users WHERE active = 1;\n',
          'c': 'int main(void) { return 0; }\n',
          'cpp': 'std::vector<int> v{1, 2, 3};\n',
          'csharp': 'public record Item(string Name);\n',
          'ruby': 'def hello(name)\n  puts name\nend\n',
          'php': '<?php echo "hello"; ?>\n',
          'markdown': '# Heading\n\n- **bold** and `code`\n',
          'diff': '--- a/file\n+++ b/file\n-old\n+new\n',
          'dockerfile': 'FROM node:22-alpine\nRUN npm ci\n',
          'objc': '@interface Foo : NSObject\n@end\n',
        };

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                for (final entry in samples.entries) {
                  final spans = highlightToTextSpans(
                    context: context,
                    source: entry.value,
                    baseStyle: const TextStyle(color: Colors.white),
                    language: entry.key,
                  );
                  expect(
                    _flattenText(spans),
                    entry.value,
                    reason: 'Exact text mismatch for ${entry.key}',
                  );
                  expect(
                    _distinctColors(spans).length,
                    greaterThan(1),
                    reason: 'Expected highlighted tokens for ${entry.key}',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );

    testWidgets(
      'falls back cleanly to plain baseStyle for unknown, plain, or oversized code',
      (tester) async {
        const baseStyle = TextStyle(fontSize: 13, color: Colors.white);
        late List<TextSpan> unknownSpans;
        late List<TextSpan> plainSpans;
        late List<TextSpan> oversizedSpans;
        final oversizedSource = List.filled(6001, 'a').join();

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                unknownSpans = highlightToTextSpans(
                  context: context,
                  source: 'some unknown syntax 123',
                  baseStyle: baseStyle,
                  language: 'nonexistent_lang_xyz',
                );
                plainSpans = highlightToTextSpans(
                  context: context,
                  source: 'plain text',
                  baseStyle: baseStyle,
                  language: 'plaintext',
                );
                oversizedSpans = highlightToTextSpans(
                  context: context,
                  source: oversizedSource,
                  baseStyle: baseStyle,
                  language: 'dart',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(unknownSpans, hasLength(1));
        expect(unknownSpans.single.text, 'some unknown syntax 123');
        expect(unknownSpans.single.style, baseStyle);

        expect(plainSpans, hasLength(1));
        expect(plainSpans.single.text, 'plain text');
        expect(plainSpans.single.style, baseStyle);

        expect(oversizedSpans, hasLength(1));
        expect(oversizedSpans.single.text, oversizedSource);
        expect(markdownPerformanceProbe.highlightSkipped, 1);
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
            key: UniqueKey(),
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
      'isolates unclosed streaming code blocks from the shared LRU cache and hits streaming slot',
      (tester) async {
        late List<TextSpan> streamFirst;
        late List<TextSpan> streamHit;

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
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
                  streamFirst = highlightToTextSpans(
                    context: context,
                    source: 'final streaming = $i;',
                    baseStyle: const TextStyle(fontSize: 12),
                    language: 'dart',
                    isStreaming: true,
                  );
                }
                // Re-querying the latest streaming snapshot hits the single-slot cache.
                streamHit = highlightToTextSpans(
                  context: context,
                  source: 'final streaming = 99;',
                  baseStyle: const TextStyle(fontSize: 12),
                  language: 'dart',
                  isStreaming: true,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(highlightCacheLengthForTesting, 1);
        expect(identical(streamFirst, streamHit), isTrue);
        expect(markdownPerformanceProbe.highlightCacheHits, 1);
      },
    );
  });

  group('FilePeekCode syntax highlighting', () {
    setUp(() {
      resetHighlightCacheForTesting();
    });

    testWidgets(
      'renders highlighted multi-line code and preserves single-token highlight styles',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: FilePeekCode(
                  content: '// comment only',
                  language: 'dart',
                  controller: controller,
                ),
              ),
            ),
          ),
        );

        final commentText = tester.widget<Text>(
          find.byKey(const ValueKey('file_peek_code_content')),
        );
        expect(commentText.textSpan!.toPlainText(), '// comment only');
        final commentSpan = _findTextSpan(
          commentText.textSpan!,
          '// comment only',
        );
        expect(commentSpan, isNotNull);
        expect(commentSpan!.style?.fontStyle, FontStyle.italic);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: FilePeekCode(
                  content: 'final a = 1;\nfinal b = "two";',
                  language: 'dart',
                  controller: controller,
                ),
              ),
            ),
          ),
        );

        final multiLineText = tester.widget<Text>(
          find.byKey(const ValueKey('file_peek_code_content')),
        );
        expect(
          multiLineText.textSpan!.toPlainText(),
          'final a = 1;\nfinal b = "two";',
        );
      },
    );
  });
}

Set<Color?> _distinctColors(List<TextSpan> spans) {
  final colors = <Color?>{};
  void visit(TextSpan span) {
    if (span.text != null && span.text!.trim().isNotEmpty) {
      colors.add(span.style?.color);
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) visit(child);
    }
  }

  for (final span in spans) {
    visit(span);
  }
  return colors;
}

TextSpan? _findSpanContaining(List<TextSpan> spans, String text) {
  for (final span in spans) {
    final found = _findTextSpan(span, text);
    if (found != null) return found;
  }
  return null;
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

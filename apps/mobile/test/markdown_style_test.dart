import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SingleLabelHostAutolinkSyntax', () {
    String render(String source) => md.markdownToHtml(
      source,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: localhostAutolinkInlineSyntaxes,
    );

    test('links localhost URLs with a port and path', () {
      expect(
        render('open http://localhost:3013/dashboard now'),
        '<p>open <a href="http://localhost:3013/dashboard">'
        'http://localhost:3013/dashboard</a> now</p>\n',
      );
    });

    test('links bare localhost and other single-label hosts', () {
      expect(
        render('http://localhost and https://devbox:8443/?q=1#top'),
        '<p><a href="http://localhost">http://localhost</a> and '
        '<a href="https://devbox:8443/?q=1#top">'
        'https://devbox:8443/?q=1#top</a></p>\n',
      );
    });

    test('excludes trailing punctuation and unbalanced parentheses', () {
      expect(
        render('(see http://localhost:3013/dashboard).'),
        '<p>(see <a href="http://localhost:3013/dashboard">'
        'http://localhost:3013/dashboard</a>).</p>\n',
      );
      expect(
        render('Go to http://localhost.'),
        '<p>Go to <a href="http://localhost">http://localhost</a>.</p>\n',
      );
    });

    test('leaves dotted domains to the GFM autolink extension', () {
      expect(
        render('https://example.com:8080/x'),
        '<p><a href="https://example.com:8080/x">'
        'https://example.com:8080/x</a></p>\n',
      );
    });

    test('does not link inside inline code or explicit links', () {
      expect(
        render('`http://localhost:3000`'),
        '<p><code>http://localhost:3000</code></p>\n',
      );
      expect(
        render('[app](http://localhost:3000)'),
        '<p><a href="http://localhost:3000">app</a></p>\n',
      );
    });

    test('does not turn an invalid authority into a partial link', () {
      for (final source in [
        'http://localhost:123456/path',
        'http://localhost:abc/path',
        'http://user@localhost/path',
      ]) {
        expect(render(source), '<p>$source</p>\n', reason: source);
      }
    });

    test(
      'preserves uppercase schemes, query strings and balanced parentheses',
      () {
        final document = md.Document(
          extensionSet: md.ExtensionSet.gitHubFlavored,
          inlineSyntaxes: localhostAutolinkInlineSyntaxes,
          encodeHtml: false,
        );
        const url = 'HTTP://localhost:3000/path(a)?x=1&y=2#result';
        final link = document.parseInline(url).single as md.Element;
        expect(link.tag, 'a');
        expect(link.attributes['href'], url);
        expect(link.textContent, url);
      },
    );

    test('does not create nested links in an explicit link label', () {
      expect(
        render('[http://localhost:3000](https://example.com)'),
        '<p><a href="https://example.com">http://localhost:3000</a></p>\n',
      );
    });

    test('does not link when glued to a preceding word', () {
      expect(
        render('xhttp://localhost:3000'),
        '<p>xhttp://localhost:3000</p>\n',
      );
    });
  });

  group('buildMarkdownStyle', () {
    testWidgets(
      'uses text emphasis without inline code background after package merge',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                return MarkdownBody(
                  data: 'before **strong_text** `inline_code` *em_text* after',
                  selectable: true,
                  styleSheet: buildMarkdownStyle(context),
                );
              },
            ),
          ),
        );

        final selectableText = tester.widget<SelectableText>(
          find.byType(SelectableText).first,
        );
        final inlineCodeSpan = _findTextSpan(
          selectableText.textSpan!,
          'inline_code',
        );

        expect(inlineCodeSpan, isNotNull);
        expect(inlineCodeSpan!.style?.backgroundColor, Colors.transparent);
        expect(inlineCodeSpan.style?.fontWeight, FontWeight.w600);

        final strongSpan = _findTextSpan(
          selectableText.textSpan!,
          'strong_text',
        );
        final baseStyle = AppTheme.lightTheme.textTheme.bodyMedium!;
        final expectedStrongStyle = GoogleFonts.ibmPlexSans(
          textStyle: baseStyle,
          fontWeight: FontWeight.w700,
        );

        expect(strongSpan, isNotNull);
        expect(strongSpan!.style?.fontWeight, FontWeight.w700);
        expect(strongSpan.style?.fontFamily, expectedStrongStyle.fontFamily);
        expect(strongSpan.style?.fontFamily, isNot(baseStyle.fontFamily));

        final emphasisSpan = _findTextSpan(selectableText.textSpan!, 'em_text');
        expect(emphasisSpan, isNotNull);
        expect(emphasisSpan!.style?.fontStyle, FontStyle.italic);
      },
    );
  });

  group('highlightToTextSpans', () {
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
  });
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

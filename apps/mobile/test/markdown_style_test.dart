import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

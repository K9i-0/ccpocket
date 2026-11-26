import 'package:markdown_kit/markdown_kit.dart';

/// Writes a [MarkdownDocument] as the HTML the CommonMark reference renderer
/// would produce, so the specification's examples can be compared against the
/// AST. Constructs outside CommonMark (alerts, details, math, footnotes) get a
/// tag of their own, which never matches a specification example.
String documentToHtml(MarkdownDocument document) {
  final buffer = StringBuffer();
  _writeBlocks(document.blocks, buffer, tight: false);
  return buffer.toString();
}

void _writeBlocks(
  List<MarkdownBlock> blocks,
  StringBuffer out, {
  required bool tight,
}) {
  for (final block in blocks) {
    switch (block) {
      case ParagraphBlock(:final inlines):
        if (tight) {
          _writeInlines(inlines, out);
          out.write('\n');
        } else {
          out.write('<p>');
          _writeInlines(inlines, out);
          out.write('</p>\n');
        }
      case HeadingBlock(:final level, :final inlines):
        out.write('<h$level>');
        _writeInlines(inlines, out);
        out.write('</h$level>\n');
      case CodeBlock(:final code, :final language):
        out.write('<pre><code');
        if (language != null && language.isNotEmpty) {
          out.write(' class="language-${_escape(language)}"');
        }
        out.write('>${_escape(code)}');
        if (code.isNotEmpty) out.write('\n');
        out.write('</code></pre>\n');
      case BlockquoteBlock(:final children):
        out.write('<blockquote>\n');
        _writeBlocks(children, out, tight: false);
        out.write('</blockquote>\n');
      case AlertBlock(:final kind, :final children):
        out.write('<alert kind="${kind.name}">\n');
        _writeBlocks(children, out, tight: false);
        out.write('</alert>\n');
      case ListBlock(:final ordered, :final start, :final items):
        final tag = ordered ? 'ol' : 'ul';
        out.write('<$tag');
        if (ordered && start != 1) out.write(' start="$start"');
        out.write('>\n');
        for (final item in items) {
          out.write('<li>');
          if (item.checked != null) {
            out.write(
              '<input type="checkbox"${item.checked! ? ' checked' : ''}>',
            );
          }
          final inner = StringBuffer();
          _writeBlocks(item.children, inner, tight: block.tight);
          var text = inner.toString();
          final startsWithBlockTag =
              item.children.isNotEmpty &&
              !(block.tight && item.children.first is ParagraphBlock);
          if (startsWithBlockTag) out.write('\n');
          if (block.tight &&
              item.children.isNotEmpty &&
              item.children.last is ParagraphBlock &&
              text.endsWith('\n')) {
            text = text.substring(0, text.length - 1);
          }
          out.write(text);
          out.write('</li>\n');
        }
        out.write('</$tag>\n');
      case TableBlock(:final header, :final rows):
        out.write('<table>\n<thead>\n<tr>\n');
        for (final cell in header.cells) {
          out.write('<th>');
          _writeInlines(cell, out);
          out.write('</th>\n');
        }
        out.write('</tr>\n</thead>\n');
        if (rows.isNotEmpty) {
          out.write('<tbody>\n');
          for (final row in rows) {
            out.write('<tr>\n');
            for (final cell in row.cells) {
              out.write('<td>');
              _writeInlines(cell, out);
              out.write('</td>\n');
            }
            out.write('</tr>\n');
          }
          out.write('</tbody>\n');
        }
        out.write('</table>\n');
      case ThematicBreakBlock():
        out.write('<hr />\n');
      case HtmlDetailsBlock(:final summary, :final children):
        out.write('<details><summary>');
        _writeInlines(summary, out);
        out.write('</summary>\n');
        _writeBlocks(children, out, tight: false);
        out.write('</details>\n');
      case FootnoteDefinitionsBlock(:final definitions):
        for (final definition in definitions) {
          out.write('<footnote label="${_escape(definition.label)}">\n');
          _writeBlocks(definition.children, out, tight: false);
          out.write('</footnote>\n');
        }
      case BlockLatexBlock(:final expression):
        out.write('<math display="block">${_escape(expression)}</math>\n');
    }
  }
}

void _writeInlines(List<MarkdownInline> inlines, StringBuffer out) {
  for (final inline in inlines) {
    switch (inline) {
      case TextInline(:final text):
        out.write(_escape(text));
      case EmphasisInline(:final children):
        _wrap('em', children, out);
      case StrongInline(:final children):
        _wrap('strong', children, out);
      case StrikethroughInline(:final children):
        _wrap('del', children, out);
      case UnderlineInline(:final children):
        _wrap('u', children, out);
      case SubscriptInline(:final children):
        _wrap('sub', children, out);
      case SuperscriptInline(:final children):
        _wrap('sup', children, out);
      case KeyboardInline(:final children):
        _wrap('kbd', children, out);
      case InlineCodeInline(:final code):
        out.write('<code>${_escape(code)}</code>');
      case LinkInline(:final destination, :final title, :final children):
        out.write('<a href="${_escape(destination)}"');
        if (title != null) out.write(' title="${_escape(title)}"');
        out.write('>');
        _writeInlines(children, out);
        out.write('</a>');
      case ImageInline(:final source, :final alt, :final title):
        out.write('<img src="${_escape(source)}" alt="${_escape(alt)}"');
        if (title != null) out.write(' title="${_escape(title)}"');
        out.write(' />');
      case LineBreakInline(:final isHard):
        out.write(isHard ? '<br />\n' : '\n');
      case FootnoteRefInline(:final label):
        out.write('<sup class="footnote">${_escape(label)}</sup>');
      case InlineLatexInline(:final expression):
        out.write('<math>${_escape(expression)}</math>');
      case CustomInline(:final text):
        out.write(_escape(text));
    }
  }
}

void _wrap(String tag, List<MarkdownInline> children, StringBuffer out) {
  out.write('<$tag>');
  _writeInlines(children, out);
  out.write('</$tag>');
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Removes differences that carry no meaning: line breaks around tags and
/// leading/trailing whitespace. Text inside tags is left alone.
String normalizeHtml(String html) {
  return html
      .replaceAll(RegExp(r'>\s*\n\s*<'), '><')
      .replaceAll(RegExp(r'\n(?=</(?:li|p|h[1-6]|td|th)>)'), '')
      .trim();
}

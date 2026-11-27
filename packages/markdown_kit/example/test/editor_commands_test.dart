import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit_example/editor/markdown_editing.dart';
import 'package:markdown_kit_example/editor/markdown_highlight.dart';
import 'package:markdown_kit_example/editor/scroll_sync.dart';

/// `|` marks the caret; two of them mark a selection.
TextEditingValue _value(String marked) {
  final first = marked.indexOf('|');
  final second = marked.indexOf('|', first + 1);
  final text = marked.replaceAll('|', '');
  return TextEditingValue(
    text: text,
    selection: second < 0
        ? TextSelection.collapsed(offset: first)
        : TextSelection(baseOffset: first, extentOffset: second - 1),
  );
}

String _marked(TextEditingValue value) {
  final selection = value.selection;
  if (selection.isCollapsed) {
    return value.text.replaceRange(selection.start, selection.start, '|');
  }
  return value.text
      .replaceRange(selection.end, selection.end, '|')
      .replaceRange(selection.start, selection.start, '|');
}

void main() {
  group('toggleInline', () {
    test('wraps the selection and keeps it selected', () {
      expect(
        _marked(toggleInline(_value('a |word| b'), '**')),
        'a **|word|** b',
      );
    });

    test('unwraps a selection inside its markers', () {
      expect(
        _marked(toggleInline(_value('a **|word|** b'), '**')),
        'a |word| b',
      );
    });

    test('unwraps a selection that includes its markers', () {
      expect(
        _marked(toggleInline(_value('a |**word**| b'), '**')),
        'a |word| b',
      );
    });

    test('with only a caret, leaves it between an empty pair', () {
      expect(_marked(toggleInline(_value('a | b'), '`')), 'a `|` b');
    });

    test('italic does not mistake the stars of bold for its own', () {
      expect(_marked(toggleInline(_value('**|word|**'), '*')), '***|word|***');
      expect(_marked(toggleInline(_value('***|word|***'), '*')), '**|word|**');
    });
  });

  group('toggleLineStyle', () {
    test('adds and removes a bullet on the caret line', () {
      final added = toggleLineStyle(_value('one\ntw|o'), LineStyle.bullet);
      expect(_marked(added), 'one\n- tw|o');
      expect(_marked(toggleLineStyle(added, LineStyle.bullet)), 'one\ntw|o');
    });

    test('numbers the selected lines in order and skips blank ones', () {
      expect(
        _marked(toggleLineStyle(_value('|a\nb\n\nc|'), LineStyle.ordered)),
        '|1. a\n2. b\n\n3. c|',
      );
    });

    test('changes one kind of list into another', () {
      expect(
        _marked(toggleLineStyle(_value('- a|'), LineStyle.task)),
        '- [ ] a|',
      );
      expect(
        _marked(toggleLineStyle(_value('- [ ] a|'), LineStyle.ordered)),
        '1. a|',
      );
    });

    test('a quote goes around a list item rather than replacing it', () {
      final quoted = toggleLineStyle(_value('- a|'), LineStyle.quote);
      expect(_marked(quoted), '> - a|');
      expect(_marked(toggleLineStyle(quoted, LineStyle.quote)), '- a|');
    });

    test('a selection ending at a line start leaves that line alone', () {
      expect(
        _marked(toggleLineStyle(_value('|a\n|b'), LineStyle.bullet)),
        '|- a|\nb',
      );
    });
  });

  test('cycleHeading goes through three levels and back to none', () {
    var value = _value('Ti|tle');
    final seen = <String>[];
    for (var i = 0; i < 4; i++) {
      value = cycleHeading(value);
      seen.add(_marked(value));
    }
    expect(seen, ['# Ti|tle', '## Ti|tle', '### Ti|tle', 'Ti|tle']);
  });

  test('insertLink selects the part still to be typed', () {
    expect(_marked(insertLink(_value('see |docs|'))), 'see [docs](|https://|)');
    expect(_marked(insertLink(_value('see |'))), 'see [|text|](https://)');
  });

  test('insertCodeBlock fences the selected lines', () {
    expect(
      _marked(insertCodeBlock(_value('before\n\na|b\n\nafter'))),
      'before\n\n```|\nab\n```\n\nafter',
    );
  });

  group('indentLines', () {
    test('indents and outdents a list item', () {
      final indented = indentLines(_value('- a\n- b|'));
      expect(_marked(indented), '- a\n  - b|');
      expect(_marked(indentLines(indented, outdent: true)), '- a\n- b|');
    });

    test('outside a list a caret gets two spaces', () {
      expect(_marked(indentLines(_value('ab|c'))), 'ab  |c');
    });
  });

  group('continueOnEnter', () {
    TextEditingValue? enter(String marked) {
      final before = _value(marked);
      final caret = before.selection.start;
      final after = TextEditingValue(
        text: before.text.replaceRange(caret, before.selection.end, '\n'),
        selection: TextSelection.collapsed(offset: caret + 1),
      );
      return continueOnEnter(before, after);
    }

    test('continues a bullet, a number, a task and a quote', () {
      expect(_marked(enter('- one|')!), '- one\n- |');
      expect(_marked(enter('3. three|')!), '3. three\n4. |');
      expect(_marked(enter('- [x] done|')!), '- [x] done\n- [ ] |');
      expect(_marked(enter('> said|')!), '> said\n> |');
    });

    test('keeps the indentation of a nested item', () {
      expect(_marked(enter('- a\n  - b|')!), '- a\n  - b\n  - |');
    });

    test('an empty item ends the list', () {
      expect(_marked(enter('- one\n- |')!), '- one\n|');
    });

    test('plain text is left alone', () {
      expect(enter('just text|'), isNull);
    });

    test('inside a code fence only the indentation is kept', () {
      expect(_marked(enter('```\n  - x|')!), '```\n  - x\n  |');
      expect(enter('```\n- x|'), isNull);
    });

    test('other edits are left alone', () {
      final before = _value('- one|');
      final typed = before.copyWith(
        text: '- one!',
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(continueOnEnter(before, typed), isNull);
    });
  });

  test('caretLineAndColumn and countWords', () {
    expect(caretLineAndColumn(_value('ab\ncd|e')), (line: 2, column: 3));
    expect(countWords('one  two\nthree'), 3);
    expect(countWords(''), 0);
  });

  group('scanMarkdown', () {
    Map<String, SyntaxKind> scan(String source) => {
      for (final token in scanMarkdown(source))
        source.substring(token.start, token.end): token.kind,
    };

    test('tokens are in order and do not overlap', () {
      const source =
          '# Title\n\n> - [ ] **bold** and `code`\n\n```dart\nx();\n```\n'
          '[link](https://example.com) *em* ~~gone~~ <br>\n---\n';
      var end = 0;
      for (final token in scanMarkdown(source)) {
        expect(token.start, greaterThanOrEqualTo(end));
        expect(token.end, greaterThan(token.start));
        end = token.end;
      }
      expect(end, lessThanOrEqualTo(source.length));
    });

    test('recognises what a writer looks for', () {
      final kinds = scan(
        '## Title\n- item **bold** *em* `code` [label](address)\n'
        '```\n# not a heading\n```\n',
      );
      expect(kinds['##'], SyntaxKind.marker);
      expect(kinds[' Title'], SyntaxKind.heading);
      expect(kinds['-'], SyntaxKind.listMarker);
      expect(kinds['bold'], SyntaxKind.strong);
      expect(kinds['em'], SyntaxKind.emphasis);
      expect(kinds['`code`'], SyntaxKind.code);
      expect(kinds['label'], SyntaxKind.linkLabel);
      expect(kinds['address'], SyntaxKind.linkAddress);
      expect(kinds['# not a heading'], SyntaxKind.codeBlock);
    });
  });

  group('scroll anchors', () {
    const anchors = <SyncAnchor>[
      (source: 0, preview: 0),
      (source: 100, preview: 300),
      (source: 200, preview: 400),
    ];

    test('interpolates between neighbours in both directions', () {
      expect(mapScrollOffset(50, anchors, fromSource: true), 150);
      expect(mapScrollOffset(150, anchors, fromSource: true), 350);
      expect(mapScrollOffset(350, anchors, fromSource: false), 150);
    });

    test('clamps outside the anchors and passes through without any', () {
      expect(mapScrollOffset(-10, anchors, fromSource: true), 0);
      expect(mapScrollOffset(999, anchors, fromSource: true), 400);
      expect(mapScrollOffset(42, const [], fromSource: true), 42);
    });

    test('the ends are added so both sides reach their bottom together', () {
      final bounded = boundSyncAnchors(
        const [(source: 40, preview: 90), (source: 120, preview: 500)],
        sourceMax: 200,
        previewMax: 600,
      );
      expect(bounded.first, (source: 0.0, preview: 0.0));
      expect(bounded.last, (source: 200.0, preview: 600.0));
      expect(bounded, hasLength(4));
    });

    test('anchors past either end or out of order are dropped', () {
      final bounded = boundSyncAnchors(
        const [
          (source: 40, preview: 90),
          (source: 30, preview: 120),
          (source: 150, preview: 700),
        ],
        sourceMax: 200,
        previewMax: 600,
      );
      expect(bounded, const [
        (source: 0.0, preview: 0.0),
        (source: 40.0, preview: 90.0),
        (source: 200.0, preview: 600.0),
      ]);
    });
  });
}

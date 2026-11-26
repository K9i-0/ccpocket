// Widget-level streaming behaviour of MarkdownView.
//
// Provenance (behaviours mined by name from the reference suites, rewritten
// against markdown_kit's API):
// - gpt_markdown regression/streaming_no_layout_jumps_test.dart (high)
// - gpt_markdown regression/streaming_semantics_test.dart (high)
// - gpt_markdown streaming/streaming_markdown_test.dart "the settled prefix
//   is not rebuilt as text arrives", "settled content never moves ...",
//   "replacing the text restarts ..." (high)
// - gpt_markdown streaming/block_entrance_streaming_test.dart "a fence label
//   never shows half its language", "a closing fence never flashes as a stray
//   backtick", "a table enters with all its rows" (medium)
// - gpt_markdown regression/render_work_reuse_test.dart (medium)
// - flutter_md widget/painter_reuse_test.dart "a streamed document paints
//   what a fresh painter paints" (medium)
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _app({
  required Widget child,
  Size size = const Size(420, 680),
  ui.TextDirection dir = ui.TextDirection.ltr,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: scaler),
      child: FocusScope(
        autofocus: true,
        child: _OverlayShell(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OverlayShell extends StatefulWidget {
  const _OverlayShell({required this.child});

  final Widget child;

  @override
  State<_OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<_OverlayShell> {
  late final ValueNotifier<Widget> _child = ValueNotifier<Widget>(widget.child);
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => ValueListenableBuilder<Widget>(
      valueListenable: _child,
      builder: (_, child, _) => child,
    ),
  );

  @override
  void didUpdateWidget(covariant _OverlayShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child.value = widget.child;
  }

  @override
  void dispose() {
    _child.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

RenderSelectableParagraph? _maybePara(WidgetTester tester, String substring) {
  for (final ro in tester.allRenderObjects) {
    if (ro is RenderSelectableParagraph &&
        ro.text.toPlainText().contains(substring)) {
      return ro;
    }
  }
  return null;
}

RenderSelectableParagraph _para(WidgetTester tester, String substring) =>
    _maybePara(tester, substring) ??
    fail('No RenderSelectableParagraph containing "$substring".');

List<String> _allParagraphTexts(WidgetTester tester) => [
  for (final ro in tester.allRenderObjects)
    if (ro is RenderSelectableParagraph) ro.text.toPlainText(),
];

List<String> _drain(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add(e.toString().split('\n').take(3).join(' / '));
  }
  return out;
}

Finder _block(String docId, int index) =>
    find.byKey(ValueKey<String>('$docId:$index'));

int _blockCount(WidgetTester tester, String docId) {
  var n = 0;
  while (_block(docId, n).evaluate().isNotEmpty) {
    n++;
  }
  return n;
}

const _reply = '''
# Streaming reply

First paragraph with **bold** text and `code` in it.

- alpha item
- beta item
  - nested item

Second paragraph that is long enough to wrap onto more than one line at this width.

```dart
void main() {
  print('hi');
}
```

> a quoted line

1. one
2. two

Closing words.''';

void main() {
  group('settled blocks', () {
    testWidgets('appending text never rebuilds a block that was already '
        'followed by another one', (tester) async {
      final built = <int>[];
      final reused = <int>[];
      var previousCount = 0;
      for (var i = 1; i <= _reply.length; i++) {
        built.clear();
        reused.clear();
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'settled',
              data: _reply.substring(0, i),
              isStreaming: true,
              onBlockBuilt: (index, _) => built.add(index),
              onBlockReused: (index, _) => reused.add(index),
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: 'prefix $i: $errors');
        final settledBoundary = previousCount - 1;
        expect(
          built.where((index) => index < settledBoundary),
          isEmpty,
          reason:
              'prefix $i (${_reply.substring(0, i).split('\n').last}) rebuilt '
              'settled blocks; built=$built, previous count=$previousCount',
        );
        previousCount = _blockCount(tester, 'settled');
        expect(built.length + reused.length, previousCount);
      }
      expect(previousCount, 8);
    });

    testWidgets(
      'a settled block keeps its render object while the tail grows',
      (tester) async {
        const head = 'Opening paragraph.\n\n';
        const tail = 'The tail keeps growing one character at a time.';
        await tester.pumpWidget(
          _app(
            child: const MarkdownView(
              documentId: 'identity',
              data: '${head}T',
              isStreaming: true,
            ),
          ),
        );
        final opening = _para(tester, 'Opening paragraph.');
        final tailRender = _para(tester, 'T');
        for (var i = 2; i <= tail.length; i++) {
          await tester.pumpWidget(
            _app(
              child: MarkdownView(
                documentId: 'identity',
                data: head + tail.substring(0, i),
                isStreaming: true,
              ),
            ),
          );
          expect(
            identical(_para(tester, 'Opening paragraph.'), opening),
            isTrue,
          );
        }
        // The growing tail is updated in place rather than remounted.
        expect(identical(_para(tester, 'The tail keeps'), tailRender), isTrue);
      },
    );

    testWidgets('settled blocks never move while later text arrives', (
      tester,
    ) async {
      var previous = <Rect>[];
      for (var i = 1; i <= _reply.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'jumps',
              data: _reply.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        final count = _blockCount(tester, 'jumps');
        final rects = [
          for (var b = 0; b < count; b++) tester.getRect(_block('jumps', b)),
        ];
        // Every block that already had a successor in the previous frame is
        // settled and must be exactly where it was.
        for (var b = 0; b < previous.length - 1 && b < rects.length; b++) {
          expect(
            rects[b],
            previous[b],
            reason:
                'block $b moved at prefix $i '
                '(${_reply.substring(0, i).split('\n').last})',
          );
        }
        previous = rects;
      }
    });

    testWidgets('a reply made of prose and code never gets shorter', (
      tester,
    ) async {
      const text =
          'First paragraph of prose that wraps over a couple of lines here.\n\n'
          'Second paragraph follows.\n\n'
          '```\nline one\nline two\n```\n\n'
          'Final paragraph.';
      var previousHeight = 0.0;
      for (var i = 1; i <= text.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'shrink',
              data: text.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        final height = tester.getSize(find.byType(MarkdownView)).height;
        expect(
          height,
          greaterThanOrEqualTo(previousHeight),
          reason:
              'shrank at prefix $i '
              '(${text.substring(0, i).split('\n').last})',
        );
        previousHeight = height;
      }
    });

    testWidgets('a scrolled code block keeps its offset while text arrives', (
      tester,
    ) async {
      final code = '```\n${'z' * 120}\n```\n\n';
      Future<void> pumpTail(String tail) => tester.pumpWidget(
        _app(
          child: MarkdownView(
            documentId: 'code-scroll',
            data: '$code$tail',
            isStreaming: true,
          ),
        ),
      );
      await pumpTail('a');
      final scroller = find.descendant(
        of: _block('code-scroll', 0),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroller, const Offset(-300, 0));
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(of: scroller, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;
      final scrolled = offset();
      expect(scrolled, greaterThan(100.0));
      for (final tail in ['ab', 'abc def', 'abc def\n\nnew block']) {
        await pumpTail(tail);
        expect(offset(), scrolled);
      }
    });
  });

  group('every prefix', () {
    const rich = '''
# Title with `code`

Text with *emphasis*, **strong**, ~~strike~~, [a link](https://x.example "t"),
an image ![alt](pic.png), a footnote[^n], <kbd>Ctrl</kbd> and \\(x^2\\).

| Name | Value |
| :--- | ---: |
| a | 1 |
| b | 2 |

- [ ] open task
- [x] done task
  1. nested one
  2. nested two

> [!WARNING]
> Careful **here**.

<details>
<summary>More</summary>

Hidden body.

</details>

~~~python
print("tilde fence")
~~~

\\[ a^2 + b^2 = c^2 \\]

---

[^n]: The footnote text.
''';

    testWidgets('renders without errors at every prefix of a rich reply', (
      tester,
    ) async {
      for (var i = 0; i <= rich.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'every-prefix',
              data: rich.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        final errors = _drain(tester);
        expect(
          errors,
          isEmpty,
          reason:
              'prefix $i (${rich.substring(0, i).split('\n').last}): $errors',
        );
      }
    });

    testWidgets('renders without errors at every prefix in a narrow RTL view '
        'at 2x', (tester) async {
      for (var i = 0; i <= rich.length; i += 3) {
        await tester.pumpWidget(
          _app(
            dir: ui.TextDirection.rtl,
            size: const Size(260, 680),
            scaler: const TextScaler.linear(2),
            child: MarkdownView(
              documentId: 'every-prefix-rtl',
              data: rich.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        final errors = _drain(tester);
        expect(errors, isEmpty, reason: 'prefix $i: $errors');
      }
    });

    testWidgets('the finished stream renders what a fresh view renders', (
      tester,
    ) async {
      for (var i = 0; i <= rich.length; i += 5) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'converge',
              data: rich.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
      }
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(documentId: 'converge', data: rich),
        ),
      );
      final streamedTexts = _allParagraphTexts(tester);
      final streamedSize = tester.getSize(find.byType(MarkdownView));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(documentId: 'converge-fresh', data: rich),
        ),
      );
      expect(streamedTexts, _allParagraphTexts(tester));
      expect(streamedSize, tester.getSize(find.byType(MarkdownView)));
    });
  });

  group('code fences while streaming', () {
    const fenced = 'Lead.\n\n```dart\nprint(1);\nprint(2);\n```\n\nAfter.';

    testWidgets('no prefix of a fenced block ever shows a backtick', (
      tester,
    ) async {
      for (var i = 1; i <= fenced.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'fence-ticks',
              data: fenced.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        final withTicks = _allParagraphTexts(tester)
            .where((t) => t.contains('`'))
            .toList();
        expect(
          withTicks,
          isEmpty,
          reason: 'prefix $i ${fenced.substring(0, i).split('\n').last}',
        );
        expect(find.textContaining('`'), findsNothing, reason: 'prefix $i');
      }
    });

    testWidgets('the language label never shows half of its name', (
      tester,
    ) async {
      final labels = <String>{};
      for (var i = 1; i <= fenced.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'fence-label',
              data: fenced.substring(0, i),
              isStreaming: true,
              builders: MarkdownBuilders(
                codeBlockBuilder: (context, block, content, theme) {
                  labels.add(block.language ?? '');
                  return content;
                },
              ),
            ),
          ),
        );
      }
      expect(labels, {'dart'});
    });

    testWidgets('an open fence is a code block with closed == false, and '
        'closes when the fence ends', (tester) async {
      final states = <int, bool>{};
      for (var i = 1; i <= fenced.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'fence-open',
              data: fenced.substring(0, i),
              isStreaming: true,
              builders: MarkdownBuilders(
                codeBlockBuilder: (context, block, content, theme) {
                  states[i] = block.closed;
                  return content;
                },
              ),
            ),
          ),
        );
        final fenceOpened = i >= fenced.indexOf('```dart\n') + 8;
        if (fenceOpened) {
          expect(
            _allParagraphTexts(tester).any((t) => t.contains('dart')),
            isFalse,
            reason: 'info string leaked as text at prefix $i',
          );
        }
      }
      final closeAt = fenced.indexOf('```\n\nAfter') + 3;
      final openStates = states.entries.where((e) => e.key < closeAt);
      final closedStates = states.entries.where((e) => e.key >= closeAt + 1);
      expect(openStates, isNotEmpty);
      expect(openStates.every((e) => e.value == false), isTrue);
      expect(closedStates.every((e) => e.value == true), isTrue);
    });

    testWidgets('code lines appear as they arrive inside one block', (
      tester,
    ) async {
      const open = '```\nfirst line\nsecond';
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'fence-grow',
            data: open,
            isStreaming: true,
          ),
        ),
      );
      final code = _para(tester, 'first line');
      expect(code.text.toPlainText(), contains('second'));
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'fence-grow',
            data: '$open line\nthird',
            isStreaming: true,
          ),
        ),
      );
      expect(identical(_para(tester, 'first line'), code), isTrue);
      expect(code.text.toPlainText(), contains('third'));
      expect(_blockCount(tester, 'fence-grow'), 1);
    });
  });

  group('tables while streaming', () {
    testWidgets('a table appears once its delimiter row is complete and then '
        'only grows', (tester) async {
      const text =
          '| Name | Qty |\n| --- | --- |\n| apple | 3 |\n| pear | 4 |\n';
      var seenTable = false;
      var previousRows = 0;
      for (var i = 1; i <= text.length; i++) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'table-stream',
              data: text.substring(0, i),
              isStreaming: true,
            ),
          ),
        );
        expect(_drain(tester), isEmpty, reason: 'prefix $i');
        final tables = find.byType(Table).evaluate();
        if (tables.isNotEmpty) {
          seenTable = true;
          final rows = (tables.single.widget as Table).children.length;
          expect(rows, greaterThanOrEqualTo(previousRows), reason: 'prefix $i');
          previousRows = rows;
        } else {
          expect(seenTable, isFalse, reason: 'table vanished at prefix $i');
        }
      }
      expect(seenTable, isTrue);
      expect(previousRows, 3);
    });
  });

  group('streaming to final', () {
    testWidgets('finishing the stream with the same text rebuilds nothing', (
      tester,
    ) async {
      final built = <int>[];
      Widget build({required bool streaming}) => _app(
        child: MarkdownView(
          documentId: 'finish',
          data: _reply,
          isStreaming: streaming,
          onBlockBuilt: (index, _) => built.add(index),
        ),
      );
      await tester.pumpWidget(build(streaming: true));
      final before = [
        for (final ro in tester.allRenderObjects)
          if (ro is RenderSelectableParagraph) ro,
      ];
      final size = tester.getSize(find.byType(MarkdownView));
      built.clear();
      await tester.pumpWidget(build(streaming: false));
      final after = [
        for (final ro in tester.allRenderObjects)
          if (ro is RenderSelectableParagraph) ro,
      ];
      expect(built, isEmpty);
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(identical(after[i], before[i]), isTrue, reason: 'paragraph $i');
      }
      expect(tester.getSize(find.byType(MarkdownView)), size);
    });

    testWidgets('finishing on an unclosed fence keeps the code block', (
      tester,
    ) async {
      const data = 'Lead.\n\n```dart\nprint(1);';
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'finish-open',
            data: data,
            isStreaming: true,
          ),
        ),
      );
      final code = _para(tester, 'print(1);');
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(documentId: 'finish-open', data: data),
        ),
      );
      expect(_drain(tester), isEmpty);
      expect(identical(_para(tester, 'print(1);'), code), isTrue);
      expect(find.textContaining('```', findRichText: true), findsNothing);
    });

    testWidgets('replacing the whole text shows only the new reply', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'replace',
            data: '# Old title\n\nOld body\n\n- old item',
            isStreaming: true,
          ),
        ),
      );
      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'replace',
            data: 'New',
            isStreaming: true,
          ),
        ),
      );
      expect(_allParagraphTexts(tester), ['New']);
      expect(_blockCount(tester, 'replace'), 1);

      await tester.pumpWidget(
        _app(
          child: const MarkdownView(
            documentId: 'replace',
            data: '',
            isStreaming: true,
          ),
        ),
      );
      expect(_allParagraphTexts(tester), isEmpty);
      expect(_drain(tester), isEmpty);
    });

    testWidgets('a stream that restarts shorter drops the stale tail blocks', (
      tester,
    ) async {
      final built = <int>[];
      Future<void> pump(String data) => tester.pumpWidget(
        _app(
          child: MarkdownView(
            documentId: 'restart',
            data: data,
            isStreaming: true,
            onBlockBuilt: (index, _) => built.add(index),
          ),
        ),
      );
      await pump('one\n\ntwo\n\nthree\n\nfour');
      built.clear();
      await pump('one\n\ntwo');
      expect(built, isEmpty);
      expect(_allParagraphTexts(tester), ['one', 'two']);
      await pump('one\n\ntwo\n\nTHREE');
      expect(built, [2]);
      expect(_allParagraphTexts(tester), ['one', 'two', 'THREE']);
    });
  });

  group('semantics while streaming', () {
    List<String> labels(WidgetTester tester) {
      SemanticsNode root = tester.getSemantics(find.byType(MarkdownView));
      while (root.parent != null) {
        root = root.parent!;
      }
      final out = <String>[];
      void visit(SemanticsNode n) {
        if (n.label.isNotEmpty) out.add(n.label);
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(root);
      return out;
    }

    testWidgets('nothing that is visible is hidden from the screen reader '
        'while the reply arrives', (tester) async {
      final handle = tester.ensureSemantics();
      const text =
          '# Heading here\n\nFirst paragraph.\n\n- item one\n- item two\n\n'
          'Last paragraph with [a link](https://s.example).';
      for (var i = 4; i <= text.length; i += 4) {
        await tester.pumpWidget(
          _app(
            child: MarkdownView(
              documentId: 'a11y-stream',
              data: text.substring(0, i),
              isStreaming: true,
              builders: MarkdownBuilders(onLinkTap: (_, _) {}),
            ),
          ),
        );
        await tester.pump();
        // Labels are split per link, so compare with whitespace removed.
        final spoken = labels(tester).join().replaceAll(RegExp(r'\s+'), '');
        for (final visible in _allParagraphTexts(tester)) {
          expect(
            spoken,
            contains(visible.replaceAll(RegExp(r'\s+'), '')),
            reason: 'prefix $i: "$visible" is drawn but not announced',
          );
        }
      }
      handle.dispose();
    });

    testWidgets('a settled reply exposes each block and its link action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          child: MarkdownView(
            data:
                '# Heading here\n\nFirst paragraph.\n\n- item one\n\n'
                'See [a link](https://s.example).',
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await tester.pump();
      final spoken = labels(tester);
      expect(spoken.any((l) => l.contains('Heading here')), isTrue);
      expect(spoken.any((l) => l.contains('First paragraph.')), isTrue);
      expect(spoken.any((l) => l.contains('item one')), isTrue);
      tester.semantics.tap(find.semantics.byLabel('a link'));
      expect(taps, ['https://s.example']);
      handle.dispose();
    });

    testWidgets('a link becomes activatable as soon as it has finished '
        'arriving', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = <String>[];
      const text = 'See [the link](https://late.example) now.';
      Future<void> pump(int length) => tester.pumpWidget(
        _app(
          child: MarkdownView(
            documentId: 'a11y-link',
            data: text.substring(0, length),
            isStreaming: true,
            builders: MarkdownBuilders(onLinkTap: (url, _) => taps.add(url)),
          ),
        ),
      );
      await pump(text.indexOf(']'));
      await tester.pump();
      expect(find.semantics.byLabel('the link'), findsNothing);
      await pump(text.indexOf(')') + 1);
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel('the link'));
      expect(taps, ['https://late.example']);
      handle.dispose();
    });
  });
}

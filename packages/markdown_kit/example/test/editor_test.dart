import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit_example/editor.dart';
import 'package:markdown_kit_example/editor/sample_document.dart';
import 'package:markdown_kit_example/editor/scroll_sync.dart';

const _wide = Size(1200, 800);
const _narrow = Size(400, 800);

Future<void> _pump(
  WidgetTester tester, {
  String text = sampleDocument,
  Size size = _wide,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(EditorApp(initialText: text));
  await tester.pump();
}

EditableTextState _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText));

ScrollController _scroll(WidgetTester tester, String key) => tester
    .widget<SingleChildScrollView>(
      find.byKey(ValueKey(key), skipOffstage: false),
    )
    .controller!;

Finder _preview(String text) => find.descendant(
  of: find.byType(MarkdownView),
  matching: find.textContaining(text, findRichText: true),
);

String _long() => [
  for (var i = 0; i < 40; i++)
    '## Section $i\n\nParagraph $i with enough words to take up a line or '
        'two of the preview.\n\n- item a$i\n- item b$i\n',
].join('\n');

void main() {
  testWidgets('shows the source and its preview side by side', (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(_editable(tester).textEditingValue.text, sampleDocument);
    expect(_preview('Markdown editor'), findsWidgets);
    final source = tester.getRect(find.byType(EditableText));
    final preview = tester.getRect(find.byType(MarkdownView));
    expect(source.right, lessThan(preview.left));
  });

  testWidgets('typing updates the preview and the status bar', (tester) async {
    await _pump(tester, text: 'Start.\n');
    await tester.enterText(find.byType(EditableText), '# Hello\n\nNew *text*.');
    await tester.pump();
    expect(_preview('Hello'), findsOneWidget);
    expect(_preview('New text.'), findsOneWidget);
    final status = tester.widget<Text>(find.byKey(const ValueKey('status')));
    expect(status.data, contains('2 blocks'));
    expect(status.data, contains('4 words'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the source is coloured without changing its text', (
    tester,
  ) async {
    await _pump(tester, text: '# Title\n\n- **bold** `code`\n');
    final editable = _editable(tester);
    final span = editable.buildTextSpan();
    expect(span.toPlainText(), '# Title\n\n- **bold** `code`\n');
    final weights = <String, FontWeight?>{};
    span.visitChildren((child) {
      if (child is TextSpan && child.text != null) {
        weights[child.text!] = child.style?.fontWeight;
      }
      return true;
    });
    expect(weights['bold'], FontWeight.w700);
    expect(weights[' Title'], FontWeight.w700);
  });

  testWidgets('a toolbar button changes the selection and keeps focus', (
    tester,
  ) async {
    await _pump(tester, text: 'make this bold');
    final editable = _editable(tester);
    editable.widget.controller.selection = const TextSelection(
      baseOffset: 5,
      extentOffset: 9,
    );
    await tester.tap(find.byKey(const ValueKey('tool-bold')));
    await tester.pump();
    expect(editable.textEditingValue.text, 'make **this** bold');
    expect(
      editable.textEditingValue.selection,
      const TextSelection(baseOffset: 7, extentOffset: 11),
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);
    expect(_preview('this'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tool-bold')));
    await tester.pump();
    expect(editable.textEditingValue.text, 'make this bold');
  });

  testWidgets('Enter continues a list as it is typed', (tester) async {
    await _pump(tester, text: '');
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '- one',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '- one\n',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    expect(_editable(tester).textEditingValue.text, '- one\n- ');
    expect(_editable(tester).textEditingValue.selection.baseOffset, 8);
  });

  testWidgets('keyboard shortcuts format and indent', (tester) async {
    await _pump(tester, text: '- word');
    final editable = _editable(tester);
    await tester.showKeyboard(find.byType(EditableText));
    editable.widget.controller.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 6,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(editable.textEditingValue.text, '- **word**');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(editable.textEditingValue.text, '  - **word**');
  });

  testWidgets('scrolling the source moves the preview, and back', (
    tester,
  ) async {
    await _pump(tester, text: _long());
    final source = _scroll(tester, 'source-scroll');
    final preview = _scroll(tester, 'preview-scroll');
    expect(preview.offset, 0);

    source.jumpTo(source.position.maxScrollExtent / 2);
    await tester.pump();
    final middle = preview.offset;
    expect(middle, greaterThan(0));
    expect(middle, lessThan(preview.position.maxScrollExtent));

    // The block at the top of the preview is the one whose source is at the
    // top of the editor.
    final editable = _editable(tester).renderEditable;
    final topOfSource = editable.getPositionForPoint(
      tester.getRect(find.byKey(const ValueKey('source-scroll'))).topLeft +
          const Offset(30, 24),
    );
    final text = _editable(tester).textEditingValue.text;
    final section = RegExp(r'## Section (\d+)')
        .allMatches(text.substring(0, topOfSource.offset))
        .last
        .group(1)!;
    final previewTop = tester.getRect(
      find.byKey(const ValueKey('preview-scroll')),
    );
    final heading = tester.getRect(_preview('Section $section').first);
    expect(heading.top, lessThan(previewTop.top + 200));
    expect(heading.bottom, greaterThan(previewTop.top - 200));

    source.jumpTo(source.position.maxScrollExtent);
    await tester.pump();
    expect(preview.offset, preview.position.maxScrollExtent);

    preview.jumpTo(0);
    await tester.pump();
    expect(source.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with Sync off each side scrolls on its own', (tester) async {
    await _pump(tester, text: _long());
    await tester.tap(find.byKey(const ValueKey('sync-scroll')));
    await tester.pump();
    final source = _scroll(tester, 'source-scroll');
    final preview = _scroll(tester, 'preview-scroll');
    source.jumpTo(source.position.maxScrollExtent);
    await tester.pump();
    expect(preview.offset, 0);

    await tester.tap(find.byKey(const ValueKey('sync-scroll')));
    await tester.pump();
    expect(preview.offset, preview.position.maxScrollExtent);
  });

  testWidgets('tapping a block in the preview puts the caret in its source', (
    tester,
  ) async {
    const text = '# One\n\nSecond block.\n\nThird block.\n';
    await _pump(tester, text: text);
    await tester.tap(_preview('Third block.'));
    await tester.pump();
    final selection = _editable(tester).textEditingValue.selection;
    expect(selection, TextSelection.collapsed(offset: text.indexOf('Third')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the block the caret is in is marked in the preview', (
    tester,
  ) async {
    const text = '# One\n\nSecond block.\n\nThird block.\n';
    await _pump(tester, text: text);
    final blocks = tester
        .widget<PreviewBlock>(find.byType(PreviewBlock).first)
        .blocks;
    _editable(tester).widget.controller.selection = TextSelection.collapsed(
      offset: text.indexOf('Second') + 3,
    );
    await tester.pump();
    expect(blocks.active, (first: 1, last: 1));
    expect(blocks.boxOf(1), isA<RenderBox>());
  });

  testWidgets('a document with reference links is still followed block by '
      'block', (tester) async {
    // Such a document is parsed in one piece; its ranges come from a second
    // look at the chunks.
    final text =
        '${_long()}\nSee [the site][site].\n\n[site]: https://pub.dev\n';
    await _pump(tester, text: text);
    final blocks = tester
        .widget<PreviewBlock>(find.byType(PreviewBlock).first)
        .blocks;
    _editable(tester).widget.controller.selection = TextSelection.collapsed(
      offset: text.indexOf('Paragraph 3 '),
    );
    await tester.pump();
    final active = blocks.active!;
    expect(active.first, active.last);
    expect(active.first, greaterThan(0));

    final source = _scroll(tester, 'source-scroll');
    final preview = _scroll(tester, 'preview-scroll');
    source.jumpTo(source.position.maxScrollExtent / 2);
    await tester.pump();
    final viewport = tester.getRect(
      find.byKey(const ValueKey('preview-scroll')),
    );
    final editable = _editable(tester).renderEditable;
    final top = editable.getPositionForPoint(
      tester.getRect(find.byKey(const ValueKey('source-scroll'))).topLeft +
          const Offset(30, 24),
    );
    final section = RegExp(r'## Section (\d+)')
        .allMatches(text.substring(0, top.offset))
        .last
        .group(1)!;
    final heading = tester.getRect(_preview('Section $section').first);
    expect(preview.offset, greaterThan(0));
    expect(heading.top, lessThan(viewport.top + 200));
    expect(heading.bottom, greaterThan(viewport.top - 200));
  });

  testWidgets('typing far down brings the preview to the edited block', (
    tester,
  ) async {
    final text = _long();
    await _pump(tester, text: text);
    final controller = _editable(tester).widget.controller;
    await tester.showKeyboard(find.byType(EditableText));
    final at = text.indexOf('Paragraph 30') + 'Paragraph 30'.length;
    controller.selection = TextSelection.collapsed(offset: at);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text.replaceRange(at, at, ' EDITED'),
        selection: TextSelection.collapsed(offset: at + 7),
      ),
    );
    await tester.pump();
    await tester.pump();
    final viewport = tester.getRect(
      find.byKey(const ValueKey('preview-scroll')),
    );
    final edited = tester.getRect(_preview('EDITED'));
    expect(edited.top, greaterThanOrEqualTo(viewport.top));
    expect(edited.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('a narrow screen shows one pane and switches between them', (
    tester,
  ) async {
    await _pump(tester, text: '# Title\n\nBody text.\n', size: _narrow);
    expect(tester.takeException(), isNull);
    expect(find.byType(EditableText), findsOneWidget);
    expect(_preview('Body text.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('show-preview')));
    await tester.pump();
    expect(_preview('Body text.'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);

    // Text typed before the switch is still there after switching back.
    await tester.tap(find.byKey(const ValueKey('show-preview')));
    await tester.pump();
    expect(_editable(tester).textEditingValue.text, '# Title\n\nBody text.\n');
  });

  testWidgets('going from wide to narrow keeps the text and caret', (
    tester,
  ) async {
    await _pump(tester, text: 'keep me');
    final state = _editable(tester);
    state.widget.controller.selection = const TextSelection.collapsed(
      offset: 4,
    );
    tester.view.physicalSize = _narrow;
    await tester.pump();
    expect(identical(_editable(tester), state), isTrue);
    expect(_editable(tester).textEditingValue.selection.baseOffset, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the divider resizes the panes', (tester) async {
    await _pump(tester);
    final before = tester.getSize(find.byKey(const ValueKey('source-scroll')));
    await tester.drag(
      find.byKey(const ValueKey('split-handle')),
      const Offset(-200, 0),
    );
    await tester.pump();
    final after = tester.getSize(find.byKey(const ValueKey('source-scroll')));
    expect(after.width, lessThan(before.width - 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dark switch restyles both panes', (tester) async {
    await _pump(tester, text: 'Plain paragraph.\n');
    await tester.tap(find.byKey(const ValueKey('dark')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_editable(tester).widget.style.color, EditorColors.dark.text);
    final paragraph = tester.renderObject<RenderParagraph>(
      _preview('Plain paragraph.'),
    );
    expect(
      paragraph.text.style?.color,
      MarkdownThemeData.dark().bodyStyle.color,
    );
  });

  testWidgets('an empty document says so instead of showing a blank pane', (
    tester,
  ) async {
    await _pump(tester, text: '');
    expect(find.text('Nothing to preview yet'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'now there is');
    await tester.pump();
    expect(find.text('Nothing to preview yet'), findsNothing);
    expect(_preview('now there is'), findsOneWidget);
  });
}

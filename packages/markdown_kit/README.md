# markdown_kit

Renders GitHub-Flavored Markdown in Flutter with text selection that works the
way readers expect on a phone, and that keeps working while the text is still
being streamed.

- **Selection across blocks.** Long-press to select, drag the handles across
  paragraphs, lists, tables and code, copy as plain text or as Markdown. The
  selection is anchored in the document, not in widgets, so it survives
  scrolling a lazy list, rebuilds, and text that is still arriving.
- **Streaming.** Finished blocks are parsed and built once. Half-written
  fences, math and escapes are held back instead of flickering.
- **`package:flutter/widgets.dart` only.** No Material or Cupertino import.
  Colours, text styles, handles, the context menu and every block can be
  replaced.
- **GFM and a little more.** Tables, task lists, strikethrough, autolinks,
  alerts (`> [!NOTE]`), footnotes, `<details>`, a set of inline HTML tags, and
  `\(…\)` / `\[…\]` math hooks.

## Requirements

- Flutter 3.50 or later (Dart 3.14). Older versions are not supported: the
  test suite fails on Flutter 3.47.
- An `Overlay` above the Markdown, which every `Navigator` (and so every
  `WidgetsApp`, `MaterialApp` or `CupertinoApp` with a `home` or routes)
  provides. Selection handles and the context menu are drawn in it.

## Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

class Reply extends StatelessWidget {
  const Reply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return MarkdownView(
      data: text,
      builders: MarkdownBuilders(
        onLinkTap: (url, title) {
          // Open the link.
        },
      ),
    );
  }
}
```

On its own, `MarkdownView` manages selection for that one document. A small
app is in [`example/`](example); run `flutter create .` there once to generate
the platform folders.

### Streaming

Pass the text received so far and say that more is coming:

```dart
MarkdownView(data: received, isStreaming: !done)
```

Only the block still being written is parsed and rebuilt on each update.

### One selection for a whole screen

Put a `MarkdownSelectionScope` above the scroll view. Every `MarkdownView`,
`SliverMarkdownView` and `SelectablePlainText` below it joins the same
selection, and dragging a handle to the edge scrolls the list.

```dart
final controller = MarkdownSelectionController(
  // A chat usually wants a selection to stay inside one message.
  allowCrossDocumentSelection: false,
);

MarkdownSelectionScope(
  controller: controller,
  child: ListView.builder(
    itemCount: messages.length,
    itemBuilder: (context, index) => MarkdownView(
      data: messages[index].text,
      // A stable id lets the selection survive the item scrolling away.
      documentId: messages[index].id,
      documentOrder: index,
    ),
  ),
)
```

Dispose the controller when the screen goes away. It keeps the parsed document
of every `MarkdownView` it has seen (unless that view sets
`keepDocumentOnDispose: false`), which is what lets a selection reach text that
has scrolled out of a lazy list.

### One long document

Inside a `CustomScrollView`, `SliverMarkdownView` builds only the blocks near
the viewport while the whole document stays selectable. It needs a
`MarkdownSelectionScope` above the scroll view.

### Appearance

```dart
MarkdownTheme(
  data: MarkdownThemeData.dark().copyWith(
    bodyStyle: const TextStyle(fontSize: 16, height: 1.5),
  ),
  child: child,
)
```

`MarkdownThemeData` has a style object for each construct (code blocks, inline
code, quotes, alerts, tables, details, footnotes, math) and compares by value,
so an unchanged theme never rebuilds anything.

### Extension points

`MarkdownBuilders` replaces individual pieces:

| Builder | Replaces |
| --- | --- |
| `codeHighlighter` | The spans of a code block. Return spans whose text equals the code. |
| `codeBlockBuilder` | The frame around a code block (header, copy button). |
| `inlineCodeBuilder`, `inlineLinkBuilder`, `customInlineBuilder` | Inline spans. |
| `imageBuilder` | Images. The default loads `http(s)` URLs and shows a chip for anything else. |
| `tableBuilder`, `alertBuilder`, `blockLatexBuilder`, `inlineLatexBuilder` | Those blocks and spans. |
| `onLinkTap` | What a tap on a link does. Without it links are not tappable. |

Math is not typeset: `\(…\)` and `\[…\]` are parsed and shown as readable text
until you supply the LaTeX builders with a renderer of your choice. `$…$` is
opt-in (`MarkdownParserOptions(enableDollarLatex: true)`) because prose about
prices would otherwise turn into formulas.

To recognise your own inline syntax (file paths, mentions, issue numbers),
subclass `MarkdownInlineRule`, pass it in `MarkdownParserOptions.inlineRules`,
and render the resulting `CustomInline` in `customInlineBuilder`.

### Context menu

With no `contextMenuBuilder`, a small built-in menu offers Copy, Copy as
Markdown and Select all (`MarkdownDefaultContextMenu`; its labels can be
translated). To show the platform's menu instead, build it in
`contextMenuBuilder` from the `MarkdownSelectionScopeState` you are given
(`contextMenuAnchors`, `copySelection()`, `selectAll()`, …).

On desktop, selection also works with the mouse and keyboard: drag,
double-click for a word, triple-click for a block, Shift+arrows, and the
platform's copy and select-all shortcuts.

## Behaviour worth knowing

- **Raw HTML is shown as text**, except `<br>`, `<b>`/`<strong>`,
  `<i>`/`<em>`, `<u>`, `<s>`/`<del>`, `<sub>`, `<sup>`, `<kbd>`, `<a>`,
  `<img>` and `<details>`/`<summary>`. HTML comments are hidden.
- **Copy as Markdown** rebuilds Markdown from the parsed document. Fully
  selected blocks keep their structure; a partly selected first or last block
  is copied as plain text. Literal characters are not re-escaped, and math is
  written with `$` delimiters.
- **A collapsed `<details>`** still belongs to the document: a selection that
  spans it copies its hidden body too.
- **While text is streaming**, a link whose closing parenthesis has not
  arrived is shown as written.
- **When a document is replaced by different text** (not just appended to),
  the selection is carried over by looking for the same words nearby. If they
  were removed and occur elsewhere, the selection moves there.
- **Nesting** deeper than 500 levels is shown as text.
- **`<sub>` and `<sup>`** rely on the font's OpenType features; with a font
  that lacks them the text is only made smaller.

The parser builds on [`package:markdown`](https://pub.dev/packages/markdown).
A few inputs make it throw; `markdown_kit` then shows just that part of the
text unparsed rather than failing. `test/commonmark_spec/baseline.json` lists
every CommonMark example where the output differs from the specification, and
why.

## Platforms

The package has no platform-specific code. It is used in an app built for iOS,
Android and macOS, and its own tests run on Linux in CI. Web has not been
exercised.

## License

MIT. One test fixture is licensed differently; see [NOTICE.md](NOTICE.md).

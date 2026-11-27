# markdown_kit

Markdown for AI chat in Flutter: text that arrives token by token, in a
scrolling list, that people still want to select and copy.

<p align="center">
  <img src="doc/demo.gif" width="330" alt="A reply streams into a chat; a word is selected with a long-press, the selection is dragged across a list, a code block and a table, and the list is scrolled with the selection kept.">
</p>

Most Markdown widgets are built for a finished document. A chat with an agent
is different, and that is where they hurt:

- **The reply is still being written.** Re-parsing and rebuilding everything
  on each token wastes work on long answers, and half-typed syntax flashes as
  raw `**`, backticks and pipes. Here finished blocks are parsed and built
  once, and unfinished bold, links, code, tables and fences are held back
  until they are complete.
- **Selection has to survive.** With widget-based selection the highlight is
  lost when a message scrolls out of a lazy list or its text updates. Here the
  selection is anchored in the document, so it stays through scrolling,
  rebuilds and streaming.
- **Fingers are imprecise.** Dragging a selection handle should not scroll the
  list behind it or trigger the back swipe. Handles here have an opaque 44pt
  hit area, and dragging one to the edge scrolls the list for you.
- **People copy from answers.** Copy gives clean text without bullet glyphs or
  code block headers, or the Markdown structure when you want it.

It is built on `package:flutter/widgets.dart` only (no Material or Cupertino
import), so colours, text styles, handles, the context menu and every block
can be replaced. It was written for
[CC Pocket](https://github.com/K9i-0/ccpocket), a mobile client for coding
agents, and renders every message there.

## When to use something else

- You need full HTML rendering. Only a small set of tags is supported; the
  rest is shown as text.
- You need math typeset out of the box. Math is parsed and handed to a
  builder; bring your own renderer.
- You are on Flutter older than 3.50.

## Requirements

- Flutter 3.50 or later (Dart 3.14). Older versions are not supported: the
  test suite fails on Flutter 3.47.
- An `Overlay` above the Markdown, which every `Navigator` (and so every
  `WidgetsApp`, `MaterialApp` or `CupertinoApp` with a `home` or routes)
  provides. Selection handles and the context menu are drawn in it.

## A chat screen

One `MarkdownSelectionScope` above the list, one `MarkdownView` per reply:

```dart
final controller = MarkdownSelectionController(
  // A chat usually wants a selection to stay inside one message.
  allowCrossDocumentSelection: false,
);

MarkdownSelectionScope(
  controller: controller,
  child: ListView.builder(
    reverse: true,
    itemCount: messages.length,
    itemBuilder: (context, index) {
      final message = messages[messages.length - 1 - index];
      return MarkdownView(
        data: message.text,
        // Only the block still being written is re-parsed and rebuilt.
        isStreaming: message.isStreaming,
        // A stable id lets the selection survive the item scrolling away
        // and the switch from streaming to finished.
        documentId: message.id,
        documentOrder: index,
        builders: MarkdownBuilders(
          onLinkTap: (url, title) {
            // Open the link.
          },
        ),
      );
    },
  ),
)
```

- Every `MarkdownView`, `SliverMarkdownView` and `SelectablePlainText` below
  the scope joins the same selection. Use `SelectablePlainText` for the
  user's own messages.
- While `isStreaming` is true, syntax that is still missing its closing half
  is not shown. When the reply is finished, pass `isStreaming: false` and the
  whole text is rendered.
- Dispose the controller when the screen goes away. It keeps the parsed
  document of every view it has seen (unless that view sets
  `keepDocumentOnDispose: false`), which is what lets a selection reach text
  that has scrolled out of a lazy list.

A runnable version of this screen is in [`example/`](example); run
`flutter create .` there once to generate the platform folders.

Outside a chat, `MarkdownView(data: text)` on its own is enough: without a
scope above it, it manages selection for that one document.

## Going further

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
| `tableBuilder`, `alertBuilder` | Those blocks. |
| `blockLatexBuilder`, `inlineLatexBuilder` | LaTeX math. Return `null` to keep the built-in Unicode rendering, for example for a formula your typesetter rejects. |
| `onLinkTap` | What a tap on a link does. Without it links are not tappable. |

The package does not depend on a math typesetter. The example wires
[flutter_math_fork](https://pub.dev/packages/flutter_math_fork) into the two
LaTeX builders in [`example/lib/math.dart`](example/lib/math.dart), including
the two things that integration needs: one parsed tree per formula, and a dry
baseline for formulas inside tables.

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
- **While text is streaming**, unfinished syntax is held only on the last
  line and only within 300 characters of the end; an opener further back is
  shown as plain text.
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

## How it is tested

About 1,900 tests cover the parser, streaming, rendering and selection,
including right-to-left text, large text scales and hostile input. The 652
examples of the CommonMark specification run in CI: 572 match, and
`test/commonmark_spec/baseline.json` lists every one that differs and why
(mostly raw HTML, which is shown as text by design).

## Used in

[CC Pocket](https://github.com/K9i-0/ccpocket) is the app this package was
built for. It runs on iOS, Android, macOS, Linux and Windows, and renders
every chat message, plan and file preview with it. Its
[adapter layer](https://github.com/K9i-0/ccpocket/blob/main/apps/mobile/lib/widgets/markdown/ccpocket_markdown.dart)
is a full-size example of wiring the package into a Material app: theme
mapping, the platform's selection toolbar, syntax highlighting, tappable file
paths and image handling.

## Platforms

The package has no platform-specific code. Its tests run on Linux in CI. Web
has not been exercised.

## License

MIT. One test fixture is licensed differently; see [NOTICE.md](NOTICE.md).

/// What the editor opens with: a short tour of itself.
const sampleDocument = r'''
# Markdown editor

Type on the left, read on the right. The preview is a `MarkdownView` that is
given the text again on **every keystroke**; only the block you are typing in
is parsed and laid out again.

## Try it

- Scroll either side: the other follows, block by block
- Tap a block in the preview to put the caret in its source
- The bar in the margin marks the block the caret is in
- Press Enter in a list to continue it, and again on an empty item to end it

1. Select a few words
2. Press **B**, *I* or `</>` in the toolbar
3. Press it again to undo the change

- [x] Syntax colours in the source
- [x] Scrolling in step
- [ ] Your own document

## What the preview renders

> [!TIP]
> Everything below is ordinary Markdown. Change it and watch the right side.

```dart
// Parse once per change, with a parser of its own.
final parser = GfmMarkdownParser(maxCacheEntries: 0);
final document = parser.parse(controller.text);
```

| Syntax        | Result          |
| :------------ | :-------------- |
| `**bold**`    | **bold**        |
| `*italic*`    | *italic*        |
| `~~struck~~`  | ~~struck~~      |
| `[link](url)` | [link](https://pub.dev) |

Inline math such as \(e^{i\pi} + 1 = 0\) is typeset, and so is a display
formula:

\[\int_0^1 x^2\,dx = \frac{1}{3}\]

<details>
<summary>How the two sides stay in step</summary>

The parser records which stretch of the source each block came from
(`MarkdownDocument.blockSourceRanges`). The editor pairs the line where a
block starts with the top of that block in the preview, and interpolates in
between.

</details>

## A longer section to scroll through

Markdown is a plain text format for writing structured documents. It was made
to be readable as it is, without looking like it has been marked up with tags.

### Paragraphs

A paragraph is one or more lines of text, separated from the next by a blank
line. A line break inside a paragraph is a space, unless the line ends with
two spaces or a backslash.

### Lists

- Lists can be nested
  - by indenting the inner list
  - under the text of its item
- and they can hold other blocks

### Quotes

> A quote is a paragraph that starts with `>`.
>
> It can hold more than one.

### Code

Indent code by four spaces, or better, put it between fences:

```
no language, no colours
```

### Rules

A line of three dashes draws a rule.

---

That is the end of the tour. Select all, delete, and write your own.
''';

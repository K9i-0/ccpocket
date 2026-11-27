import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

import 'math.dart';
import 'theme.dart';

/// Document exercising every block, inline construct, alert kind, math
/// rendering mode, custom inline rule, details section, footnote and RTL text.
const showcaseDocument = r'''
# Feature showcase

This view renders a single document with `SliverMarkdownView` inside a
`CustomScrollView`. Only blocks near the viewport are built while the entire
document stays selectable across block boundaries.

Track changes in #42 and #108, toggle **Custom syntax** above to see a
`MarkdownInlineRule` turn issue numbers into tappable pills, or press
<kbd>Ctrl</kbd>+<kbd>C</kbd> / <kbd>⌘</kbd>+<kbd>C</kbd> to copy any selection.

Inline styles include **bold**, *italic*, ~~strikethrough~~, `inline code`,
chemical formulas like H<sub>2</sub>O, exponents like r<sup>2</sup>, and
[links](https://pub.dev)[^1].

## Lists & tasks

1. Parse each top-level block once
   - Nested bullet under an ordered item
   - Inline `CodeTextSpan` stays aligned across line wraps
2. Keep selections anchored in the document model
3. Copy clean plain text or reconstructed Markdown

- [x] Built on `package:flutter/widgets.dart` only
- [x] Streaming syntax hold (`isStreaming: true`)
- [x] Custom inline rules and pluggable builders
- [ ] Try selecting from here down into the table below

## Code & tables

```dart
SliverMarkdownView(
  data: document,
  documentId: 'showcase',
  parserOptions: MarkdownParserOptions(
    inlineRules: [IssueReferenceRule()],
  ),
  builders: MarkdownBuilders(
    inlineLatexBuilder: buildInlineMath,
    blockLatexBuilder: buildBlockMath,
    customInlineBuilder: buildIssuePill,
  ),
)
```

| Feature | Default | Extensible via |
| :------ | :-----: | -------------: |
| Code blocks | Monospace frame | `codeHighlighter`, `codeBlockBuilder` |
| LaTeX math | Unicode text | `inlineLatexBuilder`, `blockLatexBuilder` |
| Alerts | 5 GitHub kinds | `alertBuilder` |
| Custom tokens | Plain text | `MarkdownInlineRule` + `customInlineBuilder` |

## Alerts

> [!NOTE]
> Useful context that stays scannable in long agent replies.

> [!TIP]
> Toggle **Math: Typeset** in the bar above to compare `flutter_math_fork`
> typesetting against the zero-dependency Unicode fallback.

> [!IMPORTANT]
> Selection survives lazy list recycling when every view uses a stable
> `documentId`.

> [!WARNING]
> Raw HTML layout tags such as `<div>` stay as literal text by design.

> [!CAUTION]
> Remember to dispose a `MarkdownSelectionController` you create yourself.

## Math

Quicksort averages \(O(n \log n)\) comparisons. Its recurrence is

\[T(n) = 2\,T\!\left(\frac{n}{2}\right) + O(n)\]

and the Gaussian integral is

\[\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}\]

## Details & quotes

<details>
<summary>Collapsed details still participate in selection</summary>

Drag a selection from the paragraph above through this summary to the quote
below: copying includes this hidden body as well.

</details>

> A blockquote can hold nested blocks:
>
> - First nested item referencing #42
> - Second nested item with `code`

## Right-to-left text

يدعم هذا العرض النصوص من اليمين إلى اليسار مع **التنسيق** و`الكود` والروابط
بشكل طبيعي داخل نفس المستند.

---

[^1]: Footnote references and definitions are linked in document order.
''';

/// Example [MarkdownInlineRule] that recognizes `#123` issue references.
class IssueReferenceRule extends MarkdownInlineRule {
  /// Creates the rule.
  const IssueReferenceRule();

  static final _pattern = RegExp(r'#(\d+)\b');

  @override
  Set<int> get triggerCodeUnits => const {0x23}; // '#'

  @override
  MarkdownInlineMatch? matchAt(String text, int index) {
    // Require start of string or whitespace / opening punctuation before '#'.
    if (index > 0) {
      final prev = text.codeUnitAt(index - 1);
      final boundary =
          prev == 0x20 ||
          prev == 0x0A ||
          prev == 0x09 ||
          prev == 0x28 ||
          prev == 0x5B;
      if (!boundary) return null;
    }
    final match = _pattern.matchAsPrefix(text, index);
    if (match == null) return null;
    return MarkdownInlineMatch(
      end: match.end,
      inline: CustomInline(
        kind: 'issue',
        text: match.group(0)!,
        data: {'number': match.group(1)!},
      ),
    );
  }
}

/// Showcase tab demonstrating [SliverMarkdownView], all supported constructs,
/// math builder fallback vs typesetting, custom inline rules, and inspecting
/// Copy vs Copy as Markdown output.
class ShowcaseTab extends StatefulWidget {
  /// Creates the showcase tab.
  const ShowcaseTab({super.key, required this.colors, this.active = true});

  /// Active colour palette.
  final ExampleColors colors;

  /// Whether this tab is currently visible.
  final bool active;

  @override
  State<ShowcaseTab> createState() => _ShowcaseTabState();
}

class _ShowcaseTabState extends State<ShowcaseTab> {
  final _selection = MarkdownSelectionController();

  bool _typesetMath = true;
  bool _customInline = true;
  String? _notice;
  ({String label, String content})? _copiedPreview;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant ShowcaseTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _selection.toolbarWanted = false;
    }
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _copy({required bool asMarkdown}) async {
    final content = asMarkdown
        ? _selection.getMarkdown()
        : _selection.getText();
    if (content.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: content));
    _selection.toolbarWanted = false;
    if (!mounted) return;
    setState(() {
      final label = asMarkdown ? 'Copied as Markdown' : 'Copied plain text';
      _notice = '$label (${content.length} chars)';
      _copiedPreview = (label: label, content: content);
    });
  }

  InlineSpan _buildCustomInline(
    BuildContext context,
    CustomInline inline,
    TextStyle style,
  ) {
    final colors = widget.colors;
    if (inline.kind != 'issue') {
      return TextSpan(text: inline.text, style: style);
    }
    return TappableTextSpan(
      onTap: () => setState(() {
        _copiedPreview = null;
        _notice = 'Custom inline tapped: Issue ${inline.text}';
      }),
      hoverStyle: TextStyle(
        color: colors.accent,
        decoration: TextDecoration.underline,
      ),
      children: [
        CodeTextSpan(
          text: inline.text,
          style: style.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w600,
          ),
          codeStyle: MarkdownInlineCodeStyle(
            fontFamily: style.fontFamily,
            fontSize: style.fontSize,
            color: colors.accent,
            backgroundColor: colors.accentSubtle,
            borderRadius: 4,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final options = _customInline
        ? const MarkdownParserOptions(inlineRules: [IssueReferenceRule()])
        : const MarkdownParserOptions();
    final builders = MarkdownBuilders(
      onLinkTap: (url, _) => setState(() {
        _copiedPreview = null;
        _notice = 'Link: $url';
      }),
      inlineLatexBuilder: _typesetMath ? buildInlineMath : null,
      blockLatexBuilder: _typesetMath ? buildBlockMath : null,
      customInlineBuilder: _customInline ? _buildCustomInline : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControlsBar(colors),
        Hairline(colors.border),
        Expanded(
          child: ColoredBox(
            color: colors.background,
            child: MarkdownSelectionScope(
              controller: _selection,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal =
                      ((constraints.maxWidth - kReadingMaxWidth) / 2).clamp(
                        16.0,
                        double.infinity,
                      );
                  return CustomScrollView(
                    key: const ValueKey('showcase-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          20,
                          horizontal,
                          36,
                        ),
                        sliver: SliverMarkdownView(
                          data: showcaseDocument,
                          documentId: 'showcase',
                          parserOptions: options,
                          theme: colors.markdown,
                          builders: builders,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Hairline(colors.border),
        _buildInspectorBar(colors),
      ],
    );
  }

  Widget _buildControlsBar(ExampleColors colors) {
    return ColoredBox(
      color: colors.chrome,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            ToggleChip(
              key: const ValueKey('showcase-math'),
              label: _typesetMath ? 'Math: Typeset' : 'Math: Unicode',
              on: _typesetMath,
              colors: colors,
              onChanged: (on) => setState(() => _typesetMath = on),
            ),
            const SizedBox(width: 8),
            ToggleChip(
              key: const ValueKey('showcase-custom-inline'),
              label: 'Custom syntax (#42)',
              on: _customInline,
              colors: colors,
              onChanged: (on) => setState(() => _customInline = on),
            ),
            const SizedBox(width: 8),
            Hairline.vertical(colors.border),
            const SizedBox(width: 8),
            ActionButton(
              key: const ValueKey('showcase-select-all'),
              label: 'Select all',
              colors: colors,
              onPressed: () => _selection.selectAll(documentId: 'showcase'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorBar(ExampleColors colors) {
    final hasSelection = _selection.hasSelection;
    final selectedLength = hasSelection ? _selection.getText().length : 0;
    final preview = _copiedPreview;

    return ColoredBox(
      color: colors.chrome,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasSelection
                        ? 'Selected $selectedLength chars'
                        : (_notice ??
                              'SliverMarkdownView · Select across blocks to '
                                  'compare Copy vs Copy as Markdown.'),
                    key: const ValueKey('showcase-status'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ),
                if (hasSelection) ...[
                  const SizedBox(width: 8),
                  ActionButton(
                    key: const ValueKey('showcase-copy-plain'),
                    label: 'Copy',
                    colors: colors,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    fontSize: 12,
                    onPressed: () => _copy(asMarkdown: false),
                  ),
                  const SizedBox(width: 6),
                  ActionButton(
                    key: const ValueKey('showcase-copy-markdown'),
                    label: 'Copy as Markdown',
                    tone: ActionTone.primary,
                    colors: colors,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    fontSize: 12,
                    onPressed: () => _copy(asMarkdown: true),
                  ),
                  const SizedBox(width: 4),
                  ActionButton(
                    key: const ValueKey('showcase-clear'),
                    label: 'Clear',
                    tone: ActionTone.subtle,
                    colors: colors,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    fontSize: 12,
                    onPressed: () => _selection.clear(),
                  ),
                ],
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.border),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              preview.label,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preview.content,
                              key: const ValueKey('showcase-copied-preview'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontFamily: 'monospace',
                                fontFamilyFallback: kMarkdownMonospaceFallback,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ActionButton(
                        key: const ValueKey('showcase-dismiss-preview'),
                        label: '×',
                        tone: ActionTone.subtle,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        fontSize: 13,
                        colors: colors,
                        onPressed: () => setState(() => _copiedPreview = null),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

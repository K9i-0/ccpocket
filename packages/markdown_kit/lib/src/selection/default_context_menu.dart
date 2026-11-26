import 'dart:async';

import 'package:flutter/widgets.dart';

import 'selection_scope.dart';

/// Text shown on the buttons of [MarkdownDefaultContextMenu].
///
/// The defaults are English. Pass translated strings to localise the menu.
@immutable
class MarkdownContextMenuLabels {
  /// Creates the labels of the default context menu.
  const MarkdownContextMenuLabels({
    this.copy = 'Copy',
    this.copyAsMarkdown = 'Copy as Markdown',
    this.selectAll = 'Select all',
  });

  /// Label of the button that copies the selection as plain text.
  final String copy;

  /// Label of the button that copies the selection as Markdown source.
  final String copyAsMarkdown;

  /// Label of the button that selects the whole document.
  final String selectAll;

  @override
  bool operator ==(Object other) =>
      other is MarkdownContextMenuLabels &&
      other.copy == copy &&
      other.copyAsMarkdown == copyAsMarkdown &&
      other.selectAll == selectAll;

  @override
  int get hashCode => Object.hash(copy, copyAsMarkdown, selectAll);
}

/// The context menu a [MarkdownSelectionScope] shows when it is given no
/// `contextMenuBuilder`: a small bar with Copy, Copy as Markdown and Select
/// all, placed above the selection (or below it when there is no room).
///
/// It is drawn with `package:flutter/widgets.dart` only, so it looks the same
/// on every platform. Apps that want the platform's own menu build one in
/// `contextMenuBuilder` from [MarkdownSelectionScopeState] instead.
class MarkdownDefaultContextMenu extends StatelessWidget {
  /// Creates the default context menu for [state].
  const MarkdownDefaultContextMenu({
    super.key,
    required this.state,
    this.labels = const MarkdownContextMenuLabels(),
    this.showCopyAsMarkdown = true,
    this.backgroundColor = const Color(0xFF2C2C2E),
    this.foregroundColor = const Color(0xFFFFFFFF),
    this.dividerColor = const Color(0x33FFFFFF),
    this.textStyle,
  });

  /// The scope whose selection the menu acts on.
  final MarkdownSelectionScopeState state;

  /// Button labels.
  final MarkdownContextMenuLabels labels;

  /// Whether to offer copying the selection as Markdown source.
  final bool showCopyAsMarkdown;

  /// Fill colour of the bar.
  final Color backgroundColor;

  /// Colour of the button labels.
  final Color foregroundColor;

  /// Colour of the hairlines between buttons.
  final Color dividerColor;

  /// Style of the button labels, merged over a 14px default.
  final TextStyle? textStyle;

  // Clears the handle knobs, which stick out above and below the selection.
  static const double _gap = 18.0;
  static const double _verticalPadding = 11.0;
  static const double _screenMargin = 8.0;

  @override
  Widget build(BuildContext context) {
    final anchors = state.contextMenuAnchors;
    final media = MediaQuery.maybeOf(context);
    final topInset = media?.padding.top ?? 0.0;
    final above = anchors.primaryAnchor - const Offset(0, _gap);
    final below =
        (anchors.secondaryAnchor ?? anchors.primaryAnchor) +
        const Offset(0, _gap);
    final style = TextStyle(
      color: foregroundColor,
      fontSize: 14.0,
      height: 1.2,
      decoration: TextDecoration.none,
      fontWeight: FontWeight.w500,
    ).merge(textStyle);

    final buttons = <Widget>[
      if (state.selectedPlainText.isNotEmpty)
        _MenuButton(
          label: labels.copy,
          style: style,
          onPressed: () => unawaited(state.copySelection()),
        ),
      if (showCopyAsMarkdown && state.selectedMarkdown.isNotEmpty)
        _MenuButton(
          label: labels.copyAsMarkdown,
          style: style,
          onPressed: () => unawaited(state.copySelectionAsMarkdown()),
        ),
      _MenuButton(
        label: labels.selectAll,
        style: style,
        onPressed: state.selectAll,
      ),
    ];

    // The bar is as tall as its (scaled) label, and scrolls sideways rather
    // than overflowing when the labels do not fit the screen.
    final fontSize = style.fontSize ?? 14.0;
    final lineHeight =
        (media?.textScaler ?? TextScaler.noScaling).scale(fontSize) *
        (style.height ?? 1.2);
    final barHeight = lineHeight + _verticalPadding * 2;
    final maxWidth = media == null
        ? double.infinity
        : (media.size.width - _screenMargin * 2).clamp(0.0, double.infinity);

    // The delegate keeps the bar inside the area it is given, so the padding
    // is what keeps it off the screen edges. Anchors are shifted to match.
    const margin = Offset(_screenMargin, 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _screenMargin),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: above - margin,
          anchorBelow: below - margin,
          fitsAbove: above.dy - barHeight >= topInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0)
                          SizedBox(
                            width: 1.0,
                            child: ColoredBox(color: dividerColor),
                          ),
                        buttons[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: MarkdownDefaultContextMenu._verticalPadding,
            ),
            child: Text(label, style: style, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

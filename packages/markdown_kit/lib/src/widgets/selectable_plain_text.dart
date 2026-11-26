import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../rendering/markdown_theme.dart';
import '../rendering/selectable_paragraph.dart';
import '../selection/selection_controller.dart';
import '../selection/selection_handles.dart';
import '../selection/selection_model.dart';
import '../selection/selection_scope.dart';
import 'markdown_widget_helpers.dart';

/// Lightweight single-block selectable plain text widget that participates in
/// the same model-anchored selection engine, opaque low-slop touch handles,
/// edge autoscroll, and non-clearing scroll UX as [MarkdownView].
///
/// Built solely on `package:flutter/widgets.dart`.
class SelectablePlainText extends StatefulWidget {
  /// Creates selectable text showing [text].
  const SelectablePlainText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.textScaler,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.documentId,
    this.documentOrder = 0,
    this.selectable = true,
    this.selectionColor,
    this.contextMenuBuilder,
    this.handleBuilder,
    this.magnifierBuilder,
    this.onSelectionChanged,
    this.keepDocumentOnDispose = true,
  });

  /// Plain text content to display and select.
  final String text;

  /// Optional [TextStyle] merged onto the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal text alignment.
  final TextAlign textAlign;

  /// Optional explicit [TextDirection].
  final TextDirection? textDirection;

  /// Optional explicit [TextScaler].
  final TextScaler? textScaler;

  /// Optional maximum number of lines.
  final int? maxLines;

  /// Whether text should break at soft line breaks.
  final bool softWrap;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  /// Optional strut style.
  final StrutStyle? strutStyle;

  /// Defines how to measure the width of the rendered text.
  final TextWidthBasis textWidthBasis;

  /// Defines how to apply height to the first and last lines.
  final TextHeightBehavior? textHeightBehavior;

  /// Stable identifier used for model-anchored selection registration.
  final String? documentId;

  /// Reading order among sibling documents inside a shared
  /// [MarkdownSelectionScope].
  final int documentOrder;

  /// Whether this text participates in selection.
  final bool selectable;

  /// Optional selection highlight (and standalone handle) color override.
  final Color? selectionColor;

  /// Context menu builder used when running in standalone mode (no ancestor
  /// [MarkdownSelectionScope]).
  final MarkdownContextMenuBuilder? contextMenuBuilder;

  /// Custom selection handle builder used in standalone mode.
  final MarkdownSelectionHandleBuilder? handleBuilder;

  /// Custom touch magnifier builder used in standalone mode.
  final MarkdownMagnifierBuilder? magnifierBuilder;

  /// Selection change callback used in standalone mode.
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;

  /// Whether to keep the document registered in an ancestor
  /// [MarkdownSelectionController] when this widget disposes.
  final bool keepDocumentOnDispose;

  @override
  State<SelectablePlainText> createState() => _SelectablePlainTextState();
}

class _SelectablePlainTextState extends State<SelectablePlainText> {
  late String _autoDocumentId;
  late MarkdownDocument _document;
  late TextOffsetMapping _offsetMapping;

  String get _effectiveDocumentId => widget.documentId ?? _autoDocumentId;

  @override
  void initState() {
    super.initState();
    _autoDocumentId = generateMarkdownDocumentId();
    _rebuildDocument();
  }

  @override
  void didUpdateWidget(covariant SelectablePlainText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _rebuildDocument();
    }
  }

  void _rebuildDocument() {
    _document = MarkdownDocument(
      blocks: [
        ParagraphBlock(inlines: [TextInline(widget.text)]),
      ],
      source: widget.text,
    );
    _offsetMapping = TextOffsetMapping.identity(widget.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final ancestorController = MarkdownSelectionScope.maybeOf(context);
    final useStandaloneScope = widget.selectable && ancestorController == null;

    Widget content = _SelectablePlainTextHost(
      text: widget.text,
      documentId: _effectiveDocumentId,
      documentOrder: widget.documentOrder,
      document: _document,
      offsetMapping: _offsetMapping,
      style: widget.style,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      strutStyle: widget.strutStyle,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectable: widget.selectable,
      selectionColor: widget.selectionColor,
      keepDocumentOnDispose: useStandaloneScope
          ? false
          : widget.keepDocumentOnDispose,
    );

    if (useStandaloneScope) {
      content = MarkdownSelectionScope(
        selectionColor: widget.selectionColor,
        contextMenuBuilder: widget.contextMenuBuilder,
        handleBuilder: widget.handleBuilder,
        magnifierBuilder: widget.magnifierBuilder,
        onSelectionChanged: widget.onSelectionChanged,
        child: content,
      );
    }

    return content;
  }
}

class _SelectablePlainTextHost extends StatefulWidget {
  const _SelectablePlainTextHost({
    required this.text,
    required this.documentId,
    required this.documentOrder,
    required this.document,
    required this.offsetMapping,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.textScaler,
    required this.maxLines,
    required this.softWrap,
    required this.overflow,
    required this.strutStyle,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.selectable,
    required this.selectionColor,
    required this.keepDocumentOnDispose,
  });

  final String text;
  final String documentId;
  final int documentOrder;
  final MarkdownDocument document;
  final TextOffsetMapping offsetMapping;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final bool selectable;
  final Color? selectionColor;
  final bool keepDocumentOnDispose;

  @override
  State<_SelectablePlainTextHost> createState() =>
      _SelectablePlainTextHostState();
}

class _SelectablePlainTextHostState extends State<_SelectablePlainTextHost> {
  final MarkdownDocumentRegistration _registration =
      MarkdownDocumentRegistration();

  MarkdownSelectionController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = MarkdownSelectionScope.maybeOf(context);
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant _SelectablePlainTextHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  @override
  void dispose() {
    _registration.dispose(keepDocumentOnDispose: widget.keepDocumentOnDispose);
    super.dispose();
  }

  void _syncRegistration() {
    _registration.sync(
      controller: _controller,
      ref: MarkdownDocumentRef(
        id: widget.documentId,
        document: widget.document,
        order: widget.documentOrder,
      ),
      selectable: widget.selectable,
      keepDocumentOnDispose: widget.keepDocumentOnDispose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = widget.style == null
        ? defaultStyle
        : (widget.style!.inherit
              ? defaultStyle.merge(widget.style)
              : widget.style!);

    final controller = widget.selectable ? _controller : null;
    final effectiveSelectionColor =
        widget.selectionColor ??
        controller?.selectionColor ??
        MarkdownTheme.maybeOf(context)?.selectionColor ??
        const Color(0x4D0969DA);

    return SelectableParagraph(
      documentId: widget.documentId,
      blockIndex: 0,
      textOffsetInBlock: 0,
      canonicalLength: widget.text.length,
      offsetMapping: widget.offsetMapping,
      text: TextSpan(text: widget.text, style: effectiveStyle),
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      strutStyle: widget.strutStyle,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: effectiveSelectionColor,
      selectable: widget.selectable,
      onSurfaceAttach: widget.selectable ? controller?.registerSurface : null,
      onSurfaceDetach: widget.selectable ? controller?.unregisterSurface : null,
    );
  }
}

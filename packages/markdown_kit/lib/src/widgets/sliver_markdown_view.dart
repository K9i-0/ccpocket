import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../parser/gfm_parser.dart';
import '../parser/markdown_parser.dart';
import '../rendering/block_renderer.dart';
import '../rendering/markdown_builders.dart';
import '../rendering/markdown_theme.dart';
import '../selection/selection_controller.dart';
import '../selection/selection_model.dart';
import '../selection/selection_scope.dart';
import 'markdown_view.dart' show MarkdownBlockBuildCallback;
import 'markdown_widget_helpers.dart';

/// Viewport-lazy sliver widget rendering a Markdown document block-by-block
/// inside a [CustomScrollView].
///
/// Only blocks within the visible viewport and `cacheExtent` are built
/// (`SliverList.builder` with `addAutomaticKeepAlives: false`), while the full
/// parsed [MarkdownDocument] is registered with the nearest ancestor
/// [MarkdownSelectionScope] so model-anchored selection and copying continue
/// to work seamlessly across mounted and scrolled-off blocks.
class SliverMarkdownView extends StatefulWidget {
  const SliverMarkdownView({
    super.key,
    this.data = '',
    this.document,
    this.documentId,
    this.documentOrder = 0,
    this.parser,
    this.parserOptions = const MarkdownParserOptions(),
    this.theme,
    this.builders = const MarkdownBuilders(),
    this.isStreaming = false,
    this.selectable = true,
    this.selectionColor,
    this.onBlockBuilt,
    this.textScaler,
    this.textDirection,
    this.keepDocumentOnDispose = true,
  });

  /// Raw Markdown source string to parse when [document] is omitted.
  final String data;

  /// Optional pre-parsed [MarkdownDocument]. When provided, bypasses [parser].
  final MarkdownDocument? document;

  /// Stable identifier used for model-anchored selection registration.
  final String? documentId;

  /// Reading order among sibling documents inside a shared
  /// [MarkdownSelectionScope].
  final int documentOrder;

  /// Optional custom [MarkdownParser]. Defaults to a shared
  /// [GfmMarkdownParser] configured with [parserOptions].
  final MarkdownParser? parser;

  /// Parsing extension options used when [parser] is omitted.
  final MarkdownParserOptions parserOptions;

  /// Optional visual theme override. Falls back to
  /// `MarkdownTheme.maybeOf(context) ?? MarkdownThemeData.fallback()`.
  final MarkdownThemeData? theme;

  /// Optional custom render builders and link tap callback.
  final MarkdownBuilders builders;

  /// Whether [data] is actively streaming.
  final bool isStreaming;

  /// Whether blocks inside this sliver participate in selection.
  final bool selectable;

  /// Optional selection highlight color override.
  final Color? selectionColor;

  /// Optional callback invoked whenever the sliver builds a block item.
  final MarkdownBlockBuildCallback? onBlockBuilt;

  /// Optional [TextScaler] override applied to built blocks.
  final TextScaler? textScaler;

  /// Optional [TextDirection] override applied to built blocks.
  final TextDirection? textDirection;

  /// Whether to keep the document registered in the ancestor
  /// [MarkdownSelectionController] when this sliver disposes.
  final bool keepDocumentOnDispose;

  @override
  State<SliverMarkdownView> createState() => _SliverMarkdownViewState();
}

class _SliverMarkdownViewState extends State<SliverMarkdownView> {
  final GlobalKey _contentKey = GlobalKey();
  final MarkdownDocumentRegistration _registration =
      MarkdownDocumentRegistration();

  late String _autoDocumentId;
  GfmMarkdownParser? _customParser;
  late MarkdownDocument _document;
  MarkdownSelectionController? _controller;

  String get _effectiveDocumentId => widget.documentId ?? _autoDocumentId;

  @override
  void initState() {
    super.initState();
    _autoDocumentId = generateMarkdownDocumentId();
    _document = _resolveDocument();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = MarkdownSelectionScope.maybeOf(context);
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant SliverMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.data != widget.data ||
        oldWidget.parser != widget.parser ||
        oldWidget.parserOptions != widget.parserOptions ||
        oldWidget.isStreaming != widget.isStreaming) {
      _document = _resolveDocument();
    }
    _syncRegistration();
  }

  @override
  void dispose() {
    _registration.dispose(keepDocumentOnDispose: widget.keepDocumentOnDispose);
    super.dispose();
  }

  MarkdownDocument _resolveDocument() {
    final preParsed = widget.document;
    if (preParsed != null) {
      return preParsed;
    }
    final resolved = resolveMarkdownParser(
      parser: widget.parser,
      options: widget.parserOptions,
      cachedCustomParser: _customParser,
    );
    _customParser = resolved.customParser;
    return resolved.parser.parse(widget.data, isStreaming: widget.isStreaming);
  }

  void _syncRegistration() {
    _registration.sync(
      controller: _controller,
      ref: MarkdownDocumentRef(
        id: _effectiveDocumentId,
        document: _document,
        order: widget.documentOrder,
      ),
      selectable: widget.selectable,
      keepDocumentOnDispose: widget.keepDocumentOnDispose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        widget.theme ??
        MarkdownTheme.maybeOf(context) ??
        MarkdownThemeData.fallback();
    final controller = widget.selectable ? _controller : null;
    final effectiveSelectionColor =
        widget.selectionColor ??
        controller?.selectionColor ??
        effectiveTheme.selectionColor;
    final blocks = _document.blocks;
    final docId = _effectiveDocumentId;
    final blockSpacing = effectiveTheme.blockSpacing;

    final Widget sliver = SliverList.builder(
      itemCount: blocks.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (BuildContext context, int index) {
        final block = blocks[index];
        widget.onBlockBuilt?.call(index, block);

        Widget item = MarkdownBlockRenderer(
          key: ValueKey<String>('$docId:$index'),
          documentId: docId,
          blockIndex: index,
          block: block,
          theme: effectiveTheme,
          builders: widget.builders,
          selectionColor: effectiveSelectionColor,
          selectable: widget.selectable,
          onSurfaceAttach: widget.selectable
              ? controller?.registerSurface
              : null,
          onSurfaceDetach: widget.selectable
              ? controller?.unregisterSurface
              : null,
        );

        if (index > 0 && blockSpacing > 0) {
          item = Padding(
            padding: EdgeInsets.only(top: blockSpacing),
            child: item,
          );
        }

        return item;
      },
    );

    return wrapWithTextOverrides(
      context,
      contentKey: _contentKey,
      child: sliver,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
    );
  }
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../parser/gfm_parser.dart';
import '../parser/markdown_parser.dart';
import '../rendering/block_renderer.dart';
import '../rendering/markdown_builders.dart';
import '../rendering/markdown_theme.dart';
import '../selection/selection_controller.dart';
import '../selection/selection_handles.dart';
import '../selection/selection_model.dart';
import '../selection/selection_scope.dart';
import 'markdown_widget_helpers.dart';

/// Callback invoked when a top-level [MarkdownBlock] widget is built or reused
/// from cache.
typedef MarkdownBlockBuildCallback = void Function(
  int blockIndex,
  MarkdownBlock block,
);

/// Wraps the widget of one top-level block in a [MarkdownView] or
/// [SliverMarkdownView].
///
/// [child] draws [block], which is `document.blocks[blockIndex]`. Return a
/// widget that contains it: to find where a block is on screen, to mark the
/// block being edited, or to add a gutter beside it.
///
/// Called when the widget of a block is created, not on every build, so the
/// result may depend only on the arguments. To show state that changes, return
/// a widget that listens to it. Passing a different function rebuilds every
/// block.
typedef MarkdownBlockWrapper = Widget Function(
  int blockIndex,
  MarkdownBlock block,
  Widget child,
);

/// Top-level widget rendering GFM Markdown with block-level caching, streaming
/// support, and model-anchored selection.
///
/// Built solely on `package:flutter/widgets.dart`.
///
/// When [selectable] is `true`:
/// - If an ancestor [MarkdownSelectionScope] exists, registers its parsed
///   [MarkdownDocument] and [SelectableParagraph] surfaces with that scope's
///   [MarkdownSelectionController].
/// - Otherwise, automatically wraps itself in a self-managed
///   [MarkdownSelectionScope] (forwarding [contextMenuBuilder],
///   [handleBuilder], [magnifierBuilder], [selectionColor], and
///   [onSelectionChanged]).
class MarkdownView extends StatefulWidget {
  /// Creates a view that renders [data], or [document] when one is given.
  const MarkdownView({
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
    this.contextMenuBuilder,
    this.handleBuilder,
    this.magnifierBuilder,
    this.onSelectionChanged,
    this.onBlockBuilt,
    this.onBlockReused,
    this.blockWrapper,
    this.textScaler,
    this.textDirection,
    this.shrinkWrap = true,
    this.keepDocumentOnDispose = true,
  });

  /// Raw Markdown source string to parse when [document] is omitted.
  final String data;

  /// Optional pre-parsed [MarkdownDocument]. When provided, bypasses [parser].
  final MarkdownDocument? document;

  /// Stable identifier used for model-anchored selection registration.
  ///
  /// When omitted, a unique stable identifier is generated for the lifetime of
  /// this widget's state.
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

  /// Whether [data] is actively streaming. Enables incomplete-construct
  /// flicker guarding and streaming tail parsing.
  final bool isStreaming;

  /// Whether text inside this Markdown view participates in selection.
  final bool selectable;

  /// Optional override for selection highlight (and standalone handle) color.
  ///
  /// Resolves as `selectionColor ?? controller?.selectionColor ?? theme.selectionColor`.
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

  /// Optional performance callback fired whenever a top-level block widget is
  /// freshly constructed (cache miss). That includes an unchanged block whose
  /// index changed because blocks were added or removed before it: its widget
  /// is made again for the new index, while its state and layout are kept.
  final MarkdownBlockBuildCallback? onBlockBuilt;

  /// Optional performance callback fired whenever an unchanged top-level block
  /// widget instance is reused from cache (cache hit).
  final MarkdownBlockBuildCallback? onBlockReused;

  /// Optional wrapper around the widget of each top-level block.
  final MarkdownBlockWrapper? blockWrapper;

  /// Optional [TextScaler] override applied to this Markdown subtree.
  final TextScaler? textScaler;

  /// Optional [TextDirection] override applied to this Markdown subtree.
  final TextDirection? textDirection;

  /// Whether the vertical [Column] shrinks to fit its blocks (`MainAxisSize.min`)
  /// rather than expanding to fill available height (`MainAxisSize.max`).
  final bool shrinkWrap;

  /// Whether to keep the document registered in an ancestor
  /// [MarkdownSelectionController] when this widget disposes.
  ///
  /// Defaults to `true` so model-anchored selections survive `ListView.builder`
  /// scroll-off virtualization and streaming-to-final widget handoffs.
  /// Ignored in standalone mode (whose internal controller is always disposed).
  final bool keepDocumentOnDispose;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final GlobalKey _contentKey = GlobalKey();
  late String _autoDocumentId;
  GfmMarkdownParser? _customParser;
  late MarkdownDocument _document;

  String get _effectiveDocumentId => widget.documentId ?? _autoDocumentId;

  @override
  void initState() {
    super.initState();
    _autoDocumentId = generateMarkdownDocumentId();
    _document = _resolveDocument();
  }

  @override
  void didUpdateWidget(covariant MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.data != widget.data ||
        oldWidget.parser != widget.parser ||
        oldWidget.parserOptions != widget.parserOptions ||
        oldWidget.isStreaming != widget.isStreaming) {
      _document = _resolveDocument();
    }
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

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        widget.theme ??
        MarkdownTheme.maybeOf(context) ??
        MarkdownThemeData.fallback();
    final ancestorController = MarkdownSelectionScope.maybeOf(context);
    final useStandaloneScope = widget.selectable && ancestorController == null;

    Widget content = _MarkdownDocumentHost(
      documentId: _effectiveDocumentId,
      documentOrder: widget.documentOrder,
      document: _document,
      theme: effectiveTheme,
      builders: widget.builders,
      selectable: widget.selectable,
      selectionColor: widget.selectionColor,
      shrinkWrap: widget.shrinkWrap,
      keepDocumentOnDispose: useStandaloneScope
          ? false
          : widget.keepDocumentOnDispose,
      onBlockBuilt: widget.onBlockBuilt,
      onBlockReused: widget.onBlockReused,
      blockWrapper: widget.blockWrapper,
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

    return wrapWithTextOverrides(
      context,
      contentKey: _contentKey,
      child: _IntrinsicWidthWhenUnbounded(child: content),
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
    );
  }
}

class _CachedBlockWidget {
  const _CachedBlockWidget({
    required this.id,
    required this.block,
    required this.widget,
  });

  /// Identifies the block across builds, and is what its widget is keyed by.
  /// It follows the block when others are added or removed before it, so the
  /// element (with its state and layout) moves instead of being rebuilt as a
  /// different block.
  final int id;
  final MarkdownBlock block;
  final Widget widget;
}

class _MarkdownDocumentHost extends StatefulWidget {
  const _MarkdownDocumentHost({
    required this.documentId,
    required this.documentOrder,
    required this.document,
    required this.theme,
    required this.builders,
    required this.selectable,
    required this.selectionColor,
    required this.shrinkWrap,
    required this.keepDocumentOnDispose,
    required this.onBlockBuilt,
    required this.onBlockReused,
    required this.blockWrapper,
  });

  final String documentId;
  final int documentOrder;
  final MarkdownDocument document;
  final MarkdownThemeData theme;
  final MarkdownBuilders builders;
  final bool selectable;
  final Color? selectionColor;
  final bool shrinkWrap;
  final bool keepDocumentOnDispose;
  final MarkdownBlockBuildCallback? onBlockBuilt;
  final MarkdownBlockBuildCallback? onBlockReused;
  final MarkdownBlockWrapper? blockWrapper;

  @override
  State<_MarkdownDocumentHost> createState() => _MarkdownDocumentHostState();
}

class _MarkdownDocumentHostState extends State<_MarkdownDocumentHost> {
  final MarkdownDocumentRegistration _registration =
      MarkdownDocumentRegistration();

  MarkdownSelectionController? _controller;

  // Block widget cache state.
  List<_CachedBlockWidget> _blockCache = const [];
  int _nextBlockId = 0;
  MarkdownBlockWrapper? _cachedWrapper;
  MarkdownThemeData? _cachedTheme;
  MarkdownBuilders? _cachedBuilders;
  String? _cachedDocumentId;
  bool? _cachedSelectable;
  Color? _cachedSelectionColor;
  MarkdownSelectionController? _cachedController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = MarkdownSelectionScope.maybeOf(context);
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant _MarkdownDocumentHost oldWidget) {
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
    final blocks = widget.document.blocks;
    if (blocks.isEmpty) {
      _blockCache = const [];
      return const SizedBox.shrink();
    }

    final controller = widget.selectable ? _controller : null;
    final effectiveSelectionColor =
        widget.selectionColor ??
        controller?.selectionColor ??
        widget.theme.selectionColor;

    // The cached widgets are stale, but the ids are not: a block keeps its
    // element across a theme change.
    final widgetsStale =
        _cachedTheme != widget.theme ||
        _cachedBuilders != widget.builders ||
        _cachedDocumentId != widget.documentId ||
        _cachedSelectable != widget.selectable ||
        _cachedSelectionColor != effectiveSelectionColor ||
        !identical(_cachedController, controller) ||
        !identical(_cachedWrapper, widget.blockWrapper);

    if (widgetsStale) {
      _cachedTheme = widget.theme;
      _cachedBuilders = widget.builders;
      _cachedDocumentId = widget.documentId;
      _cachedSelectable = widget.selectable;
      _cachedSelectionColor = effectiveSelectionColor;
      _cachedController = controller;
      _cachedWrapper = widget.blockWrapper;
    }

    final old = _blockCache;
    final newLength = blocks.length;
    final oldLength = old.length;

    // With the same number of blocks, each is compared with the one at its
    // index. When the number changed, blocks were added or removed somewhere:
    // the unchanged ones after that point are found from the end, so typing a
    // new paragraph into the middle of a document does not turn every later
    // block into a different one. A reply that grows at the end pays one
    // extra comparison for this, on the frames where it gains a block.
    var head = 0;
    var shiftedTail = 0;
    if (newLength != oldLength) {
      final shorter = newLength < oldLength ? newLength : oldLength;
      while (head < shorter && old[head].block == blocks[head]) {
        head++;
      }
      final limit = shorter - head;
      while (shiftedTail < limit &&
          old[oldLength - 1 - shiftedTail].block ==
              blocks[newLength - 1 - shiftedTail]) {
        shiftedTail++;
      }
    }
    final shiftedFrom = newLength - shiftedTail;
    final shift = newLength - oldLength;

    final nextCache = <_CachedBlockWidget>[];
    final children = <Widget>[];
    final blockSpacing = widget.theme.blockSpacing;

    for (var i = 0; i < newLength; i++) {
      final block = blocks[i];
      final _CachedBlockWidget entry;

      if (i >= shiftedFrom) {
        // Same block at a new index: same id, new widget for the new index.
        entry = _CachedBlockWidget(
          id: old[i - shift].id,
          block: block,
          widget: _buildBlock(
            id: old[i - shift].id,
            index: i,
            block: block,
            controller: controller,
            selectionColor: effectiveSelectionColor,
          ),
        );
        widget.onBlockBuilt?.call(i, block);
      } else if (i < oldLength - shiftedTail) {
        final previous = old[i];
        if (!widgetsStale && (i < head || previous.block == block)) {
          entry = previous;
          widget.onBlockReused?.call(i, block);
        } else {
          entry = _CachedBlockWidget(
            id: previous.id,
            block: block,
            widget: _buildBlock(
              id: previous.id,
              index: i,
              block: block,
              controller: controller,
              selectionColor: effectiveSelectionColor,
            ),
          );
          widget.onBlockBuilt?.call(i, block);
        }
      } else {
        final id = _nextBlockId++;
        entry = _CachedBlockWidget(
          id: id,
          block: block,
          widget: _buildBlock(
            id: id,
            index: i,
            block: block,
            controller: controller,
            selectionColor: effectiveSelectionColor,
          ),
        );
        widget.onBlockBuilt?.call(i, block);
      }

      nextCache.add(entry);
      if (i > 0 && blockSpacing > 0) {
        children.add(SizedBox(height: blockSpacing));
      }
      children.add(entry.widget);
    }

    _blockCache = nextCache;

    return Column(
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBlock({
    required int id,
    required int index,
    required MarkdownBlock block,
    required MarkdownSelectionController? controller,
    required Color selectionColor,
  }) {
    final key = ValueKey<String>('${widget.documentId}:$id');
    final wrapper = widget.blockWrapper;
    final Widget renderer = MarkdownBlockRenderer(
      key: wrapper == null ? key : null,
      documentId: widget.documentId,
      blockIndex: index,
      block: block,
      theme: widget.theme,
      builders: widget.builders,
      selectionColor: selectionColor,
      selectable: widget.selectable,
      onSurfaceAttach: widget.selectable ? controller?.registerSurface : null,
      onSurfaceDetach: widget.selectable ? controller?.unregisterSurface : null,
    );
    if (wrapper == null) return renderer;
    return KeyedSubtree(key: key, child: wrapper(index, block, renderer));
  }
}

/// Gives the content its own widest natural width when the parent offers
/// unlimited width (a horizontal scroll view, a `Row`, `UnconstrainedBox`).
///
/// Several blocks stretch to the width they are given, which is undefined when
/// that width is infinite. With a bounded width this does nothing.
class _IntrinsicWidthWhenUnbounded extends SingleChildRenderObjectWidget {
  const _IntrinsicWidthWhenUnbounded({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIntrinsicWidthWhenUnbounded();
}

class _RenderIntrinsicWidthWhenUnbounded extends RenderProxyBox {
  @override
  void performLayout() {
    final content = child;
    if (content == null || constraints.hasBoundedWidth) {
      super.performLayout();
      return;
    }
    final natural = content.getMaxIntrinsicWidth(double.infinity);
    final width = natural.clamp(constraints.minWidth, double.maxFinite);
    content.layout(constraints.copyWith(maxWidth: width), parentUsesSize: true);
    size = constraints.constrain(content.size);
  }
}

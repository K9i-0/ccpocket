/// Renders GitHub-Flavored Markdown with `package:flutter/widgets.dart` only,
/// with streaming support and text selection that spans blocks.
///
/// Start with [MarkdownView] (or [SliverMarkdownView] for one long document)
/// inside a [MarkdownSelectionScope].
library;

// Document model.
export 'src/ast/markdown_ast.dart';
export 'src/ast/rendered_text.dart';

// Parsing.
export 'src/parser/block_splitter.dart'
    show sanitizeStreamingTail, splitMarkdownBlocks;
export 'src/parser/gfm_parser.dart' show GfmMarkdownParser;
export 'src/parser/inline_scanner.dart'
    show MarkdownInlineMatch, MarkdownInlineRule;
export 'src/parser/markdown_parser.dart'
    show MarkdownParser, MarkdownParserOptions;

// Appearance and extension points.
export 'src/rendering/block_renderer.dart' show formatLatexFallback;
export 'src/rendering/markdown_builders.dart';
export 'src/rendering/markdown_theme.dart';
export 'src/rendering/selectable_paragraph.dart'
    show
        CodeTextSpan,
        OffsetSegment,
        RenderSelectableParagraph,
        SelectableParagraph,
        TappableTextSpan,
        TextOffsetMapping,
        TextOffsetMappingBuilder;

// Selection.
export 'src/selection/default_context_menu.dart';
export 'src/selection/selection_autoscroll.dart'
    show
        MarkdownAutoscrollTarget,
        MarkdownAutoscrollTargetResolver,
        MarkdownAutoscrollViewport,
        MarkdownCallbackAutoscrollTarget,
        MarkdownScrollableAutoscrollTarget,
        MarkdownSelectionAutoscrollConfig;
export 'src/selection/selection_controller.dart';
export 'src/selection/selection_formatter.dart';
export 'src/selection/selection_handles.dart'
    show
        MarkdownMagnifierBuilder,
        MarkdownSelectionHandleBuilder,
        MarkdownSelectionHandleType,
        kMarkdownEndHandleKey,
        kMarkdownHandleMinHitSize,
        kMarkdownHandleTouchSlop,
        kMarkdownStartHandleKey;
export 'src/selection/selection_model.dart';
export 'src/selection/selection_scope.dart'
    show
        MarkdownCanStartSelectionAt,
        MarkdownContextMenuBuilder,
        MarkdownSelectionScope,
        MarkdownSelectionScopeState;

// Widgets.
export 'src/widgets/markdown_view.dart'
    show MarkdownBlockBuildCallback, MarkdownView;
export 'src/widgets/selectable_plain_text.dart' show SelectablePlainText;
export 'src/widgets/sliver_markdown_view.dart' show SliverMarkdownView;

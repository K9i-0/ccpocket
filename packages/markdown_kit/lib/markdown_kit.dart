/// Standalone Flutter Markdown AST, parser, streaming splitter, selection
/// engine, and renderer built solely on `package:flutter/widgets.dart`.
library;

// AST & canonical rendered-text extraction.
export 'src/ast/markdown_ast.dart';
export 'src/ast/rendered_text.dart';

// Parser, streaming splitter, and inline post-processing scanner.
export 'src/parser/block_splitter.dart';
export 'src/parser/gfm_parser.dart';
export 'src/parser/inline_scanner.dart';
export 'src/parser/markdown_parser.dart';

// Model-anchored selection engine, opaque handles, autoscroll, and formatters.
export 'src/selection/selection_autoscroll.dart';
export 'src/selection/selection_controller.dart';
export 'src/selection/selection_formatter.dart';
export 'src/selection/selection_handles.dart';
export 'src/selection/selection_model.dart';
export 'src/selection/selection_scope.dart';

// Pure widgets.dart rendering layer.
export 'src/rendering/block_renderer.dart';
export 'src/rendering/details_widget.dart';
export 'src/rendering/list_item_widget.dart';
export 'src/rendering/markdown_builders.dart';
export 'src/rendering/markdown_theme.dart';
export 'src/rendering/selectable_paragraph.dart';
export 'src/rendering/table_widget.dart';

// Top-level public widgets.
export 'src/widgets/markdown_view.dart';
export 'src/widgets/selectable_plain_text.dart';
export 'src/widgets/sliver_markdown_view.dart';

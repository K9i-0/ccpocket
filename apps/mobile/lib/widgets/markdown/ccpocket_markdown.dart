import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logger.dart';
import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/code_text_style.dart';
import '../../theme/markdown_style.dart';
import '../../utils/platform_helper.dart';
import '../bubbles/markdown_image_chip.dart';
import 'markdown_math.dart';

/// Resolves ccpocket's Material selection highlight color (with alpha) from
/// [ThemeData], preserving high contrast on both light/dark surfaces and
/// `UserBubble`.
Color ccpocketSelectionHighlightColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textSelectionTheme.selectionColor ??
      theme.colorScheme.primary.withValues(alpha: 0.40);
}

/// Resolves ccpocket's solid opaque handle accent color.
Color ccpocketSelectionHandleColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textSelectionTheme.selectionHandleColor ??
      theme.colorScheme.primary;
}

/// Context menu builder for [CcpocketSelectionScope], [CcpocketMarkdown], and
/// [CcpocketSelectableText].
///
/// Renders Material's [AdaptiveTextSelectionToolbar] with:
/// - **Copy** (plain text)
/// - **Copy as Markdown** (when [showCopyAsMarkdown] is `true` and the active
///   document is not classified as plain text by [isPlainTextDocument])
/// - **Search with Google** (native macOS only)
/// - **Select All**
Widget ccpocketSelectionContextMenuBuilder(
  BuildContext context,
  MarkdownSelectionScopeState state, {
  bool showCopyAsMarkdown = true,
  bool Function(String documentId)? isPlainTextDocument,
}) {
  final plainText = state.selectedPlainText;
  final trimmed = plainText.trim();
  final markdown = state.selectedMarkdown;
  final activeDocId = state.controller.selection?.base.documentId;
  final includeCopyAsMarkdown =
      showCopyAsMarkdown &&
      markdown.isNotEmpty &&
      (activeDocId == null ||
          !(isPlainTextDocument?.call(activeDocId) ?? false));

  final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
  final copyAsMarkdownLabel =
      l?.copyAsMarkdownSelectionAction ?? 'Copy as Markdown';
  final googleSearchLabel =
      l?.googleSearchSelectionAction ?? 'Search with Google';

  final items = <ContextMenuButtonItem>[
    if (plainText.isNotEmpty)
      ContextMenuButtonItem(
        type: ContextMenuButtonType.copy,
        onPressed: () {
          unawaited(state.copySelection());
        },
      ),
    if (includeCopyAsMarkdown)
      ContextMenuButtonItem(
        label: copyAsMarkdownLabel,
        onPressed: () {
          unawaited(state.copySelectionAsMarkdown());
        },
      ),
    if (isMacOSPlatform && trimmed.isNotEmpty)
      ContextMenuButtonItem(
        label: googleSearchLabel,
        onPressed: () {
          state.hideToolbar();
          unawaited(_openGoogleSearch(trimmed));
        },
      ),
    ContextMenuButtonItem(
      type: ContextMenuButtonType.selectAll,
      onPressed: state.selectAll,
    ),
  ];

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: items,
  );
}

Future<void> _openGoogleSearch(String query) async {
  if (query.isEmpty) return;
  final uri = Uri.https('www.google.com', '/search', {'q': query});
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.error('Failed to open Google search: $uri');
    }
  } catch (error, stackTrace) {
    logger.error('Failed to open Google search', error, stackTrace);
  }
}

/// Custom solid-colored selection handle builder matching iOS pin / Android
/// teardrop shapes while keeping the opaque 44x44 hit target from
/// `markdown_kit`.
Widget ccpocketSelectionHandleBuilder(
  BuildContext context,
  MarkdownSelectionHandleType type,
  double lineHeight,
  Color color,
) {
  final solidColor = ccpocketSelectionHandleColor(context);
  final isApple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return CustomPaint(
    size: const Size(kMarkdownHandleMinHitSize, kMarkdownHandleMinHitSize),
    painter: isApple
        ? _CcpocketAppleHandlePainter(
            type: type,
            lineHeight: lineHeight,
            color: solidColor,
          )
        : _CcpocketTeardropHandlePainter(type: type, color: solidColor),
  );
}

class _CcpocketAppleHandlePainter extends CustomPainter {
  const _CcpocketAppleHandlePainter({
    required this.type,
    required this.lineHeight,
    required this.color,
  });

  final MarkdownSelectionHandleType type;
  final double lineHeight;
  final Color color;

  static const double _ballRadius = 5.5;
  static const double _stemWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final cx = size.width / 2;

    if (type == MarkdownSelectionHandleType.start) {
      final caretTopY = size.height - 14.0;
      final caretBottomY = caretTopY + lineHeight;
      final ballCenterY = caretTopY - _ballRadius;
      canvas.drawRect(
        Rect.fromLTRB(
          cx - _stemWidth / 2,
          caretTopY,
          cx + _stemWidth / 2,
          caretBottomY,
        ),
        paint,
      );
      canvas.drawCircle(Offset(cx, ballCenterY), _ballRadius, paint);
    } else {
      const caretBottomY = 6.0;
      final caretTopY = caretBottomY - lineHeight;
      final ballCenterY = caretBottomY + _ballRadius;
      canvas.drawRect(
        Rect.fromLTRB(
          cx - _stemWidth / 2,
          caretTopY,
          cx + _stemWidth / 2,
          caretBottomY,
        ),
        paint,
      );
      canvas.drawCircle(Offset(cx, ballCenterY), _ballRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_CcpocketAppleHandlePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.color != color;
  }
}

class _CcpocketTeardropHandlePainter extends CustomPainter {
  const _CcpocketTeardropHandlePainter({
    required this.type,
    required this.color,
  });

  final MarkdownSelectionHandleType type;
  final Color color;

  static const double _radius = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final isStart = type == MarkdownSelectionHandleType.start;
    final tipX = isStart ? size.width * 0.75 : size.width * 0.25;
    const tipY = 6.0;
    final centerX = isStart ? tipX - _radius : tipX + _radius;
    const centerY = tipY + _radius;

    final path = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: _radius),
      );
    if (isStart) {
      path.addRect(Rect.fromLTWH(centerX, tipY, _radius, _radius));
    } else {
      path.addRect(Rect.fromLTWH(tipX, tipY, _radius, _radius));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CcpocketTeardropHandlePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

/// ccpocket-styled [MarkdownSelectionScope] wired with `material_ui` colors,
/// opaque solid handles, and [ccpocketSelectionContextMenuBuilder].
class CcpocketSelectionScope extends StatefulWidget {
  const CcpocketSelectionScope({
    super.key,
    required this.child,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.allowCrossDocumentSelection = false,
    this.showCopyAsMarkdown = true,
    this.isPlainTextDocument,
    this.selectionColor,
    this.autoscroll = const MarkdownSelectionAutoscrollConfig(),
    this.canStartSelectionAt,
    this.onSelectionChanged,
  });

  final Widget child;
  final MarkdownSelectionController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool allowCrossDocumentSelection;
  final bool showCopyAsMarkdown;
  final bool Function(String documentId)? isPlainTextDocument;
  final Color? selectionColor;
  final MarkdownSelectionAutoscrollConfig autoscroll;
  final MarkdownCanStartSelectionAt? canStartSelectionAt;
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;

  @override
  State<CcpocketSelectionScope> createState() => _CcpocketSelectionScopeState();
}

class _CcpocketSelectionScopeState extends State<CcpocketSelectionScope> {
  MarkdownSelectionController? _ownedController;

  MarkdownSelectionController get _effectiveController {
    if (widget.controller != null) return widget.controller!;
    return _ownedController ??= MarkdownSelectionController(
      allowCrossDocumentSelection: widget.allowCrossDocumentSelection,
    );
  }

  @override
  void didUpdateWidget(covariant CcpocketSelectionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
    } else if (widget.controller == null &&
        oldWidget.allowCrossDocumentSelection !=
            widget.allowCrossDocumentSelection) {
      _ownedController?.dispose();
      _ownedController = MarkdownSelectionController(
        allowCrossDocumentSelection: widget.allowCrossDocumentSelection,
      );
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  Widget _buildContextMenu(
    BuildContext context,
    MarkdownSelectionScopeState state,
  ) {
    return ccpocketSelectionContextMenuBuilder(
      context,
      state,
      showCopyAsMarkdown: widget.showCopyAsMarkdown,
      isPlainTextDocument: widget.isPlainTextDocument,
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        widget.selectionColor ?? ccpocketSelectionHighlightColor(context);
    return MarkdownSelectionScope(
      controller: _effectiveController,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      selectionColor: highlightColor,
      contextMenuBuilder: _buildContextMenu,
      handleBuilder: ccpocketSelectionHandleBuilder,
      autoscroll: widget.autoscroll,
      canStartSelectionAt: widget.canStartSelectionAt,
      onSelectionChanged: widget.onSelectionChanged,
      child: widget.child,
    );
  }
}

/// Shared helper constructing a tappable file-path [TappableTextSpan] with
/// monospace w600 primary styling, dotted underline, solid hover underline,
/// and click cursor.
TappableTextSpan buildCcpocketFilePathSpan({
  required BuildContext context,
  required String displayText,
  required String path,
  required FilePathTapCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final baseStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: cs.primary,
    decoration: TextDecoration.underline,
    decorationColor: cs.primary.withValues(alpha: 0.4),
    decorationStyle: TextDecorationStyle.dotted,
  );
  final hoverStyle = TextStyle(
    color: cs.primary,
    decoration: TextDecoration.underline,
    decorationColor: cs.primary,
    decorationStyle: TextDecorationStyle.solid,
  );
  return TappableTextSpan(
    text: displayText,
    style: baseStyle,
    hoverStyle: onTap != null ? hoverStyle : null,
    mouseCursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
    onTap: onTap != null ? () => onTap(path) : null,
  );
}

/// Shared inline-code builder supporting:
/// 1. Backtick file paths (matching `knownPathSuffixes` or explicit paths)
/// 2. Hex color codes (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`) with a
///    baseline-aligned circular swatch + monospace text
/// 3. Standard pill-decorated [CodeTextSpan]
InlineSpan _buildCcpocketInlineCode({
  required BuildContext context,
  required String code,
  required TextStyle style,
  required MarkdownInlineCodeStyle codeStyle,
  required FilePathTapCallback? onFileTap,
  required Set<String> knownPathSuffixes,
  required bool enableColorCodes,
}) {
  if (onFileTap != null &&
      FilePathSyntax.isBacktickFilePath(code, knownPathSuffixes)) {
    return buildCcpocketFilePathSpan(
      context: context,
      displayText: code,
      path: code,
      onTap: onFileTap,
    );
  }

  if (enableColorCodes) {
    final color = parseHexColor(code);
    if (color != null) {
      final cs = Theme.of(context).colorScheme;
      final swatchTextStyle = codeTextSettingsOf(context)
          .style(color: style.color);
      return TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
          TextSpan(text: code, style: swatchTextStyle),
        ],
      );
    }
  }

  return CodeTextSpan(text: code, style: style, codeStyle: codeStyle);
}

MarkdownParserOptions _buildCcpocketParserOptions({
  required bool enableLocalhostAutolink,
  required bool enableBareFilePaths,
  required Set<String> knownPathSuffixes,
}) {
  final rules = <MarkdownInlineRule>[
    if (enableLocalhostAutolink) ...localhostAutolinkInlineRules,
    if (enableBareFilePaths && knownPathSuffixes.isNotEmpty)
      BareFilePathRule(knownPathSuffixes: knownPathSuffixes),
  ];
  return MarkdownParserOptions(inlineRules: rules);
}

/// ccpocket Markdown widget backed by `markdown_kit`'s [MarkdownView].
///
/// Caches [MarkdownParserOptions] and [MarkdownBuilders] across rebuilds so
/// `MarkdownView`'s block-level cache preserves unchanged widgets during
/// streaming and theme-stable rebuilds.
class CcpocketMarkdown extends StatefulWidget {
  const CcpocketMarkdown({
    super.key,
    required this.data,
    this.document,
    this.documentId,
    this.documentOrder = 0,
    this.isStreaming = false,
    this.selectable = true,
    this.onFileTap,
    this.knownPathSuffixes = const {},
    this.onLinkTap,
    this.useChatLinkHandler = false,
    this.useChatImageBuilder = false,
    this.enableColorCodes = true,
    this.enableLocalhostAutolink = true,
    this.selectionColor,
    this.onSelectionChanged,
    this.onBlockBuilt,
    this.onBlockReused,
    this.shrinkWrap = true,
    this.keepDocumentOnDispose = true,
  });

  final String data;
  final MarkdownDocument? document;
  final String? documentId;
  final int documentOrder;
  final bool isStreaming;
  final bool selectable;
  final FilePathTapCallback? onFileTap;
  final Set<String> knownPathSuffixes;
  final MarkdownLinkTapCallback? onLinkTap;
  final bool useChatLinkHandler;
  final bool useChatImageBuilder;
  final bool enableColorCodes;
  final bool enableLocalhostAutolink;
  final Color? selectionColor;
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;
  final MarkdownBlockBuildCallback? onBlockBuilt;
  final MarkdownBlockBuildCallback? onBlockReused;
  final bool shrinkWrap;
  final bool keepDocumentOnDispose;

  @override
  State<CcpocketMarkdown> createState() => _CcpocketMarkdownState();
}

class _CcpocketMarkdownState extends State<CcpocketMarkdown> {
  late MarkdownParserOptions _parserOptions;
  late MarkdownBuilders _builders;

  @override
  void initState() {
    super.initState();
    _rebuildConfig();
  }

  @override
  void didUpdateWidget(covariant CcpocketMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final suffixesChanged =
        !identical(oldWidget.knownPathSuffixes, widget.knownPathSuffixes) &&
        !setEquals(oldWidget.knownPathSuffixes, widget.knownPathSuffixes);
    if (oldWidget.onFileTap != widget.onFileTap ||
        suffixesChanged ||
        oldWidget.onLinkTap != widget.onLinkTap ||
        oldWidget.useChatLinkHandler != widget.useChatLinkHandler ||
        oldWidget.useChatImageBuilder != widget.useChatImageBuilder ||
        oldWidget.enableColorCodes != widget.enableColorCodes ||
        oldWidget.enableLocalhostAutolink != widget.enableLocalhostAutolink) {
      _rebuildConfig();
    }
  }

  void _rebuildConfig() {
    final onFileTap = widget.onFileTap;
    final suffixes = widget.knownPathSuffixes;
    final enableColorCodes = widget.enableColorCodes;

    _parserOptions = _buildCcpocketParserOptions(
      enableLocalhostAutolink: widget.enableLocalhostAutolink,
      enableBareFilePaths: onFileTap != null,
      knownPathSuffixes: suffixes,
    );

    final MarkdownLinkTapCallback effectiveOnLinkTap;
    if (widget.onLinkTap != null) {
      effectiveOnLinkTap = widget.onLinkTap!;
    } else if (widget.useChatLinkHandler) {
      effectiveOnLinkTap = (url, title) {
        if (!mounted) return;
        buildChatMarkdownLinkHandler(
          context,
          onFileTap: onFileTap,
          knownPathSuffixes: suffixes,
        )(url, title);
      };
    } else {
      effectiveOnLinkTap = handleMarkdownLink;
    }

    _builders = MarkdownBuilders(
      codeHighlighter: highlightCcpocketCodeBlock,
      codeBlockBuilder: buildCcpocketCodeBlock,
      inlineLatexBuilder: buildCcpocketInlineLatex,
      blockLatexBuilder: buildCcpocketBlockLatex,
      inlineCodeBuilder: (ctx, code, style, codeStyle) =>
          _buildCcpocketInlineCode(
            context: ctx,
            code: code,
            style: style,
            codeStyle: codeStyle,
            onFileTap: onFileTap,
            knownPathSuffixes: suffixes,
            enableColorCodes: enableColorCodes,
          ),
      customInlineBuilder: onFileTap != null
          ? (ctx, inline, style) {
              if (inline.kind == kFilePathInlineKind) {
                final path = inline.data['path'] as String? ?? inline.text;
                return buildCcpocketFilePathSpan(
                  context: ctx,
                  displayText: inline.text,
                  path: path,
                  onTap: onFileTap,
                );
              }
              return TextSpan(text: inline.text, style: style);
            }
          : null,
      imageBuilder: widget.useChatImageBuilder
          ? chatMarkdownImageBuilder(onFileTap: onFileTap)
          : null,
      onLinkTap: effectiveOnLinkTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final markdownTheme = buildMarkdownTheme(context);
    final effectiveSelectionColor =
        widget.selectionColor ?? markdownTheme.selectionColor;

    return MarkdownView(
      data: widget.data,
      document: widget.document,
      documentId: widget.documentId,
      documentOrder: widget.documentOrder,
      parserOptions: _parserOptions,
      theme: markdownTheme,
      builders: _builders,
      isStreaming: widget.isStreaming,
      selectable: widget.selectable,
      selectionColor: effectiveSelectionColor,
      contextMenuBuilder: ccpocketSelectionContextMenuBuilder,
      handleBuilder: ccpocketSelectionHandleBuilder,
      onSelectionChanged: widget.onSelectionChanged,
      onBlockBuilt: widget.onBlockBuilt,
      onBlockReused: widget.onBlockReused,
      shrinkWrap: widget.shrinkWrap,
      keepDocumentOnDispose: widget.keepDocumentOnDispose,
    );
  }
}

/// Viewport-lazy sliver Markdown widget for single long-document screens
/// (`FilePeekMarkdown`, `PlanDetailSheet`, `AuthHelpScreen`,
/// `ChangelogScreen`).
///
/// Must be placed inside a [CustomScrollView] wrapped in a
/// [CcpocketSelectionScope].
class CcpocketSliverMarkdown extends StatefulWidget {
  const CcpocketSliverMarkdown({
    super.key,
    required this.data,
    this.document,
    this.documentId,
    this.documentOrder = 0,
    this.isStreaming = false,
    this.selectable = true,
    this.onFileTap,
    this.knownPathSuffixes = const {},
    this.onLinkTap,
    this.useChatLinkHandler = false,
    this.useChatImageBuilder = false,
    this.enableColorCodes = true,
    this.enableLocalhostAutolink = true,
    this.selectionColor,
    this.onBlockBuilt,
    this.keepDocumentOnDispose = true,
  });

  final String data;
  final MarkdownDocument? document;
  final String? documentId;
  final int documentOrder;
  final bool isStreaming;
  final bool selectable;
  final FilePathTapCallback? onFileTap;
  final Set<String> knownPathSuffixes;
  final MarkdownLinkTapCallback? onLinkTap;
  final bool useChatLinkHandler;
  final bool useChatImageBuilder;
  final bool enableColorCodes;
  final bool enableLocalhostAutolink;
  final Color? selectionColor;
  final MarkdownBlockBuildCallback? onBlockBuilt;
  final bool keepDocumentOnDispose;

  @override
  State<CcpocketSliverMarkdown> createState() => _CcpocketSliverMarkdownState();
}

class _CcpocketSliverMarkdownState extends State<CcpocketSliverMarkdown> {
  late MarkdownParserOptions _parserOptions;
  late MarkdownBuilders _builders;

  @override
  void initState() {
    super.initState();
    _rebuildConfig();
  }

  @override
  void didUpdateWidget(covariant CcpocketSliverMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final suffixesChanged =
        !identical(oldWidget.knownPathSuffixes, widget.knownPathSuffixes) &&
        !setEquals(oldWidget.knownPathSuffixes, widget.knownPathSuffixes);
    if (oldWidget.onFileTap != widget.onFileTap ||
        suffixesChanged ||
        oldWidget.onLinkTap != widget.onLinkTap ||
        oldWidget.useChatLinkHandler != widget.useChatLinkHandler ||
        oldWidget.useChatImageBuilder != widget.useChatImageBuilder ||
        oldWidget.enableColorCodes != widget.enableColorCodes ||
        oldWidget.enableLocalhostAutolink != widget.enableLocalhostAutolink) {
      _rebuildConfig();
    }
  }

  void _rebuildConfig() {
    final onFileTap = widget.onFileTap;
    final suffixes = widget.knownPathSuffixes;
    final enableColorCodes = widget.enableColorCodes;

    _parserOptions = _buildCcpocketParserOptions(
      enableLocalhostAutolink: widget.enableLocalhostAutolink,
      enableBareFilePaths: onFileTap != null,
      knownPathSuffixes: suffixes,
    );

    final MarkdownLinkTapCallback effectiveOnLinkTap;
    if (widget.onLinkTap != null) {
      effectiveOnLinkTap = widget.onLinkTap!;
    } else if (widget.useChatLinkHandler) {
      effectiveOnLinkTap = (url, title) {
        if (!mounted) return;
        buildChatMarkdownLinkHandler(
          context,
          onFileTap: onFileTap,
          knownPathSuffixes: suffixes,
        )(url, title);
      };
    } else {
      effectiveOnLinkTap = handleMarkdownLink;
    }

    _builders = MarkdownBuilders(
      codeHighlighter: highlightCcpocketCodeBlock,
      codeBlockBuilder: buildCcpocketCodeBlock,
      inlineLatexBuilder: buildCcpocketInlineLatex,
      blockLatexBuilder: buildCcpocketBlockLatex,
      inlineCodeBuilder: (ctx, code, style, codeStyle) =>
          _buildCcpocketInlineCode(
            context: ctx,
            code: code,
            style: style,
            codeStyle: codeStyle,
            onFileTap: onFileTap,
            knownPathSuffixes: suffixes,
            enableColorCodes: enableColorCodes,
          ),
      customInlineBuilder: onFileTap != null
          ? (ctx, inline, style) {
              if (inline.kind == kFilePathInlineKind) {
                final path = inline.data['path'] as String? ?? inline.text;
                return buildCcpocketFilePathSpan(
                  context: ctx,
                  displayText: inline.text,
                  path: path,
                  onTap: onFileTap,
                );
              }
              return TextSpan(text: inline.text, style: style);
            }
          : null,
      imageBuilder: widget.useChatImageBuilder
          ? chatMarkdownImageBuilder(onFileTap: onFileTap)
          : null,
      onLinkTap: effectiveOnLinkTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final markdownTheme = buildMarkdownTheme(context);
    final effectiveSelectionColor =
        widget.selectionColor ?? markdownTheme.selectionColor;

    return SliverMarkdownView(
      data: widget.data,
      document: widget.document,
      documentId: widget.documentId,
      documentOrder: widget.documentOrder,
      parserOptions: _parserOptions,
      theme: markdownTheme,
      builders: _builders,
      isStreaming: widget.isStreaming,
      selectable: widget.selectable,
      selectionColor: effectiveSelectionColor,
      onBlockBuilt: widget.onBlockBuilt,
      keepDocumentOnDispose: widget.keepDocumentOnDispose,
    );
  }
}

/// ccpocket selectable plain-text widget participating in the same
/// [MarkdownSelectionScope] / [MarkdownSelectionController] as
/// [CcpocketMarkdown] (used by `UserBubble` and `AssistantBubble` plain-text
/// mode).
class CcpocketSelectableText extends StatelessWidget {
  const CcpocketSelectableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.documentId,
    this.documentOrder = 0,
    this.selectable = true,
    this.selectionColor,
    this.onSelectionChanged,
    this.keepDocumentOnDispose = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final String? documentId;
  final int documentOrder;
  final bool selectable;
  final Color? selectionColor;
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;
  final bool keepDocumentOnDispose;

  static Widget _plainTextContextMenuBuilder(
    BuildContext context,
    MarkdownSelectionScopeState state,
  ) {
    return ccpocketSelectionContextMenuBuilder(
      context,
      state,
      showCopyAsMarkdown: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        selectionColor ?? ccpocketSelectionHighlightColor(context);
    return SelectablePlainText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      documentId: documentId,
      documentOrder: documentOrder,
      selectable: selectable,
      selectionColor: highlightColor,
      contextMenuBuilder: _plainTextContextMenuBuilder,
      handleBuilder: ccpocketSelectionHandleBuilder,
      onSelectionChanged: onSelectionChanged,
      keepDocumentOnDispose: keepDocumentOnDispose,
    );
  }
}

/// Styled command-text variant for `UserBubble`'s `/command args` display,
/// participating in the same [MarkdownSelectionScope] engine.
class CcpocketSelectableCommandText extends StatelessWidget {
  const CcpocketSelectableCommandText({
    super.key,
    required this.commandName,
    this.args,
    required this.textColor,
    this.documentId,
    this.documentOrder = 0,
    this.selectionColor,
    this.onSelectionChanged,
    this.keepDocumentOnDispose = true,
  });

  final String commandName;
  final String? args;
  final Color textColor;
  final String? documentId;
  final int documentOrder;
  final Color? selectionColor;
  final ValueChanged<MarkdownSelection?>? onSelectionChanged;
  final bool keepDocumentOnDispose;

  static const _commandInlineKind = 'userCommand';

  static Widget _plainTextContextMenuBuilder(
    BuildContext context,
    MarkdownSelectionScopeState state,
  ) {
    return ccpocketSelectionContextMenuBuilder(
      context,
      state,
      showCopyAsMarkdown: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasArgs = args != null && args!.isNotEmpty;
    final fullText = hasArgs ? '$commandName $args' : commandName;
    final doc = MarkdownDocument(
      blocks: [
        ParagraphBlock(
          inlines: [
            CustomInline(kind: _commandInlineKind, text: commandName),
            if (hasArgs) TextInline(' $args'),
          ],
        ),
      ],
      source: fullText,
    );
    final baseStyle = (DefaultTextStyle.of(
      context,
    ).style).copyWith(color: textColor);
    final highlightColor =
        selectionColor ?? ccpocketSelectionHighlightColor(context);

    return MarkdownView(
      document: doc,
      documentId: documentId,
      documentOrder: documentOrder,
      theme: MarkdownThemeData(
        bodyStyle: baseStyle,
        selectionColor: highlightColor,
      ),
      builders: MarkdownBuilders(
        customInlineBuilder: (ctx, inline, style) {
          if (inline.kind == _commandInlineKind) {
            return TextSpan(
              text: inline.text,
              style: style.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            );
          }
          return TextSpan(text: inline.text, style: style);
        },
      ),
      selectionColor: highlightColor,
      contextMenuBuilder: _plainTextContextMenuBuilder,
      handleBuilder: ccpocketSelectionHandleBuilder,
      onSelectionChanged: onSelectionChanged,
      keepDocumentOnDispose: keepDocumentOnDispose,
    );
  }
}

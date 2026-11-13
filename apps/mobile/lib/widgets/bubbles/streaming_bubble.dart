import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/markdown_style.dart';
import '../../utils/markdown_block_splitter.dart';
import '../link_hover_underline.dart';

class StreamingBubble extends StatefulWidget {
  final String text;
  final FilePathTapCallback? onFileTap;
  final VoidCallback? onBeforeTextUpdate;

  const StreamingBubble({
    super.key,
    required this.text,
    this.onFileTap,
    this.onBeforeTextUpdate,
  });

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble>
    with SingleTickerProviderStateMixin {
  // Markdown parsing is the expensive part of a streaming update, so cap
  // transient updates at roughly 30 fps while retaining every received
  // character. Completed top-level blocks are additionally cached (see
  // [_buildMarkdownBlocks]) so only the trailing block is re-parsed.
  static const _markdownUpdateInterval = Duration(milliseconds: 32);
  static const _immediateDeltaLength = 128;

  late final AnimationController _cursorController;
  late MarkdownStyleSheet _markdownStyle;
  late String _renderedText;
  Timer? _markdownUpdateTimer;

  /// Built widgets per top-level markdown block, reused while their source
  /// and rendering inputs are unchanged so Flutter skips rebuilding them.
  List<_MarkdownBlockCache> _blockCache = const [];
  MarkdownStyleSheet? _cachedStyle;
  FilePathTapCallback? _cachedOnFileTap;
  Set<String>? _cachedFileSuffixes;

  @override
  void initState() {
    super.initState();
    _renderedText = widget.text;
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _markdownStyle = buildMarkdownStyle(context);
  }

  @override
  void didUpdateWidget(covariant StreamingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _renderedText) return;

    final isAppend = widget.text.startsWith(oldWidget.text);
    final deltaLength = isAppend
        ? widget.text.length - oldWidget.text.length
        : _immediateDeltaLength;
    if (deltaLength >= _immediateDeltaLength) {
      _markdownUpdateTimer?.cancel();
      _markdownUpdateTimer = null;
      _renderedText = widget.text;
      return;
    }

    if (_markdownUpdateTimer != null) return;
    _markdownUpdateTimer = Timer(_markdownUpdateInterval, _flushMarkdownText);
  }

  void _flushMarkdownText() {
    _markdownUpdateTimer = null;
    if (!mounted || widget.text == _renderedText) return;
    widget.onBeforeTextUpdate?.call();
    if (!mounted) return;
    setState(() => _renderedText = widget.text);
  }

  @override
  void dispose() {
    _markdownUpdateTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  Widget _buildMarkdownBlocks(BuildContext context, Set<String> fileSuffixes) {
    if (!identical(_cachedStyle, _markdownStyle) ||
        _cachedOnFileTap != widget.onFileTap ||
        !identical(_cachedFileSuffixes, fileSuffixes)) {
      _blockCache = const [];
      _cachedStyle = _markdownStyle;
      _cachedOnFileTap = widget.onFileTap;
      _cachedFileSuffixes = fileSuffixes;
    }

    final sources = splitMarkdownBlocks(_renderedText);
    final next = <_MarkdownBlockCache>[];
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      if (i < _blockCache.length && _blockCache[i].source == source) {
        next.add(_blockCache[i]);
        if (!kReleaseMode) markdownPerformanceProbe.streamingBlockReuses++;
        continue;
      }
      next.add(
        _MarkdownBlockCache(
          source,
          _buildMarkdownBody(context, source, fileSuffixes, ValueKey(i)),
        ),
      );
      if (!kReleaseMode) markdownPerformanceProbe.streamingBlockBuilds++;
    }
    _blockCache = next;

    if (next.length == 1) return next.single.widget;
    // Mirrors MarkdownBody's own layout of top-level blocks (fitContent:
    // start-aligned, shrink-wrapped, blockSpacing between blocks).
    final spacing = SizedBox(height: _markdownStyle.blockSpacing ?? 8.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < next.length; i++) ...[
          if (i > 0) spacing,
          next[i].widget,
        ],
      ],
    );
  }

  Widget _buildMarkdownBody(
    BuildContext context,
    String data,
    Set<String> fileSuffixes,
    Key key,
  ) {
    return MarkdownBody(
      key: key,
      data: data,
      styleSheet: _markdownStyle,
      onTapLink: buildChatMarkdownLinkHandler(
        context,
        onFileTap: widget.onFileTap,
        knownPathSuffixes: fileSuffixes,
      ),
      inlineSyntaxes: [
        if (widget.onFileTap != null) ...[
          FilePathSyntax(knownPathSuffixes: fileSuffixes),
          BareFilePathSyntax(knownPathSuffixes: fileSuffixes),
        ],
        ...colorCodeInlineSyntaxes,
        ...localhostAutolinkInlineSyntaxes,
      ],
      builders: {
        if (widget.onFileTap != null)
          'filePath': FilePathBuilder(onTap: widget.onFileTap),
        ...markdownBuilders,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_renderedText.isEmpty) return const SizedBox.shrink();
    final fileSuffixes = widget.onFileTap != null
        ? FilePathSyntax.cachedSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinkHoverUnderline(
            child: _buildMarkdownBlocks(context, fileSuffixes),
          ),
          AnimatedBuilder(
            animation: _cursorController,
            builder: (context, child) {
              return Opacity(
                opacity: _cursorController.value,
                child: const Text(
                  '\u258D',
                  style: TextStyle(fontSize: 16, height: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MarkdownBlockCache {
  final String source;
  final Widget widget;

  const _MarkdownBlockCache(this.source, this.widget);
}

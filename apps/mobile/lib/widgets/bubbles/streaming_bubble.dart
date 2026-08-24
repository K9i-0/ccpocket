import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../features/file_peek/markdown_link_handler.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/markdown_style.dart';

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
  // MarkdownBody reparses all accumulated text, so cap transient updates at
  // roughly 30 fps while retaining every received character.
  static const _markdownUpdateInterval = Duration(milliseconds: 32);
  static const _immediateDeltaLength = 128;

  late final AnimationController _cursorController;
  late MarkdownStyleSheet _markdownStyle;
  late String _renderedText;
  Timer? _markdownUpdateTimer;

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
          MarkdownBody(
            data: _renderedText,
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
            ],
            builders: {
              if (widget.onFileTap != null)
                'filePath': FilePathBuilder(onTap: widget.onFileTap),
              ...markdownBuilders,
            },
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

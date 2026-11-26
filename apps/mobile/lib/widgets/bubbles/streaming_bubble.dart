import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/file_peek/file_path_syntax.dart';
import '../../providers/bridge_cubits.dart';
import '../../theme/app_spacing.dart';
import '../../theme/markdown_style.dart';
import '../markdown/ccpocket_markdown.dart';
import 'thinking_bubble.dart';

class StreamingBubble extends StatefulWidget {
  final String text;
  final String thinking;
  final FilePathTapCallback? onFileTap;
  final VoidCallback? onBeforeTextUpdate;
  final String? documentId;
  final int documentOrder;

  const StreamingBubble({
    super.key,
    required this.text,
    this.thinking = '',
    this.onFileTap,
    this.onBeforeTextUpdate,
    this.documentId,
    this.documentOrder = 0,
  });

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble>
    with SingleTickerProviderStateMixin {
  // Markdown parsing is the expensive part of a streaming update, so cap
  // transient updates at roughly 30 fps while retaining every received
  // character. Completed top-level blocks are additionally cached inside
  // `MarkdownView` so only the trailing block is re-parsed and rebuilt.
  static const _markdownUpdateInterval = Duration(milliseconds: 32);
  static const _immediateDeltaLength = 128;

  late final AnimationController _cursorController;
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

  void _recordBlockBuilt(int _, Object? _) {
    if (!kReleaseMode) markdownPerformanceProbe.streamingBlockBuilds++;
  }

  void _recordBlockReused(int _, Object? _) {
    if (!kReleaseMode) markdownPerformanceProbe.streamingBlockReuses++;
  }

  @override
  Widget build(BuildContext context) {
    final hasThinking = widget.thinking.trim().isNotEmpty;
    final hasText = _renderedText.isNotEmpty;
    if (!hasThinking && !hasText) return const SizedBox.shrink();
    final fileSuffixes = hasText && widget.onFileTap != null
        ? FilePathSyntax.cachedSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};

    final effectiveDocId = widget.documentId != null
        ? '${widget.documentId}:text:0'
        : null;

    final textSection = hasText
        ? Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.bubbleMarginV,
              horizontal: AppSpacing.bubbleMarginH,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                CcpocketMarkdown(
                  data: _renderedText,
                  isStreaming: true,
                  documentId: effectiveDocId,
                  documentOrder: widget.documentOrder,
                  onFileTap: widget.onFileTap,
                  knownPathSuffixes: fileSuffixes,
                  useChatLinkHandler: true,
                  onBlockBuilt: _recordBlockBuilt,
                  onBlockReused: _recordBlockReused,
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
          )
        : null;

    if (!hasThinking) return textSection!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ThinkingBubble(
          thinking: widget.thinking,
          isStreaming: widget.text.isEmpty,
        ),
        ?textSection,
      ],
    );
  }
}

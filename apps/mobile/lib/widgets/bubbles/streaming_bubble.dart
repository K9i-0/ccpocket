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

  const StreamingBubble({super.key, required this.text, this.onFileTap});

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final fileSuffixes = widget.onFileTap != null
        ? FilePathSyntax.buildSuffixSet(context.watch<FileListCubit>().state)
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
            data: widget.text,
            styleSheet: buildMarkdownStyle(context),
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

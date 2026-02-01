import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import 'image_preview.dart';

class ToolResultBubble extends StatefulWidget {
  final ToolResultMessage message;
  final String? httpBaseUrl;
  const ToolResultBubble({super.key, required this.message, this.httpBaseUrl});

  @override
  State<ToolResultBubble> createState() => _ToolResultBubbleState();
}

class _ToolResultBubbleState extends State<ToolResultBubble> {
  bool _expanded = false;

  static const _previewLines = 5;

  IconData _toolIcon(String? name) {
    return switch (name) {
      'Bash' => Icons.terminal,
      'Edit' || 'FileEdit' => Icons.edit_note,
      'Read' || 'FileRead' => Icons.description_outlined,
      'Write' || 'FileWrite' => Icons.create_new_folder_outlined,
      'Grep' => Icons.search,
      'Glob' => Icons.folder_open,
      'WebFetch' => Icons.language,
      'WebSearch' => Icons.travel_explore,
      'Task' || 'Agent' => Icons.smart_toy_outlined,
      'NotebookEdit' => Icons.code,
      _ => Icons.build_outlined,
    };
  }

  String _buildSummary(String content, String? toolName) {
    final lines = content.split('\n');
    final lineCount = lines.length;

    if (toolName == 'Edit' || toolName == 'FileEdit') {
      var added = 0;
      var removed = 0;
      for (final line in lines) {
        if (line.startsWith('+') && !line.startsWith('+++')) added++;
        if (line.startsWith('-') && !line.startsWith('---')) removed++;
      }
      if (added > 0 || removed > 0) {
        return '+$added/-$removed lines';
      }
    }

    if (lineCount == 1 && content.length < 40) {
      return content;
    }

    return '$lineCount lines';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final content = widget.message.content;
    final toolName = widget.message.toolName;
    final lines = content.split('\n');
    final hasMore = lines.length > _previewLines;
    final previewText = hasMore
        ? lines.take(_previewLines).join('\n')
        : content;
    final summary = _buildSummary(content, toolName);

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: appColors.toolResultBackground,
            borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message.images.isNotEmpty &&
                  widget.httpBaseUrl != null) ...[
                ImagePreviewWidget(
                  images: widget.message.images,
                  httpBaseUrl: widget.httpBaseUrl!,
                ),
                const SizedBox(height: 8),
              ],
              // Header row: icon + tool name + summary badge + expand icon
              Row(
                children: [
                  Icon(
                    _toolIcon(toolName),
                    size: 14,
                    color: appColors.toolIcon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    toolName ?? 'Tool Result',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.toolIcon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontSize: 10,
                        color: appColors.toolIcon,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: appColors.subtleText,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Content
              if (_expanded)
                SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: appColors.toolResultTextExpanded,
                    height: 1.4,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewText,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: appColors.toolResultText,
                        height: 1.4,
                      ),
                      maxLines: _previewLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... ${lines.length - _previewLines} more lines',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: appColors.subtleText,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

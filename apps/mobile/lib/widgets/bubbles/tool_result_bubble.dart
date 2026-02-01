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

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final content = widget.message.content;
    final preview = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appColors.toolResultBackground,
            borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message.images.isNotEmpty && widget.httpBaseUrl != null) ...[
                ImagePreviewWidget(
                  images: widget.message.images,
                  httpBaseUrl: widget.httpBaseUrl!,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Tool Result',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    content,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: appColors.toolResultTextExpanded,
                    ),
                  ),
                )
              else
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: appColors.toolResultText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

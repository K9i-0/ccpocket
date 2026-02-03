import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';
import 'thinking_bubble.dart';

class AssistantBubble extends StatelessWidget {
  final AssistantServerMessage message;
  const AssistantBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final content in message.message.content)
          switch (content) {
            TextContent(:final text) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubbleMarginV,
                horizontal: AppSpacing.bubbleMarginH,
              ),
              child: MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: buildMarkdownStyle(context),
              ),
            ),
            ToolUseContent(:final name, :final input) =>
              name == 'ExitPlanMode'
                  ? _PlanReadyTile()
                  : ToolUseTile(name: name, input: input),
            ThinkingContent(:final thinking) => ThinkingBubble(
              thinking: thinking,
            ),
          },
      ],
    );
  }
}

class _PlanReadyTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Plan ready for review',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ToolUseTile extends StatefulWidget {
  final String name;
  final Map<String, dynamic> input;
  const ToolUseTile({super.key, required this.name, required this.input});

  @override
  State<ToolUseTile> createState() => _ToolUseTileState();
}

class _ToolUseTileState extends State<ToolUseTile> {
  bool _expanded = false;

  String _inputSummary() {
    final input = widget.input;
    // Pick the most informative key for a one-line summary.
    for (final key in [
      'command',
      'file_path',
      'path',
      'pattern',
      'url',
      'query',
      'prompt',
    ]) {
      if (input.containsKey(key)) {
        final val = input[key].toString();
        return val.length > 60 ? '${val.substring(0, 60)}…' : val;
      }
    }
    final keys = input.keys.take(3).join(', ');
    return keys.isNotEmpty ? keys : '{}';
  }

  void _copyContent() {
    final inputStr = const JsonEncoder.withIndent('  ').convert(widget.input);
    Clipboard.setData(ClipboardData(text: '${widget.name}\n$inputStr'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    if (_expanded) return _buildCard(appColors);
    return _buildCollapsed(appColors);
  }

  Widget _buildCollapsed(AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 1,
      ),
      child: InkWell(
        onTap: () {
          setState(() => _expanded = true);
          HapticFeedback.selectionClick();
        },
        onLongPress: _copyContent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              // Colored dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: appColors.toolIcon,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Tool name
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Input summary
              Expanded(
                child: Text(
                  _inputSummary(),
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: appColors.subtleText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppColors appColors) {
    final inputStr = const JsonEncoder.withIndent('  ').convert(widget.input);
    final preview = inputStr.length > 200
        ? '${inputStr.substring(0, 200)}...'
        : inputStr;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: () {
          setState(() => _expanded = false);
          HapticFeedback.selectionClick();
        },
        onLongPress: _copyContent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: appColors.toolBubble,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: appColors.toolBubbleBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.build, size: 14, color: appColors.toolIcon),
                  const SizedBox(width: 6),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _inputSummary(),
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.expand_less,
                    size: 16,
                    color: appColors.subtleText,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preview,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

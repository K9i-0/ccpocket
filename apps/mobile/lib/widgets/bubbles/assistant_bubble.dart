import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';
import '../plan_detail_sheet.dart';
import 'message_action_bar.dart';
import 'plan_card.dart';
import 'thinking_bubble.dart';
import 'todo_write_widget.dart';

class AssistantBubble extends StatefulWidget {
  final AssistantServerMessage message;
  final ValueNotifier<String?>? editedPlanText;

  /// Pre-resolved plan text extracted from a Write tool in a *different*
  /// AssistantMessage.  When the real SDK writes the plan to a file via the
  /// Write tool, ExitPlanMode and Write are in separate messages, so the
  /// bubble's own [message.content] won't contain the plan text.
  final String? resolvedPlanText;
  const AssistantBubble({
    super.key,
    required this.message,
    this.editedPlanText,
    this.resolvedPlanText,
  });

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble> {
  bool _plainTextMode = false;

  String _allText() {
    return widget.message.message.content
        .whereType<TextContent>()
        .map((c) => c.text)
        .join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final contents = widget.message.message.content;
    final hasTextContent = contents.any((c) => c is TextContent);
    final hasPlanExit = contents.any(
      (c) => c is ToolUseContent && c.name == 'ExitPlanMode',
    );

    if (hasPlanExit) {
      return _buildPlanLayout(context, contents, hasTextContent);
    }

    return _buildDefaultLayout(context, contents, hasTextContent);
  }

  Widget _buildPlanLayout(
    BuildContext context,
    List<AssistantContent> contents,
    bool hasTextContent,
  ) {
    var originalPlanText = contents
        .whereType<TextContent>()
        .map((c) => c.text)
        .join('\n\n');

    // Real SDK: plan is written to a file via Write tool in a *different*
    // AssistantMessage.  Use resolvedPlanText (pre-extracted from all entries)
    // when TextContent doesn't look like an actual plan (< 10 lines).
    if (originalPlanText.split('\n').length < 10 &&
        widget.resolvedPlanText != null) {
      originalPlanText = widget.resolvedPlanText!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Render thinking blocks and non-ExitPlanMode tool uses
        for (final content in contents)
          switch (content) {
            ThinkingContent(:final thinking) => ThinkingBubble(
              thinking: thinking,
            ),
            ToolUseContent(:final name, :final input) =>
              name == 'ExitPlanMode'
                  ? const SizedBox.shrink()
                  : ToolUseTile(name: name, input: input),
            TextContent() => const SizedBox.shrink(),
          },
        // Plan card – reflects edited text if available
        if (widget.editedPlanText != null)
          ValueListenableBuilder<String?>(
            valueListenable: widget.editedPlanText!,
            builder: (context, edited, _) {
              final displayText = edited ?? originalPlanText;
              return PlanCard(
                planText: displayText,
                isEdited: edited != null,
                onViewFullPlan: () async {
                  final edited = await showPlanDetailSheet(
                    context,
                    displayText,
                  );
                  if (edited != null) {
                    widget.editedPlanText!.value = edited;
                  }
                },
              );
            },
          )
        else
          PlanCard(
            planText: originalPlanText,
            onViewFullPlan: () =>
                showPlanDetailSheet(context, originalPlanText),
          ),
        if (hasTextContent)
          MessageActionBar(
            textToCopy: _allText(),
            isPlainTextMode: _plainTextMode,
            onTogglePlainText: () {
              setState(() => _plainTextMode = !_plainTextMode);
            },
          ),
      ],
    );
  }

  Widget _buildDefaultLayout(
    BuildContext context,
    List<AssistantContent> contents,
    bool hasTextContent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final content in contents)
          switch (content) {
            TextContent(:final text) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.bubbleMarginV,
                horizontal: AppSpacing.bubbleMarginH,
              ),
              child: _plainTextMode
                  ? SelectableText(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: buildMarkdownStyle(context),
                      onTapLink: handleMarkdownLink,
                    ),
            ),
            ToolUseContent(:final name, :final input) =>
              name == 'TodoWrite'
                  ? TodoWriteWidget(input: input)
                  : ToolUseTile(name: name, input: input),
            ThinkingContent(:final thinking) => ThinkingBubble(
              thinking: thinking,
            ),
          },
        if (hasTextContent)
          MessageActionBar(
            textToCopy: _allText(),
            isPlainTextMode: _plainTextMode,
            onTogglePlainText: () {
              setState(() => _plainTextMode = !_plainTextMode);
            },
          ),
      ],
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

import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';
import '../../utils/diff_parser.dart';
import '../../utils/tool_categories.dart';
import '../plan_detail_sheet.dart';
import 'inline_edit_diff.dart';
import 'message_action_bar.dart';
import 'plan_card.dart';
import 'thinking_bubble.dart';
import 'todo_write_widget.dart';

class AssistantBubble extends StatefulWidget {
  final AssistantServerMessage message;
  final ValueNotifier<String?>? editedPlanText;
  final bool allowPlanEditing;
  final String? pendingPlanToolUseId;

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
    this.allowPlanEditing = true,
    this.pendingPlanToolUseId,
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

    String? planToolUseId;
    for (final content in contents) {
      if (content is ToolUseContent && content.name == 'ExitPlanMode') {
        planToolUseId = content.id;
        break;
      }
    }
    final canEditThisPlan =
        widget.allowPlanEditing &&
        (widget.pendingPlanToolUseId == null ||
            widget.pendingPlanToolUseId == planToolUseId);

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
              final displayText = canEditThisPlan && edited != null
                  ? edited
                  : originalPlanText;
              return PlanCard(
                planText: displayText,
                isEdited: canEditThisPlan && edited != null,
                onViewFullPlan: () async {
                  final edited = await showPlanDetailSheet(
                    context,
                    displayText,
                    editable: canEditThisPlan,
                  );
                  if (edited != null && canEditThisPlan) {
                    widget.editedPlanText!.value = edited;
                  }
                },
              );
            },
          )
        else
          PlanCard(
            planText: originalPlanText,
            onViewFullPlan: () => showPlanDetailSheet(
              context,
              originalPlanText,
              editable: canEditThisPlan,
            ),
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
                      inlineSyntaxes: colorCodeInlineSyntaxes,
                      builders: colorCodeBuilders,
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

  late final ToolCategory _category = categorizeToolName(widget.name);
  late final DiffFile? _editDiff = synthesizeEditToolDiff(
    widget.name,
    widget.input,
  );

  String _inputSummary() {
    return getToolSummary(_category, widget.input);
  }

  void _copyContent() {
    final inputStr = const JsonEncoder.withIndent('  ').convert(widget.input);
    Clipboard.setData(ClipboardData(text: '${widget.name}\n$inputStr'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copied),
        duration: const Duration(seconds: 1),
      ),
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
              // Category icon
              Icon(
                getToolCategoryIcon(_category),
                size: 12,
                color: getToolCategoryColor(_category, appColors),
              ),
              const SizedBox(width: 6),
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

  void _openDiffScreen() {
    final diff = _editDiff;
    if (diff == null) return;
    final diffText = reconstructUnifiedDiff(diff);
    final filePath = diff.filePath.split('/').lastOrNull ?? diff.filePath;
    context.router.push(DiffRoute(initialDiff: diffText, title: filePath));
  }

  Widget _buildCard(AppColors appColors) {
    final diffFile = _editDiff;

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
                  Icon(
                    getToolCategoryIcon(_category),
                    size: 14,
                    color: getToolCategoryColor(_category, appColors),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inputSummary(),
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (diffFile != null) ...[
                    _DiffStatsMini(diffFile: diffFile, appColors: appColors),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.expand_less,
                    size: 16,
                    color: appColors.subtleText,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (diffFile != null)
                InlineEditDiff(
                  diffFile: diffFile,
                  onTapFullDiff: _openDiffScreen,
                )
              else
                _JsonPreview(input: widget.input, appColors: appColors),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline +N -M stats shown in the card header for edit tools.
class _DiffStatsMini extends StatelessWidget {
  final DiffFile diffFile;
  final AppColors appColors;

  const _DiffStatsMini({required this.diffFile, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final stats = diffFile.stats;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.added > 0)
          Text(
            '+${stats.added}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffAdditionText,
            ),
          ),
        if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 3),
        if (stats.removed > 0)
          Text(
            '-${stats.removed}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffDeletionText,
            ),
          ),
      ],
    );
  }
}

/// Fallback JSON preview for non-edit tools.
class _JsonPreview extends StatelessWidget {
  final Map<String, dynamic> input;
  final AppColors appColors;

  const _JsonPreview({required this.input, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final inputStr = const JsonEncoder.withIndent('  ').convert(input);
    final preview = inputStr.length > 200
        ? '${inputStr.substring(0, 200)}...'
        : inputStr;
    return Text(
      preview,
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: appColors.subtleText,
      ),
    );
  }
}

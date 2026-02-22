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
      return _PlanLayout(
        contents: contents,
        hasTextContent: hasTextContent,
        resolvedPlanText: widget.resolvedPlanText,
        allowPlanEditing: widget.allowPlanEditing,
        pendingPlanToolUseId: widget.pendingPlanToolUseId,
        editedPlanText: widget.editedPlanText,
        allText: _allText(),
        plainTextMode: _plainTextMode,
        onTogglePlainText: () {
          setState(() => _plainTextMode = !_plainTextMode);
        },
      );
    }

    return _DefaultLayout(
      contents: contents,
      hasTextContent: hasTextContent,
      plainTextMode: _plainTextMode,
      allText: _allText(),
      onTogglePlainText: () {
        setState(() => _plainTextMode = !_plainTextMode);
      },
    );
  }
}

class _PlanLayout extends StatelessWidget {
  final List<AssistantContent> contents;
  final bool hasTextContent;
  final String? resolvedPlanText;
  final bool allowPlanEditing;
  final String? pendingPlanToolUseId;
  final ValueNotifier<String?>? editedPlanText;
  final String allText;
  final bool plainTextMode;
  final VoidCallback onTogglePlainText;

  const _PlanLayout({
    required this.contents,
    required this.hasTextContent,
    required this.resolvedPlanText,
    required this.allowPlanEditing,
    required this.pendingPlanToolUseId,
    required this.editedPlanText,
    required this.allText,
    required this.plainTextMode,
    required this.onTogglePlainText,
  });

  @override
  Widget build(BuildContext context) {
    var originalPlanText = contents
        .whereType<TextContent>()
        .map((c) => c.text)
        .join('\n\n');

    // Real SDK: plan is written to a file via Write tool in a *different*
    // AssistantMessage.  Use resolvedPlanText (pre-extracted from all entries)
    // when TextContent doesn't look like an actual plan (< 10 lines).
    if (originalPlanText.split('\n').length < 10 && resolvedPlanText != null) {
      originalPlanText = resolvedPlanText!;
    }

    String? planToolUseId;
    for (final content in contents) {
      if (content is ToolUseContent && content.name == 'ExitPlanMode') {
        planToolUseId = content.id;
        break;
      }
    }
    final canEditThisPlan =
        allowPlanEditing &&
        (pendingPlanToolUseId == null || pendingPlanToolUseId == planToolUseId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Render thinking blocks and non-ExitPlanMode tool uses
        for (final content in contents)
          switch (content) {
            ThinkingContent(:final thinking) => ThinkingBubble(
              thinking: thinking,
            ),
            ToolUseContent(:final id, :final name, :final input) =>
              name == 'ExitPlanMode'
                  ? const SizedBox.shrink()
                  : ToolUseTile(toolUseId: id, name: name, input: input),
            TextContent() => const SizedBox.shrink(),
          },
        // Plan card – reflects edited text if available
        if (editedPlanText != null)
          ValueListenableBuilder<String?>(
            valueListenable: editedPlanText!,
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
                    editedPlanText!.value = edited;
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
            textToCopy: allText,
            isPlainTextMode: plainTextMode,
            onTogglePlainText: onTogglePlainText,
          ),
      ],
    );
  }
}

class _DefaultLayout extends StatelessWidget {
  final List<AssistantContent> contents;
  final bool hasTextContent;
  final bool plainTextMode;
  final String allText;
  final VoidCallback onTogglePlainText;

  const _DefaultLayout({
    required this.contents,
    required this.hasTextContent,
    required this.plainTextMode,
    required this.allText,
    required this.onTogglePlainText,
  });

  @override
  Widget build(BuildContext context) {
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
              child: plainTextMode
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
                      builders: markdownBuilders,
                    ),
            ),
            ToolUseContent(:final id, :final name, :final input) =>
              name == 'TodoWrite'
                  ? TodoWriteWidget(input: input)
                  : ToolUseTile(toolUseId: id, name: name, input: input),
            ThinkingContent(:final thinking) => ThinkingBubble(
              thinking: thinking,
            ),
          },
        if (hasTextContent)
          MessageActionBar(
            textToCopy: allText,
            isPlainTextMode: plainTextMode,
            onTogglePlainText: onTogglePlainText,
          ),
      ],
    );
  }
}

class ToolUseTile extends StatefulWidget {
  final String toolUseId;
  final String name;
  final Map<String, dynamic> input;
  const ToolUseTile({
    super.key,
    this.toolUseId = '',
    required this.name,
    required this.input,
  });

  @override
  State<ToolUseTile> createState() => _ToolUseTileState();
}

class _ToolUseTileState extends State<ToolUseTile> {
  late bool _expanded;
  bool _restoredFromStorage = false;

  late final ToolCategory _category = categorizeToolName(widget.name);
  late final DiffFile? _editDiff = synthesizeEditToolDiff(
    widget.name,
    widget.input,
  );

  @override
  void initState() {
    super.initState();
    _expanded = _defaultExpanded;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFromStorage) return;
    _restoredFromStorage = true;

    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageKey);
    if (saved is bool) {
      _expanded = saved;
      return;
    }
    _expanded = _defaultExpanded;
  }

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
    if (_expanded) {
      return _ToolUseCard(
        name: widget.name,
        input: widget.input,
        category: _category,
        inputSummary: _inputSummary(),
        editDiff: _editDiff,
        onTap: () {
          setState(() => _expanded = false);
          _persistExpandedState();
          HapticFeedback.selectionClick();
        },
        onLongPress: _copyContent,
        onOpenDiffScreen: _openDiffScreen,
      );
    }
    return _ToolUseCollapsed(
      name: widget.name,
      category: _category,
      inputSummary: _inputSummary(),
      onTap: () {
        setState(() => _expanded = true);
        _persistExpandedState();
        HapticFeedback.selectionClick();
      },
      onLongPress: _copyContent,
    );
  }

  void _openDiffScreen() {
    final diff = _editDiff;
    if (diff == null) return;
    final diffText = reconstructUnifiedDiff(diff);
    final filePath = diff.filePath.split('/').lastOrNull ?? diff.filePath;
    context.router.push(DiffRoute(initialDiff: diffText, title: filePath));
  }

  String get _storageKey {
    if (widget.toolUseId.isNotEmpty) return 'tool_use:${widget.toolUseId}';
    final encoded = const JsonEncoder().convert(widget.input);
    return 'tool_use_fallback:${widget.name}:${encoded.hashCode}';
  }

  bool get _defaultExpanded =>
      widget.name == 'Edit' ||
      widget.name == 'FileEdit' ||
      widget.name == 'MultiEdit' ||
      widget.name == 'Write' ||
      widget.name == 'NotebookEdit';

  void _persistExpandedState() {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expanded, identifier: _storageKey);
  }
}

class _ToolUseCollapsed extends StatelessWidget {
  final String name;
  final ToolCategory category;
  final String inputSummary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ToolUseCollapsed({
    required this.name,
    required this.category,
    required this.inputSummary,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 1,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              // Category icon
              Icon(
                getToolCategoryIcon(category),
                size: 12,
                color: getToolCategoryColor(category, appColors),
              ),
              const SizedBox(width: 6),
              // Tool name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Input summary
              Expanded(
                child: Text(
                  inputSummary,
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
}

class _ToolUseCard extends StatelessWidget {
  final String name;
  final Map<String, dynamic> input;
  final ToolCategory category;
  final String inputSummary;
  final DiffFile? editDiff;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpenDiffScreen;

  const _ToolUseCard({
    required this.name,
    required this.input,
    required this.category,
    required this.inputSummary,
    required this.editDiff,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenDiffScreen,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final diffFile = editDiff;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
                    getToolCategoryIcon(category),
                    size: 14,
                    color: getToolCategoryColor(category, appColors),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inputSummary,
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
                  onTapFullDiff: onOpenDiffScreen,
                )
              else
                _JsonPreview(input: input, appColors: appColors),
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

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
import '../../utils/structured_error_inference.dart';
import '../../utils/diff_parser.dart';
import '../../utils/tool_categories.dart';
import '../../features/file_peek/file_path_syntax.dart';
import 'error_bubble.dart';
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

  /// Callback for tapping file paths in markdown content.
  final FilePathTapCallback? onFileTap;

  const AssistantBubble({
    super.key,
    required this.message,
    this.editedPlanText,
    this.resolvedPlanText,
    this.allowPlanEditing = true,
    this.pendingPlanToolUseId,
    this.onFileTap,
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
    final allText = _allText();
    // Only infer structured errors from short, text-only messages that are
    // likely actual error messages from the CLI — not long assistant prose
    // that happens to contain keywords like "oauth" or "credentials".
    final inferredErrorCode = allText.length <= 500
        ? inferStructuredErrorCode(message: allText)
        : null;
    final hasOnlyTextContent =
        contents.isNotEmpty && contents.every((c) => c is TextContent);

    if (hasOnlyTextContent && inferredErrorCode != null) {
      return ErrorBubble(
        message: ErrorMessage(
          message: _allText(),
          errorCode: inferredErrorCode,
        ),
      );
    }

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
      onFileTap: widget.onFileTap,
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
  final FilePathTapCallback? onFileTap;
  final VoidCallback onTogglePlainText;

  const _DefaultLayout({
    required this.contents,
    required this.hasTextContent,
    required this.plainTextMode,
    required this.allText,
    this.onFileTap,
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
                      inlineSyntaxes: [
                        if (onFileTap != null) FilePathSyntax(),
                        ...colorCodeInlineSyntaxes,
                      ],
                      builders: {
                        if (onFileTap != null)
                          'filePath': FilePathBuilder(onTap: onFileTap),
                        ...markdownBuilders,
                      },
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

/// Three-level expansion state for tool use content (non-edit tools).
/// Edit tools use only [collapsed] and [expanded].
enum ToolUseExpansion { collapsed, preview, expanded }

class _ToolUseTileState extends State<ToolUseTile> {
  late ToolUseExpansion _expansion;
  bool _restoredFromStorage = false;

  late final ToolCategory _category = categorizeToolName(widget.name);
  late final DiffFile? _editDiff = synthesizeEditToolDiff(
    widget.name,
    widget.input,
  );

  bool get _isEditTool => _editDiff != null;

  @override
  void initState() {
    super.initState();
    _expansion = _defaultExpansion;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFromStorage) return;
    _restoredFromStorage = true;

    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageKey);
    // Backwards-compat: legacy bool values
    if (saved is bool) {
      _expansion = saved
          ? ToolUseExpansion.expanded
          : ToolUseExpansion.collapsed;
      return;
    }
    if (saved is String) {
      for (final value in ToolUseExpansion.values) {
        if (value.name == saved) {
          _expansion = value;
          return;
        }
      }
    }
    // Unknown saved value (e.g. corrupt storage) → fall back to default
    _expansion = _defaultExpansion;
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

  void _cycleExpansion() {
    setState(() {
      if (_isEditTool) {
        // Edit tools: 2-state toggle (collapsed ↔ expanded)
        _expansion = _expansion == ToolUseExpansion.collapsed
            ? ToolUseExpansion.expanded
            : ToolUseExpansion.collapsed;
      } else {
        // Non-edit tools: 3-state cycle
        _expansion = switch (_expansion) {
          ToolUseExpansion.collapsed => ToolUseExpansion.preview,
          ToolUseExpansion.preview => ToolUseExpansion.expanded,
          ToolUseExpansion.expanded => ToolUseExpansion.collapsed,
        };
      }
    });
    _persistExpandedState();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    if (_expansion == ToolUseExpansion.collapsed) {
      return _ToolUseCollapsed(
        name: widget.name,
        category: _category,
        inputSummary: _inputSummary(),
        onTap: _cycleExpansion,
        onLongPress: _copyContent,
      );
    }
    return _ToolUseCard(
      name: widget.name,
      input: widget.input,
      category: _category,
      inputSummary: _inputSummary(),
      editDiff: _editDiff,
      expansion: _expansion,
      onTap: _cycleExpansion,
      onLongPress: _copyContent,
      onOpenGitScreen: _openGitScreen,
    );
  }

  void _openGitScreen() {
    final diff = _editDiff;
    if (diff == null) return;
    final diffText = reconstructUnifiedDiff(diff);
    final filePath = diff.filePath.split('/').lastOrNull ?? diff.filePath;
    context.router.push(GitRoute(initialDiff: diffText, title: filePath));
  }

  String get _storageKey {
    if (widget.toolUseId.isNotEmpty) return 'tool_use:${widget.toolUseId}';
    final encoded = const JsonEncoder().convert(widget.input);
    return 'tool_use_fallback:${widget.name}:${encoded.hashCode}';
  }

  ToolUseExpansion get _defaultExpansion =>
      _isEditTool ? ToolUseExpansion.expanded : ToolUseExpansion.collapsed;

  void _persistExpandedState() {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expansion.name, identifier: _storageKey);
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
  final ToolUseExpansion expansion;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpenGitScreen;

  static const _previewLines = 5;

  const _ToolUseCard({
    required this.name,
    required this.input,
    required this.category,
    required this.inputSummary,
    required this.editDiff,
    required this.expansion,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenGitScreen,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final diffFile = editDiff;
    final chevronIcon = expansion == ToolUseExpansion.expanded
        ? Icons.expand_less
        : Icons.expand_more;

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
                  Icon(chevronIcon, size: 16, color: appColors.subtleText),
                ],
              ),
              const SizedBox(height: 6),
              if (diffFile != null)
                InlineEditDiff(
                  diffFile: diffFile,
                  onTapFullDiff: onOpenGitScreen,
                )
              else
                _buildInputBody(appColors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBody(AppColors appColors) {
    final fullText = getToolFullInput(category, input);
    final lines = fullText.split('\n');
    final hasMore = lines.length > _previewLines;

    if (expansion == ToolUseExpansion.expanded) {
      return SelectableText(
        fullText,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: appColors.toolResultTextExpanded,
          height: 1.4,
        ),
      );
    }

    // preview
    final previewText = hasMore
        ? lines.take(_previewLines).join('\n')
        : fullText;
    return Column(
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

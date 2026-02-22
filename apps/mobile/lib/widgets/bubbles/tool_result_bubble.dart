import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import 'package:auto_route/auto_route.dart';

import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/tool_categories.dart';
import 'image_preview.dart';

/// Three-level expansion state for tool result content.
enum ToolResultExpansion { collapsed, preview, expanded }

class ToolResultBubble extends StatefulWidget {
  final ToolResultMessage message;
  final String? httpBaseUrl;

  /// When this notifier's value changes, the bubble auto-collapses.
  /// ClaudeSessionScreen increments it whenever a new assistant message arrives.
  final ValueNotifier<int>? collapseNotifier;

  const ToolResultBubble({
    super.key,
    required this.message,
    this.httpBaseUrl,
    this.collapseNotifier,
  });

  @override
  State<ToolResultBubble> createState() => ToolResultBubbleState();
}

class ToolResultBubbleState extends State<ToolResultBubble> {
  late ToolResultExpansion _expansion;
  bool _restoredFromStorage = false;

  static const _previewLines = 5;

  @override
  void initState() {
    super.initState();
    _expansion = _defaultExpansion;
    widget.collapseNotifier?.addListener(_onCollapseSignal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFromStorage) return;
    _restoredFromStorage = true;

    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageKey);
    if (saved is String) {
      for (final value in ToolResultExpansion.values) {
        if (value.name == saved) {
          _expansion = value;
          return;
        }
      }
    }
    _expansion = _defaultExpansion;
  }

  @override
  void didUpdateWidget(ToolResultBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapseNotifier != widget.collapseNotifier) {
      oldWidget.collapseNotifier?.removeListener(_onCollapseSignal);
      widget.collapseNotifier?.addListener(_onCollapseSignal);
    }
  }

  @override
  void dispose() {
    widget.collapseNotifier?.removeListener(_onCollapseSignal);
    super.dispose();
  }

  void _onCollapseSignal() {
    if (_expansion != ToolResultExpansion.collapsed) {
      setState(() => _expansion = ToolResultExpansion.collapsed);
      _persistExpansion();
    }
  }

  void _cycleExpansion() {
    setState(() {
      _expansion = switch (_expansion) {
        ToolResultExpansion.collapsed => ToolResultExpansion.preview,
        ToolResultExpansion.preview => ToolResultExpansion.expanded,
        ToolResultExpansion.expanded => ToolResultExpansion.collapsed,
      };
    });
    _persistExpansion();
    HapticFeedback.selectionClick();
  }

  String get _storageKey => 'tool_result:${widget.message.toolUseId}';

  bool get _isCodeEditResult {
    final toolName = widget.message.toolName;
    return toolName == 'Edit' ||
        toolName == 'FileEdit' ||
        toolName == 'MultiEdit' ||
        toolName == 'Write' ||
        toolName == 'NotebookEdit' ||
        toolName == 'FileChange';
  }

  bool get _isMcpImageResult {
    final toolName = widget.message.toolName ?? '';
    return widget.message.images.isNotEmpty && toolName.startsWith('mcp__');
  }

  ToolResultExpansion get _defaultExpansion =>
      (_isCodeEditResult || _isMcpImageResult)
      ? ToolResultExpansion.preview
      : ToolResultExpansion.collapsed;

  void _persistExpansion() {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expansion.name, identifier: _storageKey);
  }

  late final ToolCategory _category = categorizeToolName(
    widget.message.toolName ?? '',
  );

  String _buildSummary(String content, String? toolName, AppLocalizations l) {
    final lines = content.split('\n');
    final lineCount = lines.length;

    if (toolName == 'Edit' ||
        toolName == 'FileEdit' ||
        toolName == 'FileChange') {
      var added = 0;
      var removed = 0;
      for (final line in lines) {
        if (line.startsWith('+') && !line.startsWith('+++')) added++;
        if (line.startsWith('-') && !line.startsWith('---')) removed++;
      }
      if (added > 0 || removed > 0) {
        return l.diffSummaryAddedRemoved(added, removed);
      }
    }

    if (lineCount == 1 && content.length < 40) {
      return content;
    }

    return l.lineCountSummary(lineCount);
  }

  /// Whether this tool result contains a viewable diff.
  bool get _isDiffContent {
    final toolName = widget.message.toolName;
    if (toolName != 'Edit' &&
        toolName != 'FileEdit' &&
        toolName != 'FileChange') {
      return false;
    }
    final content = widget.message.content;
    // Check for unified diff markers
    return content.contains('---') && content.contains('+++') ||
        _hasDiffLines(content);
  }

  static bool _hasDiffLines(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      if ((line.startsWith('+') && !line.startsWith('+++')) ||
          (line.startsWith('-') && !line.startsWith('---'))) {
        return true;
      }
    }
    return false;
  }

  String? _extractFilePath() {
    final content = widget.message.content;
    final match = RegExp(r'\+\+\+ b/(.+)').firstMatch(content);
    return match?.group(1);
  }

  void _openDiffScreen() {
    context.router.push(
      DiffRoute(initialDiff: widget.message.content, title: _extractFilePath()),
    );
  }

  void _onTap() {
    if (_isDiffContent) {
      _openDiffScreen();
    } else {
      _cycleExpansion();
    }
  }

  void _copyContent(BuildContext context) {
    final content = widget.message.content;
    if (content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copiedToClipboard),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = _buildSummary(
      widget.message.content,
      widget.message.toolName,
      l,
    );

    if (_expansion == ToolResultExpansion.collapsed) {
      return _CollapsedToolResult(
        toolName: widget.message.toolName,
        category: _category,
        summary: summary,
        onTap: _onTap,
        onLongPress: () => _copyContent(context),
      );
    }
    return _ExpandedToolResult(
      message: widget.message,
      httpBaseUrl: widget.httpBaseUrl,
      category: _category,
      summary: summary,
      expansion: _expansion,
      onTap: _onTap,
      onLongPress: () => _copyContent(context),
    );
  }
}

/// Collapsed: inline log row -- no card background.
class _CollapsedToolResult extends StatelessWidget {
  final String? toolName;
  final ToolCategory category;
  final String summary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CollapsedToolResult({
    required this.toolName,
    required this.category,
    required this.summary,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

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
                toolName ?? l.toolResult,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Summary -- plain text, no badge
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right, size: 14, color: appColors.subtleText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview / Expanded: card with background + content.
class _ExpandedToolResult extends StatelessWidget {
  final ToolResultMessage message;
  final String? httpBaseUrl;
  final ToolCategory category;
  final String summary;
  final ToolResultExpansion expansion;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _previewLines = ToolResultBubbleState._previewLines;

  const _ExpandedToolResult({
    required this.message,
    required this.httpBaseUrl,
    required this.category,
    required this.summary,
    required this.expansion,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final content = message.content;
    final toolName = message.toolName;
    final lines = content.split('\n');
    final hasMore = lines.length > _previewLines;
    final previewText = hasMore
        ? lines.take(_previewLines).join('\n')
        : content;

    final chevronIcon = expansion == ToolResultExpansion.preview
        ? Icons.expand_more
        : Icons.expand_less;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
              if (message.images.isNotEmpty && httpBaseUrl != null) ...[
                ImagePreviewWidget(
                  images: message.images,
                  httpBaseUrl: httpBaseUrl!,
                ),
                const SizedBox(height: 8),
              ],
              // Header row
              Row(
                children: [
                  Icon(
                    getToolCategoryIcon(category),
                    size: 14,
                    color: getToolCategoryColor(category, appColors),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    toolName ?? l.toolResult,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(chevronIcon, size: 16, color: appColors.subtleText),
                ],
              ),
              // Content
              if (expansion == ToolResultExpansion.preview) ...[
                const SizedBox(height: 6),
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
              ] else if (expansion == ToolResultExpansion.expanded) ...[
                const SizedBox(height: 6),
                SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: appColors.toolResultTextExpanded,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

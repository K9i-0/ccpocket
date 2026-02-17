import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import 'package:auto_route/auto_route.dart';

import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import 'image_preview.dart';

/// Three-level expansion state for tool result content.
enum ToolResultExpansion { collapsed, preview, expanded }

class ToolResultBubble extends StatefulWidget {
  final ToolResultMessage message;
  final String? httpBaseUrl;

  /// When this notifier's value changes, the bubble auto-collapses.
  /// ClaudeCodeSessionScreen increments it whenever a new assistant message arrives.
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
  ToolResultExpansion _expansion = ToolResultExpansion.collapsed;

  static const _previewLines = 5;

  @override
  void initState() {
    super.initState();
    widget.collapseNotifier?.addListener(_onCollapseSignal);
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
    HapticFeedback.selectionClick();
  }

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

  String _buildSummary(String content, String? toolName, AppLocalizations l) {
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
    if (toolName != 'Edit' && toolName != 'FileEdit') return false;
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

  /// Collapsed: inline log row — no card background.
  Widget _buildCollapsed(AppColors appColors, AppLocalizations l) {
    final toolName = widget.message.toolName;
    final summary = _buildSummary(widget.message.content, toolName, l);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 1,
      ),
      child: InkWell(
        onTap: _onTap,
        onLongPress: () => _copyContent(context),
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
                toolName ?? l.toolResult,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Summary — plain text, no badge
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

  /// Preview / Expanded: card with background + content.
  Widget _buildCard(AppColors appColors, AppLocalizations l) {
    final content = widget.message.content;
    final toolName = widget.message.toolName;
    final lines = content.split('\n');
    final hasMore = lines.length > _previewLines;
    final previewText = hasMore
        ? lines.take(_previewLines).join('\n')
        : content;
    final summary = _buildSummary(content, toolName, l);

    final chevronIcon = _expansion == ToolResultExpansion.preview
        ? Icons.expand_more
        : Icons.expand_less;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      child: InkWell(
        onTap: _onTap,
        onLongPress: () => _copyContent(context),
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
              // Header row
              Row(
                children: [
                  Icon(
                    _toolIcon(toolName),
                    size: 14,
                    color: appColors.toolIcon,
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
                  Text(
                    summary,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                  const Spacer(),
                  Icon(chevronIcon, size: 16, color: appColors.subtleText),
                ],
              ),
              // Content
              if (_expansion == ToolResultExpansion.preview) ...[
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
              ] else if (_expansion == ToolResultExpansion.expanded) ...[
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

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

    if (_expansion == ToolResultExpansion.collapsed) {
      return _buildCollapsed(appColors, l);
    }
    return _buildCard(appColors, l);
  }
}

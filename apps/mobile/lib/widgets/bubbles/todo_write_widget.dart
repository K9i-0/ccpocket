import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../google_search_text_selection.dart';

/// Maximum number of non-in_progress items shown in collapsed state.
const _maxCollapsedItems = 4;

/// Widget to display TodoWrite tool output as a checklist UI.
///
/// When there are more than [_maxCollapsedItems] non-in_progress tasks,
/// the list is truncated with a "... and X more" indicator that can be
/// tapped to expand. The expanded state is persisted via [PageStorage]
/// so it survives scrolling off-screen.
class TodoWriteWidget extends StatefulWidget {
  final Map<String, dynamic> input;

  const TodoWriteWidget({super.key, required this.input});

  @override
  State<TodoWriteWidget> createState() => _TodoWriteWidgetState();
}

class _TodoWriteWidgetState extends State<TodoWriteWidget> {
  bool _expanded = false;
  bool _restoredFromStorage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFromStorage) return;
    _restoredFromStorage = true;

    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey);
    if (saved is bool) {
      _expanded = saved;
    }
  }

  String get _storageKey {
    final encoded = const JsonEncoder().convert(widget.input);
    return 'todo_write:${encoded.hashCode}';
  }

  void _persistExpansion() {
    PageStorage.maybeOf(context)
        ?.writeState(context, _expanded, identifier: _storageKey);
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    _persistExpansion();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final todos = _parseTodos();
    final title = _stringInput('title') ?? 'Tasks';
    final explanation = _stringInput('explanation');

    if (todos.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = todos.where((t) => t.status == 'completed').length;
    final allCompleted = completedCount == todos.length;
    final inProgressItem = todos
        .where((t) => t.status == 'in_progress')
        .firstOrNull;

    final otherTodos = todos.where((t) => t.status != 'in_progress').toList();
    final hasOverflow = otherTodos.length > _maxCollapsedItems;
    final visibleOthers = _expanded
        ? otherTodos
        : otherTodos.take(_maxCollapsedItems).toList();
    final hiddenCount = otherTodos.length - _maxCollapsedItems;

    final cardBg = isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.85);
    final dividerColor = cs.outlineVariant.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleSearchSelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Icon(Icons.checklist, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completedCount/${todos.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

            if (explanation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 12,
                    color: appColors.subtleText,
                    height: 1.3,
                  ),
                ),
              ),

            // Slim neutral progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: todos.isEmpty ? 0 : completedCount / todos.length,
                  minHeight: 3,
                  backgroundColor: cs.onSurface.withValues(
                    alpha: isDark ? 0.08 : 0.07,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allCompleted
                        ? cs.onSurfaceVariant.withValues(alpha: 0.55)
                        : cs.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Current task (in_progress) - subtle neutral highlight
            if (inProgressItem != null) ...[
              _TodoItemTile(item: inProgressItem, isHighlighted: true),
              if (todos.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
            ],

            // Other tasks
            ...visibleOthers.map((item) => _TodoItemTile(item: item)),

            // Expand / collapse control
            if (hasOverflow)
              SelectionContainer.disabled(
                child: GestureDetector(
                  onTap: _toggleExpanded,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    child: Text(
                      _expanded ? 'Show less' : '... and $hiddenCount more',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  List<_TodoItem> _parseTodos() {
    final todosRaw = widget.input['todos'];
    if (todosRaw is! List) return [];

    return todosRaw
        .map((item) {
          if (item is! Map<String, dynamic>) return null;
          return _TodoItem(
            content: item['content'] as String? ?? '',
            status: item['status'] as String? ?? 'pending',
            activeForm: item['activeForm'] as String? ?? '',
            outcome: item['outcome'] as String?,
          );
        })
        .whereType<_TodoItem>()
        .toList();
  }

  String? _stringInput(String key) {
    final value = widget.input[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _TodoItem {
  final String content;
  final String status;
  final String activeForm;

  /// How a finished step ended when it was not done: `skipped` or `failed`
  /// (Antigravity's step checklist). The Bridge also appends it to the title
  /// for apps that do not know this field.
  final String? outcome;

  const _TodoItem({
    required this.content,
    required this.status,
    required this.activeForm,
    this.outcome,
  });

  bool get failed => outcome == 'failed';

  /// The title without the outcome the Bridge appended for older apps.
  String get title {
    final suffix = ' ($outcome)';
    return outcome != null && content.endsWith(suffix)
        ? content.substring(0, content.length - suffix.length)
        : content;
  }
}

class _TodoItemTile extends StatelessWidget {
  final _TodoItem item;
  final bool isHighlighted;

  const _TodoItemTile({required this.item, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final (icon, color) = _getStatusIcon(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isHighlighted
          ? cs.onSurface.withValues(alpha: isDark ? 0.04 : 0.03)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isHighlighted
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: item.status == 'completed'
                        ? appColors.subtleText
                        : cs.onSurface,
                    // A failed step was not done: leave it readable.
                    decoration: item.status == 'completed' && !item.failed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (isHighlighted && item.activeForm.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.activeForm,
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getStatusIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (item.status == 'completed' && item.outcome != null) {
      return item.failed
          ? (Icons.cancel, cs.error)
          : (Icons.remove_circle_outline, appColors.subtleText);
    }
    return switch (item.status) {
      'completed' => (Icons.check_circle, appColors.subtleText),
      'in_progress' => (Icons.timelapse, cs.primary),
      _ => (Icons.radio_button_unchecked, appColors.subtleText),
    };
  }
}

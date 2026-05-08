import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

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

    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageKey);
    if (saved is bool) {
      _expanded = saved;
    }
  }

  String get _storageKey {
    final encoded = const JsonEncoder().convert(widget.input);
    return 'todo_write:${encoded.hashCode}';
  }

  void _persistExpansion() {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expanded, identifier: _storageKey);
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    _persistExpansion();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final todos = _parseTodos();
    final title = _stringInput('title') ?? 'Tasks';
    final explanation = _stringInput('explanation');

    if (todos.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = todos.where((t) => t.status == 'completed').length;
    final inProgressItem = todos
        .where((t) => t.status == 'in_progress')
        .firstOrNull;

    final otherTodos = todos.where((t) => t.status != 'in_progress').toList();
    final hasOverflow = otherTodos.length > _maxCollapsedItems;
    final visibleOthers = _expanded
        ? otherTodos
        : otherTodos.take(_maxCollapsedItems).toList();
    final hiddenCount = otherTodos.length - _maxCollapsedItems;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      decoration: BoxDecoration(
        color: appColors.toolBubble,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: appColors.toolBubbleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.checklist, size: 16, color: appColors.toolIcon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($completedCount/${todos.length})',
                  style: TextStyle(fontSize: 12, color: appColors.subtleText),
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
                  height: 1.25,
                ),
              ),
            ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: todos.isEmpty ? 0 : completedCount / todos.length,
                minHeight: 4,
                backgroundColor: appColors.toolBubbleBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Current task (in_progress) - highlighted
          if (inProgressItem != null) ...[
            _TodoItemTile(item: inProgressItem, isHighlighted: true),
            if (todos.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(height: 1, color: appColors.toolBubbleBorder),
              ),
          ],

          // Other tasks
          ...visibleOthers.map((item) => _TodoItemTile(item: item)),

          // Expand / collapse control
          if (hasOverflow)
            GestureDetector(
              onTap: _toggleExpanded,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _expanded ? 'Show less' : '... and $hiddenCount more',
                  style: TextStyle(
                    fontSize: 11,
                    color: appColors.subtleText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 4),
        ],
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

  const _TodoItem({
    required this.content,
    required this.status,
    required this.activeForm,
  });
}

class _TodoItemTile extends StatelessWidget {
  final _TodoItem item;
  final bool isHighlighted;

  const _TodoItemTile({required this.item, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final (icon, color) = _getStatusIcon(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isHighlighted
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isHighlighted
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: item.status == 'completed'
                        ? appColors.subtleText
                        : Theme.of(context).colorScheme.onSurface,
                    decoration: item.status == 'completed'
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
                        fontStyle: FontStyle.italic,
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
    final appColors = Theme.of(context).extension<AppColors>()!;

    return switch (item.status) {
      'completed' => (Icons.check_circle, appColors.statusIdle),
      'in_progress' => (Icons.timelapse, Theme.of(context).colorScheme.primary),
      _ => (Icons.radio_button_unchecked, appColors.subtleText),
    };
  }
}

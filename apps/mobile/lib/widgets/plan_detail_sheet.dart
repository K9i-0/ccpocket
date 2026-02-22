import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/app_theme.dart';
import '../theme/markdown_style.dart';

/// Shows a full-screen bottom sheet with the complete plan text.
///
/// Returns the edited plan text if the user taps "Apply & Approve",
/// or `null` if dismissed without editing.
Future<String?> showPlanDetailSheet(
  BuildContext context,
  String planText, {
  bool editable = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _PlanDetailContent(planText: planText, editable: editable),
  );
}

class _PlanDetailContent extends StatefulWidget {
  final String planText;
  final bool editable;

  const _PlanDetailContent({required this.planText, required this.editable});

  @override
  State<_PlanDetailContent> createState() => _PlanDetailContentState();
}

class _PlanDetailContentState extends State<_PlanDetailContent> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.planText);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _editController.text.trim().isNotEmpty &&
      _editController.text != widget.planText;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.assignment, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Implementation Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                // Edit toggle button
                if (widget.editable)
                  IconButton(
                    key: const ValueKey('plan_edit_toggle'),
                    icon: Icon(
                      _isEditing ? Icons.visibility : Icons.edit,
                      size: 20,
                    ),
                    tooltip: _isEditing ? 'View' : 'Edit',
                    onPressed: () {
                      setState(() => _isEditing = !_isEditing);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // Content area
          Expanded(
            child: _isEditing
                ? _PlanEditMode(
                    editController: _editController,
                    onChanged: () => setState(() {}),
                  )
                : _PlanViewMode(planText: widget.planText),
          ),
          // Bottom action bar (edit mode only)
          if (widget.editable && _isEditing)
            _PlanEditActions(
              hasChanges: _hasChanges,
              onCancel: () {
                _editController.text = widget.planText;
                setState(() => _isEditing = false);
              },
              onApply: () => Navigator.pop(context, _editController.text),
            ),
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _PlanViewMode extends StatelessWidget {
  final String planText;

  const _PlanViewMode({required this.planText});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: planText,
        selectable: true,
        styleSheet: buildMarkdownStyle(context),
        onTapLink: handleMarkdownLink,
        inlineSyntaxes: colorCodeInlineSyntaxes,
        builders: markdownBuilders,
      ),
    );
  }
}

class _PlanEditMode extends StatelessWidget {
  final TextEditingController editController;
  final VoidCallback onChanged;

  const _PlanEditMode({required this.editController, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TextField(
        key: const ValueKey('plan_edit_field'),
        controller: editController,
        maxLines: null,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Edit the plan...',
          hintStyle: TextStyle(color: appColors.subtleText),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _PlanEditActions extends StatelessWidget {
  final bool hasChanges;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  const _PlanEditActions({
    required this.hasChanges,
    required this.onCancel,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: appColors.subtleText.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          TextButton(
            key: const ValueKey('plan_edit_cancel'),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          const Spacer(),
          // Apply button -- saves edits; approval happens back in chat
          FilledButton.icon(
            key: const ValueKey('plan_edit_apply'),
            onPressed: hasChanges ? onApply : null,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

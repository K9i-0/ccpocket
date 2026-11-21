import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../services/bridge_service.dart';
import '../directory_browser_sheet.dart';
import 'project_widgets.dart';

class NewSessionAdditionalWritableRootsSection extends StatelessWidget {
  final List<String> roots;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onDeleted;

  const NewSessionAdditionalWritableRootsSection({
    super.key,
    required this.roots,
    required this.onAddPressed,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final rootLabels = folderChipLabels(roots);
    final infoButton = _AdditionalWritableRootsInfoButton(
      message:
          '${l.additionalWritableRootsDescription}\n${l.additionalWritableRootsTooltip}',
    );
    final addButton = ActionChip(
      key: const ValueKey('additional_writable_root_add_button'),
      avatar: const Icon(Icons.add, size: 18),
      label: Text(l.add),
      onPressed: onAddPressed,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.additionalWritableRootsTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                infoButton,
                const SizedBox(width: 8),
                addButton,
              ],
            ),
            if (roots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, root) in roots.indexed)
                    InputChip(
                      key: ValueKey(
                        'additional_writable_root_${root.hashCode}',
                      ),
                      label: Text(rootLabels[index]),
                      tooltip: root,
                      onDeleted: () => onDeleted(root),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdditionalWritableRootsInfoButton extends StatefulWidget {
  final String message;

  const _AdditionalWritableRootsInfoButton({required this.message});

  @override
  State<_AdditionalWritableRootsInfoButton> createState() =>
      _AdditionalWritableRootsInfoButtonState();
}

class _AdditionalWritableRootsInfoButtonState
    extends State<_AdditionalWritableRootsInfoButton> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
        onPressed: () => _tooltipKey.currentState?.ensureTooltipVisible(),
      ),
    );
  }
}

Future<String?> showAddWritableRootSheet({
  required BuildContext context,
  required TextEditingController controller,
  required List<String> suggestions,
  required BridgeService? bridge,
  required bool includeHidden,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _AddWritableRootSheet(
      controller: controller,
      suggestions: suggestions,
      bridge: bridge,
      includeHidden: includeHidden,
    ),
  );
}

class _AddWritableRootSheet extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final BridgeService? bridge;
  final bool includeHidden;

  const _AddWritableRootSheet({
    required this.controller,
    required this.suggestions,
    required this.bridge,
    required this.includeHidden,
  });

  /// Picking a folder in the browser is already a confirmation, so it is
  /// added straight away instead of being copied into the field first.
  Future<void> _browse(BuildContext context, BridgeService bridge) async {
    final typed = controller.text.trim();
    final path = await showDirectoryBrowserSheet(
      context: context,
      bridge: bridge,
      initialPath: typed.isEmpty ? null : typed,
      allowedRoots: bridge.allowedDirs,
      includeHidden: includeHidden,
    );
    if (path != null && context.mounted) Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final suggestionLabels = folderChipLabels(suggestions);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  key: const ValueKey('additional_writable_root_scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.addDirectory,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey(
                              'additional_writable_root_dismiss_keyboard_button',
                            ),
                            tooltip: l.dismissKeyboard,
                            onPressed: () =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            icon: const Icon(Icons.keyboard_hide),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.additionalWritableRootsTooltip,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('additional_writable_root_field'),
                        controller: controller,
                        autofocus: suggestions.isEmpty,
                        decoration: InputDecoration(
                          labelText: l.directoryPath,
                          hintText: '/Users/me/Workspace/other-project',
                          border: const OutlineInputBorder(),
                          suffixIcon: bridge == null
                              ? null
                              : IconButton(
                                  key: const ValueKey(
                                    'additional_writable_root_browse_button',
                                  ),
                                  tooltip: l.browseDirectory,
                                  onPressed: () => _browse(context, bridge!),
                                  icon: const Icon(Icons.folder_open),
                                ),
                        ),
                        onSubmitted: (value) {
                          final trimmed = value.trim();
                          if (trimmed.isNotEmpty) {
                            Navigator.pop(context, trimmed);
                          }
                        },
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          l.additionalWritableRootsSuggestions,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (index, suggestion)
                                in suggestions.indexed)
                              ActionChip(
                                key: ValueKey(
                                  'additional_writable_root_suggestion_${suggestion.hashCode}',
                                ),
                                avatar: const Icon(
                                  Icons.folder_outlined,
                                  size: 16,
                                ),
                                label: Text(suggestionLabels[index]),
                                tooltip: suggestion,
                                onPressed: () {
                                  Navigator.pop(context, suggestion);
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey(
                      'additional_writable_root_submit_button',
                    ),
                    onPressed: () {
                      final trimmed = controller.text.trim();
                      if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

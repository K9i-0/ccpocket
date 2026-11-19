import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/new_session_tab.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/provider_style.dart';
import '../../../widgets/workspace_pane_chrome.dart';

/// Shows a bottom sheet for ordering the new-session tabs. [current] is the
/// enabled agents in their order; which agents are enabled is set elsewhere.
Future<void> showNewSessionTabsBottomSheet({
  required BuildContext context,
  required List<NewSessionTab> current,
  required ValueChanged<List<NewSessionTab>> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _TabsBottomSheetContent(
      current: current,
      onChanged: (tabs) {
        onChanged(tabs);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _TabsBottomSheetContent extends StatefulWidget {
  final List<NewSessionTab> current;
  final ValueChanged<List<NewSessionTab>> onChanged;

  const _TabsBottomSheetContent({
    required this.current,
    required this.onChanged,
  });

  @override
  State<_TabsBottomSheetContent> createState() =>
      _TabsBottomSheetContentState();
}

class _TabsBottomSheetContentState extends State<_TabsBottomSheetContent> {
  /// The enabled tabs in display order.
  late List<NewSessionTab> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.current];
  }

  void _save() => widget.onChanged([..._items]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Icon(Icons.tab, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l.settingsNewSessionTabs,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            l.settingsNewSessionTabsDescription,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        // Reorderable list
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final tab = _items[index];
            final style = providerStyleFor(context, tab.toProvider());

            return ReorderableDragStartListener(
              key: ValueKey(tab.value),
              index: index,
              child: ListTile(
                leading: SizedBox(
                  width: 48,
                  child: Center(
                    child: ProviderIcon(
                      tab.toProvider(),
                      color: style.foreground,
                    ),
                  ),
                ),
                title: Text(
                  tab.localizedLabel(l),
                  style: TextStyle(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
              ),
            );
          },
        ),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: Text(l.save)),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

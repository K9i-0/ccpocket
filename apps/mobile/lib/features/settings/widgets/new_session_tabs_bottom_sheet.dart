import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/new_session_tab.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/provider_style.dart';
import '../../../widgets/workspace_pane_chrome.dart';

/// Shows a bottom sheet for configuring visible new-session tabs and their order.
Future<void> showNewSessionTabsBottomSheet({
  required BuildContext context,
  required List<NewSessionTab> current,
  required ValueChanged<List<NewSessionTab>> onChanged,
  bool showAntigravity = false,
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
      showAntigravity: showAntigravity,
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

  /// Offer Antigravity for ordering (its tab is enabled in settings).
  final bool showAntigravity;

  const _TabsBottomSheetContent({
    required this.current,
    required this.onChanged,
    this.showAntigravity = false,
  });

  @override
  State<_TabsBottomSheetContent> createState() =>
      _TabsBottomSheetContentState();
}

class _TabsBottomSheetContentState extends State<_TabsBottomSheetContent> {
  /// All tabs in display order, with enabled/disabled state.
  late List<({NewSessionTab tab, bool enabled})> _items;

  @override
  void initState() {
    super.initState();
    // Build ordered list: enabled tabs first (in order), then disabled ones.
    final enabledSet = widget.current.toSet();
    _items = [
      for (final tab in widget.current)
        if (tab != NewSessionTab.antigravity || widget.showAntigravity)
          (tab: tab, enabled: true),
      for (final tab in configurableNewSessionTabs)
        if (!enabledSet.contains(tab)) (tab: tab, enabled: false),
      // Antigravity can be ordered here; whether it shows is its own setting.
      if (widget.showAntigravity &&
          !enabledSet.contains(NewSessionTab.antigravity))
        (tab: NewSessionTab.antigravity, enabled: true),
    ];
  }

  bool get _canDisableMore =>
      _items
          .where((i) => i.enabled && i.tab != NewSessionTab.antigravity)
          .length >
      1;

  void _toggle(int index) {
    final item = _items[index];
    if (item.tab == NewSessionTab.antigravity) return;
    if (item.enabled && !_canDisableMore) return;
    setState(() {
      _items[index] = (tab: item.tab, enabled: !item.enabled);
    });
  }

  void _save() {
    final tabs = _items.where((i) => i.enabled).map((i) => i.tab).toList();
    widget.onChanged(tabs);
  }

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
            final item = _items[index];
            final style = providerStyleFor(context, item.tab.toProvider());
            final canToggle = item.enabled ? _canDisableMore : true;

            return ReorderableDragStartListener(
              key: ValueKey(item.tab.value),
              index: index,
              child: ListTile(
                leading: item.tab == NewSessionTab.antigravity
                    // Shown or hidden by its own setting, and by the Bridge.
                    ? SizedBox(
                        width: 48,
                        child: Center(
                          child: ProviderIcon(
                            item.tab.toProvider(),
                            color: style.foreground,
                          ),
                        ),
                      )
                    : Checkbox(
                        value: item.enabled,
                        onChanged: canToggle ? (_) => _toggle(index) : null,
                        activeColor: style.foreground,
                      ),
                title: Text(
                  item.tab.localizedLabel(l),
                  style: TextStyle(
                    color: item.enabled
                        ? style.foreground
                        : cs.onSurfaceVariant,
                    fontWeight: item.enabled
                        ? FontWeight.w600
                        : FontWeight.w400,
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

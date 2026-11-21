import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../models/new_session_tab.dart';
import '../../../services/bridge_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/claude_settings_panel.dart';
import '../../../widgets/codex_effort_slider.dart';
import '../../../widgets/workspace_pane_chrome.dart';

/// A single model choice displayed in the enabled-models selector.
class SelectableModelItem {
  final String id;
  final String label;
  final String? subtitle;

  const SelectableModelItem({
    required this.id,
    required this.label,
    this.subtitle,
  });
}

/// Shows a bottom sheet to choose which models appear in model pickers,
/// grouped by enabled agent.
Future<void> showEnabledModelsBottomSheet({
  required BuildContext context,
  required List<NewSessionTab> agents,
  required Map<Provider, Set<String>> initialEnabledByProvider,
  required BridgeService? bridge,
  required void Function(Map<Provider, Set<String>> updated) onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _EnabledModelsBottomSheetContent(
      agents: agents,
      initialEnabledByProvider: initialEnabledByProvider,
      bridge: bridge,
      onSaved: (updated) {
        onSaved(updated);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _EnabledModelsBottomSheetContent extends StatefulWidget {
  final List<NewSessionTab> agents;
  final Map<Provider, Set<String>> initialEnabledByProvider;
  final BridgeService? bridge;
  final void Function(Map<Provider, Set<String>> updated) onSaved;

  const _EnabledModelsBottomSheetContent({
    required this.agents,
    required this.initialEnabledByProvider,
    required this.bridge,
    required this.onSaved,
  });

  @override
  State<_EnabledModelsBottomSheetContent> createState() =>
      _EnabledModelsBottomSheetContentState();
}

class _EnabledModelsBottomSheetContentState
    extends State<_EnabledModelsBottomSheetContent> {
  late Provider _selectedProvider;
  final Map<Provider, Set<String>> _draftSelected = {};
  final Set<Provider> _touchedProviders = {};
  AntigravitySettings? _antigravityCatalog;
  bool _loadingAntigravity = false;
  StreamSubscription<AntigravityCatalogMessage>? _antigravitySub;

  List<Provider> get _providers => [
    for (final agent in widget.agents) agent.toProvider(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedProvider = _providers.firstOrNull ?? Provider.claude;
    final bridge = widget.bridge;
    if (bridge != null && _providers.contains(Provider.antigravity)) {
      _antigravityCatalog = bridge.antigravityCatalog;
      if (_antigravityCatalog == null && bridge.supportsAntigravityCatalog) {
        _loadingAntigravity = true;
        _antigravitySub = bridge.antigravityCatalogResults.listen((msg) {
          if (!mounted) return;
          setState(() {
            _loadingAntigravity = false;
            if (msg.catalog != null) {
              _antigravityCatalog = msg.catalog;
              _initializeDraftIfNeeded(Provider.antigravity);
            }
          });
        });
        bridge.requestAntigravityCatalog();
      }
    }
    for (final provider in _providers) {
      _initializeDraftIfNeeded(provider);
    }
  }

  @override
  void dispose() {
    _antigravitySub?.cancel();
    super.dispose();
  }

  List<SelectableModelItem> _catalogFor(Provider provider) {
    final bridge = widget.bridge;
    final saved = widget.initialEnabledByProvider[provider] ?? const <String>{};
    final items = <SelectableModelItem>[];
    final seen = <String>{};

    switch (provider) {
      case Provider.claude:
        final options = (bridge != null && bridge.claudeModelOptions.isNotEmpty)
            ? bridge.claudeModelOptions
            : defaultClaudeModelOptions;
        for (final option in options) {
          if (!seen.add(option.value)) continue;
          items.add(
            SelectableModelItem(
              id: option.value,
              label: option.label,
              subtitle: option.description,
            ),
          );
        }
      case Provider.codex:
        final models = (bridge != null && bridge.codexModels.isNotEmpty)
            ? bridge.codexModels
            : defaultCodexModels;
        for (final model in models) {
          if (!seen.add(model)) continue;
          items.add(
            SelectableModelItem(id: model, label: codexModelDisplayName(model)),
          );
        }
      case Provider.antigravity:
        final catalog = _antigravityCatalog;
        if (catalog != null && catalog.hasModelOptions) {
          for (final option in catalog.modelOptions) {
            if (!seen.add(option.id)) continue;
            items.add(SelectableModelItem(id: option.id, label: option.name));
          }
        } else if (catalog != null && catalog.models.isNotEmpty) {
          for (final model in catalog.models) {
            if (!seen.add(model.id)) continue;
            items.add(SelectableModelItem(id: model.id, label: model.name));
          }
        }
    }

    // Preserve any saved IDs not present in the current catalog so the user can
    // still inspect or uncheck them.
    for (final id in saved) {
      if (!seen.add(id)) continue;
      items.add(SelectableModelItem(id: id, label: id));
    }
    return items;
  }

  void _initializeDraftIfNeeded(Provider provider) {
    if (_touchedProviders.contains(provider)) return;
    final items = _catalogFor(provider);
    if (items.isEmpty) return;
    final saved = widget.initialEnabledByProvider[provider] ?? const <String>{};
    if (saved.isEmpty) {
      _draftSelected[provider] = {for (final item in items) item.id};
    } else {
      _draftSelected[provider] = Set<String>.from(saved);
    }
  }

  Set<String> _selectedFor(Provider provider) {
    _initializeDraftIfNeeded(provider);
    return _draftSelected[provider] ?? const {};
  }

  bool _hasEmptyTouchedSelection() {
    for (final provider in _touchedProviders) {
      final items = _catalogFor(provider);
      if (items.isEmpty) continue;
      if ((_draftSelected[provider] ?? const <String>{}).isEmpty) return true;
    }
    return false;
  }

  void _toggleModel(Provider provider, String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _touchedProviders.add(provider);
      final current = Set<String>.from(_selectedFor(provider));
      if (!current.remove(id)) {
        current.add(id);
      }
      _draftSelected[provider] = current;
    });
  }

  void _selectAll(Provider provider) {
    HapticFeedback.selectionClick();
    final items = _catalogFor(provider);
    setState(() {
      _touchedProviders.add(provider);
      _draftSelected[provider] = {for (final item in items) item.id};
    });
  }

  void _clearAll(Provider provider) {
    HapticFeedback.selectionClick();
    setState(() {
      _touchedProviders.add(provider);
      _draftSelected[provider] = <String>{};
    });
  }

  void _save() {
    if (_hasEmptyTouchedSelection()) return;
    final result = <Provider, Set<String>>{};
    for (final provider in _providers) {
      if (!_touchedProviders.contains(provider)) {
        result[provider] =
            widget.initialEnabledByProvider[provider] ?? const <String>{};
        continue;
      }
      final items = _catalogFor(provider);
      final selected = _draftSelected[provider] ?? const <String>{};
      final allIds = {for (final item in items) item.id};
      // Selecting every available model clears the filter so new models appear
      // automatically in the future.
      if (selected.length >= allIds.length && selected.containsAll(allIds)) {
        result[provider] = const <String>{};
      } else {
        result[provider] = Set<String>.unmodifiable(selected);
      }
    }
    widget.onSaved(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final items = _catalogFor(_selectedProvider);
    final selected = _selectedFor(_selectedProvider);
    final allSelected =
        items.isNotEmpty && items.every((item) => selected.contains(item.id));
    final noneSelected = items.isNotEmpty && selected.isEmpty;
    final canSave = !_hasEmptyTouchedSelection();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.settingsEnabledModels,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.settingsEnabledModelsDescription,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          if (_providers.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Provider>(
                  key: const ValueKey('enabled_models_provider_selector'),
                  showSelectedIcon: false,
                  segments: [
                    for (final agent in widget.agents)
                      ButtonSegment(
                        value: agent.toProvider(),
                        label: Text(
                          agent.label,
                          key: ValueKey('enabled_models_tab_${agent.value}'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                  ],
                  selected: {_selectedProvider},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedProvider = selection.first);
                  },
                ),
              ),
            ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
              child: Row(
                children: [
                  Text(
                    '${selected.length} / ${items.length}',
                    key: const ValueKey('enabled_models_count_label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: noneSelected ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!allSelected)
                    TextButton(
                      key: const ValueKey('enabled_models_select_all_button'),
                      onPressed: () => _selectAll(_selectedProvider),
                      child: Text(l.settingsEnabledModelsSelectAll),
                    ),
                  if (!noneSelected)
                    TextButton(
                      key: const ValueKey('enabled_models_clear_all_button'),
                      onPressed: () => _clearAll(_selectedProvider),
                      child: Text(l.settingsEnabledModelsClearAll),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Flexible(
            child: _EnabledModelsListBody(
              provider: _selectedProvider,
              items: items,
              selected: selected,
              loading:
                  _selectedProvider == Provider.antigravity &&
                  _loadingAntigravity &&
                  items.isEmpty,
              onToggle: (id) => _toggleModel(_selectedProvider, id),
            ),
          ),
          if (noneSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l.settingsEnabledModelsAtLeastOne,
                key: const ValueKey('enabled_models_validation_message'),
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('enabled_models_save_button'),
                onPressed: canSave ? _save : null,
                child: Text(l.save),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _EnabledModelsListBody extends StatelessWidget {
  final Provider provider;
  final List<SelectableModelItem> items;
  final Set<String> selected;
  final bool loading;
  final ValueChanged<String> onToggle;

  const _EnabledModelsListBody({
    required this.provider,
    required this.items,
    required this.selected,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              l.settingsEnabledModelsLoading,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Text(
          l.settingsEnabledModelsUnavailable,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      key: ValueKey('enabled_models_list_${provider.value}'),
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selected.contains(item.id);
        return CheckboxListTile(
          key: ValueKey('enabled_model_${provider.value}_${item.id}'),
          dense: true,
          value: isSelected,
          title: Text(item.label),
          subtitle: item.subtitle != null && item.subtitle!.isNotEmpty
              ? Text(
                  item.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              : null,
          onChanged: (_) => onToggle(item.id),
        );
      },
    );
  }
}

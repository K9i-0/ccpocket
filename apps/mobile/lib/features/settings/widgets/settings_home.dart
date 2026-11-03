import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/git_diff_interaction_mode.dart';
import '../../../models/input_delivery.dart';
import '../../../models/machine.dart';
import '../../../models/new_session_tab.dart';
import '../../../providers/machine_manager_cubit.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../sections/agents_settings_section.dart';
import '../sections/appearance_settings_section.dart';
import '../sections/connection_settings_section.dart';
import '../state/settings_state.dart';
import 'app_locale_bottom_sheet.dart';
import 'settings_category_visuals.dart';
import 'settings_status_card.dart';
import 'settings_tiles.dart';
import 'settings_visibility_builder.dart';
import 'speech_locale_bottom_sheet.dart';

typedef SettingsOpenCategory = void Function(
  SettingsCategory category, {
  String? entryId,
});

/// The settings landing list: status card, search and category list.
class SettingsHome extends StatefulWidget {
  const SettingsHome({
    super.key,
    required this.environment,
    required this.onOpenCategory,
    required this.onUpdateBridge,
    this.selectedCategory,
    this.highlight,
  });

  final ValueListenable<SettingsEnvironment> environment;
  final SettingsOpenCategory onOpenCategory;
  final ValueChanged<MachineWithStatus> onUpdateBridge;

  /// Highlighted category in the two-pane layout.
  final SettingsCategory? selectedCategory;

  /// Row on the home itself (e.g. usage in the status card) to reveal.
  final SettingsHighlightRequest? highlight;

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Usage lives in the status card, so the whole card is its search /
  /// deep-link target.
  Widget _maybeUsageItem(SettingsVisibility visibility, Widget card) {
    if (!visibility.bridgeConnected) return card;
    return SettingsItem(id: SettingsEntryIds.usage, framed: true, child: card);
  }

  void _setQuery(String value) {
    if (value == _query) return;
    setState(() => _query = value);
  }

  void _clearQuery() {
    _searchController.clear();
    _setQuery('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsVisibilityBuilder(
      environment: widget.environment,
      builder: (context, state, visibility, env) {
        final query = _query.trim();
        final list = ListView(
          key: const PageStorageKey('settings_list'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SettingsAccent(
              color: SettingsCategory.connection.color(
                Theme.of(context).brightness,
              ),
              child: _maybeUsageItem(
                visibility,
                SettingsStatusCard(
                  state: state,
                  visibility: visibility,
                  onOpenCategory: (category) => widget.onOpenCategory(category),
                  onUpdateBridge: widget.onUpdateBridge,
                ),
              ),
            ),
            _SettingsSearchField(
              controller: _searchController,
              hintText: l.settingsSearchHint,
              onChanged: _setQuery,
              onClear: _clearQuery,
            ),
            if (query.isEmpty)
              _CategoryList(
                state: state,
                visibility: visibility,
                selectedCategory: widget.selectedCategory,
                onOpenCategory: widget.onOpenCategory,
              )
            else
              _SearchResults(
                query: query,
                visibility: visibility,
                onOpenCategory: widget.onOpenCategory,
              ),
          ],
        );
        return SettingsHighlightScope(request: widget.highlight, child: list);
      },
    );
  }
}

class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            key: const ValueKey('settings_search_field'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: cs.onSurfaceVariant,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('settings_search_clear'),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      onPressed: onClear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.state,
    required this.visibility,
    required this.selectedCategory,
    required this.onOpenCategory,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final SettingsCategory? selectedCategory;
  final SettingsOpenCategory onOpenCategory;

  static const _groups = [
    [SettingsCategory.connection, SettingsCategory.notifications],
    [
      SettingsCategory.appearance,
      SettingsCategory.input,
      SettingsCategory.agents,
      SettingsCategory.git,
    ],
    [SettingsCategory.support, SettingsCategory.about],
  ];

  @override
  Widget build(BuildContext context) {
    final visible = visibleSettingsCategories(visibility).toSet();
    final machineState = context.watch<MachineManagerCubit>().state;
    final bridge = context.read<BridgeService>();
    final machineName = activeMachineWithStatus(
      machineState,
      state.activeMachineId,
    )?.machine.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in _groups)
          if (group.any(visible.contains))
            SettingsGroup(
              children: [
                for (final category in group)
                  if (visible.contains(category))
                    _CategoryTile(
                      category: category,
                      summary: _summary(
                        context,
                        category,
                        machineName: machineName ?? bridge.lastUrl,
                      ),
                      selected: category == selectedCategory,
                      onTap: () => onOpenCategory(category),
                    ),
              ],
            ),
      ],
    );
  }

  String _summary(
    BuildContext context,
    SettingsCategory category, {
    required String? machineName,
  }) {
    final l = AppLocalizations.of(context);
    return switch (category) {
      SettingsCategory.connection => machineName ?? l.settingsNotConnected,
      SettingsCategory.notifications =>
        state.fcmEnabled ? l.settingsOn : l.settingsOff,
      SettingsCategory.usage => l.settingsCategoryUsageSummary,
      SettingsCategory.appearance => [
        themeModeLabel(l, state.themeMode),
        getAppLocaleLabel(context, state.appLocaleId),
        '${(state.textScale * 100).round()}%',
      ].join(' · '),
      SettingsCategory.input => [
        switch (state.defaultInputDelivery) {
          InputDelivery.queue => l.inputDeliveryQueue,
          InputDelivery.steer => l.inputDeliverySteer,
        },
        if (!state.hideVoiceInput)
          getSpeechLocaleLabel(context, state.speechLocaleId),
      ].join(' · '),
      SettingsCategory.agents => enabledAgentsLabel(
        l,
        enabledAgentsModeFromTabs(state.newSessionTabs),
      ),
      SettingsCategory.git => switch (state.gitDiffInteractionMode) {
        GitDiffInteractionMode.quickActions => l.gitDiffQuickActions,
        GitDiffInteractionMode.scrollFirst => l.gitDiffScrollFirst,
      },
      SettingsCategory.support => l.settingsCategorySupportSummary,
      SettingsCategory.about => l.settingsCategoryAboutSummary,
    };
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final SettingsCategory category;
  final String summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = category.color(theme.brightness);
    return ListTile(
      key: category.tileKey,
      selected: selected,
      selectedTileColor: color.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: SettingsCategoryBadge(icon: category.icon, color: color),
      title: Text(
        category.title(l),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.visibility,
    required this.onOpenCategory,
  });

  final String query;
  final SettingsVisibility visibility;
  final SettingsOpenCategory onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = searchSettingsEntries(
      query: query,
      l: l,
      visibility: visibility,
      categoryTitle: (category) => category.title(l),
    );
    if (results.isEmpty) {
      return Padding(
        key: const ValueKey('settings_search_empty'),
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l.settingsSearchNoResults,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return SettingsGroup(
      children: [
        for (final entry in results)
          ListTile(
            key: ValueKey('settings_search_result_${entry.id}'),
            leading: SettingsCategoryBadge(
              icon: entry.category.icon,
              color: entry.category.color(theme.brightness),
              size: 30,
            ),
            title: Text(entry.title(l)),
            subtitle: Text(entry.category.title(l)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              FocusScope.of(context).unfocus();
              onOpenCategory(entry.category, entryId: entry.id);
            },
          ),
      ],
    );
  }
}

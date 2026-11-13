import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../models/messages.dart' show SessionDisplayMode;
import '../state/recent_session_filters.dart';
import '../state/session_list_state.dart';

/// A selectable project in the recent session filters.
typedef RecentProjectOption = ({String key, String name});

String recentDatePresetLabel(AppLocalizations l, RecentDatePreset preset) =>
    switch (preset) {
      RecentDatePreset.today => l.recentDateToday,
      RecentDatePreset.yesterday => l.recentDateYesterday,
      RecentDatePreset.dayBeforeYesterday => l.recentDateDayBeforeYesterday,
      RecentDatePreset.last7Days => l.recentDateLast7Days,
      RecentDatePreset.last30Days => l.recentDateLast30Days,
      RecentDatePreset.custom => l.recentDateCustom,
    };

/// Chip / summary label of a period filter.
String recentDateFilterLabel(BuildContext context, RecentDateFilter? filter) {
  final l = AppLocalizations.of(context);
  if (filter == null) return l.recentFilterPeriod;
  if (filter.preset != RecentDatePreset.custom) {
    return recentDatePresetLabel(l, filter.preset);
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  final format = DateFormat.MMMd(locale);
  final start = filter.customStart;
  final end = filter.customEnd;
  if (start == null || end == null) return l.recentDateCustom;
  if (start == end) return format.format(start);
  return '${format.format(start)} – ${format.format(end)}';
}

/// Pick a custom inclusive day range ending today at the latest.
Future<RecentDateFilter?> pickCustomRecentDateRange(
  BuildContext context, {
  RecentDateFilter? initial,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(today.year - 5),
    lastDate: today,
    initialDateRange:
        initial?.preset == RecentDatePreset.custom &&
            initial?.customStart != null &&
            initial?.customEnd != null
        ? DateTimeRange(start: initial!.customStart!, end: initial.customEnd!)
        : null,
  );
  if (range == null) return null;
  return RecentDateFilter.custom(start: range.start, end: range.end);
}

void showRecentBridgeUpdateHint(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).recentRequiresBridgeUpdate),
      ),
    );
}

// ---------------------------------------------------------------------------
// Project picker
// ---------------------------------------------------------------------------

/// Pick projects for the recent session filter.
///
/// Returns the new selection (empty = all projects), or null when dismissed.
/// With [multiSelect] false a tap selects a single project and closes.
Future<Set<String>?> showRecentProjectPicker({
  required BuildContext context,
  required List<RecentProjectOption> projects,
  required Set<String> selected,
  required Set<String> favorites,
  required bool multiSelect,
  ValueChanged<String>? onToggleFavorite,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => RecentProjectPickerSheet(
      projects: projects,
      selected: selected,
      favorites: favorites,
      multiSelect: multiSelect,
      onToggleFavorite: onToggleFavorite,
    ),
  );
}

class RecentProjectPickerSheet extends StatefulWidget {
  final List<RecentProjectOption> projects;
  final Set<String> selected;
  final Set<String> favorites;
  final bool multiSelect;
  final ValueChanged<String>? onToggleFavorite;

  const RecentProjectPickerSheet({
    super.key,
    required this.projects,
    required this.selected,
    required this.favorites,
    required this.multiSelect,
    this.onToggleFavorite,
  });

  @override
  State<RecentProjectPickerSheet> createState() =>
      _RecentProjectPickerSheetState();
}

class _RecentProjectPickerSheetState extends State<RecentProjectPickerSheet> {
  late Set<String> _selected = {...widget.selected};
  late final Set<String> _favorites = {...widget.favorites};
  String _query = '';

  void _toggleSelected(String key) {
    if (!widget.multiSelect) {
      Navigator.of(context).pop({key});
      return;
    }
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  void _toggleFavorite(String key) {
    widget.onToggleFavorite?.call(key);
    setState(() {
      if (!_favorites.remove(key)) _favorites.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final q = _query.trim().toLowerCase();
    final visible = widget.projects
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final favoriteProjects = visible
        .where((p) => _favorites.contains(p.key))
        .toList();
    final otherProjects = visible
        .where((p) => !_favorites.contains(p.key))
        .toList();
    final favoriteKeys = widget.projects
        .where((p) => _favorites.contains(p.key))
        .map((p) => p.key)
        .toSet();

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: appColors.subtleText,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.recentProjectPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.multiSelect)
                  TextButton(
                    key: const ValueKey('project_picker_reset'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(() => _selected = {}),
                    child: Text(l.recentReset),
                  ),
              ],
            ),
          ),
          if (widget.projects.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                key: const ValueKey('project_picker_search'),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: l.search,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                ListTile(
                  key: const ValueKey('project_option_all'),
                  leading: Icon(
                    _selected.isEmpty
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _selected.isEmpty
                        ? theme.colorScheme.primary
                        : appColors.subtleText,
                  ),
                  title: Text(l.allProjects),
                  onTap: () {
                    if (!widget.multiSelect) {
                      Navigator.of(context).pop(<String>{});
                    } else {
                      setState(() => _selected = {});
                    }
                  },
                ),
                sectionLabel(l.recentFavoriteProjects),
                if (favoriteKeys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      l.recentNoFavoriteProjects,
                      style: TextStyle(
                        fontSize: 12,
                        color: appColors.subtleText,
                      ),
                    ),
                  )
                else if (widget.multiSelect)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: TextButton.icon(
                        key: const ValueKey('project_picker_select_favorites'),
                        onPressed: () =>
                            setState(() => _selected = {...favoriteKeys}),
                        icon: const Icon(Icons.star, size: 16),
                        label: Text(l.recentSelectFavorites),
                      ),
                    ),
                  ),
                for (final project in favoriteProjects) _tile(project),
                if (otherProjects.isNotEmpty) ...[
                  sectionLabel(l.recentOtherProjects),
                  for (final project in otherProjects) _tile(project),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (widget.multiSelect)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('project_picker_apply'),
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(l.recentApply),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(RecentProjectOption project) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isSelected = _selected.contains(project.key);
    final isFavorite = _favorites.contains(project.key);
    return ListTile(
      key: ValueKey('project_option_${project.key}'),
      leading: widget.multiSelect
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelected(project.key),
            )
          : Icon(
              isSelected ? Icons.check : Icons.folder_outlined,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: widget.onToggleFavorite == null
          ? null
          : IconButton(
              key: ValueKey('project_favorite_${project.key}'),
              tooltip: l.recentFavoriteTooltip,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber.shade700 : null,
              ),
              onPressed: () => _toggleFavorite(project.key),
            ),
      onTap: () => _toggleSelected(project.key),
    );
  }
}

// ---------------------------------------------------------------------------
// Display settings
// ---------------------------------------------------------------------------

Future<void> showRecentDisplaySettings({
  required BuildContext context,
  required bool grouped,
  required SessionDisplayMode displayMode,
  required ValueChanged<bool> onGroupedChanged,
  required ValueChanged<SessionDisplayMode> onDisplayModeChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      var currentGrouped = grouped;
      var currentMode = displayMode;
      return StatefulBuilder(
        builder: (context, setState) {
          final l = AppLocalizations.of(context);
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.recentDisplaySettings,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(l.recentLayout, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    key: const ValueKey('recent_layout_selector'),
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.view_list_outlined),
                        label: Text(
                          l.recentLayoutList,
                          key: const ValueKey('recent_layout_list'),
                        ),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text(
                          l.recentLayoutGrouped,
                          key: const ValueKey('recent_layout_grouped'),
                        ),
                      ),
                    ],
                    selected: {currentGrouped},
                    onSelectionChanged: (value) {
                      setState(() => currentGrouped = value.first);
                      onGroupedChanged(value.first);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.recentCardText, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<SessionDisplayMode>(
                    key: const ValueKey('recent_card_text_selector'),
                    segments: [
                      ButtonSegment(
                        value: SessionDisplayMode.first,
                        label: Text(l.sessionDisplayModeFirst),
                      ),
                      ButtonSegment(
                        value: SessionDisplayMode.last,
                        label: Text(l.sessionDisplayModeLast),
                      ),
                      ButtonSegment(
                        value: SessionDisplayMode.summary,
                        label: Text(l.sessionDisplayModeSummary),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (value) {
                      setState(() => currentMode = value.first);
                      onDisplayModeChanged(value.first);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Advanced search
// ---------------------------------------------------------------------------

class RecentAdvancedSearchResult {
  final String searchQuery;
  final RecentSessionFilters filters;
  final ProviderFilter providerFilter;
  final bool namedOnly;

  const RecentAdvancedSearchResult({
    required this.searchQuery,
    required this.filters,
    required this.providerFilter,
    required this.namedOnly,
  });
}

Future<RecentAdvancedSearchResult?> showRecentAdvancedSearch({
  required BuildContext context,
  required String searchQuery,
  required RecentSessionFilters filters,
  required ProviderFilter providerFilter,
  required List<ProviderFilter> providerOptions,
  required bool namedOnly,
  required bool supportsAdvancedFilters,
  required List<RecentProjectOption> projects,
  required Set<String> favoriteProjects,
  ValueChanged<String>? onToggleFavoriteProject,
}) {
  return showModalBottomSheet<RecentAdvancedSearchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => RecentAdvancedSearchSheet(
      searchQuery: searchQuery,
      filters: filters,
      providerFilter: providerFilter,
      providerOptions: providerOptions,
      namedOnly: namedOnly,
      supportsAdvancedFilters: supportsAdvancedFilters,
      projects: projects,
      favoriteProjects: favoriteProjects,
      onToggleFavoriteProject: onToggleFavoriteProject,
    ),
  );
}

class RecentAdvancedSearchSheet extends StatefulWidget {
  final String searchQuery;
  final RecentSessionFilters filters;
  final ProviderFilter providerFilter;
  final List<ProviderFilter> providerOptions;
  final bool namedOnly;
  final bool supportsAdvancedFilters;
  final List<RecentProjectOption> projects;
  final Set<String> favoriteProjects;
  final ValueChanged<String>? onToggleFavoriteProject;

  const RecentAdvancedSearchSheet({
    super.key,
    required this.searchQuery,
    required this.filters,
    required this.providerFilter,
    required this.providerOptions,
    required this.namedOnly,
    required this.supportsAdvancedFilters,
    required this.projects,
    required this.favoriteProjects,
    this.onToggleFavoriteProject,
  });

  @override
  State<RecentAdvancedSearchSheet> createState() =>
      _RecentAdvancedSearchSheetState();
}

class _RecentAdvancedSearchSheetState extends State<RecentAdvancedSearchSheet> {
  late final _queryController = TextEditingController(text: widget.searchQuery);
  late RecentSessionFilters _filters = widget.filters;
  late ProviderFilter _provider = widget.providerFilter;
  late bool _namedOnly = widget.namedOnly;
  late final Set<String> _favorites = {...widget.favoriteProjects};

  bool get _supported => widget.supportsAdvancedFilters;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _queryController.clear();
      _filters = const RecentSessionFilters();
      _namedOnly = false;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      RecentAdvancedSearchResult(
        searchQuery: _queryController.text.trim(),
        filters: _filters,
        providerFilter: _provider,
        namedOnly: _namedOnly,
      ),
    );
  }

  Future<void> _pickProjects() async {
    final result = await showRecentProjectPicker(
      context: context,
      projects: widget.projects,
      selected: _filters.projectKeys,
      favorites: _favorites,
      multiSelect: _supported,
      onToggleFavorite: widget.onToggleFavoriteProject == null
          ? null
          : (key) {
              widget.onToggleFavoriteProject!(key);
              setState(() {
                if (!_favorites.remove(key)) _favorites.add(key);
              });
            },
    );
    if (result == null || !mounted) return;
    setState(() => _filters = _filters.copyWith(projectKeys: result));
  }

  Future<void> _selectPreset(RecentDatePreset? preset) async {
    if (preset == RecentDatePreset.custom) {
      final picked = await pickCustomRecentDateRange(
        context,
        initial: _filters.dateFilter,
      );
      if (picked == null || !mounted) return;
      setState(() => _filters = _filters.copyWith(dateFilter: picked));
      return;
    }
    setState(() {
      _filters = preset == null
          ? _filters.copyWith(clearDateFilter: true)
          : _filters.copyWith(dateFilter: RecentDateFilter(preset));
    });
  }

  String _projectSummary(AppLocalizations l) {
    final keys = _filters.projectKeys;
    if (keys.isEmpty) return l.allProjects;
    final names = {for (final p in widget.projects) p.key: p.name};
    final first = names[keys.first] ?? keys.first;
    return keys.length == 1
        ? first
        : l.recentFilterProjectsSummary(first, keys.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final updateHint = Text(
      l.recentRequiresBridgeUpdate,
      style: TextStyle(fontSize: 12, color: appColors.subtleText),
    );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.recentAdvancedSearch,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('advanced_search_reset'),
                    onPressed: _reset,
                    child: Text(l.recentReset),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  label(l.recentKeywords),
                  TextField(
                    key: const ValueKey('advanced_search_query'),
                    controller: _queryController,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _apply(),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: l.recentKeywordsHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('advanced_search_content'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.recentSearchContent),
                    subtitle: _supported
                        ? Text(l.recentSearchContentHint)
                        : updateHint,
                    value: _supported && _filters.searchContent,
                    onChanged: _supported
                        ? (value) => setState(
                            () => _filters = _filters.copyWith(
                              searchContent: value,
                            ),
                          )
                        : null,
                  ),
                  label(l.recentFilterPeriod),
                  if (!_supported)
                    updateHint
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('advanced_period_any'),
                          label: Text(l.recentDateAnyTime),
                          selected: _filters.dateFilter == null,
                          onSelected: (_) => _selectPreset(null),
                        ),
                        for (final preset in RecentDatePreset.values)
                          ChoiceChip(
                            key: ValueKey('advanced_period_${preset.name}'),
                            label: Text(
                              preset == RecentDatePreset.custom &&
                                      _filters.dateFilter?.preset == preset
                                  ? recentDateFilterLabel(
                                      context,
                                      _filters.dateFilter,
                                    )
                                  : recentDatePresetLabel(l, preset),
                            ),
                            selected: _filters.dateFilter?.preset == preset,
                            onSelected: (_) => _selectPreset(preset),
                          ),
                      ],
                    ),
                    label(l.recentDateField),
                    SegmentedButton<RecentDateField>(
                      key: const ValueKey('advanced_date_field'),
                      segments: [
                        ButtonSegment(
                          value: RecentDateField.modified,
                          label: Text(l.recentDateFieldModified),
                        ),
                        ButtonSegment(
                          value: RecentDateField.created,
                          label: Text(l.recentDateFieldCreated),
                        ),
                      ],
                      selected: {_filters.dateField},
                      onSelectionChanged: (value) => setState(
                        () => _filters = _filters.copyWith(
                          dateField: value.first,
                        ),
                      ),
                    ),
                  ],
                  label(l.recentMatchProject),
                  ListTile(
                    key: const ValueKey('advanced_search_projects'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      _projectSummary(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickProjects,
                  ),
                  if (widget.providerOptions.length > 1) ...[
                    label(l.recentAiTool),
                    SegmentedButton<ProviderFilter>(
                      key: const ValueKey('advanced_search_provider'),
                      segments: [
                        for (final option in widget.providerOptions)
                          ButtonSegment(
                            value: option,
                            label: Text(switch (option) {
                              ProviderFilter.all => l.all,
                              ProviderFilter.claude => 'Claude',
                              ProviderFilter.codex => 'Codex',
                            }),
                          ),
                      ],
                      selected: {_provider},
                      onSelectionChanged: (value) =>
                          setState(() => _provider = value.first),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey('advanced_search_named_only'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.recentNamedOnly),
                    value: _namedOnly,
                    onChanged: (value) => setState(() => _namedOnly = value),
                  ),
                  SwitchListTile(
                    key: const ValueKey('advanced_search_pinned_only'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.recentPinnedOnly),
                    subtitle: _supported ? null : updateHint,
                    value: _supported && _filters.pinnedOnly,
                    onChanged: _supported
                        ? (value) => setState(
                            () =>
                                _filters = _filters.copyWith(pinnedOnly: value),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('advanced_search_apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.search),
                  label: Text(l.recentApply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

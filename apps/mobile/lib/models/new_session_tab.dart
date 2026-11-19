import 'dart:convert';

import '../l10n/app_localizations.dart';
import 'messages.dart';

/// Tabs available in the new session sheet.
enum NewSessionTab {
  codex('codex', 'Codex'),
  claude('claude', 'Claude'),

  /// Offered only while the Bridge advertises `antigravity_v1`. In the saved
  /// tab setting it only marks a position; see [visibleNewSessionTabs].
  antigravity('antigravity', 'Antigravity');

  final String value;
  final String label;
  const NewSessionTab(this.value, this.label);

  /// Convert to [Provider].
  Provider toProvider() => switch (this) {
    NewSessionTab.claude => Provider.claude,
    NewSessionTab.codex => Provider.codex,
    NewSessionTab.antigravity => Provider.antigravity,
  };

  /// Look up a tab by its wire-format value.
  static NewSessionTab? fromValue(String value) {
    for (final tab in values) {
      if (tab.value == value) return tab;
    }
    return null;
  }
}

extension NewSessionTabL10n on NewSessionTab {
  String localizedLabel(AppLocalizations l) => switch (this) {
    NewSessionTab.codex => l.newSessionTabCodex,
    NewSessionTab.claude => l.newSessionTabClaudeCode,
    // Product name, not translated.
    NewSessionTab.antigravity => NewSessionTab.antigravity.label,
  };
}

/// Default tab order when no user preference is saved.
const defaultNewSessionTabs = [NewSessionTab.codex, NewSessionTab.claude];

/// Tabs saved by name. Antigravity is not one of them: whether it is used is
/// its own setting, and in the saved list it only marks a position.
const configurableNewSessionTabs = [NewSessionTab.codex, NewSessionTab.claude];

/// Agents the saved settings enable, in their saved order.
///
/// [antigravity] is the Antigravity setting. Antigravity sits at its saved
/// position, or after the others when it has none. A setting that enables
/// nothing falls back to the defaults.
List<NewSessionTab> enabledAgents(
  List<NewSessionTab> savedTabs, {
  required bool antigravity,
}) {
  final saved = savedTabs.isEmpty ? defaultNewSessionTabs : savedTabs;
  final agents = <NewSessionTab>[
    for (final tab in saved.toSet())
      if (tab != NewSessionTab.antigravity || antigravity) tab,
  ];
  if (antigravity && !agents.contains(NewSessionTab.antigravity)) {
    agents.add(NewSessionTab.antigravity);
  }
  return agents.isEmpty ? defaultNewSessionTabs : agents;
}

/// Tabs to show in the new session sheet for the saved [enabledTabs].
///
/// [supportsAntigravity] is true when Antigravity is enabled in settings and
/// the Bridge advertises `antigravity_v1`. With only Antigravity enabled and
/// no such Bridge, the default tabs are shown so a session can still start.
List<NewSessionTab> visibleNewSessionTabs(
  List<NewSessionTab> enabledTabs, {
  required bool supportsAntigravity,
}) => enabledAgents(enabledTabs, antigravity: supportsAntigravity);

/// The saved tab list with Codex or Claude switched on or off. Antigravity
/// keeps its position marker either way.
List<NewSessionTab> tabsWithAgent(
  List<NewSessionTab> savedTabs,
  NewSessionTab agent,
  bool enabled,
) {
  assert(agent != NewSessionTab.antigravity);
  final saved = savedTabs.isEmpty ? defaultNewSessionTabs : savedTabs;
  if (enabled) return saved.contains(agent) ? saved : [...saved, agent];
  final rest = [
    for (final tab in saved)
      if (tab != agent) tab,
  ];
  // An empty list would read as "nothing saved", which enables the defaults.
  return rest.isEmpty ? const [NewSessionTab.antigravity] : rest;
}

bool isNewSessionTabEnabled(
  List<NewSessionTab> enabledTabs,
  NewSessionTab tab,
) {
  return enabledTabs.contains(tab);
}

/// Serialize a tab list to a JSON string for SharedPreferences.
String tabsToJson(List<NewSessionTab> tabs) =>
    jsonEncode(tabs.map((t) => t.value).toList());

/// Deserialize a JSON string to a tab list.
/// Returns null if the JSON is invalid or the result is empty.
List<NewSessionTab>? tabsFromJson(String json) {
  try {
    final list = (jsonDecode(json) as List).cast<String>();
    final tabs = list
        .map(NewSessionTab.fromValue)
        .whereType<NewSessionTab>()
        .toSet()
        .toList();
    return tabs.isEmpty ? null : tabs;
  } catch (_) {
    return null;
  }
}

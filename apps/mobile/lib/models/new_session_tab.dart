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

enum EnabledAgentsMode { both, codex, claude }

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

/// Tabs the user can enable in settings. Antigravity is not one of them: it
/// follows the Bridge capability and its own setting instead.
const configurableNewSessionTabs = [NewSessionTab.codex, NewSessionTab.claude];

/// Tabs to show in the new session sheet for the saved [enabledTabs].
///
/// Antigravity is shown when all agents are enabled and the Bridge advertises
/// `antigravity_v1` ([supportsAntigravity]): at its saved position when the
/// user ordered it, after the other tabs otherwise.
List<NewSessionTab> visibleNewSessionTabs(
  List<NewSessionTab> enabledTabs, {
  required bool supportsAntigravity,
}) {
  final tabs = [
    for (final tab in enabledTabs)
      if (configurableNewSessionTabs.contains(tab)) tab,
  ];
  final base = tabs.isEmpty ? defaultNewSessionTabs : tabs;
  if (!supportsAntigravity ||
      enabledAgentsModeFromTabs(base) != EnabledAgentsMode.both) {
    return base;
  }
  if (tabs.isNotEmpty && enabledTabs.contains(NewSessionTab.antigravity)) {
    return enabledTabs.toSet().toList();
  }
  return [...base, NewSessionTab.antigravity];
}

EnabledAgentsMode enabledAgentsModeFromTabs(List<NewSessionTab> tabs) {
  final set = tabs.toSet();
  final hasCodex = set.contains(NewSessionTab.codex);
  final hasClaude = set.contains(NewSessionTab.claude);
  if (hasCodex && !hasClaude) return EnabledAgentsMode.codex;
  if (hasClaude && !hasCodex) return EnabledAgentsMode.claude;
  return EnabledAgentsMode.both;
}

List<NewSessionTab> tabsForEnabledAgentsMode(
  EnabledAgentsMode mode,
  List<NewSessionTab> current,
) {
  switch (mode) {
    case EnabledAgentsMode.both:
      // Keeps Antigravity's saved position.
      final ordered = [...current];
      final set = ordered.toSet();
      if (!set.contains(NewSessionTab.codex)) {
        ordered.add(NewSessionTab.codex);
      }
      if (!set.contains(NewSessionTab.claude)) {
        ordered.add(NewSessionTab.claude);
      }
      return ordered;
    case EnabledAgentsMode.codex:
      return const [NewSessionTab.codex];
    case EnabledAgentsMode.claude:
      return const [NewSessionTab.claude];
  }
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
    // Antigravity alone enables nothing; it only has a position.
    return tabs.any(configurableNewSessionTabs.contains) ? tabs : null;
  } catch (_) {
    return null;
  }
}

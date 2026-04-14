import 'dart:convert';

import '../l10n/app_localizations.dart';
import 'messages.dart';

/// Tabs available in the new session sheet.
enum NewSessionTab {
  codex('codex', 'Codex'),
  claude('claude', 'Claude Code');

  final String value;
  final String label;
  const NewSessionTab(this.value, this.label);

  /// Convert to [Provider].
  Provider toProvider() => switch (this) {
    NewSessionTab.claude => Provider.claude,
    NewSessionTab.codex => Provider.codex,
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
  };
}

/// Default tab order when no user preference is saved.
const defaultNewSessionTabs = [NewSessionTab.codex, NewSessionTab.claude];

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
        .toList();
    return tabs.isEmpty ? null : tabs;
  } catch (_) {
    return null;
  }
}

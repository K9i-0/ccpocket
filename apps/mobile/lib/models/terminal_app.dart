import 'package:material_ui/material_ui.dart';

/// A terminal app preset that can be used to open projects externally.
///
/// Community members can add new presets by submitting a PR that adds
/// an entry to [kTerminalAppPresets].
class TerminalAppPreset {
  const TerminalAppPreset({
    required this.id,
    required this.name,
    required this.urlTemplate,
    this.icon,
  });

  /// Unique identifier for persistence.
  final String id;

  /// Display name (e.g. "Blink Shell").
  final String name;

  /// URL template with placeholders: `{{host}}`, `{{user}}`, `{{port}}`,
  /// `{{project_path}}`.
  final String urlTemplate;

  /// Optional icon for display.
  final IconData? icon;
}

/// Built-in presets.
///
/// To add a new terminal app, append a [TerminalAppPreset] here and submit a PR.
const kTerminalAppPresets = <TerminalAppPreset>[
  TerminalAppPreset(
    id: 'blink',
    name: 'Blink Shell',
    urlTemplate: "blinkshell://run?key=ssh&cmd=ssh {{user}}@{{host}} -t 'cd {{project_path}} && \$SHELL'",
  ),
  TerminalAppPreset(
    id: 'termius',
    name: 'Termius',
    urlTemplate: 'termius://app/host#{{user}}@{{host}}:{{port}}',
  ),
  TerminalAppPreset(
    id: 'prompt3',
    name: 'Prompt 3',
    urlTemplate: 'prompt3://x-callback-url/new?host={{host}}&user={{user}}',
  ),
];

/// User-configured terminal app setting.
///
/// Stored as JSON in SharedPreferences.
class TerminalAppConfig {
  const TerminalAppConfig({
    this.presetId,
    this.customName,
    this.customUrlTemplate,
    this.sshUser,
  });

  /// Preset ID (null when using a custom template).
  final String? presetId;

  /// Custom display name (used only when [presetId] is null).
  final String? customName;

  /// Custom URL template (used only when [presetId] is null).
  final String? customUrlTemplate;

  /// SSH username override. When empty, falls back to the machine's
  /// [Machine.sshUsername].
  final String? sshUser;

  /// Whether this config is actually configured (not empty).
  bool get isConfigured =>
      presetId != null ||
      (customUrlTemplate != null && customUrlTemplate!.isNotEmpty);

  /// Resolve the display name.
  String get displayName {
    if (presetId != null) {
      final preset = kTerminalAppPresets
          .where((p) => p.id == presetId)
          .firstOrNull;
      return preset?.name ?? presetId!;
    }
    return customName ?? '';
  }

  /// Resolve the URL template.
  String get urlTemplate {
    if (presetId != null) {
      final preset = kTerminalAppPresets
          .where((p) => p.id == presetId)
          .firstOrNull;
      return preset?.urlTemplate ?? '';
    }
    return customUrlTemplate ?? '';
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    if (presetId != null) 'presetId': presetId,
    if (customName != null) 'customName': customName,
    if (customUrlTemplate != null) 'customUrlTemplate': customUrlTemplate,
    if (sshUser != null) 'sshUser': sshUser,
  };

  /// Deserialize from JSON map.
  factory TerminalAppConfig.fromJson(Map<String, dynamic> json) =>
      TerminalAppConfig(
        presetId: json['presetId'] as String?,
        customName: json['customName'] as String?,
        customUrlTemplate: json['customUrlTemplate'] as String?,
        sshUser: json['sshUser'] as String?,
      );

  /// Empty / unconfigured instance.
  static const empty = TerminalAppConfig();
}

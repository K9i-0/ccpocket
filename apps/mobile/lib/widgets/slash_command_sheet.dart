import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/messages.dart'
    show CodexAppMetadata, CodexPluginMetadata, CodexSkillMetadata;
import '../theme/app_theme.dart';

// ---- Model ----

enum SlashCommandCategory { builtin, project, skill, app, plugin }

class SlashCommand {
  final String command;
  final String insertText;
  final String description;
  final IconData icon;
  final SlashCommandCategory category;

  /// Codex skill metadata (null for non-skill commands).
  final CodexSkillInfo? skillInfo;
  final CodexAppInfo? appInfo;
  final CodexPluginInfo? pluginInfo;

  const SlashCommand({
    required this.command,
    String? insertText,
    required this.description,
    required this.icon,
    this.category = SlashCommandCategory.builtin,
    this.skillInfo,
    this.appInfo,
    this.pluginInfo,
  }) : insertText = insertText ?? '$command ';
}

/// Lightweight skill info attached to a [SlashCommand] for Codex skill input.
class CodexSkillInfo {
  final String name;
  final String path;
  final String? defaultPrompt;

  const CodexSkillInfo({
    required this.name,
    required this.path,
    this.defaultPrompt,
  });

  Map<String, String> toJson() => {'name': name, 'path': path};
}

/// Lightweight app info attached to a [SlashCommand] for Codex app mentions.
class CodexAppInfo {
  final String id;
  final String name;
  final String path;

  const CodexAppInfo({
    required this.id,
    required this.name,
    required this.path,
  });

  Map<String, String> toJson() => {'name': name, 'path': path};
}

/// Lightweight plugin info attached to a [SlashCommand] for Codex plugin mentions.
class CodexPluginInfo {
  final String id;
  final String name;
  final String path;

  const CodexPluginInfo({
    required this.id,
    required this.name,
    required this.path,
  });

  Map<String, String> toJson() => {'name': name, 'path': path};
}

// ---- Known command metadata ----

const knownCommands = <String, ({String description, IconData icon})>{
  'compact': (description: 'Compact conversation', icon: Icons.compress),
  'plan': (description: 'Switch to Plan mode', icon: Icons.map_outlined),
  'clear': (description: 'Clear conversation', icon: Icons.delete_outline),
  'help': (description: 'Show help', icon: Icons.help_outline),
  'context': (
    description: 'Show context usage',
    icon: Icons.donut_large_outlined,
  ),
  'cost': (description: 'Show cost summary', icon: Icons.attach_money),
  'init': (description: 'Initialize project', icon: Icons.play_arrow),
  'review': (description: 'Code review', icon: Icons.rate_review_outlined),
  'model': (description: 'Switch model', icon: Icons.swap_horiz),
  'skills': (description: 'List available skills', icon: Icons.extension),
  'status': (description: 'Show status', icon: Icons.info_outline),
  'memory': (description: 'Edit CLAUDE.md', icon: Icons.edit_note),
  'config': (description: 'Open settings', icon: Icons.settings_outlined),
  'permissions': (description: 'View permissions', icon: Icons.lock_outline),
  'pr-comments': (description: 'PR comments', icon: Icons.comment_outlined),
  'release-notes': (description: 'Release notes', icon: Icons.notes_outlined),
  'security-review': (description: 'Security review', icon: Icons.security),
  'resume': (description: 'Resume session', icon: Icons.replay),
  'rename': (
    description: 'Rename session',
    icon: Icons.drive_file_rename_outline,
  ),
  'doctor': (description: 'Health checks', icon: Icons.health_and_safety),
  'mcp': (description: 'Manage MCP servers', icon: Icons.dns_outlined),
  'export': (
    description: 'Export conversation',
    icon: Icons.file_download_outlined,
  ),
  'add-dir': (
    description: 'Add directories',
    icon: Icons.create_new_folder_outlined,
  ),
  'rewind': (description: 'Rewind to previous point', icon: Icons.undo),
  'vim': (description: 'Enable vim mode', icon: Icons.keyboard),
  'login': (description: 'Switch accounts', icon: Icons.login),
};

// ---- Factory ----

SlashCommand buildSlashCommand(
  String name, {
  SlashCommandCategory category = SlashCommandCategory.builtin,
  CodexSkillMetadata? skillMeta,
  String? insertText,
}) {
  final known = knownCommands[name];
  // Prefer rich metadata from Codex skills/list when available
  final description = skillMeta?.summary ?? known?.description ?? name;
  final icon = known?.icon ?? Icons.terminal;
  return SlashCommand(
    command: '/$name',
    insertText: insertText,
    description: description,
    icon: icon,
    category: category,
    skillInfo: skillMeta != null
        ? CodexSkillInfo(
            name: skillMeta.name,
            path: skillMeta.path,
            defaultPrompt: skillMeta.defaultPrompt,
          )
        : null,
  );
}

SlashCommand buildSlashSkill(CodexSkillMetadata skillMeta) {
  return SlashCommand(
    command: '/${skillMeta.name}',
    insertText: '\$${skillMeta.name} ',
    description: skillMeta.summary,
    icon: knownCommands[skillMeta.name]?.icon ?? Icons.extension,
    category: SlashCommandCategory.skill,
    skillInfo: CodexSkillInfo(
      name: skillMeta.name,
      path: skillMeta.path,
      defaultPrompt: skillMeta.defaultPrompt,
    ),
  );
}

SlashCommand buildDollarSkill(CodexSkillMetadata skillMeta) {
  return SlashCommand(
    command: '\$${skillMeta.name}',
    description: skillMeta.summary,
    icon: Icons.extension,
    category: SlashCommandCategory.skill,
    skillInfo: CodexSkillInfo(
      name: skillMeta.name,
      path: skillMeta.path,
      defaultPrompt: skillMeta.defaultPrompt,
    ),
  );
}

SlashCommand buildDollarApp(CodexAppMetadata appMeta) {
  return SlashCommand(
    command: '\$${appMeta.id}',
    description: appMeta.description,
    icon: Icons.apps_outlined,
    category: SlashCommandCategory.app,
    appInfo: CodexAppInfo(
      id: appMeta.id,
      name: appMeta.label,
      path: 'app://${appMeta.id}',
    ),
  );
}

SlashCommand buildAtPlugin(CodexPluginMetadata pluginMeta) {
  return SlashCommand(
    command: '@${pluginMeta.name}',
    description: pluginMeta.summary,
    icon: Icons.extension_outlined,
    category: SlashCommandCategory.plugin,
    pluginInfo: CodexPluginInfo(
      id: pluginMeta.id,
      name: pluginMeta.label,
      path: pluginMeta.path,
    ),
  );
}

// ---- Fallback (used before server provides slash_commands via system.init) ----
// Only includes commands known to work through the SDK query API.

const fallbackSlashCommands = [
  SlashCommand(
    command: '/compact',
    description: 'Compact conversation',
    icon: Icons.compress,
  ),
  SlashCommand(
    command: '/review',
    description: 'Code review',
    icon: Icons.rate_review_outlined,
  ),
  SlashCommand(
    command: '/context',
    description: 'Show context usage',
    icon: Icons.donut_large_outlined,
  ),
  SlashCommand(
    command: '/cost',
    description: 'Show cost summary',
    icon: Icons.attach_money,
  ),
];

/// Codex SDK does not expose supportedCommands(), so use a conservative
/// fallback set that is known to work in local sessions.
const fallbackCodexSlashCommands = [
  SlashCommand(
    command: '/plan',
    description: 'Switch to planning-oriented responses',
    icon: Icons.map_outlined,
  ),
  SlashCommand(
    command: '/skills',
    description: 'List available skills',
    icon: Icons.extension,
  ),
  SlashCommand(
    command: '/permissions',
    description: 'Show current runtime permissions',
    icon: Icons.lock_outline,
  ),
];

// ---- Sheet widget ----

class SlashCommandSheet extends StatelessWidget {
  final List<SlashCommand> commands;
  final void Function(SlashCommand command) onSelect;

  const SlashCommandSheet({
    super.key,
    required this.commands,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Group by category
    final builtin = commands
        .where((c) => c.category == SlashCommandCategory.builtin)
        .toList();
    final project = commands
        .where((c) => c.category == SlashCommandCategory.project)
        .toList();
    final skills = commands
        .where((c) => c.category == SlashCommandCategory.skill)
        .toList();
    final apps = commands
        .where((c) => c.category == SlashCommandCategory.app)
        .toList();
    final plugins = commands
        .where((c) => c.category == SlashCommandCategory.plugin)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
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
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Commands',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (project.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Project',
                      accentColor: Theme.of(context).colorScheme.secondary,
                    ),
                    for (final cmd in project)
                      _CommandTile(command: cmd, onSelect: onSelect),
                  ],
                  if (skills.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Skills',
                      accentColor: Theme.of(context).colorScheme.tertiary,
                    ),
                    for (final cmd in skills)
                      _CommandTile(command: cmd, onSelect: onSelect),
                  ],
                  if (apps.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Apps',
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                    for (final cmd in apps)
                      _CommandTile(command: cmd, onSelect: onSelect),
                  ],
                  if (plugins.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Plugins',
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                    for (final cmd in plugins)
                      _CommandTile(command: cmd, onSelect: onSelect),
                  ],
                  if (builtin.isNotEmpty) ...[
                    if (project.isNotEmpty ||
                        skills.isNotEmpty ||
                        apps.isNotEmpty ||
                        plugins.isNotEmpty)
                      const _SectionHeader(label: 'Built-in'),
                    for (final cmd in builtin)
                      _CommandTile(command: cmd, onSelect: onSelect),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color? accentColor;

  const _SectionHeader({required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor ?? appColors.subtleText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  final SlashCommand command;
  final void Function(SlashCommand command) onSelect;

  const _CommandTile({required this.command, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = switch (command.category) {
      SlashCommandCategory.project => colorScheme.secondary,
      SlashCommandCategory.skill => colorScheme.tertiary,
      SlashCommandCategory.app => colorScheme.primary,
      SlashCommandCategory.plugin => colorScheme.primary,
      SlashCommandCategory.builtin => null,
    };
    return ListTile(
      leading: Icon(command.icon, size: 22, color: iconColor),
      title: Row(
        children: [
          Text(
            command.command,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (command.category != SlashCommandCategory.builtin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: (iconColor ?? appColors.subtleText).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                command.category == SlashCommandCategory.project
                    ? 'project'
                    : command.category == SlashCommandCategory.app
                    ? 'app'
                    : command.category == SlashCommandCategory.plugin
                    ? 'plugin'
                    : 'skill',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: iconColor ?? appColors.subtleText,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(command.description, style: const TextStyle(fontSize: 13)),
      dense: true,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        onSelect(command);
      },
    );
  }
}

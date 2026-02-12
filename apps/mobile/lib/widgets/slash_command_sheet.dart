import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

// ---- Model ----

enum SlashCommandCategory { builtin, project, skill }

class SlashCommand {
  final String command;
  final String description;
  final IconData icon;
  final SlashCommandCategory category;

  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
    this.category = SlashCommandCategory.builtin,
  });
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
}) {
  final known = knownCommands[name];
  return SlashCommand(
    command: '/$name',
    description: known?.description ?? name,
    icon: known?.icon ?? Icons.terminal,
    category: category,
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

// ---- Sheet widget ----

class SlashCommandSheet extends StatelessWidget {
  final List<SlashCommand> commands;
  final void Function(String command) onSelect;

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
                    _sectionHeader(
                      'Project',
                      appColors,
                      Theme.of(context).colorScheme.secondary,
                    ),
                    for (final cmd in project)
                      _commandTile(context, cmd, appColors),
                  ],
                  if (skills.isNotEmpty) ...[
                    _sectionHeader(
                      'Skills',
                      appColors,
                      Theme.of(context).colorScheme.tertiary,
                    ),
                    for (final cmd in skills)
                      _commandTile(context, cmd, appColors),
                  ],
                  if (builtin.isNotEmpty) ...[
                    if (project.isNotEmpty || skills.isNotEmpty)
                      _sectionHeader('Built-in', appColors, null),
                    for (final cmd in builtin)
                      _commandTile(context, cmd, appColors),
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

  Widget _sectionHeader(String label, AppColors appColors, Color? accentColor) {
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

  Widget _commandTile(
    BuildContext context,
    SlashCommand cmd,
    AppColors appColors,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = switch (cmd.category) {
      SlashCommandCategory.project => colorScheme.secondary,
      SlashCommandCategory.skill => colorScheme.tertiary,
      SlashCommandCategory.builtin => null,
    };
    return ListTile(
      leading: Icon(cmd.icon, size: 22, color: iconColor),
      title: Row(
        children: [
          Text(
            cmd.command,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (cmd.category != SlashCommandCategory.builtin) ...[
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
                cmd.category == SlashCommandCategory.project
                    ? 'project'
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
      subtitle: Text(cmd.description, style: const TextStyle(fontSize: 13)),
      dense: true,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        onSelect(cmd.command);
      },
    );
  }
}

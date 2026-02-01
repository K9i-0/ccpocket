import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class SlashCommand {
  final String command;
  final String description;
  final IconData icon;

  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
  });
}

const _commands = [
  SlashCommand(command: '/compact', description: 'Compact conversation', icon: Icons.compress),
  SlashCommand(
    command: '/plan',
    description: 'Switch to Plan mode',
    icon: Icons.map_outlined,
  ),
  SlashCommand(
    command: '/clear',
    description: 'Clear conversation',
    icon: Icons.delete_outline,
  ),
  SlashCommand(
    command: '/help',
    description: 'Show help',
    icon: Icons.help_outline,
  ),
];

class SlashCommandSheet extends StatelessWidget {
  final void Function(String command) onSelect;

  const SlashCommandSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
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
          for (final cmd in _commands)
            ListTile(
              leading: Icon(cmd.icon, size: 22),
              title: Text(
                cmd.command,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                cmd.description,
                style: const TextStyle(fontSize: 13),
              ),
              dense: true,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                onSelect(cmd.command);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

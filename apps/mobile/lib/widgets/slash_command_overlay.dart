import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'slash_command_sheet.dart';

class SlashCommandOverlay extends StatelessWidget {
  final List<SlashCommand> filteredCommands;
  final void Function(String command) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandOverlay({
    super.key,
    required this.filteredCommands,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: cs.surfaceContainer,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant,
            width: 0.5,
          ),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filteredCommands.length,
          itemBuilder: (context, index) {
            final cmd = filteredCommands[index];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(cmd.command),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(cmd.icon, size: 18, color: appColors.subtleText),
                    const SizedBox(width: 10),
                    Text(
                      cmd.command,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cmd.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: appColors.subtleText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

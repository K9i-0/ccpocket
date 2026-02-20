import 'package:flutter/material.dart';

import '../../../models/machine.dart';
import 'machine_card.dart';

/// List of saved remote machines with status indicators.
class MachineList extends StatelessWidget {
  final List<MachineWithStatus> machines;
  final String? startingMachineId;
  final String? updatingMachineId;
  final ValueChanged<MachineWithStatus> onConnect;
  final ValueChanged<MachineWithStatus> onStart;
  final ValueChanged<MachineWithStatus> onEdit;
  final ValueChanged<MachineWithStatus> onDelete;
  final ValueChanged<MachineWithStatus>? onToggleFavorite;
  final ValueChanged<MachineWithStatus>? onUpdate;
  final ValueChanged<MachineWithStatus>? onStop;
  final VoidCallback onAddMachine;
  final VoidCallback? onRefresh;

  const MachineList({
    super.key,
    required this.machines,
    this.startingMachineId,
    this.updatingMachineId,
    required this.onConnect,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    this.onToggleFavorite,
    this.onUpdate,
    this.onStop,
    required this.onAddMachine,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.dns, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Machines',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh status',
                visualDensity: VisualDensity.compact,
              ),
            TextButton.icon(
              onPressed: onAddMachine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),

        if (machines.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bubble_chart_outlined,
                        color: colorScheme.outline,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'No saved machines.\nAdd one to quickly connect or remotely start the Bridge Server.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddMachine,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Machine'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ...machines.map(
            (m) => MachineCard(
              machineWithStatus: m,
              isStarting: startingMachineId == m.machine.id,
              isUpdating: updatingMachineId == m.machine.id,
              onConnect: () => onConnect(m),
              onStart: () => onStart(m),
              onEdit: () => onEdit(m),
              onDelete: () => onDelete(m),
              onToggleFavorite: onToggleFavorite != null
                  ? () => onToggleFavorite!(m)
                  : null,
              onUpdate: onUpdate != null ? () => onUpdate!(m) : null,
              onStop: onStop != null ? () => onStop!(m) : null,
            ),
          ),
        ],
      ],
    );
  }
}

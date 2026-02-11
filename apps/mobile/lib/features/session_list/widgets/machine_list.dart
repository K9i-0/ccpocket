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
            IconButton(
              onPressed: onAddMachine,
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add machine',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),

        if (machines.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No saved machines. Add one to quickly connect or remotely start Bridge Server.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
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

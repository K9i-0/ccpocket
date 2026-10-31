import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../state/chat_session_cubit.dart';

/// Shows the steer/queue choice for a message sent while the agent works.
Future<InputDelivery?> showInputDeliverySheet(
  BuildContext context, {
  required InputDelivery defaultDelivery,
}) {
  final l = AppLocalizations.of(context);
  final options = [defaultDelivery, defaultDelivery.other];
  return showModalBottomSheet<InputDelivery>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final delivery in options)
            ListTile(
              key: ValueKey('input_delivery_${delivery.value}_option'),
              leading: Icon(
                delivery == InputDelivery.steer
                    ? Icons.subdirectory_arrow_left
                    : Icons.schedule_send_outlined,
              ),
              title: Text(
                delivery == InputDelivery.steer ? l.sendAsSteer : l.sendAsQueue,
              ),
              subtitle: Text(
                delivery == InputDelivery.steer
                    ? l.inputDeliverySteerDescription
                    : l.inputDeliveryQueueDescription,
              ),
              trailing: delivery == defaultDelivery
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(sheetContext, delivery);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Queue panel bound to the current [ChatSessionCubit].
class SessionQueuedInputPanel extends StatelessWidget {
  const SessionQueuedInputPanel({
    super.key,
    required this.item,
    required this.inputController,
  });

  final QueuedInputItem item;
  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    final isOffline = ChatSessionCubit.isOfflineQueuedInput(item);
    final isDeliveryPending = ChatSessionCubit.isDeliveryPendingQueuedInput(
      item,
    );
    final cubit = context.read<ChatSessionCubit>();
    return QueuedInputPanel(
      item: item,
      isOfflinePending: isOffline,
      isDeliveryPending: isDeliveryPending,
      onSteer: isOffline || isDeliveryPending
          ? null
          : () => cubit.steerQueuedInput(item),
      onEdit: () => moveQueuedInputToComposer(
        inputController: inputController,
        item: item,
        cancelQueuedInput: () => cubit.cancelQueuedInput(item),
      ),
      onCancel: () => cubit.cancelQueuedInput(item),
    );
  }
}

@visibleForTesting
void moveQueuedInputToComposer({
  required TextEditingController inputController,
  required QueuedInputItem item,
  required VoidCallback cancelQueuedInput,
}) {
  cancelQueuedInput();
  inputController.value = TextEditingValue(
    text: item.text,
    selection: TextSelection.collapsed(offset: item.text.length),
  );
}

class QueuedInputPanel extends StatelessWidget {
  const QueuedInputPanel({
    super.key,
    required this.item,
    required this.onSteer,
    required this.onEdit,
    required this.onCancel,
    this.isOfflinePending = false,
    this.isDeliveryPending = false,
  });

  final QueuedInputItem item;
  final VoidCallback? onSteer;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool isOfflinePending;
  final bool isDeliveryPending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final imageLabel = item.imageCount > 0
        ? ' · ${l.queuedInputImageCount(item.imageCount)}'
        : '';
    final title = isOfflinePending
        ? '${l.queuedInputForReconnect}$imageLabel'
        : isDeliveryPending
        ? '${l.queuedInputPendingDelivery}$imageLabel'
        : '${l.queuedInputForNextTurn}$imageLabel';

    return Material(
      key: const ValueKey('codex_queue_panel'),
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.schedule, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDeliveryPending)
                IconButton(
                  key: const ValueKey('codex_queue_steer_button'),
                  tooltip: l.tooltipSteerQueuedMessage,
                  icon: const Icon(Icons.subdirectory_arrow_left, size: 20),
                  onPressed: onSteer,
                ),
              IconButton(
                key: const ValueKey('codex_queue_edit_button'),
                tooltip: l.tooltipMoveQueuedMessageToInput,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                key: const ValueKey('codex_queue_cancel_button'),
                tooltip: l.tooltipCancelQueuedMessage,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

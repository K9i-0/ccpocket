import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../chat_session/state/chat_session_cubit.dart';
import '../../chat_session/state/chat_session_state.dart';

void showCodexRecoverySheet(BuildContext context) {
  final cubit = context.read<ChatSessionCubit>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: BlocBuilder<ChatSessionCubit, ChatSessionState>(
        buildWhen: (before, after) => before.recovery != after.recovery,
        builder: (context, state) => CodexRecoveryPanel(
          recovery: state.recovery ?? const CodexRecoveryInfo(),
          onChanged: cubit.setCodexRecovery,
          onCancel: cubit.cancelCodexRecovery,
        ),
      ),
    ),
  );
}

class CodexRecoveryPanel extends StatelessWidget {
  final CodexRecoveryInfo recovery;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCancel;
  const CodexRecoveryPanel({
    super.key,
    required this.recovery,
    required this.onChanged,
    required this.onCancel,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('codex_recovery_toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic recovery'),
            subtitle: const Text('For this session only'),
            value: recovery.enabled,
            onChanged: onChanged,
          ),
          const Text(
            'After a usage limit, Bridge can continue this task even while your phone is disconnected. This may use more usage and repeat work. Up to 5 automatic attempts per manual message. Sending a message or stopping cancels the wait.',
          ),
          if (recovery.enabled) ...[
            const SizedBox(height: 12),
            CodexRecoveryStatus(recovery: recovery, onCancel: onCancel),
          ],
        ],
      ),
    ),
  );
}

class CodexRecoveryStatus extends StatelessWidget {
  final CodexRecoveryInfo recovery;
  final VoidCallback onCancel;
  final VoidCallback? onSettings;
  const CodexRecoveryStatus({
    super.key,
    required this.recovery,
    required this.onCancel,
    this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    final retryAt = recovery.retryAt?.toLocal();
    final time = retryAt == null
        ? null
        : '${MaterialLocalizations.of(context).formatShortDate(retryAt)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(retryAt))}';
    final label = switch (recovery.phase) {
      'waiting' =>
        time == null ? 'Waiting to recover' : 'Recovery scheduled: $time',
      'exhausted' => 'Automatic recovery limit reached',
      'blocked' => 'Automatic recovery needs attention',
      _ => 'Automatic recovery enabled',
    };
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label · ${recovery.attempts}/${recovery.maxAttempts} attempts used',
              key: const ValueKey('codex_recovery_status'),
            ),
            if (recovery.reason != null)
              Text(
                recovery.reason!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            Wrap(
              children: [
                if (recovery.phase == 'waiting')
                  TextButton(
                    key: const ValueKey('codex_recovery_cancel_button'),
                    onPressed: onCancel,
                    child: const Text('Cancel wait'),
                  ),
                if (onSettings != null)
                  TextButton(
                    key: const ValueKey('codex_recovery_settings_button'),
                    onPressed: onSettings,
                    child: const Text('Settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/commit_cubit.dart';
import '../state/commit_state.dart';

/// Shows the commit bottom sheet.
void showCommitBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<CommitCubit>(),
      child: const _CommitBottomSheetContent(),
    ),
  );
}

class _CommitBottomSheetContent extends StatefulWidget {
  const _CommitBottomSheetContent();

  @override
  State<_CommitBottomSheetContent> createState() =>
      _CommitBottomSheetContentState();
}

class _CommitBottomSheetContentState extends State<_CommitBottomSheetContent> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommitCubit, CommitState>(
      builder: (context, state) {
        final cubit = context.read<CommitCubit>();
        final cs = Theme.of(context).colorScheme;
        final isIdle = state.status == CommitStatus.idle;
        final isBusy = state.status == CommitStatus.committing ||
            state.status == CommitStatus.pushing ||
            state.status == CommitStatus.creatingPr;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Commit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Success state
              if (state.status == CommitStatus.success) ...[
                Icon(Icons.check_circle, color: cs.primary, size: 48),
                const SizedBox(height: 8),
                Text(
                  state.prUrl != null
                      ? 'PR created: ${state.prUrl}'
                      : state.commitHash != null
                          ? 'Committed: ${state.commitHash}'
                          : 'Success',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    cubit.reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ]

              // Error state
              else if (state.status == CommitStatus.error) ...[
                Icon(Icons.error_outline, color: cs.error, size: 48),
                const SizedBox(height: 8),
                Text(
                  state.error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: cubit.reset,
                  child: const Text('Try Again'),
                ),
              ]

              // Idle / busy state
              else ...[
                // Commit message input
                TextField(
                  key: const ValueKey('commit_message_field'),
                  controller: _controller,
                  enabled: !state.autoGenerate && isIdle,
                  onChanged: cubit.setMessage,
                  decoration: InputDecoration(
                    hintText: state.autoGenerate
                        ? 'Auto-generate with AI'
                        : 'Commit message',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 8),

                // Auto-generate toggle
                Row(
                  children: [
                    Switch(
                      key: const ValueKey('auto_generate_switch'),
                      value: state.autoGenerate,
                      onChanged: isIdle ? (_) => cubit.toggleAutoGenerate() : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-generate message',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress indicator
                if (isBusy) ...[
                  LinearProgressIndicator(
                    key: const ValueKey('commit_progress'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (state.status) {
                      CommitStatus.committing => 'Committing...',
                      CommitStatus.pushing => 'Pushing...',
                      CommitStatus.creatingPr => 'Creating PR...',
                      _ => '',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],

                // Action buttons
                if (isIdle) ...[
                  FilledButton.icon(
                    key: const ValueKey('commit_button_action'),
                    onPressed: _canCommit(state) ? cubit.commit : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Commit'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('commit_push_button'),
                    onPressed: _canCommit(state) ? cubit.commitAndPush : null,
                    icon: const Icon(Icons.upload),
                    label: const Text('Commit & Push'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('commit_pr_button'),
                    onPressed: _canCommit(state) ? cubit.commitAndCreatePr : null,
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Commit & Create PR'),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  bool _canCommit(CommitState state) {
    return state.autoGenerate || state.message.trim().isNotEmpty;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../widgets/bubbles/assistant_bubble.dart';
import '../../widgets/bubbles/user_bubble.dart';
import 'state/demo_cubit.dart';
import 'state/demo_state.dart';
import 'widgets/demo_diff.dart';

/// Public, offline sample experience; never creates or reads a real session.
class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => DemoCubit(), child: const _DemoPage());
}

class _DemoPage extends StatelessWidget {
  const _DemoPage();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.demoTitle),
        leading: IconButton(
          key: const ValueKey('demo_exit_button'),
          tooltip: l.demoExit,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('demo_restart_button'),
            tooltip: l.demoRestart,
            icon: const Icon(Icons.refresh),
            onPressed: context.read<DemoCubit>().restart,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(l.demoDisclaimer),
            ),
            Expanded(
              child: BlocBuilder<DemoCubit, DemoState>(
                builder: (context, state) => SingleChildScrollView(
                  key: ValueKey('demo_conversation_${state.generation}_list'),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DemoAssistant(text: l.demoWelcome),
                      if (state.phase == DemoPhase.ready)
                        _DemoComposer(key: ValueKey(state.generation))
                      else ...[
                        UserBubble(text: state.prompt),
                        _DemoAssistant(text: l.demoProposal),
                        if (state.phase == DemoPhase.approval)
                          const _DemoApproval(),
                        if (state.phase == DemoPhase.completed) ...[
                          _DemoAssistant(text: l.demoCompleted),
                          const DemoDiff(),
                          const _DemoFinish(),
                        ],
                        if (state.phase == DemoPhase.rejected) ...[
                          _DemoAssistant(text: l.demoRejected),
                          const _DemoFinish(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAssistant extends StatelessWidget {
  final String text;
  const _DemoAssistant({required this.text});

  @override
  Widget build(BuildContext context) => AssistantBubble(
    message: AssistantServerMessage(
      message: AssistantMessage(
        id: 'demo-$text',
        role: 'assistant',
        model: 'sample',
        content: [TextContent(text: text)],
      ),
    ),
  );
}

class _DemoComposer extends StatefulWidget {
  const _DemoComposer({super.key});

  @override
  State<_DemoComposer> createState() => _DemoComposerState();
}

class _DemoComposerState extends State<_DemoComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    FocusScope.of(context).unfocus();
    context.read<DemoCubit>().send(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('demo_suggestion_button'),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(l.demoSuggestion),
          onPressed: () => context.read<DemoCubit>().send(l.demoSuggestion),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('demo_message_input'),
          controller: _controller,
          maxLength: 1000,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l.demoInputHint,
            helperText: l.demoInputHelp,
            helperMaxLines: 3,
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('demo_send_button'),
          onPressed: _send,
          icon: const Icon(Icons.send),
          label: Text(l.demoSend),
        ),
      ],
    );
  }
}

class _DemoApproval extends StatelessWidget {
  const _DemoApproval();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.demoApprovalTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l.demoApprovalDetail),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('demo_reject_button'),
                  onPressed: context.read<DemoCubit>().reject,
                  child: Text(l.demoReject),
                ),
                FilledButton(
                  key: const ValueKey('demo_approve_button'),
                  onPressed: context.read<DemoCubit>().approve,
                  child: Text(l.demoApprove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoFinish extends StatelessWidget {
  const _DemoFinish();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.demoFinish),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('demo_connect_button'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.computer),
            label: Text(l.demoConnect),
          ),
          TextButton(
            key: const ValueKey('demo_try_again_button'),
            onPressed: context.read<DemoCubit>().restart,
            child: Text(l.demoRestart),
          ),
        ],
      ),
    );
  }
}

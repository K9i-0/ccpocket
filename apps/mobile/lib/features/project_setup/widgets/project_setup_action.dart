import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../state/project_setup_cubit.dart';

class ProjectSetupAction extends StatelessWidget {
  const ProjectSetupAction({
    super.key,
    required this.projectPath,
    required this.trust,
    this.onDone,
    this.sessionId,
  });
  final String projectPath;
  final bool trust;
  final VoidCallback? onDone;
  final String? sessionId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ProjectSetupCubit(context.read<BridgeService>()),
    child: _ProjectSetupActionBody(
      projectPath: projectPath,
      trust: trust,
      onDone: onDone,
      sessionId: sessionId,
    ),
  );
}

class _ProjectSetupActionBody extends StatelessWidget {
  const _ProjectSetupActionBody({
    required this.projectPath,
    required this.trust,
    this.onDone,
    this.sessionId,
  });
  final String projectPath;
  final bool trust;
  final VoidCallback? onDone;
  final String? sessionId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<ProjectSetupCubit, ProjectSetupState>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.result != null && state.error == null)
            Text(l.projectSetupDone)
          else
            TextButton.icon(
              key: ValueKey(
                trust ? 'trust_project_button' : 'initialize_git_button',
              ),
              icon: Icon(trust ? Icons.verified_user_outlined : Icons.add),
              label: Text(trust ? l.trustProject : l.initializeGit),
              onPressed: state.busy
                  ? null
                  : () async {
                      if (trust) {
                        final accepted = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l.trustProject),
                            content: Text(
                              '$projectPath\n\n${l.trustProjectHint}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(l.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(l.trustProject),
                              ),
                            ],
                          ),
                        );
                        if (accepted != true || !context.mounted) return;
                      }
                      final result = await context
                          .read<ProjectSetupCubit>()
                          .request({
                            'type': trust ? 'trust_project' : 'initialize_git',
                            'projectPath': projectPath,
                            if (sessionId != null) 'sessionId': sessionId,
                          }, updateHint: l.projectSetupUpdateHint);
                      if (result != null && context.mounted) onDone?.call();
                    },
            ),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

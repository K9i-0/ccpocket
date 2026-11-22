import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../router/app_router.dart';
import '../workspace/state/workspace_destination.dart';
import '../../router/session_stack_navigation.dart';
import '../../services/bridge_service.dart';
import 'state/session_link_cubit.dart';
import 'state/session_link_state.dart';

@RoutePage()
class SessionLinkScreen extends StatelessWidget {
  const SessionLinkScreen({
    super.key,
    required this.sessionId,
    this.provider = 'claude',
  });

  final String sessionId;
  final String provider;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionLinkCubit(
        bridge: context.read<BridgeService>(),
        sourceSessionId: sessionId,
        provider: provider,
      )..resolve(),
      child: _SessionLinkScreenBody(
        sourceSessionId: sessionId,
        provider: provider,
      ),
    );
  }
}

class _SessionLinkScreenBody extends StatelessWidget {
  const _SessionLinkScreenBody({
    required this.sourceSessionId,
    required this.provider,
  });

  final String sourceSessionId;
  final String provider;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionLinkCubit, SessionLinkState>(
      listenWhen: (_, state) => switch (state) {
        SessionLinkOpenLive() ||
        SessionLinkOpenResumed() ||
        SessionLinkOpenLegacy() ||
        SessionLinkUnavailable() => true,
        _ => false,
      },
      listener: (context, state) {
        switch (state) {
          case SessionLinkOpenLive(:final bridgeSessionId, :final provider):
            _openSession(
              context,
              sessionId: bridgeSessionId,
              provider: provider,
            );
          case SessionLinkOpenResumed(:final session, :final gitBranch):
            _openSession(
              context,
              sessionId: session.sessionId!,
              provider: session.provider ?? provider,
              projectPath: session.projectPath,
              workspace: session.workspace,
              worktreePath: session.worktreePath,
              gitBranch: session.worktreeBranch ?? gitBranch,
              permissionMode: session.permissionMode,
              sandboxMode: session.sandboxMode,
              approvalPolicy: session.approvalPolicy,
              approvalsReviewer: session.approvalsReviewer,
            );
          case SessionLinkOpenLegacy():
            _openSession(
              context,
              sessionId: sourceSessionId,
              provider: provider,
            );
          case SessionLinkUnavailable():
            _dismissAsUnavailable(context);
          default:
            return;
        }
      },
      builder: (context, state) {
        // An unavailable link leaves this screen, so it keeps showing progress
        // instead of flashing an error while the route goes away.
        return SessionLinkStatusView(
          resuming: state is SessionLinkResuming,
          overlay: context.router.root.stack.length > 1,
        );
      },
    );
  }

  /// Returns to the screen the link was opened from and reports the failure
  /// there, so the user has nothing to close.
  void _dismissAsUnavailable(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).sessionUnavailableDescription;
    final router = context.router.root;
    if (router.stack.length > 1) {
      router.removeRoute(context.routeData);
    } else {
      router.replaceAll([AdaptiveHomeRoute()]);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('session_link_unavailable_snackbar'),
          content: Text(message),
        ),
      );
  }

  void _openSession(
    BuildContext context, {
    required String sessionId,
    required String provider,
    String? projectPath,
    SessionWorkspaceInfo? workspace,
    String? gitBranch,
    String? worktreePath,
    String? permissionMode,
    String? sandboxMode,
    String? approvalPolicy,
    String? approvalsReviewer,
  }) {
    final resolvedProvider = Provider.fromValue(provider) ?? Provider.claude;
    final normalizedProvider = resolvedProvider.value;
    if (SessionStackNavigation.revealStackedSession(
      context.router,
      sessionId: sessionId,
      provider: normalizedProvider,
    )) {
      return;
    }
    final selection = WorkspaceSessionSelection(
      sessionId: sessionId,
      provider: resolvedProvider,
      projectPath: projectPath,
      workspace: workspace,
      gitBranch: gitBranch,
      worktreePath: worktreePath,
      permissionMode: permissionMode,
      sandboxMode: sandboxMode,
      approvalPolicy: approvalPolicy,
      approvalsReviewer: approvalsReviewer,
    );
    if (SessionStackNavigation.openWorkspaceSession(
      context.router,
      selection,
    )) {
      return;
    }
    context.router.replaceAll([AdaptiveHomeRoute(initialSession: selection)]);
  }
}

/// Progress shown while a linked session is found or resumed.
///
/// As an [overlay] it dims the screen underneath instead of replacing it; with
/// nothing underneath it fills the screen.
class SessionLinkStatusView extends StatelessWidget {
  const SessionLinkStatusView({
    super.key,
    required this.resuming,
    this.overlay = false,
  });

  final bool resuming;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: overlay
          ? colors.scrim.withValues(alpha: 0.32)
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Material(
              color: overlay ? colors.surfaceContainerHigh : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator.adaptive(
                      key: ValueKey('session_link_progress_indicator'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      resuming
                          ? l.resumingLinkedSession
                          : l.resolvingLinkedSession,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

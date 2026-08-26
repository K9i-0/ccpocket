import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../router/app_router.dart';
import '../../router/session_stack_navigation.dart';
import '../../services/bridge_service.dart';
import 'state/session_link_cubit.dart';
import 'state/session_link_state.dart';
import 'widgets/session_unavailable_view.dart';

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
        SessionLinkOpenLive() || SessionLinkOpenResumed() => true,
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
              worktreePath: session.worktreePath,
              gitBranch: session.worktreeBranch ?? gitBranch,
              permissionMode: session.permissionMode,
              sandboxMode: session.sandboxMode,
              approvalPolicy: session.approvalPolicy,
              approvalsReviewer: session.approvalsReviewer,
            );
          default:
            return;
        }
      },
      builder: (context, state) {
        if (state case SessionLinkOpenReadOnly(
          :final recentSession,
          :final ownership,
          :final failure,
        )) {
          return SessionReadOnlyHistoryView(
            bridge: context.read<BridgeService>(),
            session: recentSession,
            ownership: ownership,
            failure: failure,
            onRefresh: () => context.read<SessionLinkCubit>().refresh(),
            onResumeWhenIdle: () =>
                context.read<SessionLinkCubit>().resumeWhenIdle(),
            onOpenRecentSessions: () {
              context.router.replaceAll([AdaptiveHomeRoute()]);
            },
            onOpenRemoteGuidance: _openOfficialRemoteGuidance,
          );
        }
        final unavailable = state is SessionLinkUnavailable ? state : null;
        return SessionLinkStatusView(
          unavailable: unavailable != null,
          resuming: state is SessionLinkResuming,
          reason: unavailable?.reason,
          recoveryAction: unavailable?.recoveryAction,
          onOpenRecentSessions: () {
            context.router.replaceAll([AdaptiveHomeRoute()]);
          },
        );
      },
    );
  }

  void _openOfficialRemoteGuidance() {
    unawaited(
      launchUrl(
        Uri.parse(
          'https://help.openai.com/en/articles/11369540-codex-in-chatgpt',
        ),
        mode: LaunchMode.externalApplication,
      ),
    );
  }

  void _openSession(
    BuildContext context, {
    required String sessionId,
    required String provider,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    String? permissionMode,
    String? sandboxMode,
    String? approvalPolicy,
    String? approvalsReviewer,
  }) {
    final normalizedProvider = provider == Provider.codex.value
        ? Provider.codex.value
        : Provider.claude.value;
    if (SessionStackNavigation.revealStackedSession(
      context.router,
      sessionId: sessionId,
      provider: normalizedProvider,
    )) {
      return;
    }
    context.router.replace(
      _sessionRoute(
        sessionId: sessionId,
        provider: normalizedProvider,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        permissionMode: permissionMode,
        sandboxMode: sandboxMode,
        approvalPolicy: approvalPolicy,
        approvalsReviewer: approvalsReviewer,
      ),
    );
  }

  PageRouteInfo _sessionRoute({
    required String sessionId,
    required String provider,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    String? permissionMode,
    String? sandboxMode,
    String? approvalPolicy,
    String? approvalsReviewer,
  }) {
    if (provider == Provider.codex.value) {
      return CodexSessionRoute(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        initialPermissionMode: permissionMode,
        initialSandboxMode: sandboxMode,
        initialApprovalPolicy: approvalPolicy,
        initialApprovalsReviewer: approvalsReviewer,
      );
    }
    return ClaudeSessionRoute(
      sessionId: sessionId,
      projectPath: projectPath,
      gitBranch: gitBranch,
      worktreePath: worktreePath,
      initialPermissionMode: permissionMode,
      initialSandboxMode: sandboxMode,
    );
  }
}

class SessionLinkStatusView extends StatelessWidget {
  const SessionLinkStatusView({
    super.key,
    required this.unavailable,
    required this.resuming,
    required this.onOpenRecentSessions,
    this.readOnly = false,
    this.reason,
    this.recoveryAction,
    this.onRefresh,
    this.onResumeWhenIdle,
    this.onOpenRemoteGuidance,
  });

  final bool unavailable;
  final bool resuming;
  final VoidCallback onOpenRecentSessions;
  final bool readOnly;
  final String? reason;
  final String? recoveryAction;
  final VoidCallback? onRefresh;
  final VoidCallback? onResumeWhenIdle;
  final VoidCallback? onOpenRemoteGuidance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: unavailable
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SessionUnavailableView(
                    onOpenRecentSessions: onOpenRecentSessions,
                  ),
                  if (reason != null)
                    Text(
                      _humanizeProtocolValue(reason!),
                      key: const ValueKey('session_failure_reason'),
                    ),
                  if (recoveryAction != null)
                    Text(
                      _humanizeProtocolValue(recoveryAction!),
                      key: const ValueKey('session_recovery_action'),
                    ),
                ],
              )
            : readOnly
            ? _ReadOnlyStatus(
                reason: reason,
                onRefresh: onRefresh,
                onResumeWhenIdle: onResumeWhenIdle,
                onOpenRemoteGuidance: onOpenRemoteGuidance,
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
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
    );
  }
}

class _ReadOnlyStatus extends StatelessWidget {
  const _ReadOnlyStatus({
    required this.reason,
    required this.onRefresh,
    required this.onResumeWhenIdle,
    required this.onOpenRemoteGuidance,
  });

  final String? reason;
  final VoidCallback? onRefresh;
  final VoidCallback? onResumeWhenIdle;
  final VoidCallback? onOpenRemoteGuidance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_outlined, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Read-only history',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _humanizeProtocolValue(reason ?? 'external_owner_unknown'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('refresh_session_button'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('resume_when_idle_button'),
                onPressed: onResumeWhenIdle,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Resume when idle'),
              ),
              TextButton.icon(
                key: const ValueKey('official_remote_guidance_button'),
                onPressed: onOpenRemoteGuidance,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Official Remote guidance'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SessionReadOnlyHistoryView extends StatefulWidget {
  const SessionReadOnlyHistoryView({
    super.key,
    required this.bridge,
    required this.session,
    required this.ownership,
    required this.onRefresh,
    required this.onResumeWhenIdle,
    required this.onOpenRecentSessions,
    required this.onOpenRemoteGuidance,
    this.failure,
  });

  final BridgeService bridge;
  final RecentSession session;
  final SessionOwnershipProjection ownership;
  final ErrorMessage? failure;
  final VoidCallback onRefresh;
  final VoidCallback onResumeWhenIdle;
  final VoidCallback onOpenRecentSessions;
  final VoidCallback onOpenRemoteGuidance;

  @override
  State<SessionReadOnlyHistoryView> createState() =>
      _SessionReadOnlyHistoryViewState();
}

class _SessionReadOnlyHistoryViewState
    extends State<SessionReadOnlyHistoryView> {
  StreamSubscription<ServerMessage>? _subscription;
  List<PastMessage> _messages = const [];
  ErrorMessage? _failure;

  @override
  void initState() {
    super.initState();
    _failure = widget.failure;
    _subscription = widget.bridge.messages.listen(_handleMessage);
    _requestHistory();
  }

  void _requestHistory() {
    final providerThreadId = widget.ownership.providerThreadId;
    if (providerThreadId == null || providerThreadId.isEmpty) return;
    widget.bridge.send(ClientMessage.getHistory(providerThreadId));
  }

  void _handleMessage(ServerMessage message) {
    if (!mounted) return;
    if (message case PastHistoryMessage(:final claudeSessionId, :final messages)
        when claudeSessionId == widget.ownership.providerThreadId) {
      setState(() {
        _messages = messages;
        _failure = null;
      });
    } else if (message case ErrorMessage(:final providerThreadId)
        when providerThreadId == widget.ownership.providerThreadId) {
      setState(() => _failure = message);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _failure?.errorCode ?? widget.ownership.readOnlyReason?.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name ?? widget.session.projectName),
        leading: IconButton(
          onPressed: widget.onOpenRecentSessions,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ReadOnlyStatus(
              reason: reason,
              onRefresh: () {
                _requestHistory();
                widget.onRefresh();
              },
              onResumeWhenIdle: widget.onResumeWhenIdle,
              onOpenRemoteGuidance: widget.onOpenRemoteGuidance,
            ),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('No history available'))
                  : ListView.builder(
                      key: const ValueKey('read_only_history_list'),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ListTile(
                          leading: Icon(
                            message.role == 'user'
                                ? Icons.person_outline
                                : Icons.smart_toy_outlined,
                          ),
                          title: Text(message.role),
                          subtitle: Text(_pastMessageText(message)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _pastMessageText(PastMessage message) {
  final text = message.content
      .whereType<TextContent>()
      .map((content) => content.text)
      .where((content) => content.trim().isNotEmpty)
      .join('\n');
  if (text.isNotEmpty) return text;
  return message.toolName ?? message.toolResultContent ?? '(non-text event)';
}

String _humanizeProtocolValue(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    )
    .replaceAll('_', ' ')
    .trim();

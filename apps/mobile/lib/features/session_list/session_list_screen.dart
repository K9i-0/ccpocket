import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/platform_helper.dart';

import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../widgets/new_session_sheet.dart';
import 'state/session_list_cubit.dart';
import 'widgets/home_content.dart';

// ---- Testable helpers (top-level) ----

/// Project name → session count, preserving first-seen order.
Map<String, int> projectCounts(List<RecentSession> sessions) {
  final counts = <String, int>{};
  for (final s in sessions) {
    counts[s.projectName] = (counts[s.projectName] ?? 0) + 1;
  }
  return counts;
}

/// Filter sessions by project name (null = no filter).
List<RecentSession> filterByProject(
  List<RecentSession> sessions,
  String? projectName,
) {
  if (projectName == null) return sessions;
  return sessions.where((s) => s.projectName == projectName).toList();
}

/// Unique project paths in first-seen order.
List<({String path, String name})> recentProjects(
  List<RecentSession> sessions,
) {
  final seen = <String>{};
  final result = <({String path, String name})>[];
  for (final s in sessions) {
    if (seen.add(s.projectPath)) {
      result.add((path: s.projectPath, name: s.projectName));
    }
  }
  return result;
}

/// Shorten absolute path by replacing $HOME with ~.
String shortenPath(String path) {
  final home = getHomeDirectory();
  if (home.isNotEmpty && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// Filter sessions by text query (matches firstPrompt, lastPrompt and summary).
List<RecentSession> filterByQuery(List<RecentSession> sessions, String query) {
  if (query.isEmpty) return sessions;
  final q = query.toLowerCase();
  return sessions.where((s) {
    return s.firstPrompt.toLowerCase().contains(q) ||
        (s.lastPrompt?.toLowerCase().contains(q) ?? false) ||
        (s.summary?.toLowerCase().contains(q) ?? false);
  }).toList();
}

// ---- Screen ----

/// Session list (home) screen. Only shown when connected to a Bridge server
/// (protected by [ConnectionGuard]).
@RoutePage()
class SessionListScreen extends StatefulWidget {
  /// Pre-populated sessions for UI testing (skips bridge connection).
  final List<RecentSession>? debugRecentSessions;

  const SessionListScreen({super.key, this.debugRecentSessions});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  // Cache for resume navigation
  String? _pendingResumeProjectPath;
  String? _pendingResumeGitBranch;

  // Flag: already navigated to chat for pending session creation
  bool _pendingNavigation = false;

  // Notifier for session_created that fires before chat screen listens.
  // When session_created arrives while _pendingNavigation is true,
  // we store the message here so the chat screen can replay it.
  final _pendingSessionCreated = ValueNotifier<SystemMessage?>(null);

  // Only subscription that remains: session_created navigation
  StreamSubscription<ServerMessage>? _messageSub;

  static const _prefKeySessionStartDefaults = 'session_start_defaults_v1';

  @override
  void initState() {
    super.initState();
    // session_created navigation (the only manual subscription)
    final bridge = context.read<BridgeService>();
    _messageSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        bridge.requestSessionList();
        if (msg.sessionId != null) {
          if (_pendingNavigation) {
            // Chat screen may not have its listener yet — store for replay.
            _pendingNavigation = false;
            _pendingSessionCreated.value = msg;
          } else {
            _navigateToChat(
              msg.sessionId!,
              projectPath: msg.projectPath ?? _pendingResumeProjectPath,
              gitBranch: _pendingResumeGitBranch,
              worktreePath: msg.worktreePath,
              provider: msg.provider == 'codex' ? Provider.codex : null,
            );
          }
          _pendingResumeProjectPath = null;
          _pendingResumeGitBranch = null;
        }
      }
    });
    // Refresh session list on first load
    context.read<SessionListCubit>().refresh();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  void _disconnect() {
    context.read<BridgeService>().disconnect();
    context.read<SessionListCubit>().resetFilters();
  }

  void _refresh() {
    context.read<SessionListCubit>().refresh();
  }

  void _showNewSessionDialog() async {
    final defaults = await _loadSessionStartDefaults();
    if (!mounted) return;
    final result = await _openNewSessionSheet(initialParams: defaults);
    if (result == null || !mounted) return;
    await _saveSessionStartDefaults(result);
    if (!mounted) return;
    _startNewSession(result);
  }

  Future<NewSessionParams?> _openNewSessionSheet({
    NewSessionParams? initialParams,
    bool lockProvider = false,
  }) async {
    final sessions =
        widget.debugRecentSessions ??
        context.read<SessionListCubit>().state.sessions;
    final history = context.read<ProjectHistoryCubit>().state;
    final bridge = context.read<BridgeService>();
    return showNewSessionSheet(
      context: context,
      recentProjects: recentProjects(sessions),
      projectHistory: history,
      bridge: bridge,
      initialParams: initialParams,
      lockProvider: lockProvider,
    );
  }

  void _startNewSession(NewSessionParams result) {
    final bridge = context.read<BridgeService>();
    _pendingResumeProjectPath = result.projectPath;
    _pendingResumeGitBranch = result.worktreeBranch;
    bridge.send(
      ClientMessage.start(
        result.projectPath,
        permissionMode: result.provider == Provider.claude
            ? result.permissionMode.value
            : null,
        effort: result.provider == Provider.claude
            ? result.claudeEffort?.value
            : null,
        maxTurns: result.provider == Provider.claude
            ? result.claudeMaxTurns
            : null,
        maxBudgetUsd: result.provider == Provider.claude
            ? result.claudeMaxBudgetUsd
            : null,
        fallbackModel: result.provider == Provider.claude
            ? result.claudeFallbackModel
            : null,
        // --fork-session applies to resume/continue only.
        forkSession: null,
        persistSession: result.provider == Provider.claude
            ? result.claudePersistSession
            : null,
        useWorktree: result.useWorktree ? true : null,
        worktreeBranch: result.worktreeBranch,
        existingWorktreePath: result.existingWorktreePath,
        provider: result.provider.value,
        model: result.provider == Provider.claude
            ? result.claudeModel
            : result.model,
        approvalPolicy: result.approvalPolicy?.value,
        sandboxMode: result.sandboxMode?.value,
        modelReasoningEffort: result.modelReasoningEffort?.value,
        networkAccessEnabled: result.networkAccessEnabled,
        webSearchMode: result.webSearchMode?.value,
      ),
    );
    // Navigate immediately to chat with pending state
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    _pendingNavigation = true;
    _navigateToChat(
      pendingId,
      projectPath: result.projectPath,
      gitBranch: result.worktreeBranch,
      worktreePath: result.existingWorktreePath,
      isPending: true,
      provider: result.provider,
    );
  }

  Future<NewSessionParams?> _loadSessionStartDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeySessionStartDefaults);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return sessionStartDefaultsFromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSessionStartDefaults(NewSessionParams params) async {
    final prefs = await SharedPreferences.getInstance();
    final json = sessionStartDefaultsToJson(params);
    await prefs.setString(_prefKeySessionStartDefaults, jsonEncode(json));
  }

  NewSessionParams _newSessionFromRecentSession(RecentSession session) {
    final provider = session.provider == Provider.codex.value
        ? Provider.codex
        : Provider.claude;
    final existingWorktreePath = session.resumeCwd;
    final hasExistingWorktree =
        existingWorktreePath != null && existingWorktreePath.isNotEmpty;
    return NewSessionParams(
      projectPath: session.projectPath,
      provider: provider,
      permissionMode: PermissionMode.acceptEdits,
      useWorktree: hasExistingWorktree,
      worktreeBranch: session.gitBranch.isNotEmpty ? session.gitBranch : null,
      existingWorktreePath: hasExistingWorktree ? existingWorktreePath : null,
      model: session.codexModel,
      sandboxMode: sandboxModeFromRaw(session.codexSandboxMode),
      approvalPolicy: approvalPolicyFromRaw(session.codexApprovalPolicy),
      modelReasoningEffort: reasoningEffortFromRaw(
        session.codexModelReasoningEffort,
      ),
      networkAccessEnabled: session.codexNetworkAccessEnabled,
      webSearchMode: webSearchModeFromRaw(session.codexWebSearchMode),
    );
  }

  void _showRecentSessionActions(RecentSession session) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start New with Same Settings'),
              onTap: () => Navigator.pop(ctx, 'start_same'),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Edit Settings Then Start'),
              onTap: () => Navigator.pop(ctx, 'start_edit'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'start_same') {
      final params = _newSessionFromRecentSession(session);
      _startNewSession(params);
      return;
    }

    if (action == 'start_edit') {
      final initialParams = _newSessionFromRecentSession(session);
      final edited = await _openNewSessionSheet(
        initialParams: initialParams,
        lockProvider: true,
      );
      if (edited == null || !mounted) return;
      await _saveSessionStartDefaults(edited);
      if (!mounted) return;
      _startNewSession(edited);
    }
  }

  void _navigateToChat(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    Provider? provider,
  }) {
    // Reset the notifier for this navigation.
    if (isPending) {
      _pendingSessionCreated.value = null;
    }
    final pendingNotifier = isPending ? _pendingSessionCreated : null;
    final Future<Object?> nav;
    if (provider == Provider.codex) {
      nav = context.router.push(
        CodexSessionRoute(
          sessionId: sessionId,
          projectPath: projectPath,
          gitBranch: gitBranch,
          worktreePath: worktreePath,
          isPending: isPending,
          pendingSessionCreated: pendingNotifier,
        ),
      );
    } else {
      nav = context.router.push(
        ClaudeCodeSessionRoute(
          sessionId: sessionId,
          projectPath: projectPath,
          gitBranch: gitBranch,
          worktreePath: worktreePath,
          isPending: isPending,
          pendingSessionCreated: pendingNotifier,
        ),
      );
    }
    nav.then((_) {
      if (!mounted) return;
      final isConnected =
          context.read<ConnectionCubit>().state ==
          BridgeConnectionState.connected;
      if (isConnected) {
        _refresh();
      }
    });
  }

  void _resumeSession(RecentSession session) async {
    final resumeProjectPath = session.resumeCwd ?? session.projectPath;
    _pendingResumeProjectPath = resumeProjectPath;
    _pendingResumeGitBranch = session.gitBranch;

    final isCodex = session.provider == Provider.codex.value;
    NewSessionParams? claudeDefaults;
    if (!isCodex) {
      final defaults = await _loadSessionStartDefaults();
      if (!mounted) return;
      if (defaults?.provider == Provider.claude) {
        claudeDefaults = defaults;
      }
    }

    context.read<BridgeService>().resumeSession(
      session.sessionId,
      resumeProjectPath,
      permissionMode: !isCodex ? claudeDefaults?.permissionMode.value : null,
      effort: !isCodex ? claudeDefaults?.claudeEffort?.value : null,
      maxTurns: !isCodex ? claudeDefaults?.claudeMaxTurns : null,
      maxBudgetUsd: !isCodex ? claudeDefaults?.claudeMaxBudgetUsd : null,
      fallbackModel: !isCodex ? claudeDefaults?.claudeFallbackModel : null,
      forkSession: !isCodex ? claudeDefaults?.claudeForkSession : null,
      persistSession: !isCodex ? claudeDefaults?.claudePersistSession : null,
      provider: session.provider,
      approvalPolicy: session.codexApprovalPolicy,
      sandboxMode: session.codexSandboxMode,
      model: isCodex ? session.codexModel : claudeDefaults?.claudeModel,
      modelReasoningEffort: session.codexModelReasoningEffort,
      networkAccessEnabled: session.codexNetworkAccessEnabled,
      webSearchMode: session.codexWebSearchMode,
    );
  }

  void _stopSession(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Session'),
        content: const Text(
          'Stop this session? The Claude process will be terminated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              context.read<BridgeService>().stopSession(sessionId);
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slState = context.watch<SessionListCubit>().state;
    final connectionState = widget.debugRecentSessions != null
        ? BridgeConnectionState.connected
        : context.watch<ConnectionCubit>().state;
    final sessions = context.watch<ActiveSessionsCubit>().state;
    final recentSessionsList = widget.debugRecentSessions ?? slState.sessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CC Pocket'),
        actions: [
          IconButton(
            key: const ValueKey('settings_button'),
            icon: const Icon(Icons.settings),
            onPressed: () => context.router.push(const SettingsRoute()),
            tooltip: 'Settings',
          ),
          if (kDebugMode)
            IconButton(
              key: const ValueKey('mock_preview_button'),
              icon: const Icon(Icons.science),
              onPressed: () => context.router.push(const MockPreviewRoute()),
              tooltip: 'Mock Preview',
            ),
          IconButton(
            key: const ValueKey('gallery_button'),
            icon: const Icon(Icons.collections),
            onPressed: () => context.router.push(GalleryRoute()),
            tooltip: 'Gallery',
          ),
          IconButton(
            key: const ValueKey('disconnect_button'),
            icon: const Icon(Icons.link_off),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: HomeContent(
          connectionState: connectionState,
          sessions: sessions,
          recentSessions: recentSessionsList,
          accumulatedProjectPaths: slState.accumulatedProjectPaths,
          selectedProject: slState.selectedProject,
          searchQuery: slState.searchQuery,
          isLoadingMore: slState.isLoadingMore,
          hasMoreSessions: slState.hasMore,
          currentProjectFilter: context
              .read<BridgeService>()
              .currentProjectFilter,
          onNewSession: _showNewSessionDialog,
          onTapRunning:
              (
                sessionId, {
                String? projectPath,
                String? gitBranch,
                String? worktreePath,
                String? provider,
              }) => _navigateToChat(
                sessionId,
                projectPath: projectPath,
                gitBranch: gitBranch,
                worktreePath: worktreePath,
                provider: provider == 'codex' ? Provider.codex : null,
              ),
          onStopSession: _stopSession,
          onResumeSession: _resumeSession,
          onLongPressRecentSession: _showRecentSessionActions,
          onSelectProject: (path) =>
              context.read<SessionListCubit>().selectProject(path),
          onLoadMore: () => context.read<SessionListCubit>().loadMore(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('new_session_fab'),
        onPressed: _showNewSessionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

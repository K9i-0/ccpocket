import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/platform_helper.dart';

import '../../models/messages.dart';
import '../../models/machine.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../providers/unseen_sessions_cubit.dart';
import '../../providers/server_discovery_cubit.dart';
import '../../router/app_router.dart';
import '../../services/app_update_service.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/server_discovery_service.dart';
import '../../widgets/new_session_sheet.dart';
import '../../widgets/rename_session_dialog.dart';
import '../settings/state/settings_cubit.dart';
import 'state/session_list_cubit.dart';
import 'widgets/connect_form.dart';
import 'widgets/home_content.dart';
import 'widgets/machine_edit_sheet.dart';
import 'widgets/session_list_app_bar.dart';

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

/// Quote a shell argument so it can be pasted safely into POSIX shells.
String shellQuote(String value) {
  return "'${value.replaceAll("'", r"'\''")}'";
}

/// Build a provider-specific CLI resume command for handoff to another machine.
/// Uses resumeCwd (worktree path) when available so the CLI finds the session
/// in the correct project slug directory.
String buildResumeCommand(RecentSession session) {
  final cwd = (session.resumeCwd?.isNotEmpty ?? false)
      ? session.resumeCwd!
      : session.projectPath;
  final provider = session.provider == Provider.codex.value
      ? Provider.codex
      : Provider.claude;

  String resumeCommand;
  if (provider == Provider.codex) {
    resumeCommand = 'codex resume ${shellQuote(session.sessionId)}';
  } else {
    final buf = StringBuffer(
      'claude --resume ${shellQuote(session.sessionId)}',
    );
    final pm = session.permissionMode;
    if (pm == PermissionMode.bypassPermissions.value) {
      buf.write(' --dangerously-skip-permissions');
    } else if (pm == PermissionMode.acceptEdits.value) {
      buf.write(' --permission-mode acceptEdits');
    } else if (pm == PermissionMode.plan.value) {
      buf.write(' --permission-mode plan');
    }
    resumeCommand = buf.toString();
  }

  return 'cd ${shellQuote(cwd)} && $resumeCommand';
}

/// Filter sessions by text query (matches name, firstPrompt, lastPrompt and summary).
List<RecentSession> filterByQuery(List<RecentSession> sessions, String query) {
  if (query.isEmpty) return sessions;
  final q = query.toLowerCase();
  return sessions.where((s) {
    return (s.name?.toLowerCase().contains(q) ?? false) ||
        s.firstPrompt.toLowerCase().contains(q) ||
        (s.lastPrompt?.toLowerCase().contains(q) ?? false) ||
        (s.summary?.toLowerCase().contains(q) ?? false);
  }).toList();
}

// ---- Screen ----

@RoutePage()
class SessionListScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;

  /// Pre-populated sessions for UI testing (skips bridge connection).
  final List<RecentSession>? debugRecentSessions;

  const SessionListScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen>
    with WidgetsBindingObserver {
  bool _isAutoConnecting = false;

  /// Key to access HomeContent state for programmatic search (Cmd+K).
  final _homeContentKey = GlobalKey<HomeContentState>();

  // Debug screen: 5 consecutive taps on title
  int _debugTapCount = 0;
  DateTime? _lastDebugTapTime;

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
  final Set<String> _archivingSessionIds = <String>{};

  // macOS app update
  AppUpdateInfo? _appUpdateInfo;

  // Unseen session tracking
  final _unseenCubit = UnseenSessionsCubit();
  StreamSubscription<List<SessionInfo>>? _activeSessionsSub;

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeySessionStartDefaults = 'session_start_defaults_v1';
  static const _prefKeyClaudeSessionSettingsPrefix = 'claude_session_settings_';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // session_created navigation (the only manual subscription)
    final bridge = context.read<BridgeService>();
    _messageSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        bridge.requestSessionList();
        // Clear-context recreation and session restarts (permission mode /
        // sandbox mode / rewind) are handled inside the active chat screen.
        // Navigating from the hidden session list stacks a second chat route.
        if (msg.clearContext || msg.sourceSessionId != null) {
          return;
        }
        if (msg.sessionId != null) {
          // Mark the newly created session as seen so it doesn't
          // appear as unseen when the user returns to the list.
          _unseenCubit.markSeen(msg.sessionId!);
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
              provider: Provider.values
                  .where((p) => p.value == msg.provider)
                  .firstOrNull,
              permissionMode: msg.permissionMode,
              sandboxMode: msg.sandboxMode,
            );
          }
          _pendingResumeProjectPath = null;
          _pendingResumeGitBranch = null;
        }
        return;
      }

      if (msg is ArchiveResultMessage) {
        if (_archivingSessionIds.contains(msg.sessionId) && mounted) {
          setState(() => _archivingSessionIds.remove(msg.sessionId));
        }
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        final text = msg.success
            ? l.sessionArchived
            : (msg.error?.isNotEmpty == true
                  ? l.archiveFailedWithError(msg.error!)
                  : l.archiveFailed);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    });
    widget.deepLinkNotifier?.addListener(_onDeepLink);
    _loadPreferencesAndAutoConnect();

    // Feed active session updates to the unseen tracker.
    final activeCubit = context.read<ActiveSessionsCubit>();
    _unseenCubit.updateSessions(activeCubit.state);
    _activeSessionsSub = activeCubit.stream.listen(_unseenCubit.updateSessions);
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    final update = await AppUpdateService.instance.checkForUpdate();
    if (update != null &&
        !AppUpdateService.instance.isDismissedByUser &&
        mounted) {
      setState(() => _appUpdateInfo = update);
    }
  }

  void _dismissAppUpdate() {
    AppUpdateService.instance.dismissUpdate();
    setState(() => _appUpdateInfo = null);
  }

  void _onDeepLink() {
    final params = widget.deepLinkNotifier?.value;
    if (params == null) return;
    // Reset notifier to avoid re-triggering
    widget.deepLinkNotifier?.value = null;
    _connectWithParams(params.serverUrl, params.token);
  }

  Future<void> _loadPreferencesAndAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final url = prefs.getString(_prefKeyUrl);
    if (url != null && url.isNotEmpty) {
      setState(() => _isAutoConnecting = true);
      // Try to get API key from SecureStorage via MachineManagerCubit.
      String? apiKey;
      try {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          final cubit = context.read<MachineManagerCubit?>();
          final machine = cubit?.findByHostPort(
            uri.host,
            uri.hasPort ? uri.port : 8765,
          );
          if (machine != null) {
            apiKey = await cubit?.getApiKey(machine.id);
          }
        }
      } catch (_) {
        // Ignore — autoConnect falls back to legacy SharedPreferences.
      }
      if (!mounted) return;
      final attempted = await context.read<BridgeService>().autoConnect(
        apiKey: apiKey,
      );
      if (!attempted) {
        setState(() => _isAutoConnecting = false);
      }
    }
  }

  Future<void> _connectWithParams(String rawUrl, String? apiKey) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    // Allow shorthand: just IP or host:port without ws:// prefix
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }

    // Health check before connecting
    final health = await BridgeService.checkHealth(url);
    if (health == null && mounted) {
      final shouldConnect = await _showSetupGuide(url);
      if (shouldConnect != true) return;
    }

    if (!mounted) return;
    // Auto-save to Machines on successful health check (or user choosing to connect)
    final trimmedApiKey = apiKey?.trim() ?? '';
    final machineManagerCubit = context.read<MachineManagerCubit?>();
    if (machineManagerCubit != null) {
      // Parse host and port from URL
      final uri = Uri.tryParse(
        url.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://'),
      );
      if (uri != null) {
        await machineManagerCubit.recordConnection(
          host: uri.host,
          port: uri.port != 0 ? uri.port : 8765,
          apiKey: trimmedApiKey.isNotEmpty ? trimmedApiKey : null,
        );
      }
    }

    if (!mounted) return;
    var connectUrl = url;
    if (trimmedApiKey.isNotEmpty) {
      final sep = connectUrl.contains('?') ? '&' : '?';
      connectUrl = '$connectUrl${sep}token=$trimmedApiKey';
    }
    final bridge = context.read<BridgeService>();
    bridge.connect(connectUrl);
    bridge.savePreferences(url);
  }

  /// Show setup guide when health check fails. Returns true if user wants
  /// to try connecting anyway.
  Future<bool?> _showSetupGuide(String url) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(ctx).colorScheme.primary,
              ),
              SizedBox(width: 8),
              Expanded(child: Text(l.serverUnreachable)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.serverUnreachableBody,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  url,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.setupSteps,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _SetupStep(
                  number: '1',
                  title: l.setupStep1Title,
                  command: l.setupStep1Command,
                ),
                _SetupStep(
                  number: '2',
                  title: l.setupStep2Title,
                  command: l.setupStep2Command,
                ),
                const SizedBox(height: 12),
                Text(
                  l.setupNetworkHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.connectAnyway),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanQrCode() async {
    final result = await context.router.push<ConnectionParams>(
      const QrScanRoute(),
    );
    if (result != null && mounted) {
      _connectWithParams(result.serverUrl, result.token);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final bridge = context.read<BridgeService>();
      bridge.ensureConnected();
      if (bridge.isConnected) {
        bridge.requestSessionList();
        bridge.requestRecentSessions(projectPath: bridge.currentProjectFilter);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deepLinkNotifier?.removeListener(_onDeepLink);
    _messageSub?.cancel();
    _activeSessionsSub?.cancel();
    _unseenCubit.close();
    super.dispose();
  }

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastDebugTapTime != null &&
        now.difference(_lastDebugTapTime!).inMilliseconds > 3000) {
      _debugTapCount = 0;
    }
    _lastDebugTapTime = now;
    _debugTapCount++;
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      context.router.push(const DebugRoute());
    }
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
    final visibleTabs = context.read<SettingsCubit>().state.newSessionTabs;
    return showNewSessionSheet(
      context: context,
      recentProjects: recentProjects(sessions),
      projectHistory: history,
      bridge: bridge,
      initialParams: initialParams,
      lockProvider: lockProvider,
      visibleTabs: visibleTabs,
    );
  }

  void _startNewSession(NewSessionParams result) {
    final bridge = context.read<BridgeService>();
    _pendingResumeProjectPath = result.projectPath;
    _pendingResumeGitBranch = result.worktreeBranch;
    bridge.send(
      ClientMessage.start(
        result.projectPath,
        permissionMode: result.permissionMode.value,
        executionMode: result.executionMode.value,
        planMode: result.planMode,
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
      permissionMode: result.permissionMode.value,
      sandboxMode: result.sandboxMode?.value,
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

  // ---- Per-session Claude settings persistence ----

  static Future<void> saveClaudeSessionSettings(
    String sessionId,
    Map<String, dynamic> settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // Merge with existing settings to preserve fields not being updated.
    final existing = await loadClaudeSessionSettings(sessionId);
    final merged = <String, dynamic>{
      if (existing != null) ...existing,
      ...settings,
    };
    await prefs.setString(
      '$_prefKeyClaudeSessionSettingsPrefix$sessionId',
      jsonEncode(merged),
    );
  }

  static Future<Map<String, dynamic>?> loadClaudeSessionSettings(
    String sessionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '$_prefKeyClaudeSessionSettingsPrefix$sessionId',
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Build a settings map from NewSessionParams (Claude fields only).
  static Map<String, dynamic> _claudeSettingsFromParams(
    NewSessionParams params,
  ) {
    return <String, dynamic>{
      'permissionMode': params.permissionMode.value,
      'executionMode': params.executionMode.value,
      'planMode': params.planMode,
      if (params.sandboxMode != null) 'sandboxMode': params.sandboxMode!.value,
      if (params.claudeModel != null) 'claudeModel': params.claudeModel,
      if (params.claudeEffort != null)
        'claudeEffort': params.claudeEffort!.value,
      if (params.claudeFallbackModel != null)
        'claudeFallbackModel': params.claudeFallbackModel,
      if (params.claudeForkSession != null)
        'claudeForkSession': params.claudeForkSession,
      if (params.claudePersistSession != null)
        'claudePersistSession': params.claudePersistSession,
    };
  }

  Future<NewSessionParams> _newSessionFromRecentSession(
    RecentSession session,
  ) async {
    final provider = session.provider == Provider.codex.value
        ? Provider.codex
        : Provider.claude;
    final existingWorktreePath = session.resumeCwd;
    final hasExistingWorktree =
        existingWorktreePath != null && existingWorktreePath.isNotEmpty;

    // Load per-session Claude settings (saved from previous runs).
    final sessionSettings = provider == Provider.claude
        ? await loadClaudeSessionSettings(session.sessionId)
        : null;

    return NewSessionParams(
      projectPath: session.projectPath,
      provider: provider,
      executionMode: deriveExecutionMode(
        provider: provider.value,
        executionMode: sessionSettings?['executionMode'] as String?,
        permissionMode: sessionSettings?['permissionMode'] as String?,
        approvalPolicy: session.codexApprovalPolicy,
      ),
      planMode: derivePlanMode(
        planMode: sessionSettings?['planMode'] as bool?,
        permissionMode: sessionSettings?['permissionMode'] as String?,
      ),
      useWorktree: hasExistingWorktree,
      worktreeBranch: session.gitBranch.isNotEmpty ? session.gitBranch : null,
      existingWorktreePath: hasExistingWorktree ? existingWorktreePath : null,
      model: session.codexModel,
      sandboxMode: provider == Provider.codex
          ? sandboxModeFromRaw(session.codexSandboxMode)
          : sandboxModeFromRaw(sessionSettings?['sandboxMode'] as String?),
      modelReasoningEffort: reasoningEffortFromRaw(
        session.codexModelReasoningEffort,
      ),
      networkAccessEnabled: session.codexNetworkAccessEnabled,
      webSearchMode: webSearchModeFromRaw(session.codexWebSearchMode),
      claudeModel: sessionSettings?['claudeModel'] as String?,
      claudeEffort: claudeEffortFromRaw(
        sessionSettings?['claudeEffort'] as String?,
      ),
      claudeFallbackModel: sessionSettings?['claudeFallbackModel'] as String?,
      claudeForkSession: sessionSettings?['claudeForkSession'] as bool?,
      claudePersistSession: sessionSettings?['claudePersistSession'] as bool?,
    );
  }

  void _showRunningSessionActions(SessionInfo session) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(l.rename),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.stop_circle_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.stopSession),
              onTap: () => Navigator.pop(ctx, 'stop'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'rename') {
      final newName = await showRenameSessionDialog(
        context,
        currentName: session.name,
      );
      if (newName == null || !mounted) return;
      context.read<BridgeService>().renameSession(
        sessionId: session.id,
        name: newName.isEmpty ? null : newName,
      );
      // Running session list will auto-update via broadcastSessionList
      return;
    }

    if (action == 'stop') {
      context.read<BridgeService>().stopSession(session.id);
    }
  }

  void _showRecentSessionActions(RecentSession session) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(l.rename),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l.startNewWithSameSettings),
              onTap: () => Navigator.pop(ctx, 'start_same'),
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: Text(l.copyResumeCommand),
              subtitle: Text(l.copyResumeCommandSubtitle),
              onTap: () => Navigator.pop(ctx, 'copy_resume_command'),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l.editSettingsThenStart),
              onTap: () => Navigator.pop(ctx, 'start_edit'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.archive_outlined,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                l.archive,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'rename') {
      final newName = await showRenameSessionDialog(
        context,
        currentName: session.name,
      );
      if (newName == null || !mounted) return;
      final effectiveName = newName.isEmpty ? null : newName;
      // Optimistically update the local state for instant UI feedback
      context.read<SessionListCubit>().updateSessionName(
        session.sessionId,
        effectiveName,
      );
      context.read<BridgeService>().renameSession(
        sessionId: session.sessionId,
        name: effectiveName,
        provider: session.provider,
        providerSessionId: session.sessionId,
        projectPath: session.projectPath,
      );
      // Also refresh from server to confirm persistence
      context.read<BridgeService>().requestRecentSessions();
      return;
    }

    if (action == 'start_same') {
      final params = await _newSessionFromRecentSession(session);
      if (!mounted) return;
      // Don't save as defaults — these are session-specific settings from a
      // recent session, not user-chosen defaults for future sessions.
      _startNewSession(params);
      return;
    }

    if (action == 'copy_resume_command') {
      await Clipboard.setData(ClipboardData(text: buildResumeCommand(session)));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.resumeCommandCopied)));
      return;
    }

    if (action == 'start_edit') {
      final initialParams = await _newSessionFromRecentSession(session);
      if (!mounted) return;
      final edited = await _openNewSessionSheet(
        initialParams: initialParams,
        lockProvider: true,
      );
      if (edited == null || !mounted) return;
      await _saveSessionStartDefaults(edited);
      if (!mounted) return;
      _resumeSessionWithParams(session, edited);
      return;
    }

    if (action == 'archive') {
      _archiveSession(session);
    }
  }

  void _archiveSession(RecentSession session) {
    if (_archivingSessionIds.contains(session.sessionId)) return;
    setState(() => _archivingSessionIds.add(session.sessionId));
    context.read<BridgeService>().archiveSession(
      sessionId: session.sessionId,
      provider: session.provider ?? 'claude',
      projectPath: session.projectPath,
    );
  }

  void _navigateToChat(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    Provider? provider,
    String? permissionMode,
    String? sandboxMode,
  }) {
    // Mark session as seen when navigating into it.
    _unseenCubit.markSeen(sessionId);
    // Reset the notifier for this navigation.
    if (isPending) {
      _pendingSessionCreated.value = null;
    }
    final pendingNotifier = isPending ? _pendingSessionCreated : null;
    final PageRouteInfo route = switch (provider) {
      Provider.codex => CodexSessionRoute(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        isPending: isPending,
        initialSandboxMode: sandboxMode,
        initialPermissionMode: permissionMode,
        pendingSessionCreated: pendingNotifier,
      ),
      _ => ClaudeSessionRoute(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        isPending: isPending,
        initialPermissionMode: permissionMode,
        initialSandboxMode: sandboxMode,
        pendingSessionCreated: pendingNotifier,
      ),
    };
    context.router.push(route).then((_) {
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

    // For Claude sessions, prefer per-session settings over global defaults.
    Map<String, dynamic>? sessionSettings;
    NewSessionParams? claudeDefaults;
    if (!isCodex) {
      sessionSettings = await loadClaudeSessionSettings(session.sessionId);
      final defaults = await _loadSessionStartDefaults();
      if (!mounted) return;
      if (defaults?.provider == Provider.claude) {
        claudeDefaults = defaults;
      }
    }

    // Resolve each setting: per-session > global defaults > null
    final sandboxMode =
        sessionSettings?['sandboxMode'] as String? ??
        claudeDefaults?.sandboxMode?.value;
    final permissionMode =
        sessionSettings?['permissionMode'] as String? ??
        claudeDefaults?.permissionMode.value;
    final effort =
        sessionSettings?['claudeEffort'] as String? ??
        claudeDefaults?.claudeEffort?.value;
    final claudeModel =
        sessionSettings?['claudeModel'] as String? ??
        claudeDefaults?.claudeModel;
    final fallbackModel =
        sessionSettings?['claudeFallbackModel'] as String? ??
        claudeDefaults?.claudeFallbackModel;
    final forkSession =
        sessionSettings?['claudeForkSession'] as bool? ??
        claudeDefaults?.claudeForkSession;
    final persistSession =
        sessionSettings?['claudePersistSession'] as bool? ??
        claudeDefaults?.claudePersistSession;
    final codexModel = sanitizeCodexModelName(session.codexModel);

    context.read<BridgeService>().resumeSession(
      session.sessionId,
      resumeProjectPath,
      permissionMode: isCodex
          ? (session.codexApprovalPolicy == 'never'
                ? 'bypassPermissions'
                : 'acceptEdits')
          : permissionMode,
      executionMode: isCodex
          ? deriveExecutionMode(
              provider: Provider.codex.value,
              executionMode: session.executionMode,
              permissionMode: session.permissionMode,
              approvalPolicy: session.codexApprovalPolicy,
            ).value
          : deriveExecutionMode(
              provider: Provider.claude.value,
              executionMode: sessionSettings?['executionMode'] as String?,
              permissionMode: permissionMode,
            ).value,
      planMode: isCodex
          ? session.planMode
          : derivePlanMode(
              planMode: sessionSettings?['planMode'] as bool?,
              permissionMode: permissionMode,
            ),
      effort: !isCodex ? effort : null,
      maxTurns: !isCodex ? claudeDefaults?.claudeMaxTurns : null,
      maxBudgetUsd: !isCodex ? claudeDefaults?.claudeMaxBudgetUsd : null,
      fallbackModel: !isCodex ? fallbackModel : null,
      forkSession: !isCodex ? forkSession : null,
      persistSession: !isCodex ? persistSession : null,
      provider: session.provider,
      sandboxMode: isCodex ? session.codexSandboxMode : sandboxMode,
      model: isCodex ? codexModel : claudeModel,
      modelReasoningEffort: session.codexModelReasoningEffort,
      networkAccessEnabled: session.codexNetworkAccessEnabled,
      webSearchMode: session.codexWebSearchMode,
    );

    // Persist settings for this session (so the next resume uses them too).
    if (!isCodex) {
      final derivedExecutionMode = deriveExecutionMode(
        provider: Provider.claude.value,
        executionMode: sessionSettings?['executionMode'] as String?,
        permissionMode: permissionMode,
      ).value;
      final derivedPlanMode = derivePlanMode(
        planMode: sessionSettings?['planMode'] as bool?,
        permissionMode: permissionMode,
      );
      final settings = <String, dynamic>{
        'permissionMode': ?permissionMode,
        'executionMode': derivedExecutionMode,
        'planMode': derivedPlanMode,
        'sandboxMode': ?sandboxMode,
        'claudeEffort': ?effort,
        'claudeModel': ?claudeModel,
        'claudeFallbackModel': ?fallbackModel,
        'claudeForkSession': ?forkSession,
        'claudePersistSession': ?persistSession,
      };
      if (settings.isNotEmpty) {
        unawaited(saveClaudeSessionSettings(session.sessionId, settings));
      }
    }
  }

  /// Resume session with user-edited settings (from "Edit settings then start")
  void _resumeSessionWithParams(
    RecentSession session,
    NewSessionParams edited,
  ) {
    final resumeProjectPath = session.resumeCwd ?? session.projectPath;
    _pendingResumeProjectPath = resumeProjectPath;
    _pendingResumeGitBranch = session.gitBranch;

    final isCodex = edited.provider == Provider.codex;
    context.read<BridgeService>().resumeSession(
      session.sessionId,
      resumeProjectPath,
      permissionMode: edited.permissionMode.value,
      executionMode: edited.executionMode.value,
      planMode: edited.planMode,
      effort: !isCodex ? edited.claudeEffort?.value : null,
      maxTurns: !isCodex ? edited.claudeMaxTurns : null,
      maxBudgetUsd: !isCodex ? edited.claudeMaxBudgetUsd : null,
      fallbackModel: !isCodex ? edited.claudeFallbackModel : null,
      forkSession: !isCodex ? edited.claudeForkSession : null,
      persistSession: !isCodex ? edited.claudePersistSession : null,
      provider: session.provider,
      sandboxMode: edited.sandboxMode?.value,
      model: isCodex ? edited.model : edited.claudeModel,
      modelReasoningEffort: isCodex ? edited.modelReasoningEffort?.value : null,
      networkAccessEnabled: isCodex ? edited.networkAccessEnabled : null,
      webSearchMode: isCodex ? edited.webSearchMode?.value : null,
    );

    // Persist per-session Claude settings for future resumes.
    if (!isCodex) {
      unawaited(
        saveClaudeSessionSettings(
          session.sessionId,
          _claudeSettingsFromParams(edited),
        ),
      );
    }
  }

  void _stopSession(String sessionId) {
    context.read<BridgeService>().stopSession(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    // Read state from cubits
    final slState = context.watch<SessionListCubit>().state;
    final connectionState = widget.debugRecentSessions != null
        ? BridgeConnectionState.connected
        : context.watch<ConnectionCubit>().state;
    final sessions = context.watch<ActiveSessionsCubit>().state;
    final recentSessionsList = widget.debugRecentSessions ?? slState.sessions;
    final discoveredServers = context.watch<ServerDiscoveryCubit>().state;

    final isConnected = connectionState == BridgeConnectionState.connected;
    final showConnectedUI =
        isConnected || connectionState == BridgeConnectionState.reconnecting;

    final l = AppLocalizations.of(context);

    // Try to get MachineManagerCubit if available
    final machineManagerCubit = context.watch<MachineManagerCubit?>();
    final machineState = machineManagerCubit?.state;

    return BlocProvider<UnseenSessionsCubit>.value(
      value: _unseenCubit,
      child: BlocBuilder<UnseenSessionsCubit, Set<String>>(
        builder: (context, unseenSessionIds) =>
            BlocListener<ConnectionCubit, BridgeConnectionState>(
              listener: (context, nextState) {
                // Clear auto-connecting spinner once we get any connection state update
                if (_isAutoConnecting) {
                  setState(() => _isAutoConnecting = false);
                }
                if (nextState == BridgeConnectionState.connected) {
                  context.read<SessionListCubit>().refresh();
                }
              },
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  // Cmd+N: New Session
                  const SingleActivator(
                    LogicalKeyboardKey.keyN,
                    meta: true,
                  ): () {
                    if (showConnectedUI) _showNewSessionDialog();
                  },
                  // Cmd+K: Focus search
                  const SingleActivator(
                    LogicalKeyboardKey.keyK,
                    meta: true,
                  ): () {
                    _homeContentKey.currentState?.openSearch();
                  },
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    appBar: showConnectedUI && !_isAutoConnecting
                        ? null
                        : AppBar(
                            title: GestureDetector(
                              onTap: _onTitleTap,
                              child: Text(l.appTitle),
                            ),
                            actions: [
                              IconButton(
                                key: const ValueKey('settings_button'),
                                icon: Badge(
                                  isLabelVisible:
                                      AppUpdateService.instance.cachedUpdate !=
                                      null,
                                  smallSize: 8,
                                  child: const Icon(Icons.settings),
                                ),
                                onPressed: () =>
                                    context.router.push(const SettingsRoute()),
                                tooltip: l.settings,
                              ),
                            ],
                          ),
                    body: _isAutoConnecting
                        ? const Center(child: CircularProgressIndicator())
                        : showConnectedUI
                        ? NestedScrollView(
                            headerSliverBuilder:
                                (context, innerBoxIsScrolled) => [
                                  SessionListSliverAppBar(
                                    onTitleTap: _onTitleTap,
                                    onDisconnect: _disconnect,
                                    forceElevated: innerBoxIsScrolled,
                                  ),
                                ],
                            body: RefreshIndicator(
                              onRefresh: () async => _refresh(),
                              child: HomeContent(
                                key: _homeContentKey,
                                connectionState: connectionState,
                                bridgeVersion: context
                                    .read<BridgeService>()
                                    .bridgeVersion,
                                sessions: sessions,
                                recentSessions: recentSessionsList,
                                accumulatedProjectPaths:
                                    slState.accumulatedProjectPaths,
                                searchQuery: slState.searchQuery,
                                isLoadingMore: slState.isLoadingMore,
                                isInitialLoading: slState.isInitialLoading,
                                hasMoreSessions: slState.hasMore,
                                archivingSessionIds: _archivingSessionIds,
                                unseenSessionIds: unseenSessionIds,
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
                                      String? permissionMode,
                                      String? sandboxMode,
                                    }) => _navigateToChat(
                                      sessionId,
                                      projectPath: projectPath,
                                      gitBranch: gitBranch,
                                      worktreePath: worktreePath,
                                      provider: provider == 'codex'
                                          ? Provider.codex
                                          : null,
                                      permissionMode: permissionMode,
                                      sandboxMode: sandboxMode,
                                    ),
                                onStopSession: _stopSession,
                                onApprovePermission:
                                    (
                                      sessionId,
                                      toolUseId, {
                                      Map<String, dynamic>? updatedInput,
                                      bool clearContext = false,
                                    }) {
                                      final bridge = context
                                          .read<BridgeService>();
                                      bridge.send(
                                        ClientMessage.approve(
                                          toolUseId,
                                          sessionId: sessionId,
                                          updatedInput: updatedInput,
                                          clearContext: clearContext,
                                        ),
                                      );
                                      bridge.clearSessionPermission(sessionId);
                                    },
                                onApproveAlways: (sessionId, toolUseId) {
                                  final bridge = context.read<BridgeService>();
                                  bridge.send(
                                    ClientMessage.approveAlways(
                                      toolUseId,
                                      sessionId: sessionId,
                                    ),
                                  );
                                  bridge.clearSessionPermission(sessionId);
                                },
                                onRejectPermission:
                                    (sessionId, toolUseId, {message}) {
                                      final bridge = context
                                          .read<BridgeService>();
                                      bridge.send(
                                        ClientMessage.reject(
                                          toolUseId,
                                          message: message,
                                          sessionId: sessionId,
                                        ),
                                      );
                                      bridge.clearSessionPermission(sessionId);
                                    },
                                onAnswerQuestion:
                                    (sessionId, toolUseId, result) {
                                      final bridge = context
                                          .read<BridgeService>();
                                      bridge.send(
                                        ClientMessage.answer(
                                          toolUseId,
                                          result,
                                          sessionId: sessionId,
                                        ),
                                      );
                                      bridge.clearSessionPermission(sessionId);
                                    },
                                onResumeSession: _resumeSession,
                                onLongPressRecentSession:
                                    _showRecentSessionActions,
                                onArchiveSession: _archiveSession,
                                onLongPressRunningSession:
                                    _showRunningSessionActions,
                                onSelectProject: (path) => context
                                    .read<SessionListCubit>()
                                    .selectProject(path),
                                onLoadMore: () =>
                                    context.read<SessionListCubit>().loadMore(),
                                providerFilter: slState.providerFilter,
                                namedOnly: slState.namedOnly,
                                onToggleProvider: () => context
                                    .read<SessionListCubit>()
                                    .toggleProviderFilter(),
                                onToggleNamed: () => context
                                    .read<SessionListCubit>()
                                    .toggleNamedOnly(),
                                appUpdateInfo: _appUpdateInfo,
                                onDismissAppUpdate: _dismissAppUpdate,
                              ),
                            ),
                          )
                        : connectionState == BridgeConnectionState.connecting
                        ? const Center(child: CircularProgressIndicator())
                        : _ConnectFormWidget(
                            discoveredServers: discoveredServers,
                            machines: machineState?.machines ?? [],
                            startingMachineId: machineState?.startingMachineId,
                            updatingMachineId: machineState?.updatingMachineId,
                            onScanQrCode: _scanQrCode,
                            onViewSetupGuide: () =>
                                context.router.push(const SetupGuideRoute()),
                            onConnectToDiscovered: _connectToDiscovered,
                            onConnectToMachine: _connectToMachine,
                            onStartMachine: _startMachine,
                            onEditMachine: _editMachine,
                            onDeleteMachine: _deleteMachine,
                            onToggleFavorite: _toggleFavorite,
                            onUpdateMachine: _updateMachine,
                            onStopMachine: _stopMachine,
                            onAddMachine: _addMachine,
                            onRefreshMachines: () =>
                                machineManagerCubit?.refreshAll(),
                          ),
                    floatingActionButton:
                        showConnectedUI &&
                            MediaQuery.of(context).viewInsets.bottom == 0
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FloatingActionButton.extended(
                              key: const ValueKey('new_session_fab'),
                              onPressed: _showNewSessionDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('New'),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _connectToDiscovered(DiscoveredServer server) {
    if (server.authRequired) {
      // Open MachineEditSheet pre-filled with discovered server info
      _addMachineFromDiscovered(server);
      return;
    }
    _connectWithParams(server.wsUrl, null);
  }

  void _addMachineFromDiscovered(DiscoveredServer server) {
    final cubit = context.read<MachineManagerCubit>();
    final uri = Uri.tryParse(
      server.wsUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://'),
    );
    final host = uri?.host ?? server.name;
    final port = uri?.port ?? 8765;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MachineEditSheet(
        machine: Machine(id: '', host: host, port: port, name: server.name),
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          final newMachine = cubit.createNewMachine(
            name: machine.name,
            host: machine.host,
            port: machine.port,
          );
          await cubit.addMachine(
            newMachine.copyWith(
              sshEnabled: machine.sshEnabled,
              sshUsername: machine.sshUsername,
              sshPort: machine.sshPort,
              sshAuthType: machine.sshAuthType,
              isFavorite: true,
            ),
            apiKey: apiKey,
            sshPassword: sshPassword,
            sshPrivateKey: sshPrivateKey,
          );
        },
        onSaveAndConnect: (machine, apiKey) {
          _connectWithParams('ws://${machine.host}:${machine.port}', apiKey);
        },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }

  // ---- Machine Management ----

  void _connectToMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final wsUrl = await cubit.buildWsUrl(m.machine.id);
    final apiKey = await cubit.getApiKey(m.machine.id);

    // Record connection to update lastConnected
    await cubit.recordConnection(
      host: m.machine.host,
      port: m.machine.port,
      apiKey: apiKey,
    );

    if (!mounted) return;
    final bridge = context.read<BridgeService>();
    bridge.connect(wsUrl);
    bridge.savePreferences(m.machine.wsUrl);
  }

  void _toggleFavorite(MachineWithStatus m) {
    context.read<MachineManagerCubit>().toggleFavorite(m.machine.id);
  }

  void _updateMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final l = AppLocalizations.of(context);

    // Check if password is saved
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    // If no saved password, prompt for it
    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return; // User cancelled
    }

    final success = await cubit.updateBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bridgeServerUpdated)));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? l.failedToUpdateServer)));
    }
  }

  void _startMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final l = AppLocalizations.of(context);

    // Check if password is saved
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    // If no saved password, prompt for it
    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return; // User cancelled
    }

    final success = await cubit.startBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bridgeServerStarted)));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? l.failedToStartServer)));
    }
  }

  void _stopMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final l = AppLocalizations.of(context);

    // Check if password is saved
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    // If no saved password, prompt for it
    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return; // User cancelled
    }

    final success = await cubit.stopBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bridgeServerStopped)));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? l.failedToStopServer)));
    }
  }

  Future<String?> _promptForPassword(String machineName) async {
    final controller = TextEditingController();
    final l = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.sshPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.sshPasswordPrompt(machineName)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.password,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.connect),
          ),
        ],
      ),
    );
  }

  void _editMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final apiKey = await cubit.getApiKey(m.machine.id);
    final sshPassword = await cubit.getSshPassword(m.machine.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MachineEditSheet(
        machine: m.machine,
        existingApiKey: apiKey,
        existingSshPassword: sshPassword,
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          await cubit.updateMachine(
            machine,
            apiKey: apiKey,
            sshPassword: sshPassword,
            sshPrivateKey: sshPrivateKey,
          );
        },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }

  void _deleteMachine(MachineWithStatus m) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteMachine),
        content: Text(l.deleteMachineConfirm(m.machine.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<MachineManagerCubit>().deleteMachine(m.machine.id);
    }
  }

  void _addMachine() {
    final cubit = context.read<MachineManagerCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MachineEditSheet(
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          final newMachine = cubit.createNewMachine(
            name: machine.name,
            host: machine.host,
            port: machine.port,
          );
          await cubit.addMachine(
            newMachine.copyWith(
              sshEnabled: machine.sshEnabled,
              sshUsername: machine.sshUsername,
              sshPort: machine.sshPort,
              sshAuthType: machine.sshAuthType,
              isFavorite: true, // New manually added machines are favorites
            ),
            apiKey: apiKey,
            sshPassword: sshPassword,
            sshPrivateKey: sshPrivateKey,
          );
        },
        onSaveAndConnect: (machine, apiKey) {
          _connectWithParams('ws://${machine.host}:${machine.port}', apiKey);
        },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String title;
  final String command;

  const _SetupStep({
    required this.number,
    required this.title,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: cs.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectFormWidget extends StatelessWidget {
  final List<DiscoveredServer> discoveredServers;
  final List<MachineWithStatus> machines;
  final String? startingMachineId;
  final String? updatingMachineId;
  final VoidCallback onScanQrCode;
  final VoidCallback onViewSetupGuide;
  final ValueChanged<DiscoveredServer> onConnectToDiscovered;
  final ValueChanged<MachineWithStatus> onConnectToMachine;
  final ValueChanged<MachineWithStatus> onStartMachine;
  final ValueChanged<MachineWithStatus> onEditMachine;
  final ValueChanged<MachineWithStatus> onDeleteMachine;
  final ValueChanged<MachineWithStatus> onToggleFavorite;
  final ValueChanged<MachineWithStatus> onUpdateMachine;
  final ValueChanged<MachineWithStatus> onStopMachine;
  final VoidCallback onAddMachine;
  final VoidCallback? onRefreshMachines;

  const _ConnectFormWidget({
    required this.discoveredServers,
    required this.machines,
    this.startingMachineId,
    this.updatingMachineId,
    required this.onScanQrCode,
    required this.onViewSetupGuide,
    required this.onConnectToDiscovered,
    required this.onConnectToMachine,
    required this.onStartMachine,
    required this.onEditMachine,
    required this.onDeleteMachine,
    required this.onToggleFavorite,
    required this.onUpdateMachine,
    required this.onStopMachine,
    required this.onAddMachine,
    this.onRefreshMachines,
  });

  @override
  Widget build(BuildContext context) {
    return ConnectForm(
      discoveredServers: discoveredServers,
      onScanQrCode: onScanQrCode,
      onViewSetupGuide: onViewSetupGuide,
      onConnectToDiscovered: onConnectToDiscovered,
      // Machine management
      machines: machines,
      startingMachineId: startingMachineId,
      updatingMachineId: updatingMachineId,
      onConnectToMachine: onConnectToMachine,
      onStartMachine: onStartMachine,
      onEditMachine: onEditMachine,
      onDeleteMachine: onDeleteMachine,
      onToggleFavorite: onToggleFavorite,
      onUpdateMachine: onUpdateMachine,
      onStopMachine: onStopMachine,
      onAddMachine: onAddMachine,
      onRefreshMachines: onRefreshMachines,
    );
  }
}

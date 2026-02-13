import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/platform_helper.dart';

import '../../models/messages.dart';
import '../../models/machine.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../providers/server_discovery_cubit.dart';
import '../../screens/mock_preview_screen.dart';
import '../../screens/qr_scan_screen.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/server_discovery_service.dart';
import '../../widgets/new_session_sheet.dart';
import '../chat/chat_screen.dart';
import '../chat_codex/codex_chat_screen.dart';
import '../gallery/gallery_screen.dart';
import '../settings/settings_screen.dart';
import 'state/session_list_cubit.dart';
import 'widgets/connect_form.dart';
import 'widgets/home_content.dart';
import 'widgets/machine_edit_sheet.dart';

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

/// Filter sessions by text query (matches firstPrompt and summary).
List<RecentSession> filterByQuery(List<RecentSession> sessions, String query) {
  if (query.isEmpty) return sessions;
  final q = query.toLowerCase();
  return sessions.where((s) {
    return s.firstPrompt.toLowerCase().contains(q) ||
        (s.summary?.toLowerCase().contains(q) ?? false);
  }).toList();
}

// ---- Screen ----

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

class _SessionListScreenState extends State<SessionListScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isAutoConnecting = false;

  // Cache for resume navigation
  String? _pendingResumeProjectPath;
  String? _pendingResumeGitBranch;

  // Flag: already navigated to chat for pending session creation
  bool _pendingNavigation = false;

  // Only subscription that remains: session_created navigation
  StreamSubscription<ServerMessage>? _messageSub;

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeyApiKey = 'bridge_api_key';

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
            // Already navigated to chat screen; it will pick up session_created
            _pendingNavigation = false;
          } else {
            _navigateToChat(
              msg.sessionId!,
              projectPath: msg.projectPath ?? _pendingResumeProjectPath,
              gitBranch: _pendingResumeGitBranch,
              worktreePath: msg.worktreePath,
            );
          }
          _pendingResumeProjectPath = null;
          _pendingResumeGitBranch = null;
        }
      }
    });
    widget.deepLinkNotifier?.addListener(_onDeepLink);
    _loadPreferencesAndAutoConnect();
  }

  void _onDeepLink() {
    final params = widget.deepLinkNotifier?.value;
    if (params == null) return;
    // Reset notifier to avoid re-triggering
    widget.deepLinkNotifier?.value = null;
    _urlController.text = params.serverUrl;
    if (params.token != null) {
      _apiKeyController.text = params.token!;
    }
    _connect();
  }

  Future<void> _loadPreferencesAndAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final url = prefs.getString(_prefKeyUrl);
    final apiKey = prefs.getString(_prefKeyApiKey);
    if (url != null && url.isNotEmpty) {
      _urlController.text = url;
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKeyController.text = apiKey;
    }
    if (url != null && url.isNotEmpty) {
      setState(() => _isAutoConnecting = true);
      final attempted = await context.read<BridgeService>().autoConnect();
      if (!attempted) {
        setState(() => _isAutoConnecting = false);
      }
    }
  }

  Future<void> _connect() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    // Allow shorthand: just IP or host:port without ws:// prefix
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
      _urlController.text = url;
    }

    // Health check before connecting
    final health = await BridgeService.checkHealth(url);
    if (health == null && mounted) {
      final shouldConnect = await _showSetupGuide(url);
      if (shouldConnect != true) return;
    }

    if (!mounted) return;
    // Auto-save to Machines on successful health check (or user choosing to connect)
    final apiKey = _apiKeyController.text.trim();
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
          apiKey: apiKey.isNotEmpty ? apiKey : null,
        );
      }
    }

    if (!mounted) return;
    var connectUrl = url;
    if (apiKey.isNotEmpty) {
      final sep = connectUrl.contains('?') ? '&' : '?';
      connectUrl = '$connectUrl${sep}token=$apiKey';
    }
    final bridge = context.read<BridgeService>();
    bridge.connect(connectUrl);
    bridge.savePreferences(
      _urlController.text.trim(),
      _apiKeyController.text.trim(),
    );
  }

  /// Show setup guide when health check fails. Returns true if user wants
  /// to try connecting anyway.
  Future<bool?> _showSetupGuide(String url) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(child: Text('Server Unreachable')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not reach the Bridge server at:',
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
                'Setup Steps:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _setupStep(
                ctx,
                '1',
                'Install and build the Bridge server',
                'cd packages/bridge && npm install && npm run bridge:build',
              ),
              _setupStep(ctx, '2', 'Start the server', 'npm run bridge'),
              _setupStep(
                ctx,
                '3',
                'For persistent startup, register as service',
                'npm run setup',
              ),
              const SizedBox(height: 12),
              Text(
                'Make sure both devices are on the same network (or use Tailscale).',
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connect Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _setupStep(
    BuildContext ctx,
    String number,
    String title,
    String command,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<ConnectionParams>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result != null && mounted) {
      _urlController.text = result.serverUrl;
      if (result.token != null) {
        _apiKeyController.text = result.token!;
      }
      _connect();
    }
  }

  @override
  void dispose() {
    widget.deepLinkNotifier?.removeListener(_onDeepLink);
    _messageSub?.cancel();
    _urlController.dispose();
    _apiKeyController.dispose();
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
    final sessions =
        widget.debugRecentSessions ??
        context.read<SessionListCubit>().state.sessions;
    final history = context.read<ProjectHistoryCubit>().state;
    final bridge = context.read<BridgeService>();
    final result = await showNewSessionSheet(
      context: context,
      recentProjects: recentProjects(sessions),
      projectHistory: history,
      bridge: bridge,
    );
    if (result == null) return;
    if (!mounted) return;
    _pendingResumeProjectPath = result.projectPath;
    bridge.send(
      ClientMessage.start(
        result.projectPath,
        permissionMode: result.provider == Provider.claude
            ? result.permissionMode.value
            : null,
        useWorktree: result.useWorktree ? true : null,
        worktreeBranch: result.worktreeBranch,
        existingWorktreePath: result.existingWorktreePath,
        provider: result.provider.value,
        model: result.model,
      ),
    );
    // Navigate immediately to chat with pending state
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    _pendingNavigation = true;
    _navigateToChat(
      pendingId,
      projectPath: result.projectPath,
      isPending: true,
      provider: result.provider,
    );
  }

  void _navigateToChat(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    Provider? provider,
  }) {
    final Widget screen;
    if (provider == Provider.codex) {
      screen = CodexChatScreen(
        sessionId: sessionId,
        projectPath: projectPath,
        isPending: isPending,
      );
    } else {
      screen = ChatScreen(
        sessionId: sessionId,
        projectPath: projectPath,
        gitBranch: gitBranch,
        worktreePath: worktreePath,
        isPending: isPending,
      );
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      if (!mounted) return;
      final isConnected =
          context.read<ConnectionCubit>().state ==
          BridgeConnectionState.connected;
      if (isConnected) {
        _refresh();
      }
    });
  }

  void _resumeSession(RecentSession session) {
    _pendingResumeProjectPath = session.projectPath;
    _pendingResumeGitBranch = session.gitBranch;
    context.read<BridgeService>().resumeSession(
      session.sessionId,
      session.projectPath,
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

    return BlocListener<ConnectionCubit, BridgeConnectionState>(
      listener: (context, nextState) {
        // Clear auto-connecting spinner once we get any connection state update
        if (_isAutoConnecting) {
          setState(() => _isAutoConnecting = false);
        }
        if (nextState == BridgeConnectionState.connected) {
          context.read<SessionListCubit>().refresh();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ccpocket'),
          actions: [
            IconButton(
              key: const ValueKey('settings_button'),
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              tooltip: 'Settings',
            ),
            if (kDebugMode)
              IconButton(
                key: const ValueKey('mock_preview_button'),
                icon: const Icon(Icons.science),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MockPreviewScreen()),
                ),
                tooltip: 'Mock Preview',
              ),
            if (showConnectedUI)
              IconButton(
                key: const ValueKey('gallery_button'),
                icon: const Icon(Icons.collections),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                ),
                tooltip: 'Gallery',
              ),
            if (showConnectedUI)
              IconButton(
                key: const ValueKey('disconnect_button'),
                icon: const Icon(Icons.link_off),
                onPressed: _disconnect,
                tooltip: 'Disconnect',
              ),
          ],
        ),
        body: _isAutoConnecting
            ? const Center(child: CircularProgressIndicator())
            : showConnectedUI
            ? RefreshIndicator(
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
                  onSelectProject: (path) =>
                      context.read<SessionListCubit>().selectProject(path),
                  onLoadMore: () => context.read<SessionListCubit>().loadMore(),
                ),
              )
            : connectionState == BridgeConnectionState.connecting
            ? const Center(child: CircularProgressIndicator())
            : _buildConnectForm(discoveredServers),
        floatingActionButton: showConnectedUI
            ? FloatingActionButton(
                key: const ValueKey('new_session_fab'),
                onPressed: _showNewSessionDialog,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  void _connectToDiscovered(DiscoveredServer server) {
    _urlController.text = server.wsUrl;
    _apiKeyController.clear();
    if (server.authRequired) {
      // Let user fill in the API key manually
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This server requires an API key')),
      );
      return;
    }
    _connect();
  }

  // ---- Machine Management ----

  Widget _buildConnectForm(List<DiscoveredServer> discoveredServers) {
    // Try to get MachineManagerCubit if available
    final machineManagerCubit = context.watch<MachineManagerCubit?>();
    final machineState = machineManagerCubit?.state;

    return ConnectForm(
      urlController: _urlController,
      apiKeyController: _apiKeyController,
      discoveredServers: discoveredServers,
      onConnect: _connect,
      onScanQrCode: _scanQrCode,
      onConnectToDiscovered: _connectToDiscovered,
      // Machine management
      machines: machineState?.machines ?? [],
      startingMachineId: machineState?.startingMachineId,
      updatingMachineId: machineState?.updatingMachineId,
      onConnectToMachine: _connectToMachine,
      onStartMachine: _startMachine,
      onEditMachine: _editMachine,
      onDeleteMachine: _deleteMachine,
      onToggleFavorite: _toggleFavorite,
      onUpdateMachine: _updateMachine,
      onStopMachine: _stopMachine,
      onAddMachine: _addMachine,
      onRefreshMachines: () => machineManagerCubit?.refreshAll(),
    );
  }

  void _connectToMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final wsUrl = await cubit.buildWsUrl(m.machine.id);
    _urlController.text = m.machine.wsUrl;
    final apiKey = await cubit.getApiKey(m.machine.id);
    _apiKeyController.text = apiKey ?? '';

    // Record connection to update lastConnected
    await cubit.recordConnection(
      host: m.machine.host,
      port: m.machine.port,
      apiKey: apiKey,
    );

    if (!mounted) return;
    final bridge = context.read<BridgeService>();
    bridge.connect(wsUrl);
    bridge.savePreferences(m.machine.wsUrl, apiKey ?? '');
  }

  void _toggleFavorite(MachineWithStatus m) {
    context.read<MachineManagerCubit>().toggleFavorite(m.machine.id);
  }

  void _updateMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();

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
      ).showSnackBar(const SnackBar(content: Text('Bridge Server updated')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update server')),
      );
    }
  }

  void _startMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();

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
      ).showSnackBar(const SnackBar(content: Text('Bridge Server started')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to start server')),
      );
    }
  }

  void _stopMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();

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
      ).showSnackBar(const SnackBar(content: Text('Bridge Server stopped')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Failed to stop server')));
    }
  }

  Future<String?> _promptForPassword(String machineName) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SSH Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter SSH password for $machineName'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Connect'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Machine'),
        content: Text(
          'Delete "${m.machine.displayName}"? This will remove all saved credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }
}

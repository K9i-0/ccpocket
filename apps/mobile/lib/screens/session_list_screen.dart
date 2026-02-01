import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_card.dart';
import 'chat_screen.dart';
import 'mock_preview_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final BridgeService _bridge = BridgeService();
  final TextEditingController _urlController = TextEditingController(
    text: 'ws://localhost:8765',
  );
  final TextEditingController _apiKeyController = TextEditingController();

  BridgeConnectionState _connectionState = BridgeConnectionState.disconnected;
  List<SessionInfo> _sessions = [];
  List<RecentSession> _recentSessions = [];
  bool _isAutoConnecting = false;

  // Cache for resume navigation
  String? _pendingResumeProjectPath;
  String? _pendingResumeGitBranch;

  StreamSubscription<BridgeConnectionState>? _connectionSub;
  StreamSubscription<List<SessionInfo>>? _sessionListSub;
  StreamSubscription<List<RecentSession>>? _recentSessionsSub;
  StreamSubscription<ServerMessage>? _messageSub;

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeyApiKey = 'bridge_api_key';

  bool get _isConnected => _connectionState == BridgeConnectionState.connected;

  @override
  void initState() {
    super.initState();
    _connectionSub = _bridge.connectionStatus.listen((state) {
      setState(() {
        _connectionState = state;
        _isAutoConnecting = false;
      });
      if (state == BridgeConnectionState.connected) {
        _bridge.requestSessionList();
        _bridge.requestRecentSessions();
      }
    });
    _sessionListSub = _bridge.sessionList.listen((sessions) {
      setState(() => _sessions = sessions);
    });
    _recentSessionsSub = _bridge.recentSessionsStream.listen((sessions) {
      setState(() => _recentSessions = sessions);
    });
    _messageSub = _bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        _bridge.requestSessionList();
        if (msg.sessionId != null) {
          _navigateToChat(
            msg.sessionId!,
            projectPath: msg.projectPath ?? _pendingResumeProjectPath,
            gitBranch: _pendingResumeGitBranch,
          );
          _pendingResumeProjectPath = null;
          _pendingResumeGitBranch = null;
        }
      }
    });
    _loadPreferencesAndAutoConnect();
  }

  Future<void> _loadPreferencesAndAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
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
      final attempted = await _bridge.autoConnect();
      if (!attempted) {
        setState(() => _isAutoConnecting = false);
      }
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _sessionListSub?.cancel();
    _recentSessionsSub?.cancel();
    _messageSub?.cancel();
    _bridge.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _connect() {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}token=$apiKey';
    }
    _bridge.connect(url);
    _bridge.savePreferences(
      _urlController.text.trim(),
      _apiKeyController.text.trim(),
    );
  }

  void _disconnect() {
    _bridge.disconnect();
    setState(() {
      _sessions = [];
      _recentSessions = [];
    });
  }

  void _refresh() {
    _bridge.requestSessionList();
    _bridge.requestRecentSessions();
  }

  void _showNewSessionDialog() {
    final pathController = TextEditingController();
    final sessionIdController = TextEditingController();
    var permissionMode = PermissionMode.acceptEdits;
    var continueMode = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('dialog_project_path'),
                  controller: pathController,
                  decoration: const InputDecoration(
                    labelText: 'Project Path',
                    hintText: '/path/to/your/project',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('dialog_session_id'),
                  controller: sessionIdController,
                  decoration: const InputDecoration(
                    labelText: 'Session ID (optional, for resume)',
                    hintText: 'Leave empty for new session',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PermissionMode>(
                  key: const ValueKey('dialog_permission_mode'),
                  initialValue: permissionMode,
                  decoration: const InputDecoration(
                    labelText: 'Permission Mode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: PermissionMode.values
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => permissionMode = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('dialog_continue_mode'),
                  title: const Text('Continue last session'),
                  value: continueMode,
                  onChanged: (val) =>
                      setDialogState(() => continueMode = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('dialog_start_button'),
              onPressed: () {
                final path = pathController.text.trim();
                if (path.isEmpty) return;
                Navigator.pop(context);
                _pendingResumeProjectPath = path;
                final sessionId = sessionIdController.text.trim();
                _bridge.send(
                  ClientMessage.start(
                    path,
                    sessionId: sessionId.isNotEmpty ? sessionId : null,
                    continueMode: continueMode ? true : null,
                    permissionMode: permissionMode.value,
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bridge: _bridge,
          sessionId: sessionId,
          projectPath: projectPath,
          gitBranch: gitBranch,
        ),
      ),
    ).then((_) {
      if (_isConnected) {
        _refresh();
      }
    });
  }

  void _resumeSession(RecentSession session) {
    _pendingResumeProjectPath = session.projectPath;
    _pendingResumeGitBranch = session.gitBranch;
    _bridge.resumeSession(session.sessionId, session.projectPath);
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
              _bridge.stopSession(sessionId);
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showConnectedUI = _isConnected ||
        _connectionState == BridgeConnectionState.reconnecting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ccpocket'),
        actions: [
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
              key: const ValueKey('refresh_button'),
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: 'Refresh',
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
              child: _buildHomeContent(),
            )
          : _connectionState == BridgeConnectionState.connecting
          ? const Center(child: CircularProgressIndicator())
          : _buildConnectForm(),
      floatingActionButton: showConnectedUI
          ? FloatingActionButton(
              key: const ValueKey('new_session_fab'),
              onPressed: _showNewSessionDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildConnectForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.terminal,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connect to Bridge Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('server_url_field'),
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'ws://localhost:8765',
              prefixIcon: Icon(Icons.dns),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('api_key_field'),
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key (optional)',
              hintText: 'Leave empty if no auth',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('connect_button'),
              onPressed: _connect,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasRunningSessions = _sessions.isNotEmpty;
    final hasRecentSessions = _recentSessions.isNotEmpty;
    final isReconnecting = _connectionState == BridgeConnectionState.reconnecting;

    if (!hasRunningSessions && !hasRecentSessions) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isReconnecting) _buildReconnectingBanner(appColors),
          const SizedBox(height: 80),
          _buildEmptyState(appColors),
        ],
      );
    }

    return ListView(
      key: const ValueKey('session_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        if (isReconnecting) _buildReconnectingBanner(appColors),
        if (hasRunningSessions) ...[
          _buildSectionHeader(
            icon: Icons.play_circle_filled,
            label: 'Running',
            color: appColors.statusRunning,
          ),
          const SizedBox(height: 4),
          for (final session in _sessions)
            RunningSessionCard(
              session: session,
              onTap: () =>
                  _navigateToChat(session.id, projectPath: session.projectPath),
              onStop: () => _stopSession(session.id),
            ),
          const SizedBox(height: 16),
        ],
        if (hasRecentSessions) ...[
          _buildSectionHeader(
            icon: Icons.history,
            label: 'Recent Sessions',
            color: appColors.subtleText,
          ),
          const SizedBox(height: 4),
          for (final session in _recentSessions)
            RecentSessionCard(
              session: session,
              onTap: () => _resumeSession(session),
            ),
        ],
      ],
    );
  }

  Widget _buildReconnectingBanner(AppColors appColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: appColors.approvalBar,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: appColors.statusApproval,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Reconnecting...',
            style: TextStyle(
              fontSize: 13,
              color: appColors.statusApproval,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors appColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rocket_launch_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ready to start',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Press the + button to create a new session and start coding with Claude.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: appColors.subtleText,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _showNewSessionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.4), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

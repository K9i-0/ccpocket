import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/messages.dart';
import '../providers/bridge_providers.dart';
import '../providers/discovery_provider.dart';
import '../services/bridge_service.dart';
import '../services/server_discovery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/horizontal_chip_bar.dart';
import '../widgets/new_session_sheet.dart';
import '../widgets/session_card.dart';
import '../services/connection_url_parser.dart';
import 'chat_screen.dart';
import 'gallery_screen.dart';
import 'mock_preview_screen.dart';
import 'qr_scan_screen.dart';

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
  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// Unique branch names for a given project (null project = all branches).
List<String> branchesForProject(
  List<RecentSession> sessions,
  String? projectName,
) {
  final filtered = projectName == null
      ? sessions
      : sessions.where((s) => s.projectName == projectName);
  final seen = <String>{};
  final result = <String>[];
  for (final s in filtered) {
    if (s.gitBranch.isNotEmpty && seen.add(s.gitBranch)) {
      result.add(s.gitBranch);
    }
  }
  return result;
}

/// Filter sessions by branch name (null = no filter).
List<RecentSession> filterByBranch(
  List<RecentSession> sessions,
  String? branch,
) {
  if (branch == null) return sessions;
  return sessions.where((s) => s.gitBranch == branch).toList();
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

/// Date filter period.
enum DateFilter { all, today, thisWeek, thisMonth }

/// Filter sessions by date period.
List<RecentSession> filterByDate(
  List<RecentSession> sessions,
  DateFilter filter,
) {
  if (filter == DateFilter.all) return sessions;
  final now = DateTime.now();
  final threshold = switch (filter) {
    DateFilter.today => DateTime(now.year, now.month, now.day),
    DateFilter.thisWeek => DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)),
    DateFilter.thisMonth => DateTime(now.year, now.month),
    DateFilter.all => now, // unreachable
  };
  return sessions.where((s) {
    final modified = DateTime.tryParse(s.modified);
    return modified != null && modified.isAfter(threshold);
  }).toList();
}

// ---- Screen ----

class SessionListScreen extends ConsumerStatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;

  /// Pre-populated sessions for UI testing (skips bridge connection).
  final List<RecentSession>? debugRecentSessions;

  const SessionListScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  String? _selectedProject; // null = show all
  String? _selectedBranch; // null = show all
  DateFilter _dateFilter = DateFilter.all;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isAutoConnecting = false;

  // Cache for resume navigation
  String? _pendingResumeProjectPath;
  String? _pendingResumeGitBranch;

  // Only subscription that remains: session_created navigation
  StreamSubscription<ServerMessage>? _messageSub;

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeyApiKey = 'bridge_api_key';

  @override
  void initState() {
    super.initState();
    // session_created navigation (the only manual subscription)
    final bridge = ref.read(bridgeServiceProvider);
    _messageSub = bridge.messages.listen((msg) {
      if (msg is SystemMessage && msg.subtype == 'session_created') {
        bridge.requestSessionList();
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
      final attempted = await ref.read(bridgeServiceProvider).autoConnect();
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

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}token=$apiKey';
    }
    final bridge = ref.read(bridgeServiceProvider);
    bridge.connect(url);
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
                'For persistent startup, use launchd',
                'launchctl load ~/Library/LaunchAgents/com.ccpocket.bridge.plist',
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
    ref.read(bridgeServiceProvider).disconnect();
    setState(() {
      _selectedProject = null;
      _selectedBranch = null;
      _dateFilter = DateFilter.all;
      _searchQuery = '';
      _isSearching = false;
    });
  }

  void _refresh() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.requestSessionList();
    bridge.requestRecentSessions();
  }

  void _showNewSessionDialog() async {
    final sessions =
        widget.debugRecentSessions ??
        (ref.read(recentSessionsProvider).valueOrNull ?? []);
    final result = await showNewSessionSheet(
      context: context,
      recentProjects: recentProjects(sessions),
    );
    if (result == null) return;
    _pendingResumeProjectPath = result.projectPath;
    ref
        .read(bridgeServiceProvider)
        .send(
          ClientMessage.start(
            result.projectPath,
            continueMode: result.continueMode ? true : null,
            permissionMode: result.permissionMode.value,
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
          sessionId: sessionId,
          projectPath: projectPath,
          gitBranch: gitBranch,
        ),
      ),
    ).then((_) {
      final isConnected =
          ref.read(connectionStateProvider).valueOrNull ==
          BridgeConnectionState.connected;
      if (isConnected) {
        _refresh();
      }
    });
  }

  void _resumeSession(RecentSession session) {
    _pendingResumeProjectPath = session.projectPath;
    _pendingResumeGitBranch = session.gitBranch;
    ref
        .read(bridgeServiceProvider)
        .resumeSession(session.sessionId, session.projectPath);
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
              ref.read(bridgeServiceProvider).stopSession(sessionId);
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Side-effect: auto-request lists on connect
    ref.listen<AsyncValue<BridgeConnectionState>>(connectionStateProvider, (
      prev,
      next,
    ) {
      final prevState = prev?.valueOrNull;
      final nextState = next.valueOrNull;
      if (nextState != null) {
        // Clear auto-connecting spinner once we get any connection state update
        if (_isAutoConnecting) {
          setState(() => _isAutoConnecting = false);
        }
      }
      if (prevState != BridgeConnectionState.connected &&
          nextState == BridgeConnectionState.connected) {
        final bridge = ref.read(bridgeServiceProvider);
        bridge.requestSessionList();
        bridge.requestRecentSessions();
      }
    });

    // Read state from providers
    final connectionState = widget.debugRecentSessions != null
        ? BridgeConnectionState.connected
        : (ref.watch(connectionStateProvider).valueOrNull ??
              BridgeConnectionState.disconnected);
    final sessions = ref.watch(sessionListProvider).valueOrNull ?? [];
    final recentSessionsList =
        widget.debugRecentSessions ??
        (ref.watch(recentSessionsProvider).valueOrNull ?? []);
    final discoveredServers =
        ref.watch(serverDiscoveryProvider).valueOrNull ?? [];

    final isConnected = connectionState == BridgeConnectionState.connected;
    final showConnectedUI =
        isConnected || connectionState == BridgeConnectionState.reconnecting;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                key: const ValueKey('search_field'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search sessions...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('ccpocket'),
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
          if (showConnectedUI && recentSessionsList.isNotEmpty)
            IconButton(
              key: const ValueKey('search_button'),
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              }),
              tooltip: 'Search',
            ),
          if (showConnectedUI)
            IconButton(
              key: const ValueKey('gallery_button'),
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              ),
              tooltip: 'Gallery',
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
              child: _buildHomeContent(
                connectionState: connectionState,
                sessions: sessions,
                recentSessionsList: recentSessionsList,
              ),
            )
          : connectionState == BridgeConnectionState.connecting
          ? const Center(child: CircularProgressIndicator())
          : _buildConnectForm(discoveredServers: discoveredServers),
      floatingActionButton: showConnectedUI
          ? FloatingActionButton(
              key: const ValueKey('new_session_fab'),
              onPressed: _showNewSessionDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildConnectForm({
    required List<DiscoveredServer> discoveredServers,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
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
          if (discoveredServers.isNotEmpty) ...[
            _buildDiscoveredServers(discoveredServers: discoveredServers),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or enter manually',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const ValueKey('server_url_field'),
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'ws://<host-ip>:8765',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const ValueKey('scan_qr_button'),
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
          ),
        ],
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

  Widget _buildDiscoveredServers({
    required List<DiscoveredServer> discoveredServers,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wifi_find,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Discovered Servers',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final server in discoveredServers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.dns,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                server.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                server.wsUrl,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: server.authRequired
                  ? Icon(
                      Icons.lock,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    )
                  : Icon(
                      Icons.lock_open,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
              onTap: () => _connectToDiscovered(server),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeContent({
    required BridgeConnectionState connectionState,
    required List<SessionInfo> sessions,
    required List<RecentSession> recentSessionsList,
  }) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasRunningSessions = sessions.isNotEmpty;
    final hasRecentSessions = recentSessionsList.isNotEmpty;
    final isReconnecting =
        connectionState == BridgeConnectionState.reconnecting;

    // Compute derived state
    final allProjectCounts = projectCounts(recentSessionsList);
    final allBranchChips = branchesForProject(
      recentSessionsList,
      _selectedProject,
    );
    var filteredSessions = filterByProject(
      recentSessionsList,
      _selectedProject,
    );
    filteredSessions = filterByBranch(filteredSessions, _selectedBranch);
    filteredSessions = filterByDate(filteredSessions, _dateFilter);
    filteredSessions = filterByQuery(filteredSessions, _searchQuery);

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
          for (final session in sessions)
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
          if (allProjectCounts.length > 1) ...[
            const SizedBox(height: 8),
            _buildProjectFilterChips(appColors, recentSessionsList),
          ],
          // Branch filter chips (show when branches exist for selection)
          if (allBranchChips.length > 1) ...[
            const SizedBox(height: 4),
            _buildBranchFilterChips(appColors, recentSessionsList),
          ],
          // Date filter chips
          const SizedBox(height: 4),
          _buildDateFilterChips(appColors),
          const SizedBox(height: 8),
          for (final session in filteredSessions)
            RecentSessionCard(
              session: session,
              onTap: () => _resumeSession(session),
              hideProjectBadge: _selectedProject != null,
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
            style: TextStyle(fontSize: 13, color: appColors.statusApproval),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Press the + button to create a new session and start coding with Claude.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: appColors.subtleText),
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

  Widget _buildProjectFilterChips(
    AppColors appColors,
    List<RecentSession> recentSessionsList,
  ) {
    final cs = Theme.of(context).colorScheme;
    final counts = projectCounts(recentSessionsList);
    return HorizontalChipBar(
      height: 36,
      fontSize: 12,
      showFade: true,
      selectedColor: cs.primary,
      selectedTextColor: cs.onPrimary,
      unselectedTextColor: appColors.subtleText,
      items: [
        ChipItem(
          label: 'All (${recentSessionsList.length})',
          isSelected: _selectedProject == null,
          onSelected: () => setState(() {
            _selectedProject = null;
            _selectedBranch = null;
          }),
        ),
        for (final entry in counts.entries)
          ChipItem(
            label: entry.key,
            isSelected: _selectedProject == entry.key,
            onSelected: () => setState(() {
              _selectedProject = entry.key;
              _selectedBranch = null;
            }),
          ),
      ],
    );
  }

  Widget _buildBranchFilterChips(
    AppColors appColors,
    List<RecentSession> recentSessionsList,
  ) {
    final cs = Theme.of(context).colorScheme;
    final branchChipsList = branchesForProject(
      recentSessionsList,
      _selectedProject,
    );
    return HorizontalChipBar(
      selectedColor: cs.secondary,
      selectedTextColor: cs.onSecondary,
      unselectedTextColor: appColors.subtleText,
      items: [
        ChipItem(
          label: 'All branches',
          isSelected: _selectedBranch == null,
          onSelected: () => setState(() => _selectedBranch = null),
          avatar: Icon(
            Icons.account_tree,
            size: 14,
            color: appColors.subtleText,
          ),
        ),
        for (final branch in branchChipsList)
          ChipItem(
            label: branch,
            isSelected: _selectedBranch == branch,
            onSelected: () => setState(() => _selectedBranch = branch),
          ),
      ],
    );
  }

  Widget _buildDateFilterChips(AppColors appColors) {
    final cs = Theme.of(context).colorScheme;
    const filters = [
      (DateFilter.all, 'All time'),
      (DateFilter.today, 'Today'),
      (DateFilter.thisWeek, 'This week'),
      (DateFilter.thisMonth, 'This month'),
    ];
    return HorizontalChipBar(
      selectedColor: cs.tertiary,
      selectedTextColor: cs.onTertiary,
      unselectedTextColor: appColors.subtleText,
      items: [
        for (final (filter, label) in filters)
          ChipItem(
            label: label,
            isSelected: _dateFilter == filter,
            onSelected: () => setState(() => _dateFilter = filter),
          ),
      ],
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

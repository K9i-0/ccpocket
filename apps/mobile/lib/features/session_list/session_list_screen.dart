import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import '../../providers/discovery_provider.dart';
import '../../screens/mock_preview_screen.dart';
import '../../screens/qr_scan_screen.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/server_discovery_service.dart';
import '../../services/url_history_service.dart';
import '../../widgets/new_session_sheet.dart';
import '../chat/chat_screen.dart';
import '../gallery/gallery_screen.dart';
import 'state/session_list_notifier.dart';
import 'state/session_list_state.dart';
import 'widgets/connect_form.dart';
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
  final home = Platform.environment['HOME'] ?? '';
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

  bool _isSearching = false;
  bool _isAutoConnecting = false;

  // URL history
  UrlHistoryService? _urlHistoryService;
  List<UrlHistoryEntry> _urlHistory = [];

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
            worktreePath: msg.worktreePath,
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
    _urlHistoryService = UrlHistoryService(prefs);
    setState(() => _urlHistory = _urlHistoryService!.load());
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

    // Save to URL history on health check pass (or user choosing to connect)
    final apiKey = _apiKeyController.text.trim();
    if (_urlHistoryService != null) {
      await _urlHistoryService!.add(url, apiKey);
      setState(() => _urlHistory = _urlHistoryService!.load());
    }
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
    ref.read(sessionListNotifierProvider.notifier).resetFilters();
    setState(() => _isSearching = false);
  }

  void _refresh() {
    ref.read(sessionListNotifierProvider.notifier).refresh();
  }

  void _showNewSessionDialog() async {
    final sessions =
        widget.debugRecentSessions ??
        ref.read(sessionListNotifierProvider).sessions;
    final history = ref.read(projectHistoryProvider).valueOrNull ?? [];
    final result = await showNewSessionSheet(
      context: context,
      recentProjects: recentProjects(sessions),
      projectHistory: history,
    );
    if (result == null) return;
    _pendingResumeProjectPath = result.projectPath;
    ref
        .read(bridgeServiceProvider)
        .send(
          ClientMessage.start(
            result.projectPath,
            permissionMode: result.permissionMode.value,
            useWorktree: result.useWorktree ? true : null,
            worktreeBranch: result.worktreeBranch,
          ),
        );
  }

  void _navigateToChat(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sessionId: sessionId,
          projectPath: projectPath,
          gitBranch: gitBranch,
          worktreePath: worktreePath,
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
        ref.read(sessionListNotifierProvider.notifier).refresh();
      }
    });

    // Read state from providers
    final slState = ref.watch(sessionListNotifierProvider);
    final connectionState = widget.debugRecentSessions != null
        ? BridgeConnectionState.connected
        : (ref.watch(connectionStateProvider).valueOrNull ??
              BridgeConnectionState.disconnected);
    final sessions = ref.watch(sessionListProvider).valueOrNull ?? [];
    final recentSessionsList = widget.debugRecentSessions ?? slState.sessions;
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
                onChanged: (v) => ref
                    .read(sessionListNotifierProvider.notifier)
                    .setSearchQuery(v),
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
              onPressed: () {
                setState(() => _isSearching = !_isSearching);
                if (!_isSearching) {
                  ref
                      .read(sessionListNotifierProvider.notifier)
                      .setSearchQuery('');
                }
              },
              tooltip: 'Search',
            ),
          if (showConnectedUI)
            IconButton(
              key: const ValueKey('gallery_button'),
              icon: const Icon(Icons.preview),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              ),
              tooltip: 'Preview',
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
              child: HomeContent(
                connectionState: connectionState,
                sessions: sessions,
                recentSessions: recentSessionsList,
                accumulatedProjectPaths: slState.accumulatedProjectPaths,
                selectedProject: slState.selectedProject,
                dateFilter: slState.dateFilter,
                searchQuery: slState.searchQuery,
                isLoadingMore: slState.isLoadingMore,
                hasMoreSessions: slState.hasMore,
                currentProjectFilter: ref
                    .read(bridgeServiceProvider)
                    .currentProjectFilter,
                onNewSession: _showNewSessionDialog,
                onTapRunning:
                    (sessionId, {String? projectPath, String? worktreePath}) =>
                        _navigateToChat(
                          sessionId,
                          projectPath: projectPath,
                          worktreePath: worktreePath,
                        ),
                onStopSession: _stopSession,
                onResumeSession: _resumeSession,
                onSelectProject: (path) => ref
                    .read(sessionListNotifierProvider.notifier)
                    .selectProject(path),
                onSelectDateFilter: (f) => ref
                    .read(sessionListNotifierProvider.notifier)
                    .setDateFilter(f),
                onLoadMore: () =>
                    ref.read(sessionListNotifierProvider.notifier).loadMore(),
              ),
            )
          : connectionState == BridgeConnectionState.connecting
          ? const Center(child: CircularProgressIndicator())
          : ConnectForm(
              urlController: _urlController,
              apiKeyController: _apiKeyController,
              discoveredServers: discoveredServers,
              urlHistory: _urlHistory,
              onConnect: _connect,
              onScanQrCode: _scanQrCode,
              onConnectToDiscovered: _connectToDiscovered,
              onSelectUrlHistory: _selectUrlHistory,
              onRemoveUrlHistory: (url) async {
                await _removeUrlHistory(url);
              },
            ),
      floatingActionButton: showConnectedUI
          ? FloatingActionButton(
              key: const ValueKey('new_session_fab'),
              onPressed: _showNewSessionDialog,
              child: const Icon(Icons.add),
            )
          : null,
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

  void _selectUrlHistory(UrlHistoryEntry entry) {
    _urlController.text = entry.url;
    _apiKeyController.text = entry.apiKey;
  }

  Future<void> _removeUrlHistory(String url) async {
    if (_urlHistoryService == null) return;
    await _urlHistoryService!.remove(url);
    setState(() => _urlHistory = _urlHistoryService!.load());
  }
}

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/session_list/state/session_list_cubit.dart';
import '../features/session_list/widgets/home_content.dart';
import '../mock/mock_scenarios.dart';
import '../mock/mock_sessions.dart';
import '../mock/store_screenshot_data.dart';
import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import '../services/bridge_service.dart';
import '../services/draft_service.dart';
import '../services/mock_bridge_service.dart';
import '../services/replay_bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_card.dart';
import '../features/claude_session/claude_session_screen.dart';

@RoutePage()
class MockPreviewScreen extends StatelessWidget {
  const MockPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mock Preview'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scenarios'),
              Tab(text: 'Replay'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ScenariosTab(), _ReplayTab()]),
      ),
    );
  }
}

class _ScenariosTab extends StatelessWidget {
  const _ScenariosTab();

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Group scenarios by section
    final grouped = <MockScenarioSection, List<MockScenario>>{};
    for (final s in mockScenarios) {
      grouped.putIfAbsent(s.section, () => []).add(s);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Select a scenario to preview UI behavior.',
            style: TextStyle(fontSize: 13, color: appColors.subtleText),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final section in MockScenarioSection.values)
                if (grouped.containsKey(section)) ...[
                  _SectionHeader(section: section),
                  for (final scenario in grouped[section]!)
                    _ScenarioCard(
                      scenario: scenario,
                      onTap: () => _launchScenario(context, scenario),
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }

  void _launchScenario(BuildContext context, MockScenario scenario) {
    if (scenario.section == MockScenarioSection.storeScreenshot) {
      _launchStoreScenario(context, scenario);
    } else if (scenario.section == MockScenarioSection.sessionList) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MockSessionListWrapper(scenario: scenario),
        ),
      );
    } else {
      final mockService = MockBridgeService();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _MockChatWrapper(mockService: mockService, scenario: scenario),
        ),
      );
    }
  }

  void _launchStoreScenario(BuildContext context, MockScenario scenario) {
    if (scenario.name == 'Session List' ||
        scenario.name == 'Session List (Recent)') {
      final draftService = context.read<DraftService>();
      final minimal = scenario.name == 'Session List (Recent)';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _StoreSessionListWrapper(
            draftService: draftService,
            minimalRunning: minimal,
          ),
        ),
      );
    } else {
      final mockService = MockBridgeService();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _StoreChatWrapper(mockService: mockService, scenario: scenario),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final MockScenarioSection section;
  const _SectionHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(section.icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            section.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final MockScenario scenario;
  final VoidCallback onTap;
  const _ScenarioCard({required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(scenario.icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      scenario.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayTab extends StatefulWidget {
  const _ReplayTab();

  @override
  State<_ReplayTab> createState() => _ReplayTabState();
}

class _ReplayTabState extends State<_ReplayTab> {
  List<RecordingInfo>? _recordings;
  bool _loading = true;
  String? _error;
  StreamSubscription<RecordingListMessage>? _sub;

  BridgeService get _bridge => context.read<BridgeService>();

  @override
  void initState() {
    super.initState();
    _sub = _bridge.recordingList.listen((msg) {
      if (mounted) {
        setState(() {
          _recordings = msg.recordings;
          _loading = false;
          _error = null;
        });
      }
    });
    _loadRecordings();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    _bridge.send(ClientMessage.listRecordings());
    // Response comes via the stream listener
  }

  Future<void> _launchReplay(RecordingInfo info) async {
    // Request content from Bridge
    final completer = Completer<String>();
    late final StreamSubscription<RecordingContentMessage> sub;
    sub = _bridge.recordingContent.listen((msg) {
      if (msg.sessionId == info.name) {
        completer.complete(msg.content);
        sub.cancel();
      }
    });
    _bridge.send(ClientMessage.getRecording(info.name));

    final content = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        return '';
      },
    );
    if (!mounted || content.isEmpty) return;

    final replayService = ReplayBridgeService();
    replayService.loadFromJsonlString(content);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReplayChatWrapper(
          replayService: replayService,
          recordingName: info.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $_error', style: TextStyle(color: cs.error)),
        ),
      );
    }

    final recordings = _recordings ?? [];
    if (recordings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 48, color: cs.outline),
              const SizedBox(height: 12),
              Text(
                'No recordings found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recordings are automatically created when you use '
                'the Bridge Server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: appColors.subtleText),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Replay a recorded session to reproduce bugs deterministically.',
            style: TextStyle(fontSize: 13, color: appColors.subtleText),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecordings,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final info = recordings[index];
                final dt = info.modifiedDate;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _launchReplay(info),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.replay,
                              color: cs.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.displayText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (info.projectName != null)
                                      info.projectName!,
                                    info.sizeLabel,
                                    if (dt != null) _formatDate(dt),
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: cs.outline,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Wrapper that starts scenario playback after ClaudeSessionScreen's initState completes.
class _MockChatWrapper extends StatefulWidget {
  final MockBridgeService mockService;
  final MockScenario scenario;

  const _MockChatWrapper({required this.mockService, required this.scenario});

  @override
  State<_MockChatWrapper> createState() => _MockChatWrapperState();
}

class _MockChatWrapperState extends State<_MockChatWrapper> {
  @override
  void initState() {
    super.initState();
    // Start playback after the frame so ClaudeSessionScreen's listener is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.mockService.playScenario(widget.scenario);
    });
  }

  @override
  void dispose() {
    widget.mockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId =
        'mock-${widget.scenario.name.toLowerCase().replaceAll(' ', '-')}';
    final mockService = widget.mockService;
    return RepositoryProvider<BridgeService>.value(
      value: mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], mockService.fileList),
          ),
        ],
        child: ClaudeSessionScreen(
          sessionId: sessionId,
          projectPath: '/mock/preview',
        ),
      ),
    );
  }
}

/// Wrapper that starts replay playback after ClaudeSessionScreen's initState completes.
class _ReplayChatWrapper extends StatefulWidget {
  final ReplayBridgeService replayService;
  final String recordingName;

  const _ReplayChatWrapper({
    required this.replayService,
    required this.recordingName,
  });

  @override
  State<_ReplayChatWrapper> createState() => _ReplayChatWrapperState();
}

class _ReplayChatWrapperState extends State<_ReplayChatWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.replayService.play();
    });
  }

  @override
  void dispose() {
    widget.replayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId =
        'replay-${widget.recordingName.toLowerCase().replaceAll(' ', '-')}';
    final replayService = widget.replayService;
    return RepositoryProvider<BridgeService>.value(
      value: replayService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              replayService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], replayService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], replayService.fileList),
          ),
        ],
        child: ClaudeSessionScreen(
          sessionId: sessionId,
          projectPath: '/replay/${widget.recordingName}',
        ),
      ),
    );
  }
}

/// Wrapper that shows mock RunningSessionCards for session-list approval UI
/// prototyping. No Bridge connection needed.
class _MockSessionListWrapper extends StatefulWidget {
  final MockScenario scenario;
  const _MockSessionListWrapper({required this.scenario});

  @override
  State<_MockSessionListWrapper> createState() =>
      _MockSessionListWrapperState();
}

class _MockSessionListWrapperState extends State<_MockSessionListWrapper> {
  late List<SessionInfo> _sessions;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _sessions = _buildSessions();
  }

  List<SessionInfo> _buildSessions() {
    switch (widget.scenario.name) {
      case 'Single Question':
        return [mockSessionSingleQuestion()];
      case 'PageView Multi-Question':
        return [mockSessionMultiQuestion()];
      case 'MultiSelect Question':
        return [mockSessionMultiSelect()];
      case 'Batch Approval':
        return mockSessionsBatchApproval();
      case 'Plan Approval':
        return [mockSessionPlanApproval()];
      default:
        return [];
    }
  }

  void _addLog(String msg) {
    setState(() {
      _log.insert(0, msg);
      if (_log.length > 20) _log.removeLast();
    });
  }

  void _approve(String sessionId, String toolUseId) {
    _addLog('Approve: $sessionId ($toolUseId)');
    setState(() {
      _sessions = _sessions.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(status: 'running', clearPermission: true);
        }
        return s;
      }).toList();
    });
  }

  void _approveAlways(String sessionId, String toolUseId) {
    _addLog('Always: $sessionId ($toolUseId)');
    setState(() {
      _sessions = _sessions.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(status: 'running', clearPermission: true);
        }
        return s;
      }).toList();
    });
  }

  void _reject(String sessionId, String toolUseId) {
    _addLog('Reject: $sessionId ($toolUseId)');
    setState(() {
      _sessions = _sessions.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(status: 'running', clearPermission: true);
        }
        return s;
      }).toList();
    });
  }

  void _answer(String sessionId, String toolUseId, String result) {
    _addLog('Answer: $sessionId → $result');
    setState(() {
      _sessions = _sessions.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(status: 'running', clearPermission: true);
        }
        return s;
      }).toList();
    });
  }

  void _reset() {
    setState(() {
      _sessions = _buildSessions();
      _log.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scenario.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Running session cards
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final session in _sessions)
                  RunningSessionCard(
                    session: session,
                    onTap: () => _addLog('Tap: ${session.id}'),
                    onStop: () => _addLog('Stop: ${session.id}'),
                    onApprove: (toolUseId) => _approve(session.id, toolUseId),
                    onApproveAlways: (toolUseId) =>
                        _approveAlways(session.id, toolUseId),
                    onReject: (toolUseId) => _reject(session.id, toolUseId),
                    onAnswer: (toolUseId, result) =>
                        _answer(session.id, toolUseId, result),
                  ),
              ],
            ),
          ),
          // Action log
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            flex: 1,
            child: Container(
              color: cs.surfaceContainerLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      'Action Log',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: appColors.subtleText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _log.isEmpty
                        ? Center(
                            child: Text(
                              'Interact with the cards above',
                              style: TextStyle(
                                fontSize: 12,
                                color: appColors.subtleText,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _log.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  _log[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Store Screenshot: Session List Wrapper
// =============================================================================

class _StoreSessionListWrapper extends StatefulWidget {
  final DraftService draftService;
  final bool minimalRunning;
  const _StoreSessionListWrapper({
    required this.draftService,
    this.minimalRunning = false,
  });

  @override
  State<_StoreSessionListWrapper> createState() =>
      _StoreSessionListWrapperState();
}

class _StoreSessionListWrapperState extends State<_StoreSessionListWrapper> {
  late final MockBridgeService _mockBridge;
  late final SessionListCubit _sessionListCubit;

  @override
  void initState() {
    super.initState();
    _mockBridge = MockBridgeService();
    _sessionListCubit = SessionListCubit(bridge: _mockBridge);
  }

  @override
  void dispose() {
    _sessionListCubit.close();
    _mockBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.minimalRunning
        ? storeRunningSessionsMinimal()
        : storeRunningSessions();
    final recent = storeRecentSessions();
    final projectPaths = {
      ...running.map((s) => s.projectPath),
      ...recent.map((s) => s.projectPath),
    };

    return RepositoryProvider<DraftService>.value(
      value: widget.draftService,
      child: BlocProvider.value(
        value: _sessionListCubit,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('CC Pocket'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.collections),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: () {},
              ),
            ],
          ),
          body: HomeContent(
            connectionState: BridgeConnectionState.connected,
            sessions: running,
            recentSessions: recent,
            accumulatedProjectPaths: projectPaths,
            selectedProject: null,
            searchQuery: '',
            isLoadingMore: false,
            isInitialLoading: false,
            hasMoreSessions: false,
            currentProjectFilter: null,
            onNewSession: () {},
            onTapRunning:
                (
                  _, {
                  projectPath,
                  gitBranch,
                  worktreePath,
                  provider,
                  permissionMode,
                  sandboxMode,
                }) {},
            onStopSession: (_) {},
            onResumeSession: (_) {},
            onLongPressRecentSession: (_) {},
            onSelectProject: (_) {},
            onLoadMore: () {},
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Store Screenshot: Chat Wrapper
// =============================================================================

class _StoreChatWrapper extends StatefulWidget {
  final MockBridgeService mockService;
  final MockScenario scenario;

  const _StoreChatWrapper({required this.mockService, required this.scenario});

  @override
  State<_StoreChatWrapper> createState() => _StoreChatWrapperState();
}

class _StoreChatWrapperState extends State<_StoreChatWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = switch (widget.scenario.name) {
        'Coding Session' => storeChatCodingSession,
        'Task Planning' => storeChatTaskPlanning,
        _ => <ServerMessage>[],
      };
      widget.mockService.loadHistory(history);
    });
  }

  @override
  void dispose() {
    widget.mockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId =
        'store-${widget.scenario.name.toLowerCase().replaceAll(' ', '-')}';
    final mockService = widget.mockService;
    return RepositoryProvider<BridgeService>.value(
      value: mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], mockService.fileList),
          ),
        ],
        child: ClaudeSessionScreen(
          sessionId: sessionId,
          projectPath: '/store/preview',
        ),
      ),
    );
  }
}

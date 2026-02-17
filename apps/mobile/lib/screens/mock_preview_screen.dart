import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../mock/mock_scenarios.dart';
import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import '../services/bridge_service.dart';
import '../services/mock_bridge_service.dart';
import '../services/replay_bridge_service.dart';
import '../theme/app_theme.dart';
import '../features/claude_code_session/claude_code_session_screen.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Select a scenario to preview the chat UI behavior.',
            style: TextStyle(fontSize: 13, color: appColors.subtleText),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: mockScenarios.length,
            itemBuilder: (context, index) {
              final scenario = mockScenarios[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _launchScenario(context, scenario),
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
                            scenario.icon,
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
            },
          ),
        ),
      ],
    );
  }

  void _launchScenario(BuildContext context, MockScenario scenario) {
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
                                    if (info.projectName != null) info.projectName!,
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

/// Wrapper that starts scenario playback after ClaudeCodeSessionScreen's initState completes.
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
    // Start playback after the frame so ClaudeCodeSessionScreen's listener is ready
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
        child: ClaudeCodeSessionScreen(
          sessionId: sessionId,
          projectPath: '/mock/preview',
        ),
      ),
    );
  }
}

/// Wrapper that starts replay playback after ClaudeCodeSessionScreen's initState completes.
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
        child: ClaudeCodeSessionScreen(
          sessionId: sessionId,
          projectPath: '/replay/${widget.recordingName}',
        ),
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../mock/mock_scenarios.dart';
import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import '../services/bridge_service.dart';
import '../services/mock_bridge_service.dart';
import '../theme/app_theme.dart';
import '../features/claude_code_session/claude_code_session_screen.dart';

@RoutePage()
class MockPreviewScreen extends StatelessWidget {
  const MockPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mock Preview')),
      body: Column(
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
        ],
      ),
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

/// LP capture scenarios rendered with the shipping chat and file preview UI.
/// Only the conversation data and media responses are fixtures.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/codex_session/codex_session_screen.dart';
import '../features/file_peek/file_peek_sheet.dart';
import '../mock/mock_image_data.dart';
import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import '../services/bridge_service.dart';
import '../services/mock_bridge_service.dart';

class LandingPreviewScreen extends StatefulWidget {
  final String scenario;

  const LandingPreviewScreen({super.key, required this.scenario});

  @override
  State<LandingPreviewScreen> createState() => _LandingPreviewScreenState();
}

class _LandingPreviewScreenState extends State<LandingPreviewScreen> {
  static const _projectPath = '/projects/pocket-studio';
  static const _mediaBaseUrl = String.fromEnvironment(
    'LP_MEDIA_BASE_URL',
    defaultValue: 'http://127.0.0.1:8898',
  );
  late final MockBridgeService _bridge;
  String get _sessionId => 'landing-${widget.scenario}';

  @override
  void initState() {
    super.initState();
    _bridge = MockBridgeService()..mockHttpBaseUrl = _mediaBaseUrl;
    _bridge.mockFileContents = {
      'outputs/pocket-preview.mp4': const FileContentMessage(
        filePath: 'outputs/pocket-preview.mp4',
        kind: 'video',
        content: '',
        mediaUrl: '/pocket-preview.mp4',
        mimeType: 'video/mp4',
      ),
      'outputs/pocket-chime.wav': const FileContentMessage(
        filePath: 'outputs/pocket-chime.wav',
        kind: 'audio',
        content: '',
        mediaUrl: '/pocket-chime.wav',
        mimeType: 'audio/wav',
      ),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    final history = <ServerMessage>[
      SystemMessage(
        subtype: 'init',
        sessionId: _sessionId,
        model: 'gpt-6',
        projectPath: _projectPath,
      ),
    ];
    if (widget.scenario == 'LP Imagegen') {
      final bytes = await generateMockGeneratedLandscapeImage(
        title: 'AGENT WORKFLOW',
        subtitle: 'From an idea to something you can share',
      );
      if (!mounted) return;
      history.addAll([
        const UserInputMessage(
          text: 'Sketch a simple workflow for our coding agents.',
        ),
        const AssistantServerMessage(
          message: AssistantMessage(
            id: 'lp-image-response',
            role: 'assistant',
            model: 'gpt-6',
            content: [
              TextContent(text: 'Here is a visual direction for the workflow.'),
              ToolUseContent(
                id: 'lp-imagegen',
                name: 'ImageGeneration',
                input: {
                  'status': 'completed',
                  'revisedPrompt':
                      'A hand-drawn coding-agent workflow on paper.',
                },
              ),
            ],
          ),
        ),
        ToolResultMessage(
          toolUseId: 'lp-imagegen',
          toolName: 'ImageGeneration',
          content:
              'status: completed\n'
              'revisedPrompt: A hand-drawn coding-agent workflow on paper.\n'
              'savedPath: /projects/pocket-studio/outputs/workflow.png',
          images: [
            ImageRef(
              id: 'lp-workflow',
              url: 'data:image/png;base64,${base64Encode(bytes)}',
              mimeType: 'image/png',
            ),
          ],
        ),
      ]);
    } else if (widget.scenario == 'LP Video' || widget.scenario == 'LP Audio') {
      history.addAll(const [
        UserInputMessage(
          text: 'Prepare the app preview and a notification sound.',
        ),
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'lp-media-response',
            role: 'assistant',
            model: 'gpt-6',
            content: [
              TextContent(
                text:
                    'Both files are ready to preview.\n\n'
                    '- Video: `outputs/pocket-preview.mp4`\n'
                    '- Audio: `outputs/pocket-chime.wav`',
              ),
            ],
          ),
        ),
      ]);
    } else {
      history.addAll(const [
        UserInputMessage(text: 'Make the checkout feel simpler on mobile.'),
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'lp-chat-response',
            role: 'assistant',
            model: 'gpt-6',
            content: [
              TextContent(
                text:
                    'I simplified the checkout into three steps:\n\n'
                    '1. Contact details\n'
                    '2. Delivery\n'
                    '3. Payment\n\n'
                    'The order summary stays visible, and the form now keeps '
                    'your progress when you go back.',
              ),
              ToolUseContent(
                id: 'lp-tests',
                name: 'Bash',
                input: {'command': 'npm test -- checkout'},
              ),
            ],
          ),
        ),
        ToolResultMessage(
          toolUseId: 'lp-tests',
          toolName: 'Bash',
          content: 'PASS checkout.test.tsx\n12 tests passed',
        ),
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'lp-chat-complete',
            role: 'assistant',
            model: 'gpt-6',
            content: [
              TextContent(text: 'Ready for your review. All 12 tests pass.'),
            ],
          ),
        ),
      ]);
    }
    history.addAll([
      ResultMessage(subtype: 'success', sessionId: _sessionId),
      const StatusMessage(status: ProcessStatus.idle),
    ]);
    if (!mounted) return;
    _bridge.loadHistory(history);
    if (widget.scenario == 'LP Video' || widget.scenario == 'LP Audio') {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      unawaited(
        showFilePeekSheet(
          context,
          bridge: _bridge,
          projectPath: _projectPath,
          filePath: widget.scenario == 'LP Video'
              ? 'outputs/pocket-preview.mp4'
              : 'outputs/pocket-chime.wav',
        ),
      );
    }
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BridgeService>.value(
      value: _bridge,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              _bridge.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) => ActiveSessionsCubit(const [], _bridge.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], _bridge.fileList),
          ),
        ],
        child: CodexSessionScreen(
          sessionId: _sessionId,
          projectPath: _projectPath,
        ),
      ),
    );
  }
}

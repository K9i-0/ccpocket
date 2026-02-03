import 'dart:async';
import 'dart:convert';

import '../mock/mock_scenarios.dart';
import '../models/messages.dart';
import 'bridge_service.dart';

class MockBridgeService extends BridgeService {
  final _mockMessageController = StreamController<ServerMessage>.broadcast();
  final List<Timer> _timers = [];

  @override
  Stream<ServerMessage> get messages => _mockMessageController.stream;

  @override
  String? get httpBaseUrl => null;

  @override
  bool get isConnected => true;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      Stream.value(BridgeConnectionState.connected);

  @override
  void send(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final type = json['type'] as String;

    switch (type) {
      case 'approve':
        // Simulate tool execution result after approval
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.running),
        );
        _scheduleMessage(
          const Duration(milliseconds: 800),
          ToolResultMessage(
            toolUseId: json['id'] as String? ?? '',
            content: 'Tool executed successfully (mock)',
          ),
        );
        _scheduleMessage(
          const Duration(milliseconds: 1200),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-approve',
              role: 'assistant',
              content: [
                const TextContent(
                  text: 'The tool has been executed successfully.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
        _scheduleMessage(
          const Duration(milliseconds: 1500),
          const StatusMessage(status: ProcessStatus.idle),
        );
      case 'reject':
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.idle),
        );
        _scheduleMessage(
          const Duration(milliseconds: 500),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-reject',
              role: 'assistant',
              content: [
                const TextContent(
                  text: 'Understood. I will not execute that tool.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
      case 'answer':
        final result = json['result'] as String? ?? '';
        _scheduleMessage(
          const Duration(milliseconds: 500),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-answer',
              role: 'assistant',
              content: [
                TextContent(
                  text:
                      'Thank you for your answer: "$result". '
                      'I will proceed accordingly.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
      case 'input':
        final text = json['text'] as String? ?? '';
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.running),
        );
        _playStreamingScenario(
          'You said: "$text". This is a mock response echoing your input.',
          startDelay: const Duration(milliseconds: 500),
        );
      default:
        break;
    }
  }

  @override
  Stream<List<String>> get fileList => const Stream.empty();

  @override
  Stream<List<SessionInfo>> get sessionList => const Stream.empty();

  @override
  void requestFileList(String projectPath) {
    // No-op for mock
  }

  @override
  void interrupt(String sessionId) {
    // Simulate interrupt: stop running and go idle
    _scheduleMessage(
      const Duration(milliseconds: 200),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  @override
  void requestSessionList() {
    // No-op for mock
  }

  @override
  void requestSessionHistory(String sessionId) {
    // No-op for mock — history is empty
  }

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => messages;

  @override
  void stopSession(String sessionId) {
    _scheduleMessage(
      const Duration(milliseconds: 200),
      const ResultMessage(subtype: 'stopped'),
    );
    _scheduleMessage(
      const Duration(milliseconds: 300),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  /// Play a scenario: emit each step's message after its delay.
  void playScenario(MockScenario scenario) {
    if (scenario.streamingText != null) {
      // Find the delay of the last step to start streaming after it
      final lastStepDelay = scenario.steps.isNotEmpty
          ? scenario.steps.last.delay
          : Duration.zero;
      for (final step in scenario.steps) {
        _scheduleMessage(step.delay, step.message);
      }
      _playStreamingScenario(
        scenario.streamingText!,
        startDelay: lastStepDelay + const Duration(milliseconds: 300),
      );
    } else {
      for (final step in scenario.steps) {
        _scheduleMessage(step.delay, step.message);
      }
    }
  }

  void _playStreamingScenario(
    String text, {
    Duration startDelay = Duration.zero,
  }) {
    const charDelay = Duration(milliseconds: 20);
    for (var i = 0; i < text.length; i++) {
      _scheduleMessage(
        startDelay + charDelay * i,
        StreamDeltaMessage(text: text[i]),
      );
    }
    // Final assistant message after streaming completes
    _scheduleMessage(
      startDelay + charDelay * text.length + const Duration(milliseconds: 100),
      AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-stream-final',
          role: 'assistant',
          content: [TextContent(text: text)],
          model: 'mock',
        ),
      ),
    );
    _scheduleMessage(
      startDelay + charDelay * text.length + const Duration(milliseconds: 200),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  void _scheduleMessage(Duration delay, ServerMessage message) {
    final timer = Timer(delay, () {
      if (!_mockMessageController.isClosed) {
        _mockMessageController.add(message);
      }
    });
    _timers.add(timer);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _mockMessageController.close();
    super.dispose();
  }
}

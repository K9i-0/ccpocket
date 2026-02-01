import 'package:flutter/material.dart';

import '../models/messages.dart';

class MockStep {
  final Duration delay;
  final ServerMessage message;

  const MockStep({required this.delay, required this.message});
}

class MockScenario {
  final String name;
  final IconData icon;
  final String description;
  final List<MockStep> steps;

  /// If non-null, a streaming scenario is played after the steps.
  final String? streamingText;

  const MockScenario({
    required this.name,
    required this.icon,
    required this.description,
    required this.steps,
    this.streamingText,
  });
}

final List<MockScenario> mockScenarios = [
  _approvalFlow,
  _askUserQuestion,
  _imageResult,
  _streaming,
  _thinkingBlock,
  _planMode,
  _errorScenario,
  _fullConversation,
];

// ---------------------------------------------------------------------------
// 1. Approval Flow
// ---------------------------------------------------------------------------
final _approvalFlow = MockScenario(
  name: 'Approval Flow',
  icon: Icons.shield_outlined,
  description: 'Tool use requiring approval (Bash command)',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-approval-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'I need to run a command to check the project structure.'),
            const ToolUseContent(
              id: 'tool-bash-1',
              name: 'Bash',
              input: {'command': 'ls -la /project'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-bash-1',
        toolName: 'Bash',
        input: {'command': 'ls -la /project'},
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1400),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 2. AskUserQuestion
// ---------------------------------------------------------------------------
final _askUserQuestion = MockScenario(
  name: 'AskUserQuestion',
  icon: Icons.help_outline,
  description: 'Claude asks the user a question with options',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'I have a question about how to proceed.'),
            const ToolUseContent(
              id: 'tool-ask-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question': 'Which state management solution should we use?',
                    'header': 'State Mgmt',
                    'options': [
                      {
                        'label': 'Riverpod (Recommended)',
                        'description':
                            'Modern, compile-safe state management with code generation support.',
                      },
                      {
                        'label': 'BLoC',
                        'description':
                            'Pattern-based approach with streams, great for complex apps.',
                      },
                      {
                        'label': 'Provider',
                        'description':
                            'Simple and widely used, good for smaller projects.',
                      },
                    ],
                    'multiSelect': false,
                  },
                ],
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 3. Image Result
// ---------------------------------------------------------------------------
final _imageResult = MockScenario(
  name: 'Image Result',
  icon: Icons.image_outlined,
  description: 'Tool result with image references',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-img-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'Let me take a screenshot of the current state.'),
            const ToolUseContent(
              id: 'tool-screenshot-1',
              name: 'Screenshot',
              input: {},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const ToolResultMessage(
        toolUseId: 'tool-screenshot-1',
        toolName: 'Screenshot',
        content: 'Screenshot captured successfully.',
        images: [
          ImageRef(
            id: 'img-mock-1',
            url: '/images/img-mock-1',
            mimeType: 'image/png',
          ),
          ImageRef(
            id: 'img-mock-2',
            url: '/images/img-mock-2',
            mimeType: 'image/png',
          ),
        ],
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-img-2',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'Here are the screenshots. The UI looks correct '
                  'with proper layout and spacing.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2000),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 4. Streaming
// ---------------------------------------------------------------------------
final _streaming = MockScenario(
  name: 'Streaming',
  icon: Icons.stream,
  description: 'Character-by-character streaming response',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 200),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
  ],
  streamingText:
      'This is a **streaming** response from Claude. Each character appears '
      'one at a time, simulating real-time output. The streaming mechanism uses '
      '`StreamDeltaMessage` events that are accumulated into a single '
      '`AssistantServerMessage` at the end.\n\n'
      'Here is a code example:\n'
      '```dart\n'
      'void main() {\n'
      '  print("Hello, ccpocket!");\n'
      '}\n'
      '```\n\n'
      'Streaming complete!',
);

// ---------------------------------------------------------------------------
// 5. Thinking Block
// ---------------------------------------------------------------------------
final _thinkingBlock = MockScenario(
  name: 'Thinking Block',
  icon: Icons.psychology,
  description: 'Extended thinking with collapsible display',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-think-1',
          role: 'assistant',
          content: [
            const ThinkingContent(
              thinking:
                  'Let me analyze this step by step.\n\n'
                  '1. The user wants to understand the project structure.\n'
                  '2. I should look at the directory layout first.\n'
                  '3. Then examine key files like pubspec.yaml and main.dart.\n'
                  '4. I need to identify the architecture pattern being used.\n'
                  '5. Finally, I should summarize the dependencies and their purposes.\n\n'
                  'The project appears to use a standard Flutter structure with:\n'
                  '- lib/screens/ for UI screens\n'
                  '- lib/models/ for data models\n'
                  '- lib/services/ for business logic\n'
                  '- lib/widgets/ for reusable components',
            ),
            const TextContent(
              text:
                  'I\'ve analyzed the project structure. Here\'s what I found:\n\n'
                  '- **Architecture**: Clean separation with screens, models, services, and widgets\n'
                  '- **State Management**: Uses StatefulWidget with service injection\n'
                  '- **Navigation**: Standard Navigator-based routing',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: const ResultMessage(
        subtype: 'success',
        cost: 0.0089,
        duration: 2.1,
        sessionId: 'mock-session-think',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1700),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6. Plan Mode
// ---------------------------------------------------------------------------
final _planMode = MockScenario(
  name: 'Plan Mode',
  icon: Icons.assignment,
  description: 'Plan creation with approval flow',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-plan-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I\'ve analyzed the requirements. Here\'s my implementation plan:\n\n'
                  '## Phase 1: Data Layer\n'
                  '- Create `User` model class\n'
                  '- Add SQLite repository with CRUD operations\n\n'
                  '## Phase 2: UI\n'
                  '- Build `UserListScreen` with search and filtering\n'
                  '- Build `UserDetailScreen` with edit form\n\n'
                  '## Phase 3: Integration\n'
                  '- Wire up navigation between screens\n'
                  '- Add error handling and loading states',
            ),
            const ToolUseContent(
              id: 'tool-plan-exit-1',
              name: 'ExitPlanMode',
              input: {},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-plan-exit-1',
        toolName: 'ExitPlanMode',
        input: {},
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1700),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 7. Error
// ---------------------------------------------------------------------------
final _errorScenario = MockScenario(
  name: 'Error',
  icon: Icons.error_outline,
  description: 'Error message during execution',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-err-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'Let me read the configuration file.'),
            const ToolUseContent(
              id: 'tool-read-1',
              name: 'Read',
              input: {'file_path': '/nonexistent/config.yaml'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: const ErrorMessage(
        message: 'Error: ENOENT: no such file or directory, '
            'open \'/nonexistent/config.yaml\'',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2000),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 8. Full Conversation
// ---------------------------------------------------------------------------
final _fullConversation = MockScenario(
  name: 'Full Conversation',
  icon: Icons.forum_outlined,
  description: 'Complete flow: system → assistant → tool → result',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 200),
      message: const SystemMessage(
        subtype: 'init',
        sessionId: 'mock-session-full',
        model: 'claude-sonnet-4-20250514',
        projectPath: '/Users/demo/project',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 500),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-full-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I\'ll help you understand the project structure. '
                  'Let me start by reading the main entry point.',
            ),
            const ToolUseContent(
              id: 'tool-read-main',
              name: 'Read',
              input: {'file_path': 'lib/main.dart'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2000),
      message: const ToolResultMessage(
        toolUseId: 'tool-read-main',
        toolName: 'Read',
        content: 'import \'package:flutter/material.dart\';\n\n'
            'void main() {\n'
            '  runApp(const MyApp());\n'
            '}\n',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-full-2',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'The project has a standard Flutter structure. '
                  'The `main.dart` file contains the app entry point '
                  'with `runApp`. The app uses Material Design widgets.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3000),
      message: const ResultMessage(
        subtype: 'success',
        result: 'Analysis complete.',
        cost: 0.0142,
        duration: 3.5,
        sessionId: 'mock-session-full',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3200),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

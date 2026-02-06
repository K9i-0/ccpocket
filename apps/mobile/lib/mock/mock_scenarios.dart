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
  _askUserMultiQuestion,
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
            const TextContent(
              text: 'I need to run a command to check the project structure.',
            ),
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
                    'question':
                        'Which state management solution should we use?',
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
// 2b. AskUserQuestion (Multi-question)
// ---------------------------------------------------------------------------
final _askUserMultiQuestion = MockScenario(
  name: 'Multi-Question',
  icon: Icons.quiz_outlined,
  description: 'Multiple questions requiring batch answers',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-multi-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need a few decisions before proceeding.',
            ),
            const ToolUseContent(
              id: 'tool-ask-multi-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question': 'Which database should we use?',
                    'header': 'Database',
                    'options': [
                      {
                        'label': 'SQLite (Recommended)',
                        'description':
                            'Lightweight, embedded, no server needed.',
                      },
                      {
                        'label': 'PostgreSQL',
                        'description': 'Full-featured relational database.',
                      },
                    ],
                    'multiSelect': false,
                  },
                  {
                    'question': 'Which features do you want to enable?',
                    'header': 'Features',
                    'options': [
                      {
                        'label': 'Authentication',
                        'description': 'User login and registration.',
                      },
                      {
                        'label': 'Push Notifications',
                        'description': 'Firebase Cloud Messaging.',
                      },
                      {
                        'label': 'Analytics',
                        'description': 'Usage tracking and reporting.',
                      },
                    ],
                    'multiSelect': true,
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
            const TextContent(
              text: 'Let me take a screenshot of the current state.',
            ),
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
              text:
                  'Here are the screenshots. The UI looks correct '
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
  description: 'Plan creation with EnterPlanMode → ExitPlanMode approval',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    // EnterPlanMode triggers plan mode indicator
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-plan-enter',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'Let me plan the implementation before writing code.',
            ),
            const ToolUseContent(
              id: 'tool-enter-plan-1',
              name: 'EnterPlanMode',
              input: {},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
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
                  '# User Management Feature Implementation Plan\n\n'
                  '## Overview\n\n'
                  'Add a complete user management module with CRUD operations, '
                  'search/filtering, and offline support.\n\n'
                  '## Step 1: Data Layer\n\n'
                  '**Files:**\n'
                  '- `lib/models/user.dart` (new)\n'
                  '- `lib/repositories/user_repository.dart` (new)\n'
                  '- `lib/services/user_sync_service.dart` (new)\n\n'
                  '```dart\n'
                  '@freezed\n'
                  'class User with _\$User {\n'
                  '  const factory User({\n'
                  '    required String id,\n'
                  '    required String name,\n'
                  '    required String email,\n'
                  '    @Default(UserRole.member) UserRole role,\n'
                  '    DateTime? lastLoginAt,\n'
                  '  }) = _User;\n'
                  '}\n'
                  '```\n\n'
                  '## Step 2: Repository & Database\n\n'
                  '- Create SQLite table with migrations\n'
                  '- Implement `UserRepository` with CRUD + batch operations\n'
                  '- Add `UserSyncService` for offline-first sync\n\n'
                  '## Step 3: State Management\n\n'
                  '**Files:**\n'
                  '- `lib/features/users/state/user_list_notifier.dart` (new)\n'
                  '- `lib/features/users/state/user_list_state.dart` (new)\n\n'
                  '- [ ] `UserListNotifier` with pagination support\n'
                  '- [ ] Search debounce (300ms)\n'
                  '- [ ] Filter by role, status, date range\n'
                  '- [ ] Sort by name, email, last login\n\n'
                  '## Step 4: UI Screens\n\n'
                  '**Files:**\n'
                  '- `lib/features/users/user_list_screen.dart` (new)\n'
                  '- `lib/features/users/user_detail_screen.dart` (new)\n'
                  '- `lib/features/users/widgets/user_card.dart` (new)\n'
                  '- `lib/features/users/widgets/user_filter_bar.dart` (new)\n\n'
                  '### UserListScreen\n'
                  '- Infinite scroll with `Sliver` list\n'
                  '- Pull-to-refresh\n'
                  '- Search bar with real-time filtering\n'
                  '- Role filter chips\n\n'
                  '### UserDetailScreen\n'
                  '- Form validation with `FormField` widgets\n'
                  '- Avatar upload (camera + gallery)\n'
                  '- Role assignment dropdown\n'
                  '- Delete with confirmation dialog\n\n'
                  '## Step 5: Navigation & Integration\n\n'
                  '- Add `/users` route to `GoRouter`\n'
                  '- Wire up deep links\n'
                  '- Add to bottom navigation\n\n'
                  '## Step 6: Testing\n\n'
                  '| Test File | Coverage |\n'
                  '|-----------|----------|\n'
                  '| `test/models/user_test.dart` | Model serialization |\n'
                  '| `test/repositories/user_repository_test.dart` | CRUD ops |\n'
                  '| `test/features/users/user_list_screen_test.dart` | UI + state |',
            ),
            const ToolUseContent(
              id: 'tool-plan-exit-1',
              name: 'ExitPlanMode',
              input: {'plan': 'User Management Feature Implementation Plan'},
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
        input: {'plan': 'User Management Feature Implementation Plan'},
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
        message:
            'Error: ENOENT: no such file or directory, '
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
        slashCommands: [
          'compact',
          'plan',
          'clear',
          'help',
          'review',
          'context',
          'cost',
          'model',
          'status',
          'fix-issue',
          'deploy',
        ],
        skills: ['review'],
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
              text:
                  'I\'ll help you understand the project structure. '
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
        content:
            'import \'package:flutter/material.dart\';\n\n'
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
              text:
                  'The project has a standard Flutter structure. '
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

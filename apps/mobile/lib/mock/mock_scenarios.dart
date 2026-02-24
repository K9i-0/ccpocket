import 'package:flutter/material.dart';

import '../models/messages.dart';
import 'store_screenshot_data.dart';

class MockStep {
  final Duration delay;
  final ServerMessage message;

  const MockStep({required this.delay, required this.message});
}

enum MockScenarioProvider { claude, codex }

/// Section category for grouping scenarios in the preview screen.
enum MockScenarioSection {
  chat('Chat Session', Icons.chat_bubble_outline),
  sessionList('Session List', Icons.list_alt),
  storeScreenshot('Store Screenshots', Icons.photo_camera);

  final String label;
  final IconData icon;
  const MockScenarioSection(this.label, this.icon);
}

class MockScenario {
  final String name;
  final IconData icon;
  final String description;
  final List<MockStep> steps;
  final MockScenarioSection section;
  final MockScenarioProvider provider;

  /// If non-null, a streaming scenario is played after the steps.
  final String? streamingText;

  const MockScenario({
    required this.name,
    required this.icon,
    required this.description,
    required this.steps,
    this.section = MockScenarioSection.chat,
    this.provider = MockScenarioProvider.claude,
    this.streamingText,
  });
}

final List<MockScenario> mockScenarios = [
  // Chat session scenarios
  _approvalFlow,
  _multipleApprovalFlow,
  _askUserQuestion,
  _askUserSingleMultiSelect,
  _askUserMultiQuestion,
  _todoWrite,
  _imageResult,
  _streaming,
  _markdownCodeBlocks,
  _markdownMixedContent,
  _thinkingBlock,
  _planMode,
  _codexPlanApproval,
  _subagentSummary,
  _errorScenario,
  _fullConversation,
  // Session list scenarios
  _sessionListSingleQuestion,
  _sessionListMultiQuestion,
  _sessionListMultiSelect,
  _sessionListBatchApproval,
  _sessionListPlanApproval,
  _sessionListCodexPlanApproval,
  // Store screenshot scenarios
  ...storeScreenshotScenarios,
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
// 1b. Multiple Approval Flow (sequential tool approvals)
// ---------------------------------------------------------------------------
/// This scenario tests sequential tool approvals:
/// Both PermissionRequests arrive before user approves the first one.
/// After approving the first, the second dialog should appear immediately.
final _multipleApprovalFlow = MockScenario(
  name: 'Multi-Approval',
  icon: Icons.shield_moon_outlined,
  description: 'Two approvals queued (approve first → second appears)',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    // First tool use
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-multi-approval-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need to run two commands to check the project.',
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
    // First permission request
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-bash-1',
        toolName: 'Bash',
        input: {'command': 'ls -la /project'},
      ),
    ),
    // Second tool use (queued before first is approved)
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-multi-approval-2',
          role: 'assistant',
          content: [
            const TextContent(text: 'Also need to check the git status.'),
            const ToolUseContent(
              id: 'tool-bash-2',
              name: 'Bash',
              input: {'command': 'git status'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    // Second permission request (queued)
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-bash-2',
        toolName: 'Bash',
        input: {'command': 'git status'},
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1400),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
    // After user approves tool-bash-1, tool-bash-2 dialog should appear
    // automatically via _emitNextApprovalOrNone
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
            const TextContent(
              text:
                  'I found multiple approaches for implementing this. '
                  'Let me ask which one you prefer.',
            ),
            const ToolUseContent(
              id: 'tool-ask-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question':
                        'How should we handle the error recovery logic?',
                    'header': 'Approach',
                    'options': [
                      {
                        'label': 'Retry with backoff (Recommended)',
                        'description':
                            'Exponential backoff with max 3 retries. Handles transient failures gracefully.',
                      },
                      {
                        'label': 'Fail fast',
                        'description':
                            'Immediately surface the error to the user. Simpler but less resilient.',
                      },
                      {
                        'label': 'Circuit breaker',
                        'description':
                            'Track failure rate and temporarily disable requests when threshold is reached.',
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
// 2a-2. AskUserQuestion (Single question, multi-select)
// ---------------------------------------------------------------------------
final _askUserSingleMultiSelect = MockScenario(
  name: 'Single Multi-Select',
  icon: Icons.checklist,
  description: 'Single question with multi-select options',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-single-multi-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I have several improvements ready. '
                  'Let me know which ones to implement.',
            ),
            const ToolUseContent(
              id: 'tool-ask-single-multi-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question': 'Which improvements should I implement?',
                    'header': 'Tasks',
                    'options': [
                      {
                        'label': 'All of the above',
                        'description':
                            'Implement auto-reconnect, keyboard enhancement, and error handling all at once.',
                      },
                      {
                        'label': 'Auto-reconnect + error handling',
                        'description':
                            'Auto-reconnect on disconnect and H.264→JPEG fallback.',
                      },
                      {
                        'label': 'Keyboard enhancement',
                        'description':
                            'Modifier key support and iOS keyboard UI improvements.',
                      },
                      {
                        'label': 'Multi-simulator support',
                        'description':
                            'Connect to multiple simulators simultaneously from different clients.',
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
              text:
                  'Before I set up the project, I need to clarify a few things.',
            ),
            const ToolUseContent(
              id: 'tool-ask-multi-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question': 'What npm scope should we use for the package?',
                    'header': 'Scope',
                    'options': [
                      {
                        'label': '@myorg (Recommended)',
                        'description':
                            'Scoped under your organization namespace.',
                      },
                      {
                        'label': 'No scope',
                        'description':
                            'Publish as a top-level unscoped package.',
                      },
                    ],
                    'multiSelect': false,
                  },
                  {
                    'question':
                        'Which components should be included in the initial scaffold?',
                    'header': 'Components',
                    'options': [
                      {
                        'label': 'REST API',
                        'description':
                            'Express server with typed routes and middleware.',
                      },
                      {
                        'label': 'WebSocket',
                        'description':
                            'Real-time bidirectional communication layer.',
                      },
                      {
                        'label': 'CLI',
                        'description':
                            'Command-line interface with argument parsing.',
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
// 2c. TodoWrite
// ---------------------------------------------------------------------------
final _todoWrite = MockScenario(
  name: 'TodoWrite',
  icon: Icons.checklist,
  description: 'Task list with progress tracking',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-todo-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I\'ll track the implementation tasks for this feature.',
            ),
            const ToolUseContent(
              id: 'tool-todo-1',
              name: 'TodoWrite',
              input: {
                'todos': [
                  {
                    'content': 'Create todo widget',
                    'status': 'completed',
                    'activeForm': 'Creating todo widget',
                  },
                  {
                    'content': 'Add to assistant bubble',
                    'status': 'completed',
                    'activeForm': 'Adding to assistant bubble',
                  },
                  {
                    'content': 'Implement mock scenario',
                    'status': 'in_progress',
                    'activeForm': 'Implementing mock scenario',
                  },
                  {
                    'content': 'Run static analysis',
                    'status': 'pending',
                    'activeForm': 'Running static analysis',
                  },
                  {
                    'content': 'Execute tests',
                    'status': 'pending',
                    'activeForm': 'Executing tests',
                  },
                ],
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: const ToolResultMessage(
        toolUseId: 'tool-todo-1',
        toolName: 'TodoWrite',
        content: 'Todo list updated successfully.',
      ),
    ),
    // Second update: more progress
    MockStep(
      delay: const Duration(milliseconds: 2500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-todo-2',
          role: 'assistant',
          content: [
            const TextContent(text: 'Making progress on the tasks.'),
            const ToolUseContent(
              id: 'tool-todo-2',
              name: 'TodoWrite',
              input: {
                'todos': [
                  {
                    'content': 'Create todo widget',
                    'status': 'completed',
                    'activeForm': 'Creating todo widget',
                  },
                  {
                    'content': 'Add to assistant bubble',
                    'status': 'completed',
                    'activeForm': 'Adding to assistant bubble',
                  },
                  {
                    'content': 'Implement mock scenario',
                    'status': 'completed',
                    'activeForm': 'Implementing mock scenario',
                  },
                  {
                    'content': 'Run static analysis',
                    'status': 'in_progress',
                    'activeForm': 'Running static analysis',
                  },
                  {
                    'content': 'Execute tests',
                    'status': 'pending',
                    'activeForm': 'Executing tests',
                  },
                ],
              },
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
        cost: 0.0156,
        duration: 3.2,
        sessionId: 'mock-session-todo',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3200),
      message: const StatusMessage(status: ProcessStatus.idle),
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
// 4b. Markdown Code Blocks
// ---------------------------------------------------------------------------
final _markdownCodeBlocks = MockScenario(
  name: 'Markdown Code Blocks',
  icon: Icons.code,
  description:
      'Multi-language fenced blocks, aliases, and long-line readability',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 200),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 700),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-markdown-code-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Use this scenario to verify code block readability and copy behavior.\n\n'
                  '### Dart\n'
                  '```dart\n'
                  'Future<void> bootstrapApp() async {\n'
                  '  WidgetsFlutterBinding.ensureInitialized();\n'
                  '  await Firebase.initializeApp();\n'
                  '  runApp(const CcpocketApp());\n'
                  '}\n'
                  '```\n\n'
                  '### Bash\n'
                  '```bash\n'
                  'cd /Users/k9i-mini/Workspace/ccpocket && flutter test test/markdown_code_block_test.dart\n'
                  '```\n\n'
                  '### TypeScript (long line)\n'
                  '```ts\n'
                  'const result = await websocketClient.send({ type: "start", sessionId: "mock-session-markdown", projectPath: "/Users/k9i-mini/Workspace/ccpocket/apps/mobile", permissionMode: "default" });\n'
                  '```\n\n'
                  '### JavaScript alias (`js`)\n'
                  '```js\n'
                  'const started = events.filter((e) => e.type === "start");\n'
                  '```\n\n'
                  '### Python alias (`py`)\n'
                  '```py\n'
                  'def normalize_session(value: str) -> str:\n'
                  '    return value.strip().lower()\n'
                  '```\n\n'
                  '### YAML alias (`yml`)\n'
                  '```yml\n'
                  'release:\n'
                  '  platform: ios\n'
                  '  version: 1.2.3+45\n'
                  '```\n\n'
                  '### JSON\n'
                  '```json\n'
                  '{\n'
                  '  "sessionId": "mock-session-markdown",\n'
                  '  "status": "running"\n'
                  '}\n'
                  '```\n\n'
                  '### SQL\n'
                  '```sql\n'
                  'select id, title from sessions where archived = false order by updated_at desc;\n'
                  '```\n\n'
                  '### No language\n'
                  '```\n'
                  'plain text fenced block\n'
                  '- keeps spacing\n'
                  '- uses text header\n'
                  '```\n',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const ResultMessage(
        subtype: 'success',
        result: 'Markdown code block preview complete.',
        cost: 0.0042,
        duration: 1.8,
        sessionId: 'mock-session-markdown',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1400),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 4c. Markdown Mixed Content
// ---------------------------------------------------------------------------
final _markdownMixedContent = MockScenario(
  name: 'Markdown Mixed Content',
  icon: Icons.article_outlined,
  description: 'Headings, lists, table, quote, and mixed code fences',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 250),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 750),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-markdown-mixed-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  '# Markdown Render Checklist\n\n'
                  '> Validate spacing, typography, and block boundaries.\n\n'
                  '## Items\n'
                  '- [x] Heading hierarchy\n'
                  '- [x] Quote styling\n'
                  '- [x] Table and inline code (`sessionId`)\n\n'
                  '| Language | Purpose |\n'
                  '|---|---|\n'
                  '| `dart` | app startup |\n'
                  '| `bash` | commands |\n\n'
                  '```dart\n'
                  'final sessionId = "mock-markdown-mixed";\n'
                  '```\n\n'
                  '```sh\n'
                  'echo "sh should display as bash"\n'
                  '```\n',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1300),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
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
// 6b. Codex Plan Approval
// ---------------------------------------------------------------------------
final _codexPlanApproval = MockScenario(
  name: 'Codex Plan Approval',
  icon: Icons.task_alt_outlined,
  description: 'Codex ExitPlanMode approval (Reject / Accept Plan)',
  provider: MockScenarioProvider.codex,
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-codex-plan-enter',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I will draft an implementation plan before editing code.',
            ),
            const ToolUseContent(
              id: 'tool-codex-enter-plan-1',
              name: 'EnterPlanMode',
              input: {},
            ),
          ],
          model: 'gpt-5-codex',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-codex-plan-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  '## Plan\n'
                  '1. Review existing approval components and identify Claude-specific UI paths.\n'
                  '2. Split plan-approval presentation into Claude and Codex modes.\n'
                  '3. Keep Claude behavior unchanged while simplifying Codex to Reject/Accept Plan.\n'
                  '4. Validate session-list and session-screen behavior for both providers.\n'
                  '5. Run static analysis and tests.',
            ),
            const ToolUseContent(
              id: 'tool-codex-exit-plan-1',
              name: 'ExitPlanMode',
              input: {'plan': 'Codex plan approval update'},
            ),
          ],
          model: 'gpt-5-codex',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1400),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-exit-plan-1',
        toolName: 'ExitPlanMode',
        input: {'plan': 'Codex plan approval update'},
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1600),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 7. Subagent Summary (tool_use_summary)
// ---------------------------------------------------------------------------
final _subagentSummary = MockScenario(
  name: 'Subagent Summary',
  icon: Icons.smart_toy_outlined,
  description: 'Task tool with compressed subagent results',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    // Main agent starts Task tool
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-subagent-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I\'ll explore the codebase to understand its structure. '
                  'Let me launch an exploration agent.',
            ),
            const ToolUseContent(
              id: 'tool-task-1',
              name: 'Task',
              input: {
                'description': 'Explore codebase structure',
                'prompt':
                    'Explore the project directory, identify key files and architecture patterns.',
                'subagent_type': 'Explore',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    // Subagent tool results (these will be hidden by the summary)
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const ToolResultMessage(
        toolUseId: 'subagent-read-1',
        toolName: 'Read',
        content: 'lib/main.dart:\nimport \'package:flutter/material.dart\';...',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1400),
      message: const ToolResultMessage(
        toolUseId: 'subagent-glob-1',
        toolName: 'Glob',
        content: 'Found 42 files matching **/*.dart',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1600),
      message: const ToolResultMessage(
        toolUseId: 'subagent-read-2',
        toolName: 'Read',
        content: 'pubspec.yaml:\nname: my_app\nversion: 1.0.0...',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1800),
      message: const ToolResultMessage(
        toolUseId: 'subagent-grep-1',
        toolName: 'Grep',
        content: 'Found 15 matches for "class.*extends StatelessWidget"',
      ),
    ),
    // Tool use summary replaces the above tool results
    MockStep(
      delay: const Duration(milliseconds: 2200),
      message: const ToolUseSummaryMessage(
        summary:
            'Read 4 files (main.dart, pubspec.yaml, etc.), '
            'searched for widget patterns, '
            'identified 42 Dart files in the project',
        precedingToolUseIds: [
          'subagent-read-1',
          'subagent-glob-1',
          'subagent-read-2',
          'subagent-grep-1',
        ],
      ),
    ),
    // Task tool result
    MockStep(
      delay: const Duration(milliseconds: 2500),
      message: const ToolResultMessage(
        toolUseId: 'tool-task-1',
        toolName: 'Task',
        content:
            'Exploration complete. The project is a Flutter application with:\n'
            '- 42 Dart files organized in lib/\n'
            '- Feature-first architecture (features/, widgets/, models/)\n'
            '- 15 StatelessWidget components\n'
            '- Dependencies: flutter_riverpod, freezed, go_router',
      ),
    ),
    // Main agent continues
    MockStep(
      delay: const Duration(milliseconds: 3000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-subagent-2',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Based on the exploration, here\'s what I found:\n\n'
                  '**Project Structure:**\n'
                  '- 42 Dart files with feature-first architecture\n'
                  '- Uses Riverpod for state management\n'
                  '- Freezed for immutable data classes\n'
                  '- GoRouter for navigation\n\n'
                  'The codebase follows Flutter best practices with '
                  'clear separation of concerns.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3500),
      message: const ResultMessage(
        subtype: 'success',
        cost: 0.0256,
        duration: 4.2,
        sessionId: 'mock-session-subagent',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3700),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 8. Error
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

// ===========================================================================
// Session List Scenarios
// ===========================================================================

// ---------------------------------------------------------------------------
// SL-1. Single Question (most common pattern)
// ---------------------------------------------------------------------------
const _sessionListSingleQuestion = MockScenario(
  name: 'Single Question',
  icon: Icons.help_outline,
  description: 'Single-select question with (Recommended) option',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-2. PageView Multi-Question
// ---------------------------------------------------------------------------
const _sessionListMultiQuestion = MockScenario(
  name: 'PageView Multi-Question',
  icon: Icons.view_carousel_outlined,
  description: 'Multiple questions in a compact PageView within the card',
  section: MockScenarioSection.sessionList,
  steps: [], // Session list scenarios use mock SessionInfo, not steps
);

// ---------------------------------------------------------------------------
// SL-3. MultiSelect Question
// ---------------------------------------------------------------------------
const _sessionListMultiSelect = MockScenario(
  name: 'MultiSelect Question',
  icon: Icons.checklist_rtl,
  description: 'Toggle chips with Confirm button for multi-select',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-4. Batch Approval
// ---------------------------------------------------------------------------
const _sessionListBatchApproval = MockScenario(
  name: 'Batch Approval',
  icon: Icons.done_all,
  description: '3 sessions waiting for approval simultaneously',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-5. Plan Approval (ExitPlanMode)
// ---------------------------------------------------------------------------
const _sessionListPlanApproval = MockScenario(
  name: 'Plan Approval',
  icon: Icons.assignment_outlined,
  description: 'ExitPlanMode approval with Approve/Open actions',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-6. Codex Plan Approval
// ---------------------------------------------------------------------------
const _sessionListCodexPlanApproval = MockScenario(
  name: 'Codex Plan Approval',
  icon: Icons.task_alt_outlined,
  description: 'Codex ExitPlanMode approval with Reject/Approve actions',
  section: MockScenarioSection.sessionList,
  steps: [],
);

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
  settings('Settings', Icons.settings_outlined),
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
  // Chat session scenarios — Claude
  _longToolCommands,
  _longCommandApproval,
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
  _subagentSummary,
  _errorScenario,
  _authErrorScenario,
  _assistantAuthErrorScenario,
  _fullConversation,
  _longHistory,
  // Chat session scenarios — Codex
  _codexPlanApproval,
  _codexBashApprovalTwoChoices,
  _codexBashApprovalThreeChoices,
  _codexFileChangeApproval,
  _codexMcpApproval,
  _codexAskUserQuestion,
  _codexWebSearch,
  _codexFullConversation,
  // Session list scenarios — Claude
  _sessionListAllStatuses,
  _sessionListAllApprovals,
  _sessionListSingleQuestion,
  _sessionListMultiQuestion,
  _sessionListMultiSelect,
  _sessionListBatchApproval,
  _sessionListPlanApproval,
  // Session list scenarios — Codex
  _sessionListCodexPlanApproval,
  _sessionListCodexBashApprovalTwoChoices,
  _sessionListCodexBashApprovalThreeChoices,
  _sessionListCodexFileChangeApproval,
  _sessionListCodexMcpApproval,
  sessionListNewSession20Projects,
  supporterPreviewInactive,
  supporterPreviewActive,
  supporterPreviewVeteran,
  // Store screenshot scenarios
  ...storeScreenshotScenarios,
  // Standalone viewers
  imageDiffScenario,
  storeDiffLineNumberScenario,
  // File Peek
  _filePeek,
];

// ---------------------------------------------------------------------------
// 0. Long Tool Commands (expandable preview)
// ---------------------------------------------------------------------------
final _longToolCommands = MockScenario(
  name: 'Long Tool Commands',
  icon: Icons.unfold_more,
  description: 'Long commands with expandable preview (... more lines)',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    // Long Bash command (single line)
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'Let me stage all the changed files for commit.',
            ),
            const ToolUseContent(
              id: 'tool-long-bash-1',
              name: 'Bash',
              input: {
                'command':
                    'git add README.md README.ja.md apps/mobile/fastlane/metadata/en-US/description.txt apps/mobile/fastlane/metadata/ja/description.txt apps/mobile/fastlane/metadata/android/en-US/full_description.txt apps/mobile/fastlane/metadata/android/ja-JP/full_description.txt',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const ToolResultMessage(
        toolUseId: 'tool-long-bash-1',
        toolName: 'Bash',
        content: '',
      ),
    ),
    // Long Bash command (multiline piped)
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-2',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Now let me search for all Dart files that reference ToolUseTile.',
            ),
            const ToolUseContent(
              id: 'tool-long-bash-2',
              name: 'Bash',
              input: {
                'command':
                    'find /Users/k9i-mini/Workspace/ccpocket \\\n'
                    '  -name "*.dart" \\\n'
                    '  -not -path "*/build/*" \\\n'
                    '  -not -path "*/.dart_tool/*" \\\n'
                    '  -not -path "*/generated/*" \\\n'
                    '  | xargs grep -l "ToolUseTile" \\\n'
                    '  | sort \\\n'
                    '  | head -20',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1800),
      message: const ToolResultMessage(
        toolUseId: 'tool-long-bash-2',
        toolName: 'Bash',
        content:
            '/Users/k9i-mini/Workspace/ccpocket/apps/mobile/lib/widgets/bubbles/assistant_bubble.dart\n'
            '/Users/k9i-mini/Workspace/ccpocket/apps/mobile/test/tool_use_tile_test.dart\n'
            '/Users/k9i-mini/Workspace/ccpocket/apps/mobile/lib/mock/mock_scenarios.dart',
      ),
    ),
    // Grep with multiple parameters
    MockStep(
      delay: const Duration(milliseconds: 2000),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-3',
          role: 'assistant',
          content: [
            const TextContent(text: 'Let me search for the expansion pattern.'),
            const ToolUseContent(
              id: 'tool-long-grep',
              name: 'Grep',
              input: {
                'pattern': r'enum\s+Tool(Use|Result)Expansion\s*\{',
                'path': '/Users/k9i-mini/Workspace/ccpocket/apps/mobile/lib',
                'glob': '**/*.dart',
                'type': 'dart',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2400),
      message: const ToolResultMessage(
        toolUseId: 'tool-long-grep',
        toolName: 'Grep',
        content:
            'lib/widgets/bubbles/assistant_bubble.dart:275:enum ToolUseExpansion { collapsed, preview, expanded }\n'
            'lib/widgets/bubbles/tool_result_bubble.dart:15:enum ToolResultExpansion { collapsed, preview, expanded }',
      ),
    ),
    // Short Read for contrast
    MockStep(
      delay: const Duration(milliseconds: 2600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-4',
          role: 'assistant',
          content: [
            const TextContent(text: 'Let me check the file.'),
            const ToolUseContent(
              id: 'tool-long-read',
              name: 'Read',
              input: {'file_path': 'lib/main.dart'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2800),
      message: const ToolResultMessage(
        toolUseId: 'tool-long-read',
        toolName: 'Read',
        content: 'void main() {\n  runApp(const MyApp());\n}',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3200),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-5',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Found the expansion enums. Both ToolUseTile and ToolResultBubble '
                  'now support three-state expansion: collapsed, preview, and expanded.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3400),
      message: const ResultMessage(
        subtype: 'success',
        cost: 0.0234,
        duration: 5.1,
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3500),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 0b. Long Command Approval (expandable summary in approval UI)
// ---------------------------------------------------------------------------
final _longCommandApproval = MockScenario(
  name: 'Long Cmd Approval',
  icon: Icons.unfold_more_double,
  description: 'Approval with a very long command (expandable summary)',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-long-approval-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need to stage all the changed metadata files.',
            ),
            const ToolUseContent(
              id: 'tool-long-approval-bash',
              name: 'Bash',
              input: {
                'command':
                    'git add README.md README.ja.md apps/mobile/fastlane/metadata/en-US/description.txt apps/mobile/fastlane/metadata/ja/description.txt apps/mobile/fastlane/metadata/android/en-US/full_description.txt apps/mobile/fastlane/metadata/android/ja-JP/full_description.txt',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-long-approval-bash',
        toolName: 'Bash',
        input: {
          'command':
              'git add README.md README.ja.md apps/mobile/fastlane/metadata/en-US/description.txt apps/mobile/fastlane/metadata/ja/description.txt apps/mobile/fastlane/metadata/android/en-US/full_description.txt apps/mobile/fastlane/metadata/android/ja-JP/full_description.txt',
        },
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

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
    // --- Dummy conversation to make chat area scrollable ---
    MockStep(
      delay: const Duration(milliseconds: 500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-pre-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I\'ll start by analyzing the current error handling implementation '
                  'in your codebase. Let me look at the relevant files.',
            ),
            const ToolUseContent(
              id: 'tool-ask-pre-read-1',
              name: 'Read',
              input: {'file_path': 'lib/services/api_client.dart'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 700),
      message: const ToolResultMessage(
        toolUseId: 'tool-ask-pre-read-1',
        toolName: 'Read',
        content:
            'class ApiClient {\n'
            '  final HttpClient _client;\n'
            '  Future<Response> get(String path) async {\n'
            '    try {\n'
            '      return await _client.get(path);\n'
            '    } catch (e) {\n'
            '      throw ApiException(e.toString());\n'
            '    }\n'
            '  }\n'
            '}',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 900),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-pre-2',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I can see the current implementation simply catches errors and rethrows them. '
                  'Let me also check how errors are handled upstream.',
            ),
            const ToolUseContent(
              id: 'tool-ask-pre-grep-1',
              name: 'Grep',
              input: {
                'pattern': 'ApiException',
                'path': 'lib/',
                'glob': '**/*.dart',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1100),
      message: const ToolResultMessage(
        toolUseId: 'tool-ask-pre-grep-1',
        toolName: 'Grep',
        content:
            'lib/services/api_client.dart:8:      throw ApiException(e.toString());\n'
            'lib/providers/data_provider.dart:23:    } on ApiException catch (e) {\n'
            'lib/providers/data_provider.dart:24:      state = AsyncError(e, StackTrace.current);\n'
            'lib/screens/home_screen.dart:45:  // TODO: handle ApiException',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1300),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ask-pre-3',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I found 3 places where `ApiException` is referenced. The error handling '
                  'is inconsistent — `data_provider.dart` catches it but `home_screen.dart` has '
                  'a TODO comment. There are several approaches we could take to improve this.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    // --- End dummy conversation ---
    MockStep(
      delay: const Duration(milliseconds: 1500),
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
    // --- Dummy conversation to make chat area scrollable ---
    MockStep(
      delay: const Duration(milliseconds: 500),
      message: const UserInputMessage(text: 'VNCビューアの改善点を洗い出して、優先度をつけて'),
    ),
    MockStep(
      delay: const Duration(milliseconds: 700),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ms-pre-1',
          role: 'assistant',
          content: [
            const TextContent(text: 'VNCビューアの現在の実装を確認します。まず関連ファイルを見てみましょう。'),
            const ToolUseContent(
              id: 'tool-ms-pre-glob-1',
              name: 'Glob',
              input: {'pattern': 'lib/**/vnc*.dart'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 900),
      message: const ToolResultMessage(
        toolUseId: 'tool-ms-pre-glob-1',
        toolName: 'Glob',
        content:
            'lib/features/vnc/vnc_viewer_screen.dart\n'
            'lib/features/vnc/vnc_connection.dart\n'
            'lib/features/vnc/vnc_input_handler.dart',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1100),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ms-pre-2',
          role: 'assistant',
          content: [
            const TextContent(text: 'VNCビューアの実装を読みます。'),
            const ToolUseContent(
              id: 'tool-ms-pre-read-1',
              name: 'Read',
              input: {'file_path': 'lib/features/vnc/vnc_viewer_screen.dart'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1300),
      message: const ToolResultMessage(
        toolUseId: 'tool-ms-pre-read-1',
        toolName: 'Read',
        content:
            'class VncViewerScreen extends StatefulWidget {\n'
            '  // ... 250 lines of VNC viewer implementation\n'
            '  // Current issues:\n'
            '  // - No auto-reconnect on disconnect\n'
            '  // - Keyboard input limited to basic keys\n'
            '  // - Single simulator only\n'
            '  // - No error recovery for codec failures\n'
            '}',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-ms-pre-3',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'コードを分析した結果、以下の改善点を特定しました：\n\n'
                  '1. **Auto-reconnect** — 切断時の自動再接続がない\n'
                  '2. **Keyboard enhancement** — 修飾キー（Cmd, Ctrl等）未対応\n'
                  '3. **Error handling** — H.264デコード失敗時のフォールバックなし\n'
                  '4. **Multi-simulator** — 同時接続は1台のみ\n\n'
                  'どれを実装するか選んでください。',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    // --- End dummy conversation ---
    MockStep(
      delay: const Duration(milliseconds: 1700),
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
                  {
                    'content': 'E2E verification',
                    'status': 'pending',
                    'activeForm': 'Running E2E verification',
                  },
                  {
                    'content': 'Self review',
                    'status': 'pending',
                    'activeForm': 'Running self review',
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
                  {
                    'content': 'E2E verification',
                    'status': 'pending',
                    'activeForm': 'Running E2E verification',
                  },
                  {
                    'content': 'Self review',
                    'status': 'pending',
                    'activeForm': 'Running self review',
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
// 6c. Codex Bash Approval (2 choices)
// ---------------------------------------------------------------------------
final _codexBashApprovalTwoChoices = MockScenario(
  name: 'Codex Bash Approval (2 Choices)',
  icon: Icons.terminal,
  description: 'Codex command execution approval with accept / reject only',
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
          id: 'mock-codex-bash-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need to run the test suite to verify the changes.',
            ),
            const ToolUseContent(
              id: 'tool-codex-bash-1',
              name: 'Bash',
              input: {
                'command': 'cd apps/mobile && flutter test test/widgets/',
                'cwd': '/Users/demo/Workspace/ccpocket',
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-bash-2',
        toolName: 'Bash',
        input: {
          'command': 'cd apps/mobile && flutter test test/widgets/',
          'cwd': '/Users/demo/Workspace/ccpocket',
          'availableDecisions': ['accept', 'decline'],
        },
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6d. Codex Bash Approval (3 choices)
// ---------------------------------------------------------------------------
final _codexBashApprovalThreeChoices = MockScenario(
  name: 'Codex Bash Approval (3 Choices)',
  icon: Icons.terminal,
  description: 'Codex command execution approval with session reuse option',
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
          id: 'mock-codex-bash-3',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need to run the test suite and may need to repeat it.',
            ),
            const ToolUseContent(
              id: 'tool-codex-bash-3',
              name: 'Bash',
              input: {
                'command': 'cd apps/mobile && flutter test test/widgets/',
                'cwd': '/Users/demo/Workspace/ccpocket',
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-bash-3',
        toolName: 'Bash',
        input: {
          'command': 'cd apps/mobile && flutter test test/widgets/',
          'cwd': '/Users/demo/Workspace/ccpocket',
          'availableDecisions': ['accept', 'acceptForSession', 'decline'],
        },
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6e. Codex FileChange Approval
// ---------------------------------------------------------------------------
final _codexFileChangeApproval = MockScenario(
  name: 'Codex FileChange Approval',
  icon: Icons.insert_drive_file_outlined,
  description: 'Codex file change approval with changes array',
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
          id: 'mock-codex-fc-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I will update the pubspec.yaml to add the new dependency.',
            ),
            const ToolUseContent(
              id: 'tool-codex-fc-1',
              name: 'FileChange',
              input: {
                'changes': [
                  {
                    'file': 'apps/mobile/pubspec.yaml',
                    'description': 'Add http package dependency',
                  },
                ],
                'reason': 'Adding http package for API client implementation',
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-fc-1',
        toolName: 'FileChange',
        input: {
          'changes': [
            {
              'file': 'apps/mobile/pubspec.yaml',
              'description': 'Add http package dependency',
            },
          ],
          'reason': 'Adding http package for API client implementation',
        },
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6f. Codex MCP Tool Approval (AskUserQuestion → ApprovalBar)
// ---------------------------------------------------------------------------
final _codexMcpApproval = MockScenario(
  name: 'Codex MCP Approval',
  icon: Icons.extension_outlined,
  description: 'MCP tool approval shown as ApprovalBar (not dialog)',
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
          id: 'mock-codex-mcp-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'I need to use an MCP tool to read the project files.',
            ),
            const ToolUseContent(
              id: 'tool-codex-mcp-1',
              name: 'McpElicitation',
              input: {
                'questions': [
                  {
                    'question':
                        'Tool call: filesystem.readFile(path: "/src/main.ts")',
                    'header': 'Approve app tool call?',
                    'options': [
                      {
                        'label': 'Allow',
                        'description': 'Run the tool and continue.',
                      },
                      {
                        'label': 'Allow for this session',
                        'description':
                            'Run the tool and remember this choice for this session.',
                      },
                      {
                        'label': 'Always allow',
                        'description':
                            'Run the tool and remember this choice for future tool calls.',
                      },
                      {
                        'label': 'Cancel',
                        'description': 'Cancel this tool call.',
                      },
                    ],
                    'multiSelect': false,
                  },
                ],
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-mcp-1',
        toolName: 'McpElicitation',
        input: {
          'questions': [
            {
              'question':
                  'Tool call: filesystem.readFile(path: "/src/main.ts")',
              'header': 'Approve app tool call?',
              'options': [
                {'label': 'Allow', 'description': 'Run the tool and continue.'},
                {
                  'label': 'Allow for this session',
                  'description':
                      'Run the tool and remember this choice for this session.',
                },
                {
                  'label': 'Always allow',
                  'description':
                      'Run the tool and remember this choice for future tool calls.',
                },
                {'label': 'Cancel', 'description': 'Cancel this tool call.'},
              ],
              'multiSelect': false,
            },
          ],
        },
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6f. Codex AskUserQuestion (non-MCP)
// ---------------------------------------------------------------------------
final _codexAskUserQuestion = MockScenario(
  name: 'Codex AskUserQuestion',
  icon: Icons.help_center_outlined,
  description: 'Codex question dialog (not MCP approval)',
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
          id: 'mock-codex-ask-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I found two possible approaches for the refactoring. '
                  'Which one do you prefer?',
            ),
            const ToolUseContent(
              id: 'tool-codex-ask-1',
              name: 'AskUserQuestion',
              input: {
                'questions': [
                  {
                    'question':
                        'Which refactoring approach should I use for the state management?',
                    'header': 'Approach',
                    'options': [
                      {
                        'label': 'BLoC pattern (Recommended)',
                        'description':
                            'Use BLoC/Cubit with Freezed states for predictable state management.',
                      },
                      {
                        'label': 'Riverpod',
                        'description':
                            'Use Riverpod providers for a more functional approach.',
                      },
                      {
                        'label': 'Keep current',
                        'description':
                            'Keep the existing StatefulWidget approach.',
                      },
                    ],
                    'multiSelect': false,
                  },
                ],
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6g. Codex Web Search
// ---------------------------------------------------------------------------
final _codexWebSearch = MockScenario(
  name: 'Codex Web Search',
  icon: Icons.travel_explore,
  description: 'Web search tool execution and result',
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
          id: 'mock-codex-ws-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Let me search for the latest Flutter testing best practices.',
            ),
            const ToolUseContent(
              id: 'tool-codex-ws-1',
              name: 'WebSearch',
              input: {'query': 'Flutter widget testing best practices 2025'},
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1200),
      message: const ToolResultMessage(
        toolUseId: 'tool-codex-ws-1',
        toolName: 'WebSearch',
        content:
            '1. flutter.dev - Widget testing guide\n'
            '2. medium.com - Advanced Flutter testing patterns\n'
            '3. github.com/flutter - Testing cookbook examples',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-codex-ws-2',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'Based on the search results, here are the key testing practices:\n\n'
                  '- Use `testWidgets` for widget tests with `WidgetTester`\n'
                  '- Prefer `pumpWidget` + `pumpAndSettle` for async operations\n'
                  '- Use `find.byKey` for reliable element selection',
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2200),
      message: const ResultMessage(
        subtype: 'success',
        cost: 0.0085,
        duration: 2.8,
        sessionId: 'mock-session-codex-ws',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2400),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

// ---------------------------------------------------------------------------
// 6h. Codex Full Conversation
// ---------------------------------------------------------------------------
final _codexFullConversation = MockScenario(
  name: 'Codex Full Conversation',
  icon: Icons.forum,
  description: 'Complete Codex flow: init → bash approval → result',
  provider: MockScenarioProvider.codex,
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 200),
      message: const SystemMessage(
        subtype: 'init',
        sessionId: 'mock-session-codex-full',
        model: 'o3',
        projectPath: '/Users/demo/project',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 500),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 900),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-codex-full-1',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I\'ll start by checking the project structure '
                  'and running the existing tests.',
            ),
            const ToolUseContent(
              id: 'tool-codex-full-bash-1',
              name: 'Bash',
              input: {
                'command': 'ls -la && npm test',
                'cwd': '/Users/demo/project',
              },
            ),
          ],
          model: 'o3',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1300),
      message: const PermissionRequestMessage(
        toolUseId: 'tool-codex-full-bash-1',
        toolName: 'Bash',
        input: {'command': 'ls -la && npm test', 'cwd': '/Users/demo/project'},
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: const StatusMessage(status: ProcessStatus.waitingApproval),
    ),
    // After approval, the tool result and completion would follow
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
// 7b. Auth Error (structured error with Help button)
// ---------------------------------------------------------------------------
final _authErrorScenario = MockScenario(
  name: 'Auth Error',
  icon: Icons.lock_outline,
  description: 'Authentication error with help & settings buttons',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: const ErrorMessage(
        message:
            'Claude Code authentication failed\n\n'
            'OAuth token refresh failed: invalid_grant\n\n'
            'Run "claude auth login" on the Bridge machine to re-authenticate.',
        errorCode: 'auth_login_required',
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

final _assistantAuthErrorScenario = MockScenario(
  name: 'Assistant Auth Error',
  icon: Icons.lock_clock_outlined,
  description:
      'Auth failure delivered as assistant text should still use auth UI',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    MockStep(
      delay: const Duration(milliseconds: 800),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-auth-assistant',
          role: 'assistant',
          content: [
            TextContent(
              text:
                  'Failed to authenticate. API Error: 401\n'
                  '{"type":"error","error":{"type":"authentication_error","message":"OAuth token has expired. Please obtain a new token or refresh your existing token."}}',
            ),
          ],
          model: 'claude-opus-4-6',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 1000),
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

// ---------------------------------------------------------------------------
// Long History (chunked loading test — 50+ entries)
// ---------------------------------------------------------------------------

/// Generates 50+ chat entries to test chunked loading (initial 30 + scroll).
/// Simulates a realistic long refactoring session with multiple rounds of
/// read → edit → test cycles.
final _longHistory = MockScenario(
  name: 'Long History (50+)',
  icon: Icons.history,
  description: 'Long conversation (50+ entries) for chunked loading test',
  steps: [
    const MockStep(
      delay: Duration(milliseconds: 100),
      message: SystemMessage(
        subtype: 'init',
        sessionId: 'mock-session-long',
        model: 'claude-sonnet-4-20250514',
        projectPath: '/Users/demo/project',
        slashCommands: ['compact', 'plan', 'clear'],
        skills: [],
      ),
    ),
    const MockStep(
      delay: Duration(milliseconds: 200),
      message: StatusMessage(status: ProcessStatus.running),
    ),
    // --- Round 1: Read project structure ---
    MockStep(
      delay: const Duration(milliseconds: 300),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'long-1',
          role: 'assistant',
          content: [
            const TextContent(
              text: 'Let me start by understanding the project structure.',
            ),
            const ToolUseContent(
              id: 'tool-long-read-1',
              name: 'Bash',
              input: {'command': 'find lib -name "*.dart" | head -20'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    const MockStep(
      delay: Duration(milliseconds: 400),
      message: ToolResultMessage(
        toolUseId: 'tool-long-read-1',
        toolName: 'Bash',
        content:
            'lib/main.dart\nlib/app.dart\nlib/router.dart\n'
            'lib/models/user.dart\nlib/models/session.dart\n'
            'lib/services/api_service.dart\nlib/services/auth_service.dart\n'
            'lib/screens/home_screen.dart\nlib/screens/login_screen.dart\n'
            'lib/widgets/user_card.dart',
      ),
    ),
    // --- Round 2-15: Repeated read/edit/test cycles ---
    ..._generateLongHistoryRounds(2, 14),
    // --- Final round ---
    MockStep(
      delay: const Duration(milliseconds: 500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'long-final',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  '## Summary\n\n'
                  'All refactoring tasks are complete:\n\n'
                  '- Migrated 14 files to the new architecture\n'
                  '- Updated all imports and references\n'
                  '- All 47 tests passing\n'
                  '- No analyzer warnings\n\n'
                  'The codebase is now using the feature-first pattern consistently.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    const MockStep(
      delay: Duration(milliseconds: 600),
      message: ResultMessage(
        subtype: 'success',
        result: 'Refactoring complete.',
        cost: 0.2847,
        duration: 142.5,
        sessionId: 'mock-session-long',
      ),
    ),
    const MockStep(
      delay: Duration(milliseconds: 700),
      message: StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

/// Generate repeated read→edit→test rounds for long history.
List<MockStep> _generateLongHistoryRounds(int start, int count) {
  final steps = <MockStep>[];
  final files = [
    'lib/models/user.dart',
    'lib/models/session.dart',
    'lib/services/api_service.dart',
    'lib/services/auth_service.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/widgets/user_card.dart',
    'lib/widgets/session_tile.dart',
    'lib/utils/validators.dart',
    'lib/utils/formatters.dart',
    'lib/providers/auth_provider.dart',
    'lib/providers/theme_provider.dart',
    'lib/config/routes.dart',
  ];

  for (var i = 0; i < count; i++) {
    final round = start + i;
    final file = files[i % files.length];
    final fileName = file.split('/').last;

    // Assistant reads the file
    steps.add(
      MockStep(
        delay: Duration(milliseconds: 300 + round * 10),
        message: AssistantServerMessage(
          message: AssistantMessage(
            id: 'long-r$round-read',
            role: 'assistant',
            content: [
              TextContent(text: 'Reading `$fileName` to plan the migration.'),
              ToolUseContent(
                id: 'tool-long-r$round-read',
                name: 'Read',
                input: {'file_path': file},
              ),
            ],
            model: 'claude-sonnet-4-20250514',
          ),
        ),
      ),
    );

    // Tool result
    steps.add(
      MockStep(
        delay: Duration(milliseconds: 400 + round * 10),
        message: ToolResultMessage(
          toolUseId: 'tool-long-r$round-read',
          toolName: 'Read',
          content:
              '// $fileName\nimport \'package:flutter/material.dart\';\n\n'
              'class ${fileName.replaceAll('.dart', '').split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join()} {\n'
              '  // TODO: migrate to feature-first\n'
              '}\n',
        ),
      ),
    );

    // Assistant edits the file
    steps.add(
      MockStep(
        delay: Duration(milliseconds: 500 + round * 10),
        message: AssistantServerMessage(
          message: AssistantMessage(
            id: 'long-r$round-edit',
            role: 'assistant',
            content: [
              TextContent(
                text: 'Migrating `$fileName` to the feature-first pattern.',
              ),
              ToolUseContent(
                id: 'tool-long-r$round-edit',
                name: 'Edit',
                input: {
                  'file_path': file,
                  'old_string': '// TODO: migrate to feature-first',
                  'new_string': '// Migrated to feature-first pattern ✓',
                },
              ),
            ],
            model: 'claude-sonnet-4-20250514',
          ),
        ),
      ),
    );

    // Edit result
    steps.add(
      MockStep(
        delay: Duration(milliseconds: 600 + round * 10),
        message: ToolResultMessage(
          toolUseId: 'tool-long-r$round-edit',
          toolName: 'Edit',
          content: 'File edited successfully.',
        ),
      ),
    );
  }
  return steps;
}

// ===========================================================================
// Session List Scenarios
// ===========================================================================

// ---------------------------------------------------------------------------
// SL-1. Single Question (most common pattern)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// SL-0a. All Statuses
// ---------------------------------------------------------------------------
const _sessionListAllStatuses = MockScenario(
  name: 'All Statuses',
  icon: Icons.palette_outlined,
  description: 'Every session status variant in one view',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-0b. All Approval UIs
// ---------------------------------------------------------------------------
const _sessionListAllApprovals = MockScenario(
  name: 'All Approval UIs',
  icon: Icons.approval_outlined,
  description: 'Every approval UI variant (tool, ask, plan) in one view',
  section: MockScenarioSection.sessionList,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-1. Single Question
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
  provider: MockScenarioProvider.codex,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-7. Codex Bash Approval (2 choices)
// ---------------------------------------------------------------------------
const _sessionListCodexBashApprovalTwoChoices = MockScenario(
  name: 'Codex Bash Approval (2 Choices)',
  icon: Icons.terminal,
  description: 'Codex Bash command approval in session list with 2 actions',
  section: MockScenarioSection.sessionList,
  provider: MockScenarioProvider.codex,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-8. Codex Bash Approval (3 choices)
// ---------------------------------------------------------------------------
const _sessionListCodexBashApprovalThreeChoices = MockScenario(
  name: 'Codex Bash Approval (3 Choices)',
  icon: Icons.terminal,
  description: 'Codex Bash command approval in session list with 3 actions',
  section: MockScenarioSection.sessionList,
  provider: MockScenarioProvider.codex,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-9. Codex FileChange Approval
// ---------------------------------------------------------------------------
const _sessionListCodexFileChangeApproval = MockScenario(
  name: 'Codex FileChange Approval',
  icon: Icons.insert_drive_file_outlined,
  description: 'Codex file change approval in session list',
  section: MockScenarioSection.sessionList,
  provider: MockScenarioProvider.codex,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-10. Codex MCP Approval
// ---------------------------------------------------------------------------
const _sessionListCodexMcpApproval = MockScenario(
  name: 'Codex MCP Approval',
  icon: Icons.extension_outlined,
  description: 'Codex MCP tool approval (ApprovalBar) in session list',
  section: MockScenarioSection.sessionList,
  provider: MockScenarioProvider.codex,
  steps: [],
);

// ---------------------------------------------------------------------------
// SL-11. New Session (20 Projects)
// ---------------------------------------------------------------------------
const sessionListNewSession20Projects = MockScenario(
  name: 'New Session (20 Projects)',
  icon: Icons.folder_copy_outlined,
  description: 'New session sheet with 20 projects to test expandable history',
  section: MockScenarioSection.sessionList,
  steps: [],
);

const supporterPreviewInactive = MockScenario(
  name: 'Supporter (Inactive)',
  icon: Icons.favorite_border,
  description: 'Support section with products visible before any purchase',
  section: MockScenarioSection.settings,
  steps: [],
);

const supporterPreviewActive = MockScenario(
  name: 'Supporter (Active)',
  icon: Icons.favorite,
  description: 'Active monthly supporter with a few one-time supports',
  section: MockScenarioSection.settings,
  steps: [],
);

const supporterPreviewVeteran = MockScenario(
  name: 'Supporter (Veteran)',
  icon: Icons.workspace_premium,
  description: 'Long-running supporter with heavier one-time support history',
  section: MockScenarioSection.settings,
  steps: [],
);

// ---------------------------------------------------------------------------
// Standalone: Image Diff Viewer
// ---------------------------------------------------------------------------
const imageDiffScenario = MockScenario(
  name: 'Image Diff',
  icon: Icons.compare,
  description: 'Full-screen image diff viewer with Slider / Toggle / Overlay',
  section: MockScenarioSection.chat,
  steps: [],
);

// ---------------------------------------------------------------------------
// File Peek: tappable file paths in assistant messages
// ---------------------------------------------------------------------------
final _filePeek = MockScenario(
  name: 'File Peek',
  icon: Icons.description_outlined,
  description: 'Tappable file paths in messages (tap to view content)',
  steps: [
    MockStep(
      delay: const Duration(milliseconds: 200),
      message: const StatusMessage(status: ProcessStatus.running),
    ),
    // First message: editing Dart files
    MockStep(
      delay: const Duration(milliseconds: 600),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-file-peek-1',
          role: 'assistant',
          content: [
            const ToolUseContent(
              id: 'tool-edit-1',
              name: 'Edit',
              input: {
                'file_path': 'lib/main.dart',
                'old_string': 'const MyApp()',
                'new_string': 'const MyApp(title: "Hello")',
              },
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 900),
      message: const ToolResultMessage(
        toolUseId: 'tool-edit-1',
        content: 'Successfully edited lib/main.dart',
        toolName: 'Edit',
      ),
    ),
    // Second message: mentions multiple file paths in text
    MockStep(
      delay: const Duration(milliseconds: 1500),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-file-peek-2',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'I\'ve updated the app entry point. Here\'s a summary of changes:\n\n'
                  '1. Modified `lib/main.dart` to add the title parameter\n'
                  '2. The config is defined in `pubspec.yaml`\n'
                  '3. Bridge server entry point is at `packages/bridge/src/index.ts`\n'
                  '4. See `README.md` for documentation\n\n'
                  'You can also check `package.json` for the npm scripts configuration.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    // Third message: read tool result with file path
    MockStep(
      delay: const Duration(milliseconds: 2200),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-file-peek-3',
          role: 'assistant',
          content: [
            const ToolUseContent(
              id: 'tool-read-1',
              name: 'Read',
              input: {'file_path': 'docs/architecture.md'},
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 2500),
      message: const ToolResultMessage(
        toolUseId: 'tool-read-1',
        content:
            '# Architecture\n\nThe app uses a Bridge Server pattern...\n'
            '(200 lines)',
        toolName: 'Read',
      ),
    ),
    // Final summary
    MockStep(
      delay: const Duration(milliseconds: 3200),
      message: AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-file-peek-4',
          role: 'assistant',
          content: [
            const TextContent(
              text:
                  'The architecture docs in `docs/architecture.md` confirm the pattern. '
                  'I also verified the test setup in `test/widget_test.dart`.\n\n'
                  'Everything looks good! The changes are consistent with the '
                  'project structure defined in `pubspec.yaml`.\n\n'
                  'I also updated the authentication configuration at '
                  '`apps/mobile/lib/features/connection/widgets/authentication_connection_settings_dialog.dart`.',
            ),
          ],
          model: 'claude-sonnet-4-20250514',
        ),
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3500),
      message: ResultMessage(
        subtype: 'success',
        cost: 0.0156,
        duration: 3.5,
        inputTokens: 12500,
        outputTokens: 850,
      ),
    ),
    MockStep(
      delay: const Duration(milliseconds: 3700),
      message: const StatusMessage(status: ProcessStatus.idle),
    ),
  ],
);

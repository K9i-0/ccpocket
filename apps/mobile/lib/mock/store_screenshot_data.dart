import 'package:flutter/material.dart';

import '../models/messages.dart';
import 'mock_scenarios.dart';

// =============================================================================
// Store Screenshot Scenarios
// =============================================================================

final storeSessionListScenario = MockScenario(
  name: 'Session List',
  icon: Icons.home_outlined,
  description: 'Home screen with running + recent sessions',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final storeChatCodingScenario = MockScenario(
  name: 'Coding Session',
  icon: Icons.code,
  description: 'Feature implementation with file edits',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final storeChatTaskScenario = MockScenario(
  name: 'Task Planning',
  icon: Icons.checklist,
  description: 'Refactoring with thinking + TodoWrite',
  steps: [],
  section: MockScenarioSection.storeScreenshot,
);

final List<MockScenario> storeScreenshotScenarios = [
  storeSessionListScenario,
  storeChatCodingScenario,
  storeChatTaskScenario,
];

// =============================================================================
// Running Sessions (for Session List screenshot)
// =============================================================================

List<SessionInfo> storeRunningSessions() => [
  SessionInfo(
    id: 'store-run-1',
    provider: 'claude',
    projectPath: '/Users/dev/projects/shopify-app',
    status: 'running',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toIso8601String(),
    gitBranch: 'feat/checkout-redesign',
    lastMessage:
        'Implementing the new checkout flow with Stripe integration...',
    messageCount: 34,
  ),
  SessionInfo(
    id: 'store-run-2',
    provider: 'codex',
    projectPath: '/Users/dev/projects/rust-cli',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 30))
        .toIso8601String(),
    gitBranch: 'feat/parser',
    lastMessage: 'Running the test suite to verify parser changes.',
    messageCount: 18,
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-tool-1',
      toolName: 'Bash',
      input: {'command': 'cargo test --release'},
    ),
  ),
  SessionInfo(
    id: 'store-run-3',
    provider: 'claude',
    projectPath: '/Users/dev/projects/my-portfolio',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String(),
    gitBranch: 'feat/dark-mode',
    lastMessage: 'Which color palette should I use for the dark mode?',
    messageCount: 12,
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'store-ask-1',
      toolName: 'AskUserQuestion',
      input: {
        'questions': [
          {
            'question': 'Which color palette should I use for the dark mode?',
            'header': 'Theme',
            'options': [
              {
                'label': 'Nord (Recommended)',
                'description':
                    'Cool blue-gray tones. Popular for developer tools and IDEs.',
              },
              {
                'label': 'Dracula',
                'description':
                    'Deep purple with vivid accents. High contrast and eye-friendly.',
              },
              {
                'label': 'One Dark',
                'description':
                    'Warm neutral palette from Atom editor. Balanced readability.',
              },
            ],
            'multiSelect': false,
          },
        ],
      },
    ),
  ),
];

// =============================================================================
// Recent Sessions (for Session List screenshot)
// =============================================================================

List<RecentSession> storeRecentSessions() => [
  RecentSession(
    sessionId: 'store-recent-1',
    provider: 'claude',
    summary: 'Add product search with Algolia integration',
    firstPrompt: 'Integrate Algolia search into the product listing page',
    messageCount: 45,
    created: DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    gitBranch: 'feat/search',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-2',
    provider: 'claude',
    summary: 'Fix WebSocket reconnection on network change',
    firstPrompt: 'WebSocket drops when switching from WiFi to cellular',
    messageCount: 22,
    created: DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    gitBranch: 'fix/ws-reconnect',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-3',
    provider: 'codex',
    summary: 'Implement streaming JSON parser for large files',
    firstPrompt: 'Add a streaming JSON parser that handles files over 1GB',
    messageCount: 53,
    created: DateTime.now()
        .subtract(const Duration(hours: 6))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    gitBranch: 'feat/json-parser',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-4',
    provider: 'claude',
    summary: 'Set up CI/CD pipeline with GitHub Actions',
    firstPrompt: 'Create a CI/CD pipeline for build, test, and deploy',
    messageCount: 31,
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    gitBranch: 'chore/ci-cd',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-5',
    provider: 'claude',
    summary: 'Refactor auth module to use OAuth 2.0 PKCE flow',
    firstPrompt: 'Migrate the authentication from session-based to OAuth 2.0',
    messageCount: 67,
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 8))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 6))
        .toIso8601String(),
    gitBranch: 'refactor/auth-oauth2',
    projectPath: '/Users/dev/projects/shopify-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-6',
    provider: 'codex',
    summary: 'Write unit tests for CLI argument parser',
    firstPrompt: 'Add comprehensive tests for the argument parsing module',
    messageCount: 19,
    created: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 18))
        .toIso8601String(),
    gitBranch: 'test/cli-args',
    projectPath: '/Users/dev/projects/rust-cli',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'store-recent-7',
    provider: 'claude',
    summary: 'Add responsive layout for tablet and desktop',
    firstPrompt: 'Make the app responsive across phone, tablet, and desktop',
    messageCount: 41,
    created: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 2, hours: 12))
        .toIso8601String(),
    gitBranch: 'feat/responsive',
    projectPath: '/Users/dev/projects/my-portfolio',
    isSidechain: false,
  ),
];

// =============================================================================
// Chat History: Coding Session
// =============================================================================

/// A realistic coding session where the user asks to add a dark mode toggle.
/// Shows: user input → file read → file edits → completion summary → result.
final List<ServerMessage> storeChatCodingSession = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-coding',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Add a dark mode toggle to the settings page. '
        'Use the existing ThemeProvider and persist the preference.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a1',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "I'll implement the dark mode toggle. Let me check your current theme setup first.",
        ),
        const ToolUseContent(
          id: 'store-r1',
          name: 'Read',
          input: {'file_path': 'lib/theme/theme_provider.dart'},
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-r1',
    toolName: 'Read',
    content:
        'class ThemeProvider extends ChangeNotifier {\n'
        '  ThemeMode _mode = ThemeMode.system;\n'
        '  ThemeMode get mode => _mode;\n'
        '\n'
        '  void setThemeMode(ThemeMode mode) {\n'
        '    _mode = mode;\n'
        '    notifyListeners();\n'
        '  }\n'
        '}',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a2',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "Found the ThemeProvider. I'll add persistence with SharedPreferences and a toggle method.",
        ),
        const ToolUseContent(
          id: 'store-e1',
          name: 'Edit',
          input: {
            'file_path': 'lib/theme/theme_provider.dart',
            'old_string':
                '  void setThemeMode(ThemeMode mode) {\n'
                '    _mode = mode;\n'
                '    notifyListeners();\n'
                '  }',
            'new_string':
                '  Future<void> setThemeMode(ThemeMode mode) async {\n'
                '    _mode = mode;\n'
                '    notifyListeners();\n'
                "    final prefs = await SharedPreferences.getInstance();\n"
                "    await prefs.setString('theme_mode', mode.name);\n"
                '  }\n'
                '\n'
                '  void toggle() {\n'
                '    setThemeMode(\n'
                '      _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,\n'
                '    );\n'
                '  }',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e1',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a3',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Now I'll add the toggle switch to the settings screen.",
        ),
        const ToolUseContent(
          id: 'store-e2',
          name: 'Edit',
          input: {
            'file_path': 'lib/screens/settings_screen.dart',
            'old_string': '    // Theme section',
            'new_string':
                '    SwitchListTile(\n'
                "      title: const Text('Dark Mode'),\n"
                "      subtitle: Text(isDark ? 'On' : 'Off'),\n"
                '      secondary: Icon(\n'
                '        isDark ? Icons.dark_mode : Icons.light_mode,\n'
                '      ),\n'
                '      value: isDark,\n'
                '      onChanged: (_) => themeProvider.toggle(),\n'
                '    ),',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e2',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-a4',
      role: 'assistant',
      content: [
        const TextContent(
          text:
              "Done! Here's what I changed:\n\n"
              "**`lib/theme/theme_provider.dart`**\n"
              "- Added `toggle()` convenience method\n"
              "- Added SharedPreferences persistence in `setThemeMode()`\n\n"
              "**`lib/screens/settings_screen.dart`**\n"
              "- Added `SwitchListTile` with dark/light mode icon\n"
              "- Wired to ThemeProvider's toggle method\n\n"
              "The user's preference is now persisted across app restarts.",
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ResultMessage(
    subtype: 'success',
    cost: 0.0234,
    duration: 12800,
    sessionId: 'store-chat-coding',
    inputTokens: 15420,
    outputTokens: 2830,
  ),
  const StatusMessage(status: ProcessStatus.idle),
];

// =============================================================================
// Chat History: Task Planning
// =============================================================================

/// A session showing thinking + TodoWrite + edits for an OAuth refactor.
final List<ServerMessage> storeChatTaskPlanning = [
  const SystemMessage(
    subtype: 'init',
    sessionId: 'store-chat-task',
    model: 'claude-sonnet-4-20250514',
    projectPath: '/Users/dev/projects/shopify-app',
  ),
  const StatusMessage(status: ProcessStatus.running),
  const UserInputMessage(
    text:
        'Refactor the authentication module to use OAuth 2.0 with PKCE. '
        'Keep backward compatibility with existing sessions.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t1',
      role: 'assistant',
      content: [
        const ThinkingContent(
          thinking:
              "This is a significant refactor. I need to:\n"
              "1. Understand the current session-based auth flow\n"
              "2. Design the OAuth 2.0 PKCE implementation\n"
              "3. Ensure backward compatibility with existing sessions\n"
              "4. Update token storage and refresh logic\n\n"
              "The PKCE flow requires: authorization endpoint, token endpoint, "
              "code verifier/challenge generation, and secure token storage. "
              "I should use the existing SecureStorage service for tokens.\n\n"
              "For backward compatibility, I'll add a migration path that "
              "converts existing session tokens to OAuth tokens on first use.",
        ),
        const TextContent(
          text:
              "I'll refactor the auth module to OAuth 2.0 PKCE. Let me start by reviewing the current implementation and planning the migration.",
        ),
        const ToolUseContent(
          id: 'store-todo-1',
          name: 'TodoWrite',
          input: {
            'todos': [
              {
                'content': 'Review current auth implementation',
                'status': 'completed',
              },
              {
                'content': 'Implement PKCE code verifier/challenge',
                'status': 'completed',
              },
              {'content': 'Create OAuth token manager', 'status': 'completed'},
              {
                'content': 'Add token refresh with retry logic',
                'status': 'in_progress',
                'activeForm': 'Adding token refresh logic',
              },
              {
                'content': 'Migrate existing sessions to OAuth tokens',
                'status': 'pending',
              },
              {
                'content': 'Update API client interceptors',
                'status': 'pending',
              },
              {'content': 'Write integration tests', 'status': 'pending'},
            ],
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-todo-1',
    toolName: 'TodoWrite',
    content: 'Todo list updated successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t2',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Creating the PKCE helper and OAuth token manager.",
        ),
        const ToolUseContent(
          id: 'store-w1',
          name: 'Write',
          input: {
            'file_path': 'lib/auth/pkce.dart',
            'content':
                "import 'dart:convert';\n"
                "import 'dart:math';\n"
                "import 'package:crypto/crypto.dart';\n\n"
                "class PKCE {\n"
                "  final String verifier;\n"
                "  final String challenge;\n\n"
                "  PKCE._(this.verifier, this.challenge);\n\n"
                "  factory PKCE.generate() {\n"
                "    final random = Random.secure();\n"
                "    final bytes = List.generate(32, (_) => random.nextInt(256));\n"
                "    final verifier = base64Url.encode(bytes);\n"
                "    final digest = sha256.convert(utf8.encode(verifier));\n"
                "    final challenge = base64Url.encode(digest.bytes);\n"
                "    return PKCE._(verifier, challenge);\n"
                "  }\n"
                "}\n",
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-w1',
    toolName: 'Write',
    content: 'File created successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t3',
      role: 'assistant',
      content: [
        const TextContent(
          text: "Now updating the token refresh logic with automatic retry.",
        ),
        const ToolUseContent(
          id: 'store-e3',
          name: 'Edit',
          input: {
            'file_path': 'lib/auth/token_manager.dart',
            'old_string': '  Future<String> getAccessToken() async {',
            'new_string':
                '  Future<String> getAccessToken({int retries = 3}) async {',
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-e3',
    toolName: 'Edit',
    content: 'File edited successfully.',
  ),
  AssistantServerMessage(
    message: AssistantMessage(
      id: 'store-t4',
      role: 'assistant',
      content: [
        const ToolUseContent(
          id: 'store-todo-2',
          name: 'TodoWrite',
          input: {
            'todos': [
              {
                'content': 'Review current auth implementation',
                'status': 'completed',
              },
              {
                'content': 'Implement PKCE code verifier/challenge',
                'status': 'completed',
              },
              {'content': 'Create OAuth token manager', 'status': 'completed'},
              {
                'content': 'Add token refresh with retry logic',
                'status': 'completed',
              },
              {
                'content': 'Migrate existing sessions to OAuth tokens',
                'status': 'in_progress',
                'activeForm': 'Migrating existing sessions',
              },
              {
                'content': 'Update API client interceptors',
                'status': 'pending',
              },
              {'content': 'Write integration tests', 'status': 'pending'},
            ],
          },
        ),
      ],
      model: 'claude-sonnet-4-20250514',
    ),
  ),
  const ToolResultMessage(
    toolUseId: 'store-todo-2',
    toolName: 'TodoWrite',
    content: 'Todo list updated successfully.',
  ),
  const StatusMessage(status: ProcessStatus.running),
];

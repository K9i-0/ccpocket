import '../models/messages.dart';

/// Mock recent sessions for testing project filter and picker UI.
/// 3 projects × 2-3 sessions = 8 total sessions.
final List<RecentSession> mockRecentSessions = [
  RecentSession(
    sessionId: 'mock-sess-1',
    summary: 'Implement slash command improvements',
    firstPrompt: 'スラッシュコマンド改善',
    messageCount: 42,
    created: DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(minutes: 30))
        .toIso8601String(),
    gitBranch: 'feat/slash-commands',
    projectPath: '/Users/demo/Workspace/ccpocket',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-2',
    summary: 'Fix WebSocket reconnection bug',
    firstPrompt: 'WebSocket reconnection issue',
    messageCount: 18,
    created: DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String(),
    gitBranch: 'fix/ws-reconnect',
    projectPath: '/Users/demo/Workspace/ccpocket',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-3',
    summary: 'Add dark mode support',
    firstPrompt: 'ダークモード対応して',
    messageCount: 65,
    created: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 4))
        .toIso8601String(),
    gitBranch: 'feat/dark-mode',
    projectPath: '/Users/demo/Workspace/my-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-4',
    summary: 'Setup CI/CD pipeline with GitHub Actions',
    firstPrompt: 'Set up CI/CD',
    messageCount: 25,
    created: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(hours: 20))
        .toIso8601String(),
    gitBranch: 'chore/ci-cd',
    projectPath: '/Users/demo/Workspace/my-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-5',
    summary: 'Refactor auth module',
    firstPrompt: '認証モジュールのリファクタ',
    messageCount: 31,
    created: DateTime.now()
        .subtract(const Duration(days: 1, hours: 2))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 1))
        .toIso8601String(),
    gitBranch: 'refactor/auth',
    projectPath: '/Users/demo/Workspace/my-app',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-6',
    summary: 'Add JSON parser with streaming support',
    firstPrompt: 'Implement streaming JSON parser',
    messageCount: 53,
    created: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 1, hours: 20))
        .toIso8601String(),
    gitBranch: 'feat/json-parser',
    projectPath: '/Users/demo/Workspace/cli-tool',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-7',
    summary: 'Write unit tests for CLI arguments',
    firstPrompt: 'テスト書いて',
    messageCount: 15,
    created: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(days: 2, hours: 12))
        .toIso8601String(),
    gitBranch: 'test/cli-args',
    projectPath: '/Users/demo/Workspace/cli-tool',
    isSidechain: false,
  ),
  RecentSession(
    sessionId: 'mock-sess-8',
    summary: 'Home screen UI improvements',
    firstPrompt: 'ホーム画面の改善',
    messageCount: 8,
    created: DateTime.now()
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    modified: DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toIso8601String(),
    gitBranch: 'feat/home-screen',
    projectPath: '/Users/demo/Workspace/ccpocket',
    isSidechain: false,
  ),
];

// ---------------------------------------------------------------------------
// Mock running sessions for session-list approval UI prototyping
// ---------------------------------------------------------------------------

/// Session with a multi-question AskUserQuestion pending.
SessionInfo mockSessionMultiQuestion() => SessionInfo(
  id: 'mock-running-mq',
  provider: 'claude',
  projectPath: '/Users/demo/Workspace/my-app',
  status: 'waiting_approval',
  createdAt: DateTime.now()
      .subtract(const Duration(minutes: 10))
      .toIso8601String(),
  lastActivityAt: DateTime.now()
      .subtract(const Duration(seconds: 30))
      .toIso8601String(),
  gitBranch: 'feat/user-mgmt',
  lastMessage: 'I need a few decisions before proceeding.',
  messageCount: 12,
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-ask-mq-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question': 'Which database should we use?',
          'header': 'Database',
          'options': [
            {
              'label': 'SQLite (Recommended)',
              'description': 'Lightweight, embedded, no server needed.',
            },
            {
              'label': 'PostgreSQL',
              'description': 'Full-featured relational database.',
            },
            {
              'label': 'MongoDB',
              'description': 'Document-oriented NoSQL database.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question': 'Which authentication method?',
          'header': 'Auth',
          'options': [
            {
              'label': 'JWT (Recommended)',
              'description': 'Stateless token-based auth.',
            },
            {
              'label': 'Session Cookie',
              'description': 'Traditional server-side sessions.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question': 'Target platforms?',
          'header': 'Platforms',
          'options': [
            {'label': 'iOS', 'description': 'Apple iOS devices.'},
            {'label': 'Android', 'description': 'Android devices.'},
            {'label': 'Web', 'description': 'Web browsers.'},
          ],
          'multiSelect': true,
        },
      ],
    },
  ),
);

/// Session with a single multiSelect AskUserQuestion pending.
SessionInfo mockSessionMultiSelect() => SessionInfo(
  id: 'mock-running-ms',
  provider: 'claude',
  projectPath: '/Users/demo/Workspace/ccpocket',
  status: 'waiting_approval',
  createdAt: DateTime.now()
      .subtract(const Duration(minutes: 5))
      .toIso8601String(),
  lastActivityAt: DateTime.now()
      .subtract(const Duration(seconds: 15))
      .toIso8601String(),
  gitBranch: 'feat/settings',
  lastMessage: 'Which features do you want to enable?',
  messageCount: 8,
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-ask-ms-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
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
            {'label': 'Dark Mode', 'description': 'Dark theme support.'},
          ],
          'multiSelect': true,
        },
      ],
    },
  ),
);

/// Sessions waiting for tool approval (for batch approval demo).
List<SessionInfo> mockSessionsBatchApproval() => [
  SessionInfo(
    id: 'mock-running-ba-1',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 20))
        .toIso8601String(),
    gitBranch: 'feat/api',
    lastMessage: 'Running npm test to verify changes.',
    messageCount: 15,
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-bash-ba-1',
      toolName: 'Bash',
      input: {'command': 'npm test'},
    ),
  ),
  SessionInfo(
    id: 'mock-running-ba-2',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/ccpocket',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 12))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 10))
        .toIso8601String(),
    gitBranch: 'fix/build',
    lastMessage: 'Need to edit the config file.',
    messageCount: 22,
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-edit-ba-2',
      toolName: 'Edit',
      input: {'file_path': 'lib/config.dart'},
    ),
  ),
  SessionInfo(
    id: 'mock-running-ba-3',
    provider: 'codex',
    projectPath: '/Users/demo/Workspace/cli-tool',
    status: 'waiting_approval',
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 3))
        .toIso8601String(),
    lastActivityAt: DateTime.now()
        .subtract(const Duration(seconds: 5))
        .toIso8601String(),
    gitBranch: 'feat/parser',
    lastMessage: 'Checking git status before commit.',
    messageCount: 7,
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-bash-ba-3',
      toolName: 'Bash',
      input: {'command': 'git status && git diff --stat'},
    ),
  ),
];

import '../models/messages.dart';

/// Mock recent sessions for testing project filter and picker UI.
/// 3 projects × 2-3 sessions = 8 total sessions.
final List<RecentSession> mockRecentSessions = [
  RecentSession(
    sessionId: 'mock-sess-1',
    summary: 'Implement slash command improvements',
    firstPrompt: 'スラッシュコマンド改善',

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
/// Based on real patterns: project setup decisions (architecture, deployment,
/// package scope).
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
  gitBranch: 'feat/ci-setup',
  lastMessage: 'I have a few questions about how to set up the CI/CD pipeline.',
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-ask-mq-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question':
              'Which architecture pattern should we use for the new module?',
          'header': 'Architecture',
          'options': [
            {
              'label': 'Feature-first (Recommended)',
              'description':
                  'Group by feature with co-located state, widgets, and models.',
            },
            {
              'label': 'Layer-first',
              'description':
                  'Group by layer (screens/, models/, services/) across features.',
            },
            {
              'label': 'Hybrid',
              'description':
                  'Feature-first for complex features, shared layer for common code.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question': 'How should we handle the deployment?',
          'header': 'Deploy',
          'options': [
            {
              'label': 'GitHub Actions (Recommended)',
              'description':
                  'CI/CD with GitHub Actions workflow. Free for public repos.',
            },
            {
              'label': 'Codemagic',
              'description':
                  'Flutter-focused CI/CD with built-in code signing.',
            },
          ],
          'multiSelect': false,
        },
        {
          'question':
              'Which platforms should we target for the initial release?',
          'header': 'Platforms',
          'options': [
            {'label': 'iOS', 'description': 'iOS with App Store distribution.'},
            {
              'label': 'Android',
              'description': 'Android with Play Store distribution.',
            },
            {
              'label': 'Web',
              'description': 'Web deployment via Firebase Hosting.',
            },
          ],
          'multiSelect': true,
        },
      ],
    },
  ),
);

/// Session with a single multiSelect AskUserQuestion pending.
/// Based on real patterns: selecting target areas for a refactor or fix.
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
  gitBranch: 'refactor/ui-cleanup',
  lastMessage: 'Which areas should I update to use the new design tokens?',
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-ask-ms-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question':
              'Which areas should I update to use the new design tokens?',
          'header': 'Scope',
          'options': [
            {
              'label': 'AppBar & Navigation',
              'description': 'Top bar, bottom nav, drawer headers.',
            },
            {
              'label': 'Card Components',
              'description': 'Session cards, detail cards, list tiles.',
            },
            {
              'label': 'Form Inputs',
              'description': 'Text fields, dropdowns, toggle switches.',
            },
            {
              'label': 'All of the above',
              'description': 'Apply design tokens across the entire app.',
            },
          ],
          'multiSelect': true,
        },
      ],
    },
  ),
);

/// Sessions waiting for tool approval (for batch approval demo).
/// Based on real patterns: test execution, file editing, git operations.
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
    lastMessage: 'Running tests to verify the API changes.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-bash-ba-1',
      toolName: 'Bash',
      input: {'command': 'cd apps/mobile && flutter test test/services/'},
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
    lastMessage: 'Need to update the pubspec.yaml dependencies.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-edit-ba-2',
      toolName: 'Edit',
      input: {
        'file_path': 'apps/mobile/pubspec.yaml',
        'old_string': "  http: ^1.1.0",
        'new_string': "  http: ^1.2.1",
      },
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
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-bash-ba-3',
      toolName: 'Bash',
      input: {'command': 'git diff --stat HEAD'},
    ),
  ),
];

// ---------------------------------------------------------------------------
// Mock single-question AskUserQuestion session
// ---------------------------------------------------------------------------

/// Session with a single-question single-select AskUserQuestion pending.
/// The most common real-world pattern: a simple choice with (Recommended).
SessionInfo mockSessionSingleQuestion() => SessionInfo(
  id: 'mock-running-sq',
  provider: 'claude',
  projectPath: '/Users/demo/Workspace/my-app',
  status: 'waiting_approval',
  createdAt: DateTime.now()
      .subtract(const Duration(minutes: 7))
      .toIso8601String(),
  lastActivityAt: DateTime.now()
      .subtract(const Duration(seconds: 12))
      .toIso8601String(),
  gitBranch: 'feat/config',
  lastMessage: 'How should we structure the configuration?',
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-ask-sq-1',
    toolName: 'AskUserQuestion',
    input: {
      'questions': [
        {
          'question':
              'How should we structure the configuration for this project?',
          'header': 'Config',
          'options': [
            {
              'label': 'YAML file (Recommended)',
              'description':
                  'Human-readable config in config.yaml with environment overrides.',
            },
            {
              'label': 'Environment variables',
              'description':
                  'Twelve-factor style config via .env file and process.env.',
            },
            {
              'label': 'JSON with schema',
              'description': 'Typed JSON config with JSON Schema validation.',
            },
          ],
          'multiSelect': false,
        },
      ],
    },
  ),
);

// ---------------------------------------------------------------------------
// Mock ExitPlanMode session
// ---------------------------------------------------------------------------

/// Session with an ExitPlanMode pending (plan review approval).
SessionInfo mockSessionPlanApproval() => SessionInfo(
  id: 'mock-running-plan',
  provider: 'claude',
  projectPath: '/Users/demo/Workspace/my-app',
  status: 'waiting_approval',
  createdAt: DateTime.now()
      .subtract(const Duration(minutes: 15))
      .toIso8601String(),
  lastActivityAt: DateTime.now()
      .subtract(const Duration(seconds: 45))
      .toIso8601String(),
  gitBranch: 'feat/notifications',
  lastMessage: 'I\'ve designed the implementation plan for push notifications.',
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-plan-exit-1',
    toolName: 'ExitPlanMode',
    input: {'plan': 'Push Notification Implementation Plan'},
  ),
);

// ---------------------------------------------------------------------------
// All statuses scenario — every visual status in one list
// ---------------------------------------------------------------------------

/// All session status variants for visual confirmation.
/// Covers: Running, Running+Plan, Compacting, NeedsYou (tool/ask/plan),
/// Ready, Ready+Plan.
List<SessionInfo> mockSessionsAllStatuses() => [
  // Working — running
  SessionInfo(
    id: 'mock-status-running',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'running',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 3)).toIso8601String(),
    gitBranch: 'feat/api',
    lastMessage: 'Implementing the new REST API endpoints.',
  ),
  // Working — running + Plan badge
  SessionInfo(
    id: 'mock-status-running-plan',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'running',
    permissionMode: 'plan',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String(),
    gitBranch: 'feat/auth',
    lastMessage: 'Designing the authentication flow.',
  ),
  // Working — compacting
  SessionInfo(
    id: 'mock-status-compacting',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/ccpocket',
    status: 'compacting',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 5)).toIso8601String(),
    gitBranch: 'feat/long-session',
    lastMessage: 'Summarizing conversation context.',
  ),
  // Needs You — tool approval
  SessionInfo(
    id: 'mock-status-tool-approval',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'waiting_approval',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 8)).toIso8601String(),
    gitBranch: 'feat/tests',
    lastMessage: 'Running the test suite.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-status-bash',
      toolName: 'Bash',
      input: {'command': 'flutter test'},
    ),
  ),
  // Needs You — AskUserQuestion
  SessionInfo(
    id: 'mock-status-ask',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'waiting_approval',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 15)).toIso8601String(),
    gitBranch: 'feat/config',
    lastMessage: 'Which database should we use?',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-status-ask',
      toolName: 'AskUserQuestion',
      input: {
        'questions': [
          {
            'question': 'Which database should we use?',
            'header': 'DB',
            'options': [
              {'label': 'SQLite', 'description': 'Local embedded database.'},
              {'label': 'PostgreSQL', 'description': 'Full relational DB.'},
            ],
            'multiSelect': false,
          },
        ],
      },
    ),
  ),
  // Needs You — ExitPlanMode
  SessionInfo(
    id: 'mock-status-plan',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/ccpocket',
    status: 'waiting_approval',
    permissionMode: 'plan',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 30)).toIso8601String(),
    gitBranch: 'feat/refactor',
    lastMessage: 'Plan is ready for review.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-status-plan',
      toolName: 'ExitPlanMode',
      input: {'plan': 'Refactor plan'},
    ),
  ),
  // Ready — idle
  SessionInfo(
    id: 'mock-status-idle',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/cli-tool',
    status: 'idle',
    createdAt:
        DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
    gitBranch: 'main',
    lastMessage: 'All tasks completed successfully.',
  ),
  // Ready — idle + Plan badge
  SessionInfo(
    id: 'mock-status-idle-plan',
    provider: 'codex',
    projectPath: '/Users/demo/Workspace/cli-tool',
    status: 'idle',
    permissionMode: 'plan',
    createdAt:
        DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    gitBranch: 'feat/parser',
    lastMessage: 'Finished implementing the parser.',
  ),
];

// ---------------------------------------------------------------------------
// All approval UIs scenario — every approval variant in one list
// ---------------------------------------------------------------------------

/// All approval UI variants for visual confirmation.
/// Covers: Tool (Bash), Tool (Edit), AskUser single, AskUser multi-select,
/// AskUser multi-question, ExitPlanMode (Claude), ExitPlanMode (Codex).
List<SessionInfo> mockSessionsAllApprovals() => [
  // Tool approval — Bash
  SessionInfo(
    id: 'mock-approval-bash',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/my-app',
    status: 'waiting_approval',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 5)).toIso8601String(),
    gitBranch: 'feat/deploy',
    lastMessage: 'Deploying to staging environment.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-all-bash',
      toolName: 'Bash',
      input: {'command': 'npm run deploy:staging'},
    ),
  ),
  // Tool approval — Edit
  SessionInfo(
    id: 'mock-approval-edit',
    provider: 'claude',
    projectPath: '/Users/demo/Workspace/ccpocket',
    status: 'waiting_approval',
    createdAt:
        DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
    lastActivityAt:
        DateTime.now().subtract(const Duration(seconds: 8)).toIso8601String(),
    gitBranch: 'fix/typo',
    lastMessage: 'Fixing a typo in the README.',
    pendingPermission: const PermissionRequestMessage(
      toolUseId: 'tool-all-edit',
      toolName: 'Edit',
      input: {
        'file_path': 'README.md',
        'old_string': 'recieve',
        'new_string': 'receive',
      },
    ),
  ),
  // AskUser — single select
  mockSessionSingleQuestion(),
  // AskUser — multi select
  mockSessionMultiSelect(),
  // AskUser — multi question
  mockSessionMultiQuestion(),
  // Plan approval — Claude
  mockSessionPlanApproval(),
  // Plan approval — Codex
  mockSessionCodexPlanApproval(),
];

/// Session with an ExitPlanMode pending for Codex.
/// Used to verify Codex-specific plan approval UI in session list.
SessionInfo mockSessionCodexPlanApproval() => SessionInfo(
  id: 'mock-running-codex-plan',
  provider: 'codex',
  projectPath: '/Users/demo/Workspace/ccpocket',
  status: 'waiting_approval',
  createdAt: DateTime.now()
      .subtract(const Duration(minutes: 11))
      .toIso8601String(),
  lastActivityAt: DateTime.now()
      .subtract(const Duration(seconds: 20))
      .toIso8601String(),
  gitBranch: 'feat/codex-plan-ui',
  lastMessage: 'I drafted the plan and need your approval before coding.',
  codexModel: 'gpt-5-codex',
  codexSandboxMode: 'workspace-write',
  codexApprovalPolicy: 'on-request',
  pendingPermission: const PermissionRequestMessage(
    toolUseId: 'tool-codex-plan-exit-1',
    toolName: 'ExitPlanMode',
    input: {'plan': 'Codex plan approval update'},
  ),
);

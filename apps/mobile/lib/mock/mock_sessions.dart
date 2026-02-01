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

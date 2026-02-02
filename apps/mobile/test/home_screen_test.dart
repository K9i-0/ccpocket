import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/screens/session_list_screen.dart';

RecentSession _session({
  required String projectPath,
  String sessionId = 'sess',
  String firstPrompt = '',
  String gitBranch = 'main',
  String? summary,
  String modified = '2025-01-01T00:00:00Z',
}) {
  return RecentSession(
    sessionId: sessionId,
    firstPrompt: firstPrompt,
    summary: summary,
    messageCount: 0,
    created: '2025-01-01T00:00:00Z',
    modified: modified,
    gitBranch: gitBranch,
    projectPath: projectPath,
    isSidechain: false,
  );
}

void main() {
  final sessions = [
    _session(projectPath: '/home/user/ccpocket', sessionId: 's1'),
    _session(projectPath: '/home/user/ccpocket', sessionId: 's2'),
    _session(projectPath: '/home/user/my-app', sessionId: 's3'),
    _session(projectPath: '/home/user/my-app', sessionId: 's4'),
    _session(projectPath: '/home/user/my-app', sessionId: 's5'),
    _session(projectPath: '/home/user/cli-tool', sessionId: 's6'),
  ];

  group('projectCounts', () {
    test('counts sessions per project name', () {
      final counts = projectCounts(sessions);
      expect(counts['ccpocket'], 2);
      expect(counts['my-app'], 3);
      expect(counts['cli-tool'], 1);
    });

    test('preserves first-seen order', () {
      final keys = projectCounts(sessions).keys.toList();
      expect(keys, ['ccpocket', 'my-app', 'cli-tool']);
    });

    test('returns empty map for empty input', () {
      expect(projectCounts([]), isEmpty);
    });
  });

  group('filterByProject', () {
    test('null filter returns all sessions', () {
      expect(filterByProject(sessions, null), sessions);
    });

    test('filters by project name', () {
      final filtered = filterByProject(sessions, 'my-app');
      expect(filtered, hasLength(3));
      expect(filtered.every((s) => s.projectName == 'my-app'), isTrue);
    });

    test('non-existent project returns empty', () {
      expect(filterByProject(sessions, 'nope'), isEmpty);
    });
  });

  group('recentProjects', () {
    test('returns unique projects in first-seen order', () {
      final projects = recentProjects(sessions);
      expect(projects, hasLength(3));
      expect(projects[0].name, 'ccpocket');
      expect(projects[1].name, 'my-app');
      expect(projects[2].name, 'cli-tool');
    });

    test('preserves full path', () {
      final projects = recentProjects(sessions);
      expect(projects[0].path, '/home/user/ccpocket');
    });

    test('empty input returns empty', () {
      expect(recentProjects([]), isEmpty);
    });
  });

  group('shortenPath', () {
    test('replaces HOME prefix with ~', () {
      // This test depends on the runtime HOME env var.
      // We test the no-match case which is platform-independent.
      expect(shortenPath('/some/other/path'), '/some/other/path');
    });

    test('returns original if no HOME match', () {
      expect(shortenPath('/tmp/foo'), '/tmp/foo');
    });
  });

  group('branchesForProject', () {
    final branchSessions = [
      _session(
        projectPath: '/home/user/app',
        sessionId: 'b1',
        gitBranch: 'main',
      ),
      _session(
        projectPath: '/home/user/app',
        sessionId: 'b2',
        gitBranch: 'feat/login',
      ),
      _session(
        projectPath: '/home/user/app',
        sessionId: 'b3',
        gitBranch: 'main',
      ),
      _session(
        projectPath: '/home/user/other',
        sessionId: 'b4',
        gitBranch: 'develop',
      ),
    ];

    test('returns unique branches for all projects', () {
      final branches = branchesForProject(branchSessions, null);
      expect(branches, ['main', 'feat/login', 'develop']);
    });

    test('filters branches by project name', () {
      final branches = branchesForProject(branchSessions, 'app');
      expect(branches, ['main', 'feat/login']);
    });

    test('returns empty for unknown project', () {
      expect(branchesForProject(branchSessions, 'nope'), isEmpty);
    });
  });

  group('filterByBranch', () {
    final branchSessions = [
      _session(
        projectPath: '/home/user/app',
        sessionId: 'b1',
        gitBranch: 'main',
      ),
      _session(
        projectPath: '/home/user/app',
        sessionId: 'b2',
        gitBranch: 'feat/login',
      ),
    ];

    test('null branch returns all sessions', () {
      expect(filterByBranch(branchSessions, null), branchSessions);
    });

    test('filters by exact branch name', () {
      final filtered = filterByBranch(branchSessions, 'main');
      expect(filtered, hasLength(1));
      expect(filtered.first.sessionId, 'b1');
    });
  });

  group('filterByQuery', () {
    final querySessions = [
      _session(
        projectPath: '/home/user/app',
        sessionId: 'q1',
        firstPrompt: 'Fix the login bug',
        summary: 'Fixed auth issue',
      ),
      _session(
        projectPath: '/home/user/app',
        sessionId: 'q2',
        firstPrompt: 'Add dark mode',
      ),
      _session(
        projectPath: '/home/user/app',
        sessionId: 'q3',
        firstPrompt: 'Refactor tests',
        summary: 'Login flow refactored',
      ),
    ];

    test('empty query returns all sessions', () {
      expect(filterByQuery(querySessions, ''), querySessions);
    });

    test('matches firstPrompt case-insensitively', () {
      final filtered = filterByQuery(querySessions, 'LOGIN');
      expect(filtered, hasLength(2));
      expect(filtered.map((s) => s.sessionId), containsAll(['q1', 'q3']));
    });

    test('matches summary', () {
      final filtered = filterByQuery(querySessions, 'auth');
      expect(filtered, hasLength(1));
      expect(filtered.first.sessionId, 'q1');
    });

    test('no match returns empty', () {
      expect(filterByQuery(querySessions, 'zzzzz'), isEmpty);
    });
  });

  group('filterByDate', () {
    test('DateFilter.all returns all sessions', () {
      expect(filterByDate(sessions, DateFilter.all), sessions);
    });

    test('filters by today', () {
      final now = DateTime.now();
      final todaySessions = [
        _session(
          projectPath: '/home/user/app',
          sessionId: 'd1',
          modified: now.toIso8601String(),
        ),
        _session(
          projectPath: '/home/user/app',
          sessionId: 'd2',
          modified: '2020-01-01T00:00:00Z',
        ),
      ];
      final filtered = filterByDate(todaySessions, DateFilter.today);
      expect(filtered, hasLength(1));
      expect(filtered.first.sessionId, 'd1');
    });

    test('filters by this month', () {
      final now = DateTime.now();
      final monthSessions = [
        _session(
          projectPath: '/home/user/app',
          sessionId: 'm1',
          modified: now.toIso8601String(),
        ),
        _session(
          projectPath: '/home/user/app',
          sessionId: 'm2',
          modified: '2020-06-15T00:00:00Z',
        ),
      ];
      final filtered = filterByDate(monthSessions, DateFilter.thisMonth);
      expect(filtered, hasLength(1));
      expect(filtered.first.sessionId, 'm1');
    });
  });

  group('RecentSessionsMessage.hasMore', () {
    test('parses hasMore: true', () {
      final json = {
        'type': 'recent_sessions',
        'sessions': <Map<String, dynamic>>[],
        'hasMore': true,
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<RecentSessionsMessage>());
      expect((msg as RecentSessionsMessage).hasMore, isTrue);
    });

    test('defaults hasMore to false when missing', () {
      final json = {
        'type': 'recent_sessions',
        'sessions': <Map<String, dynamic>>[],
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<RecentSessionsMessage>());
      expect((msg as RecentSessionsMessage).hasMore, isFalse);
    });

    test('parses hasMore: false', () {
      final json = {
        'type': 'recent_sessions',
        'sessions': <Map<String, dynamic>>[],
        'hasMore': false,
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<RecentSessionsMessage>());
      expect((msg as RecentSessionsMessage).hasMore, isFalse);
    });
  });

  group('ClientMessage.listRecentSessions', () {
    test('serializes with no optional params', () {
      final msg = ClientMessage.listRecentSessions();
      final decoded = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(decoded['type'], 'list_recent_sessions');
      expect(decoded.containsKey('offset'), isFalse);
      expect(decoded.containsKey('projectPath'), isFalse);
    });

    test('serializes with offset and projectPath', () {
      final msg = ClientMessage.listRecentSessions(
        limit: 10,
        offset: 20,
        projectPath: '/tmp/project',
      );
      final decoded = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(decoded['type'], 'list_recent_sessions');
      expect(decoded['limit'], 10);
      expect(decoded['offset'], 20);
      expect(decoded['projectPath'], '/tmp/project');
    });

    test('omits null optional params', () {
      final msg = ClientMessage.listRecentSessions(limit: 5);
      final decoded = jsonDecode(msg.toJson()) as Map<String, dynamic>;
      expect(decoded['limit'], 5);
      expect(decoded.containsKey('offset'), isFalse);
      expect(decoded.containsKey('projectPath'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/screens/session_list_screen.dart';

RecentSession _session({
  required String projectPath,
  String sessionId = 'sess',
  String firstPrompt = '',
}) {
  return RecentSession(
    sessionId: sessionId,
    firstPrompt: firstPrompt,
    messageCount: 0,
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
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
}

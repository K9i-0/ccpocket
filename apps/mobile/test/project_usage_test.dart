import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/utils/project_usage.dart';
import 'package:flutter_test/flutter_test.dart';

RecentSession session(
  String path,
  String modified, {
  String? group,
  String created = '',
  bool sidechain = false,
}) => RecentSession(
  sessionId: '$path-$modified',
  firstPrompt: '',
  created: created,
  modified: modified,
  gitBranch: '',
  projectPath: path,
  isSidechain: sidechain,
  workspace: group == null
      ? null
      : SessionWorkspaceInfo(
          kind: 'project',
          projectId: group,
          rootPaths: ['/ccpocket', '/T2QR', '/Bookmark-Safe'],
        ),
);

void main() {
  test('keeps standalone and group activity independent and takes latest', () {
    final usage = projectUsage([
      session('/ccpocket', '2026-10-20T10:00:00Z'),
      session('/ccpocket', '2026-10-18T10:00:00Z', group: 'flutter'),
      session('/T2QR', '2026-10-19T10:00:00Z'),
      session('/ccpocket', '2026-10-17T10:00:00Z'),
      session('/ccpocket', '2026-10-16T10:00:00Z', group: 'other'),
    ]);
    expect(usage, {
      'folder:/ccpocket': DateTime.parse('2026-10-20T10:00:00Z'),
      'project:flutter': DateTime.parse('2026-10-18T10:00:00Z'),
      'folder:/T2QR': DateTime.parse('2026-10-19T10:00:00Z'),
      'project:other': DateTime.parse('2026-10-16T10:00:00Z'),
    });
  });

  test('ignores sidechains and falls back to creation for missing dates', () {
    expect(
      projectUsage([
        session('/ccpocket', '2026-10-20T10:00:00Z', sidechain: true),
        session('/T2QR', '', created: '2026-10-19T10:00:00Z'),
        session('/invalid', 'invalid'),
      ]),
      {'folder:/T2QR': DateTime.parse('2026-10-19T10:00:00Z')},
    );
  });
}

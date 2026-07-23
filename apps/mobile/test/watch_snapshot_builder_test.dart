import 'dart:convert';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/watch_snapshot_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WatchSnapshotBuilder', () {
    test('preserves mobile order and maps semantic status', () {
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        bridgeUrl: 'ws://localhost:8765',
        generatedAt: DateTime.utc(2026, 7, 22),
        sessions: [
          _session(id: 'idle', status: 'idle', projectPath: '/work/idle'),
          _session(
            id: 'approval',
            status: 'waiting_approval',
            projectPath: '/work/ccpocket',
            name: 'Watch MVP',
            permission: _questionPermission(),
          ),
          _session(id: 'running', status: 'running', projectPath: '/work/api'),
        ],
      );

      final sessions = snapshot['sessions']! as List<Object?>;
      final first = sessions.first! as Map<String, Object?>;
      expect(snapshot['connected'], isTrue);
      expect(snapshot['bridgeHost'], 'localhost');
      expect(snapshot['bridgePort'], 8765);
      expect(snapshot['activeSessionCount'], 3);
      expect(snapshot['statusCounts'], {
        'idle': 1,
        'waiting_approval': 1,
        'running': 1,
      });
      expect(first['id'], 'idle');
      expect(first['statusLabel'], 'Ready');
      expect(first['hasCustomName'], isFalse);

      final approval = sessions[1]! as Map<String, Object?>;
      expect(approval['title'], 'Watch MVP');
      expect(approval['hasCustomName'], isTrue);
      expect(approval['statusLabel'], 'Needs You');
      expect(approval['permission'], isA<Map<String, Object?>>());

      final running = sessions[2]! as Map<String, Object?>;
      expect(running['statusLabel'], 'Working');
    });

    test('maps utilization to remaining fractions', () {
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        sessions: const [],
        usage: const UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              fiveHour: UsageWindow(
                utilization: 37,
                resetsAt: '2026-07-22T12:00:00Z',
              ),
            ),
          ],
        ),
      );

      final usage = (snapshot['usage']! as List).first as Map;
      final window = usage['fiveHour'] as Map;
      expect(window['remaining'], 0.63);
    });

    test('keeps a single-select answer as plain text', () {
      final result = WatchSnapshotBuilder.buildAnswerResult(
        permission: _questionPermission(),
        answers: const {
          'Environment?': ['Staging'],
        },
      );

      expect(result, 'Staging');
    });

    test('restores opaque Watch option values to original labels', () {
      final result = WatchSnapshotBuilder.buildAnswerResult(
        permission: _questionPermission(),
        answers: const {
          'q:0': ['option:1'],
        },
      );

      expect(result, 'Production');
    });

    test('encodes multi-select answers using mobile protocol envelope', () {
      final permission = PermissionRequestMessage(
        toolUseId: 'tool-2',
        toolName: 'AskUserQuestion',
        input: const {
          'questions': [
            {
              'question': 'Checks?',
              'multiSelect': true,
              'options': [
                {'label': 'Analyze'},
                {'label': 'Tests'},
              ],
            },
          ],
        },
      );
      final result = WatchSnapshotBuilder.buildAnswerResult(
        permission: permission,
        answers: const {
          'Checks?': ['Analyze', 'Tests'],
        },
      );

      final decoded = jsonDecode(result!) as Map<String, dynamic>;
      expect(decoded['answers']['Checks?'], ['Analyze', 'Tests']);
    });

    test('rejects missing required answers', () {
      final result = WatchSnapshotBuilder.buildAnswerResult(
        permission: _questionPermission(),
        answers: const {},
      );

      expect(result, isNull);
    });

    test('encodes an intentionally skipped optional question', () {
      const permission = PermissionRequestMessage(
        toolUseId: 'tool-optional',
        toolName: 'AskUserQuestion',
        input: {
          'questions': [
            {'question': 'Anything else?', 'required': false, 'options': []},
          ],
        },
      );

      final result = WatchSnapshotBuilder.buildAnswerResult(
        permission: permission,
        answers: const {},
      );

      expect(jsonDecode(result!)['answers'], isEmpty);
    });

    test('bounds the application context payload', () {
      final longText = List.filled(2000, '界').join();
      final permission = PermissionRequestMessage(
        toolUseId: 'tool-large',
        toolName: 'AskUserQuestion',
        input: {
          'questions': List.generate(
            3,
            (questionIndex) => {
              'question': '$questionIndex $longText',
              'header': longText,
              'options': List.generate(
                6,
                (optionIndex) => {
                  'label': '$optionIndex $longText',
                  'description': longText,
                },
              ),
            },
          ),
        },
      );
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        usage: UsageResultMessage(
          providers: [UsageInfo(provider: longText, error: longText)],
        ),
        sessions: List.generate(
          20,
          (index) => _session(
            id: 'session-$index',
            status: 'waiting_approval',
            projectPath: '/work/$longText',
            name: longText,
            lastMessage: longText,
            permission: permission,
          ),
        ),
      );

      expect((snapshot['sessions']! as List), hasLength(6));
      expect(snapshot['activeSessionCount'], 20);
      expect(snapshot['statusCounts'], {'waiting_approval': 20});
      expect(utf8.encode(jsonEncode(snapshot)).length, lessThan(40 * 1024));
    });

    test('uses default ports when the Bridge URL omits one', () {
      final secure = WatchSnapshotBuilder.build(
        connected: true,
        bridgeUrl: 'wss://bridge.example.com',
        sessions: const [],
      );
      final local = WatchSnapshotBuilder.build(
        connected: true,
        bridgeUrl: 'ws://localhost',
        sessions: const [],
      );

      expect(secure['bridgePort'], 443);
      expect(local['bridgePort'], 80);
    });

    test('falls back to a non-empty title without a project path', () {
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        sessions: [_session(id: 'empty-project', status: 'idle', projectPath: '')],
      );

      final session = (snapshot['sessions']! as List).single as Map;
      expect(session['title'], 'Session');
      expect(session['hasCustomName'], isFalse);
    });

    test('aggregates unknown statuses without growing the payload map', () {
      final longStatus = List.filled(2000, '異常').join();
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        sessions: List.generate(
          200,
          (index) => _session(
            id: 'unknown-$index',
            status: '$index-$longStatus',
            projectPath: '/work/project-$index',
          ),
        ),
      );

      expect(snapshot['activeSessionCount'], 200);
      expect(snapshot['statusCounts'], {'other': 200});
      final sessions = snapshot['sessions']! as List;
      expect(sessions, hasLength(6));
      expect((sessions.first as Map)['status'], 'other');
      expect(utf8.encode(jsonEncode(snapshot)).length, lessThan(40 * 1024));
    });

    test('routes oversized question sets to iPhone', () {
      final permission = PermissionRequestMessage(
        toolUseId: 'tool-many-questions',
        toolName: 'AskUserQuestion',
        input: {
          'questions': List.generate(
            4,
            (index) => {
              'question': 'Question $index?',
              'options': [
                {'label': 'Yes'},
                {'label': 'No'},
              ],
            },
          ),
        },
      );
      final snapshot = WatchSnapshotBuilder.build(
        connected: true,
        sessions: [
          _session(
            id: 'questions',
            status: 'waiting_approval',
            projectPath: '/work/ccpocket',
            permission: permission,
          ),
        ],
      );

      final session = (snapshot['sessions']! as List).single as Map;
      final payload = session['permission'] as Map;
      expect(payload['requiresPhone'], isTrue);
    });
  });
}

SessionInfo _session({
  required String id,
  required String status,
  required String projectPath,
  String? name,
  String lastMessage = '',
  PermissionRequestMessage? permission,
}) => SessionInfo(
  id: id,
  projectPath: projectPath,
  name: name,
  status: status,
  createdAt: '2026-07-22T00:00:00Z',
  lastActivityAt: '2026-07-22T01:00:00Z',
  lastMessage: lastMessage,
  pendingPermission: permission,
);

PermissionRequestMessage _questionPermission() =>
    const PermissionRequestMessage(
      toolUseId: 'tool-1',
      toolName: 'AskUserQuestion',
      input: {
        'questions': [
          {
            'question': 'Environment?',
            'options': [
              {'label': 'Staging', 'description': 'Use the test environment'},
              {'label': 'Production', 'description': 'Use live services'},
            ],
          },
        ],
      },
    );

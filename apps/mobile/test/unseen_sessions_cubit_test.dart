import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/unseen_sessions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionInfo _session({
  required String id,
  String status = 'idle',
  String lastActivityAt = '2026-03-11T10:00:00Z',
}) {
  return SessionInfo(
    id: id,
    projectPath: '/test',
    status: status,
    createdAt: '2026-03-11T09:00:00Z',
    lastActivityAt: lastActivityAt,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UnseenSessionsCubit', () {
    test('idle session with no seen-at record is unseen', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([_session(id: 'a')]);
      expect(cubit.state, contains('a'));
      expect(cubit.isUnseen('a'), isTrue);

      await cubit.close();
    });

    test('non-idle sessions are never unseen', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([
        _session(id: 'a', status: 'running'),
        _session(id: 'b', status: 'waiting_approval'),
        _session(id: 'c', status: 'starting'),
      ]);
      expect(cubit.state, isEmpty);

      await cubit.close();
    });

    test('markSeen removes session from unseen set', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([_session(id: 'a')]);
      expect(cubit.isUnseen('a'), isTrue);

      cubit.markSeen('a');
      expect(cubit.isUnseen('a'), isFalse);

      await cubit.close();
    });

    test('markSeen persists and subsequent updates respect seen-at', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([
        _session(id: 'a', lastActivityAt: '2026-03-11T10:00:00Z'),
      ]);
      expect(cubit.isUnseen('a'), isTrue);

      cubit.markSeen('a');
      expect(cubit.isUnseen('a'), isFalse);

      // Same lastActivityAt → still seen
      cubit.updateSessions([
        _session(id: 'a', lastActivityAt: '2026-03-11T10:00:00Z'),
      ]);
      expect(cubit.isUnseen('a'), isFalse);

      // Newer lastActivityAt → unseen again
      cubit.updateSessions([
        _session(id: 'a', lastActivityAt: '2099-01-01T00:00:00Z'),
      ]);
      expect(cubit.isUnseen('a'), isTrue);

      await cubit.close();
    });

    test('empty lastActivityAt is never unseen', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([_session(id: 'a', lastActivityAt: '')]);
      expect(cubit.state, isEmpty);

      await cubit.close();
    });

    test('multiple sessions tracked independently', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([
        _session(id: 'a'),
        _session(id: 'b', status: 'running'),
        _session(id: 'c'),
      ]);
      expect(cubit.state, {'a', 'c'});

      cubit.markSeen('a');
      expect(cubit.state, {'c'});

      await cubit.close();
    });

    test('stale entries are cleaned up', () async {
      final cubit = UnseenSessionsCubit();
      await Future<void>.delayed(Duration.zero);

      cubit.updateSessions([_session(id: 'a'), _session(id: 'b')]);
      cubit.markSeen('a');
      cubit.markSeen('b');

      // Session 'a' removed from running list
      cubit.updateSessions([_session(id: 'b')]);
      // No assertion on internal state, just ensure no error and 'b' is still seen
      expect(cubit.isUnseen('b'), isFalse);

      await cubit.close();
    });

    // ---------------------------------------------------------------
    // False-positive prevention tests
    // ---------------------------------------------------------------

    group('false-positive prevention', () {
      test(
        'markSeen before session becomes idle prevents unseen indicator',
        () async {
          // Simulates: user sends a message → markSeen called → session
          // briefly stays idle with updated lastActivityAt before going
          // to "working". The +1 day buffer in markSeen should prevent
          // the session from being marked unseen.
          final cubit = UnseenSessionsCubit();
          await Future<void>.delayed(Duration.zero);

          // Session starts as idle and user taps into it.
          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-11T10:00:00Z'),
          ]);
          cubit.markSeen('s1');
          expect(cubit.isUnseen('s1'), isFalse);

          // Activity timestamp updates moments later (user sent a message,
          // Bridge echoed back) but session is still idle briefly.
          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-11T10:00:05Z'),
          ]);
          expect(
            cubit.isUnseen('s1'),
            isFalse,
            reason: '+1 day buffer should cover near-future activity',
          );

          await cubit.close();
        },
      );

      test(
        'newly created session marked seen before it appears in list',
        () async {
          // Simulates: session_created event fires → markSeen called with
          // real session ID → session later appears in active list as idle.
          final cubit = UnseenSessionsCubit();
          await Future<void>.delayed(Duration.zero);

          // markSeen called when session_created arrives (before the session
          // appears in the active session list).
          cubit.markSeen('new-session-123');

          // Session now appears in the list as idle.
          cubit.updateSessions([
            _session(
              id: 'new-session-123',
              lastActivityAt: '2026-03-11T10:00:00Z',
            ),
          ]);
          expect(
            cubit.isUnseen('new-session-123'),
            isFalse,
            reason: 'Session created by the user should not appear as unseen',
          );

          await cubit.close();
        },
      );

      test(
        'session transitions working → idle after markSeen stays seen',
        () async {
          // Simulates: user views session → sends message → session goes
          // to working → finishes → returns to idle with newer timestamp.
          // Should remain seen because the work was initiated by this user.
          final cubit = UnseenSessionsCubit();
          await Future<void>.delayed(Duration.zero);

          // User views and marks seen.
          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-11T10:00:00Z'),
          ]);
          cubit.markSeen('s1');

          // Session goes to working (not tracked as unseen).
          cubit.updateSessions([
            _session(
              id: 's1',
              status: 'running',
              lastActivityAt: '2026-03-11T10:01:00Z',
            ),
          ]);
          expect(cubit.state, isEmpty);

          // Session returns to idle with newer timestamp.
          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-11T10:02:00Z'),
          ]);
          expect(
            cubit.isUnseen('s1'),
            isFalse,
            reason: '+1 day buffer covers activity within same user session',
          );

          await cubit.close();
        },
      );

      test(
        'genuinely new activity after buffer period is detected as unseen',
        () async {
          // Ensures the +1 day buffer doesn't permanently suppress unseen.
          // Activity with a timestamp beyond the buffer should be detected.
          final cubit = UnseenSessionsCubit();
          await Future<void>.delayed(Duration.zero);

          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-11T10:00:00Z'),
          ]);
          cubit.markSeen('s1');
          expect(cubit.isUnseen('s1'), isFalse);

          // Activity far in the future (beyond +1 day buffer) → unseen.
          cubit.updateSessions([
            _session(id: 's1', lastActivityAt: '2026-03-25T10:00:00Z'),
          ]);
          expect(
            cubit.isUnseen('s1'),
            isTrue,
            reason: 'Activity beyond buffer period should be unseen',
          );

          await cubit.close();
        },
      );
    });

    // ---------------------------------------------------------------
    // Persistence across cubit instances
    // ---------------------------------------------------------------

    group('persistence', () {
      test('seen-at survives cubit recreation', () async {
        final cubit1 = UnseenSessionsCubit();
        await Future<void>.delayed(Duration.zero);

        cubit1.updateSessions([
          _session(id: 'a', lastActivityAt: '2026-03-11T10:00:00Z'),
        ]);
        cubit1.markSeen('a');
        // Wait for SharedPreferences write.
        await Future<void>.delayed(Duration.zero);
        await cubit1.close();

        // New cubit instance loads persisted data.
        final cubit2 = UnseenSessionsCubit();
        await Future<void>.delayed(Duration.zero);

        cubit2.updateSessions([
          _session(id: 'a', lastActivityAt: '2026-03-11T10:00:00Z'),
        ]);
        expect(
          cubit2.isUnseen('a'),
          isFalse,
          reason: 'Persisted seen-at should carry over to new instance',
        );

        await cubit2.close();
      });
    });
  });
}

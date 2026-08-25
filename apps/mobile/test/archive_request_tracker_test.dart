import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/session_list/state/archive_request_tracker.dart';

void main() {
  testWidgets('only unfinished archive requests time out', (tester) async {
    final timedOut = <String>[];
    final tracker = ArchiveRequestTracker(
      timeout: const Duration(seconds: 1),
      onTimeout: timedOut.add,
    );
    addTearDown(tracker.dispose);

    tracker.start('completed');
    tracker.start('stalled');
    expect(tracker.pendingSessionIds, {'completed', 'stalled'});

    expect(tracker.complete('completed'), isTrue);
    await tester.pump(const Duration(milliseconds: 999));
    expect(timedOut, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(timedOut, ['stalled']);
    expect(tracker.pendingSessionIds, isEmpty);
  });

  testWidgets('dispose cancels pending timeouts', (tester) async {
    final timedOut = <String>[];
    final tracker = ArchiveRequestTracker(
      timeout: const Duration(seconds: 1),
      onTimeout: timedOut.add,
    );

    tracker.start('pending');
    tracker.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(timedOut, isEmpty);
    expect(tracker.pendingSessionIds, isEmpty);
  });
}

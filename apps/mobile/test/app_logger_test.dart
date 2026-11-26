import 'package:ccpocket/core/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    test('records all log levels with optional error and stackTrace', () {
      var tick = 0;
      final baseTime = DateTime.utc(2026, 11, 26, 9, 5, 3, 42);
      final consoleLines = <String>[];
      final log = AppLogger(
        consoleOutput: consoleLines.add,
        clock: () => baseTime.add(Duration(milliseconds: tick++)),
      );
      final st = StackTrace.fromString('#0 main (file:///app.dart:10:3)');

      log.debug('debug msg');
      log.info('info msg');
      log.warning('warn msg', 'warn-err');
      log.error('error msg', StateError('boom'), st);
      log.critical('critical msg', 'fatal');
      log.handle(FormatException('bad format'), st, 'handled failure');
      log.log('custom log', level: AppLogLevel.warning);

      expect(log.length, 7);
      expect(log.isEmpty, isFalse);
      expect(log.history, hasLength(7));
      expect(() => log.entries.add(log.entries.first), throwsUnsupportedError);

      expect(log.entries[0].level, AppLogLevel.debug);
      expect(log.entries[0].message, 'debug msg');
      expect(log.entries[0].formattedTimestamp, '09:05:03.042');

      expect(log.entries[1].level, AppLogLevel.info);
      expect(log.entries[2].level, AppLogLevel.warning);
      expect(log.entries[2].error, 'warn-err');

      expect(log.entries[3].level, AppLogLevel.error);
      expect(log.entries[3].error, isA<StateError>());
      expect(log.entries[3].stackTrace, st);

      expect(log.entries[4].level, AppLogLevel.critical);
      expect(log.entries[4].level.label, 'CRITICAL');

      expect(log.entries[5].level, AppLogLevel.error);
      expect(log.entries[5].message, 'handled failure');
      expect(log.entries[5].error, isA<FormatException>());
      expect(log.entries[5].stackTrace, st);

      expect(log.entries[6].level, AppLogLevel.warning);
      expect(log.entries[6].message, 'custom log');

      expect(consoleLines, hasLength(7));
      expect(consoleLines[0], '[09:05:03.042] [DEBUG] debug msg');
      expect(consoleLines[3], contains('Bad state: boom'));
      expect(consoleLines[3], contains('#0 main'));
    });

    test('handle falls back to exception string when msg is omitted', () {
      final log = AppLogger(useConsoleLogs: false);
      final exception = ArgumentError('missing id');
      log.handle(exception);

      expect(log.length, 1);
      expect(log.entries.single.level, AppLogLevel.error);
      expect(log.entries.single.message, exception.toString());
      expect(log.entries.single.error, exception);
    });

    test('ring buffer evicts oldest entries when maxEntries is exceeded', () {
      final log = AppLogger(maxEntries: 3, useConsoleLogs: false);
      for (var i = 1; i <= 5; i++) {
        log.info('entry-$i');
      }

      expect(log.length, 3);
      expect(log.entries.map((e) => e.message), [
        'entry-3',
        'entry-4',
        'entry-5',
      ]);
      expect(log.entries.map((e) => e.id), [3, 4, 5]);
    });

    test('notifies listenable on log and clear, ignores redundant clear, and is not a Listenable', () {
      final log = AppLogger(useConsoleLogs: false);
      expect(log, isNot(isA<Listenable>()));
      expect(log.listenable, isA<Listenable>());

      var notifications = 0;
      log.listenable.addListener(() => notifications++);

      log.clear();
      expect(notifications, 0);

      log.info('first');
      log.warning('second');
      expect(notifications, 2);

      log.clear();
      expect(log.isEmpty, isTrue);
      expect(notifications, 3);

      log.clear();
      expect(notifications, 3);

      log.dispose();
    });

    test('respects useConsoleLogs = false', () {
      final consoleLines = <String>[];
      final log = AppLogger(
        useConsoleLogs: false,
        consoleOutput: consoleLines.add,
      );
      log.info('quiet');
      expect(consoleLines, isEmpty);
    });

    test(
      'format and exportText include timestamps, errors, and stack traces',
      () {
        final fixed = DateTime.utc(2026, 11, 26, 12, 34, 56, 789);
        final log = AppLogger(useConsoleLogs: false, clock: () => fixed);
        final st = StackTrace.fromString('#0 foo (foo.dart:1:1)');

        log.info('started');
        log.error('crashed', 'disk full', st);

        final exported = log.exportText();
        expect(exported, contains('[2026-11-26T12:34:56.789Z] [INFO] started'));
        expect(
          exported,
          contains('[2026-11-26T12:34:56.789Z] [ERROR] crashed'),
        );
        expect(exported, contains('Error: disk full'));
        expect(exported, contains('#0 foo (foo.dart:1:1)'));

        final withoutStack = log.entries.last.format(includeStackTrace: false);
        expect(withoutStack, contains('Error: disk full'));
        expect(withoutStack, isNot(contains('#0 foo')));

        final subset = log.exportText(entries: [log.entries.first]);
        expect(subset, '[2026-11-26T12:34:56.789Z] [INFO] started');
      },
    );

    test('matchesQuery checks message, error, stackTrace, and level', () {
      final log = AppLogger(useConsoleLogs: false);
      log.error(
        'Bridge disconnected',
        'SocketException: broken pipe',
        StackTrace.fromString('#0 BridgeService.connect (bridge.dart:42)'),
      );
      final entry = log.entries.single;

      expect(entry.matchesQuery(''), isTrue);
      expect(entry.matchesQuery('   '), isTrue);
      expect(entry.matchesQuery('bridge'), isTrue);
      expect(entry.matchesQuery('broken PIPE'), isTrue);
      expect(entry.matchesQuery('bridge.dart:42'), isTrue);
      expect(entry.matchesQuery('error'), isTrue);
      expect(entry.matchesQuery('nonexistent'), isFalse);
    });
  });
}

import 'package:ccpocket/core/app_bloc_observer.dart';
import 'package:ccpocket/core/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestCubit extends Cubit<String> {
  _TestCubit(super.initialState);

  void update(String value) => emit(value);

  void reportError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
  }
}

void main() {
  group('AppBlocObserver', () {
    late BlocObserver previousObserver;

    setUp(() {
      previousObserver = Bloc.observer;
    });

    tearDown(() {
      Bloc.observer = previousObserver;
    });

    test('logs create, change, error, and close events', () async {
      final log = AppLogger(useConsoleLogs: false);
      Bloc.observer = AppBlocObserver(logger: log);

      final cubit = _TestCubit('idle');
      cubit.update('loading');
      final st = StackTrace.fromString('#0 test (test.dart:1:1)');
      cubit.reportError(StateError('failed'), st);
      await cubit.close();

      expect(log.length, 4);

      expect(log.entries[0].level, AppLogLevel.debug);
      expect(log.entries[0].message, '[bloc] create _TestCubit');

      expect(log.entries[1].level, AppLogLevel.debug);
      expect(
        log.entries[1].message,
        '[bloc] change _TestCubit: idle -> loading',
      );

      expect(log.entries[2].level, AppLogLevel.error);
      expect(log.entries[2].message, '[bloc] error _TestCubit');
      expect(log.entries[2].error, isA<StateError>());
      expect(log.entries[2].stackTrace, st);

      expect(log.entries[3].level, AppLogLevel.debug);
      expect(log.entries[3].message, '[bloc] close _TestCubit');
    });

    test(
      'truncates oversized state strings and normalizes whitespace',
      () async {
        final log = AppLogger(useConsoleLogs: false);
        Bloc.observer = AppBlocObserver(logger: log, maxStateLength: 20);

        final cubit = _TestCubit('short');
        cubit.update('line1\n  line2\t${'x' * 200}');
        await cubit.close();

        final changeMessage = log.entries[1].message;
        expect(
          changeMessage,
          startsWith('[bloc] change _TestCubit: short -> '),
        );
        expect(changeMessage, contains('line1 line2 '));
        expect(changeMessage, endsWith('…'));
        expect(changeMessage.length, lessThan(80));
      },
    );
  });
}

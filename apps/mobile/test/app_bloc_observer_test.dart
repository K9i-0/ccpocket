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

    test('records bloc errors and nothing else', () async {
      final log = AppLogger(useConsoleLogs: false);
      Bloc.observer = AppBlocObserver(logger: log);

      final cubit = _TestCubit('idle');
      cubit.update('loading');
      final st = StackTrace.fromString('#0 test (test.dart:1:1)');
      cubit.reportError(StateError('failed'), st);
      cubit.update('secret message text');
      await cubit.close();

      expect(log.length, 1);
      expect(log.entries[0].level, AppLogLevel.error);
      expect(log.entries[0].message, '[bloc] error _TestCubit');
      expect(log.entries[0].error, isA<StateError>());
      expect(log.entries[0].stackTrace, st);
    });
  });
}

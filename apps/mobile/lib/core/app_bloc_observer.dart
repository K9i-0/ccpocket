import 'package:flutter_bloc/flutter_bloc.dart';

import 'logger.dart';

/// [BlocObserver] that forwards bloc errors to [AppLogger].
///
/// State changes are deliberately not recorded: streaming cubits emit once
/// per delta with a state whose `toString` grows with the response, so
/// logging them costs O(n²) on the UI thread, pushes real warnings out of the
/// log ring buffer, and leaks message text into shared logs.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver({required this.logger});

  final AppLogger logger;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    logger.error('[bloc] error ${bloc.runtimeType}', error, stackTrace);
  }
}

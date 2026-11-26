import 'package:flutter_bloc/flutter_bloc.dart';

import 'logger.dart';

/// Concise [BlocObserver] that forwards lifecycle events to [AppLogger]
/// without dumping oversized state payloads.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver({required this.logger, this.maxStateLength = 120})
    : assert(maxStateLength > 0, 'maxStateLength must be positive');

  final AppLogger logger;

  /// Maximum character length kept for each summarized state string.
  final int maxStateLength;

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    logger.debug('[bloc] create ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final current = _summarizeState(change.currentState);
    final next = _summarizeState(change.nextState);
    logger.debug('[bloc] change ${bloc.runtimeType}: $current -> $next');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    logger.error('[bloc] error ${bloc.runtimeType}', error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    logger.debug('[bloc] close ${bloc.runtimeType}');
  }

  String _summarizeState(Object? state) {
    if (state == null) return 'null';
    final compact = state.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxStateLength) return compact;
    if (maxStateLength <= 1) return '…';
    return '${compact.substring(0, maxStateLength - 1)}…';
  }
}

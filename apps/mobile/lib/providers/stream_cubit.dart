import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Generic Cubit that mirrors a Stream as state.
/// Replaces Riverpod's StreamProvider for simple stream-wrapping use cases.
class StreamCubit<T> extends Cubit<T> {
  StreamSubscription<T>? _sub;

  StreamCubit(super.initial, Stream<T> stream) {
    _sub = stream.listen(emit);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

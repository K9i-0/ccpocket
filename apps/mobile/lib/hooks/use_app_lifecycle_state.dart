import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Tracks the current [AppLifecycleState] via [WidgetsBindingObserver].
///
/// Returns [AppLifecycleState.resumed] initially and updates whenever the
/// lifecycle state changes (e.g. app goes to background).
AppLifecycleState useAppLifecycleState() {
  final state = useState(AppLifecycleState.resumed);

  useEffect(() {
    final observer = _LifecycleObserver((s) => state.value = s);
    WidgetsBinding.instance.addObserver(observer);
    return () => WidgetsBinding.instance.removeObserver(observer);
  }, const []);

  return state.value;
}

class _LifecycleObserver extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onStateChange;

  _LifecycleObserver(this.onStateChange);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onStateChange(state);
}

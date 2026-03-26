import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Calls [onResume] only on genuine resume from background (paused/detached),
/// not from inactive (e.g. Android notification shade).
void useAppResumeCallback(
  AppLifecycleState? lifecycleState,
  VoidCallback onResume,
) {
  final prevLifecycleState = useRef<AppLifecycleState?>(null);
  useEffect(() {
    final prev = prevLifecycleState.value;
    prevLifecycleState.value = lifecycleState;

    if (lifecycleState == AppLifecycleState.resumed &&
        (prev == AppLifecycleState.paused ||
            prev == AppLifecycleState.detached)) {
      onResume();
    }
    return null;
  }, [lifecycleState]);
}

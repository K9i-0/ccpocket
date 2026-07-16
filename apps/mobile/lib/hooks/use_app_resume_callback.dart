import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Calls [onResume] only on genuine resume from background
/// (paused/hidden/detached),
/// not from inactive (e.g. Android notification shade).
void useAppResumeCallback(
  AppLifecycleState? lifecycleState,
  VoidCallback onResume,
) {
  final wasBackgrounded = useRef(false);
  useEffect(() {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.detached) {
      wasBackgrounded.value = true;
    } else if (lifecycleState == AppLifecycleState.resumed &&
        wasBackgrounded.value) {
      wasBackgrounded.value = false;
      onResume();
    }
    return null;
  }, [lifecycleState]);
}

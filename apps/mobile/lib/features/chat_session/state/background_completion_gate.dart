import 'dart:async';

/// Defers a Claude "session complete" notification while background tasks are
/// live, then fires it once the session stays idle without them.
///
/// Claude ends a turn with a result even while background agents, shells or
/// monitors run, and starts a follow-up turn when they report back. The task
/// set can also empty for a moment before a task resumes, so the release waits
/// for the session to stay settled for [settle]. Mirrors the Bridge's push
/// gate for the local-notification fallback.
class BackgroundCompletionGate {
  BackgroundCompletionGate({
    required this.isSettled,
    required this.onRelease,
    this.settle = const Duration(seconds: 2),
  });

  final bool Function() isSettled;
  final void Function() onRelease;
  final Duration settle;

  bool _held = false;
  Timer? _timer;

  bool get isHolding => _held;

  /// Called for each completion. Returns true when it is held; false when
  /// the caller should notify now (an older held one is dropped).
  bool hold({required bool hasBackgroundWork}) {
    _cancelTimer();
    _held = hasBackgroundWork;
    return hasBackgroundWork;
  }

  /// Re-evaluate after the status or the background tasks changed.
  void update() {
    if (!_held) return;
    if (!isSettled()) {
      _cancelTimer();
      return;
    }
    _timer ??= Timer(settle, () {
      _timer = null;
      if (!_held || !isSettled()) return;
      _held = false;
      onRelease();
    });
  }

  void discard() {
    _cancelTimer();
    _held = false;
  }

  void dispose() => discard();

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

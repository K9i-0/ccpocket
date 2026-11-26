import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../widgets/indexed_scroll_controller.dart';

/// Cross-session scroll position persistence.
final Map<String, double> _scrollOffsets = {};

/// A tiny tolerance avoids toggling reading mode because of rounding noise.
const _kReadingThreshold = 1.0;

/// Keep the return button hidden for small, incidental movement near latest.
const _kScrollToLatestButtonThreshold = 100.0;

@visibleForTesting
bool isReadingHistoryAt(double distanceFromLatest) =>
    distanceFromLatest > _kReadingThreshold;

@visibleForTesting
bool shouldShowScrollToLatestAt(double distanceFromLatest) =>
    distanceFromLatest > _kScrollToLatestButtonThreshold;

bool shouldAutoCollapseToolResults(bool isReadingHistory) => !isReadingHistory;

/// Result record returned by [useScrollTracking].
typedef ScrollTrackingResult = ({
  IndexedScrollController controller,
  bool isReadingHistory,
  bool showScrollToLatest,
  bool Function() isReadingHistoryNow,
  VoidCallback onScrollMetricsChanged,
  void Function() goToLatest,
});

/// Tracks the single piece of intent the chat needs: whether the user is
/// reading away from the latest message.
///
/// The reverse list naturally follows output at offset zero. This hook only
/// persists offsets across sessions and exposes an explicit way to return to
/// latest; it does not infer intent from scroll direction or content extent.
ScrollTrackingResult useScrollTracking(String sessionId) {
  final controller = useMemoized(IndexedScrollController.new);
  useEffect(() => controller.dispose, const []);

  final isReadingHistory = useState(false);
  final showScrollToLatest = useState(false);
  final isReadingHistoryRef = useRef(false);
  final isGoingToLatest = useRef(false);
  final restorationVersion = useRef(0);
  final onScrollMetricsChangedRef = useRef<VoidCallback>(() {});

  void updateState(double distanceFromLatest) {
    final reading = isReadingHistoryAt(distanceFromLatest);
    final showButton = shouldShowScrollToLatestAt(distanceFromLatest);
    isReadingHistoryRef.value = reading;
    if (isReadingHistory.value != reading) {
      isReadingHistory.value = reading;
    }
    if (showScrollToLatest.value != showButton) {
      showScrollToLatest.value = showButton;
    }
  }

  useEffect(() {
    var cancelled = false;
    final currentRestorationVersion = ++restorationVersion.value;
    isGoingToLatest.value = false;
    isReadingHistoryRef.value = false;
    isReadingHistory.value = false;
    showScrollToLatest.value = false;

    final savedOffset = _scrollOffsets[sessionId] ?? 0;
    var lastRestoreMaxExtent = double.negativeInfinity;
    // Suppress stale pixels from the previous session until the first layout
    // has applied this session's target, including the default target of zero.
    var restorePending = true;
    var applyingRestore = false;
    var restoreScheduled = false;
    late final VoidCallback scheduleRestore;

    void restoreSavedOffset() {
      restoreScheduled = false;
      if (cancelled ||
          currentRestorationVersion != restorationVersion.value ||
          !controller.hasClients) {
        return;
      }
      final position = controller.position;
      lastRestoreMaxExtent = position.maxScrollExtent;
      final reachableOffset = savedOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - reachableOffset).abs() > _kReadingThreshold) {
        applyingRestore = true;
        controller.jumpTo(reachableOffset);
        applyingRestore = false;
      }
      restorePending =
          (savedOffset - reachableOffset).abs() > _kReadingThreshold;
      updateState(reachableOffset - position.minScrollExtent);
    }

    scheduleRestore = () {
      if (restoreScheduled ||
          cancelled ||
          currentRestorationVersion != restorationVersion.value) {
        return;
      }
      restoreScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreSavedOffset());
    };

    void onScroll() {
      if (!controller.hasClients || isGoingToLatest.value) return;
      final position = controller.position;
      if (currentRestorationVersion != restorationVersion.value) {
        restorePending = false;
      }
      if (position.userScrollDirection != ScrollDirection.idle) {
        restorePending = false;
        restorationVersion.value++;
        _scrollOffsets[sessionId] = position.pixels;
      } else if (restorePending &&
          position.maxScrollExtent >
              lastRestoreMaxExtent + _kReadingThreshold) {
        // Resume a pending restore only when newly laid-out content makes more
        // of the saved offset reachable. This also handles delayed history.
        scheduleRestore();
      } else if (!applyingRestore && !restorePending) {
        _scrollOffsets[sessionId] = position.pixels;
      }
      updateState(position.pixels - position.minScrollExtent);
    }

    controller.addListener(onScroll);
    void metricsCallback() {
      if (!restorePending ||
          currentRestorationVersion != restorationVersion.value ||
          !controller.hasClients ||
          isGoingToLatest.value) {
        return;
      }
      final position = controller.position;
      if (position.maxScrollExtent <
          lastRestoreMaxExtent - _kReadingThreshold) {
        lastRestoreMaxExtent = position.maxScrollExtent;
      }
      if (position.maxScrollExtent >
          lastRestoreMaxExtent + _kReadingThreshold) {
        scheduleRestore();
      }
    }

    onScrollMetricsChangedRef.value = metricsCallback;
    void persistAnchorCorrection(double offset) {
      if (cancelled || applyingRestore || restorePending) return;
      _scrollOffsets[sessionId] = offset;
    }

    controller.onLayoutAnchorCorrected = persistAnchorCorrection;
    scheduleRestore();

    return () {
      cancelled = true;
      if (identical(
        controller.onLayoutAnchorCorrected,
        persistAnchorCorrection,
      )) {
        controller.onLayoutAnchorCorrected = null;
      }
      if (identical(onScrollMetricsChangedRef.value, metricsCallback)) {
        onScrollMetricsChangedRef.value = () {};
      }
      controller.removeListener(onScroll);
    };
  }, [sessionId]);

  void goToLatest() {
    restorationVersion.value++;
    isGoingToLatest.value = true;
    _scrollOffsets[sessionId] = 0;
    updateState(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) {
        isGoingToLatest.value = false;
        return;
      }
      controller
          .animateTo(
            controller.position.minScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            isGoingToLatest.value = false;
            if (controller.hasClients) {
              updateState(
                controller.position.pixels -
                    controller.position.minScrollExtent,
              );
            }
          });
    });
  }

  return (
    controller: controller,
    isReadingHistory: isReadingHistory.value,
    showScrollToLatest: showScrollToLatest.value,
    isReadingHistoryNow: () => isReadingHistoryRef.value,
    onScrollMetricsChanged: () => onScrollMetricsChangedRef.value(),
    goToLatest: goToLatest,
  );
}

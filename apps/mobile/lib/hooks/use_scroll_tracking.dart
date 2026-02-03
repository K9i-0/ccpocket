import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Cross-session scroll offset persistence.
final Map<String, double> _scrollOffsets = {};

/// Result record returned by [useScrollTracking].
typedef ScrollTrackingResult = ({
  ScrollController controller,
  bool isScrolledUp,
  void Function() scrollToBottom,
});

/// Manages scroll position tracking with three responsibilities:
///
/// 1. **Scrolled-up detection**: Returns `isScrolledUp` when the user scrolls
///    more than 100px from the bottom.
/// 2. **Cross-session offset persistence**: Saves/restores scroll offset keyed
///    by [sessionId] so switching sessions preserves position.
/// 3. **Scroll-to-bottom**: Provides a [scrollToBottom] callback that smoothly
///    animates to the bottom (skipped when the user has scrolled up).
ScrollTrackingResult useScrollTracking(String sessionId) {
  final controller = useScrollController();
  final isScrolledUp = useState(false);

  // Ref to track isScrolledUp without rebuilds (for scrollToBottom closure).
  final isScrolledUpRef = useRef(false);

  useEffect(() {
    void onScroll() {
      if (!controller.hasClients) return;
      final pos = controller.position;
      final scrolled = pos.pixels < pos.maxScrollExtent - 100;
      isScrolledUpRef.value = scrolled;
      if (scrolled != isScrolledUp.value) {
        isScrolledUp.value = scrolled;
      }
    }

    controller.addListener(onScroll);

    // Restore saved offset after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = _scrollOffsets[sessionId];
      if (saved != null && controller.hasClients) {
        controller.jumpTo(saved);
      }
    });

    return () {
      // Persist offset before disposal.
      if (controller.hasClients) {
        _scrollOffsets[sessionId] = controller.offset;
      }
      controller.removeListener(onScroll);
    };
  }, [sessionId]);

  void scrollToBottom() {
    if (isScrolledUpRef.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  return (
    controller: controller,
    isScrolledUp: isScrolledUp.value,
    scrollToBottom: scrollToBottom,
  );
}

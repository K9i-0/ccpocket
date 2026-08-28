import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../utils/ordered_list_editing.dart';

/// Google Keep-style list auto-completion hook.
///
/// When the user presses Enter after a list item (numbered or bullet),
/// automatically inserts the next list prefix. If the current list item
/// is empty (just the prefix), removes it instead (exits list mode).
///
/// Supported patterns:
/// - Numbered lists: `1. foo` → Enter → `2. `
/// - Bullet lists: `- foo` or `* foo` → Enter → `- ` or `* `
/// - Empty list cancellation: `2. ` → Enter → removes prefix
void useListAutoComplete(TextEditingController controller) {
  // Guard flag to prevent re-entrant listener calls when we modify the text.
  final isProcessing = useRef(false);
  // Track previous text to detect newline insertion.
  final previousText = useRef(controller.text);

  useEffect(() {
    void onChanged() {
      if (isProcessing.value) return;

      final text = controller.text;
      final oldText = previousText.value;
      previousText.value = text;

      // Only act when text grew (not on deletion or programmatic clear).
      if (text.length <= oldText.length) return;

      final cursorPos = controller.selection.baseOffset;
      // Ignore if cursor position is invalid or not collapsed.
      if (cursorPos < 1 || !controller.selection.isCollapsed) return;

      // Check if a newline was just inserted at the cursor position.
      if (text[cursorPos - 1] != '\n') return;

      final result = completeListAfterNewline(controller.value);
      if (result == null) return;

      isProcessing.value = true;
      try {
        controller.value = result;
      } finally {
        // Update previousText to the new value so the next listener call
        // doesn't re-trigger.
        previousText.value = controller.text;
        isProcessing.value = false;
      }
    }

    controller.addListener(onChanged);
    return () => controller.removeListener(onChanged);
  }, [controller]);
}

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Regular expressions for detecting list patterns at the start of a line.
final _numberedListWithContent = RegExp(r'^(\s*)(\d+)\.\s(.+)$');
final _bulletListWithContent = RegExp(r'^(\s*)([-*])\s(.+)$');
final _emptyNumberedList = RegExp(r'^(\s*)(\d+)\.\s*$');
final _emptyBulletList = RegExp(r'^(\s*)([-*])\s*$');

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

      // Extract the line before the newly inserted newline.
      final beforeNewline = text.substring(0, cursorPos - 1);
      final lastNewlineIdx = beforeNewline.lastIndexOf('\n');
      final prevLine = beforeNewline.substring(lastNewlineIdx + 1);

      final result = _processLine(prevLine);
      if (result == null) return;

      isProcessing.value = true;
      try {
        if (result.isCancel) {
          // Remove the empty list prefix and the newline.
          // Before: "...<prefix>\n..." → After: "...\n..."
          // But actually we want to remove the whole empty line prefix too.
          final lineStart = lastNewlineIdx + 1;
          final newText =
              text.substring(0, lineStart) + text.substring(cursorPos);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: lineStart),
          );
        } else {
          // Insert the next list prefix after the newline.
          final insertion = result.prefix;
          final newText =
              text.substring(0, cursorPos) +
              insertion +
              text.substring(cursorPos);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: cursorPos + insertion.length,
            ),
          );
        }
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

/// Result of processing a line for list auto-completion.
class _LineResult {
  final String prefix;
  final bool isCancel;

  const _LineResult.insert(this.prefix) : isCancel = false;
  const _LineResult.cancel() : prefix = '', isCancel = true;
}

/// Analyzes a line and returns the action to take.
///
/// Returns `null` if the line is not a list item.
_LineResult? _processLine(String line) {
  // Check empty list items first (cancel).
  final emptyNumbered = _emptyNumberedList.firstMatch(line);
  if (emptyNumbered != null) {
    return const _LineResult.cancel();
  }

  final emptyBullet = _emptyBulletList.firstMatch(line);
  if (emptyBullet != null) {
    return const _LineResult.cancel();
  }

  // Check list items with content (continue).
  final numbered = _numberedListWithContent.firstMatch(line);
  if (numbered != null) {
    final indent = numbered.group(1)!;
    final currentNum = int.parse(numbered.group(2)!);
    return _LineResult.insert('$indent${currentNum + 1}. ');
  }

  final bullet = _bulletListWithContent.firstMatch(line);
  if (bullet != null) {
    final indent = bullet.group(1)!;
    final marker = bullet.group(2)!;
    return _LineResult.insert('$indent$marker ');
  }

  return null;
}

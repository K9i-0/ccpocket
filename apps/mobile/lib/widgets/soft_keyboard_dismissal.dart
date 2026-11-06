import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the on-screen keyboard currently occupies the bottom of [context]'s
/// view.
///
/// Reads the raw view insets: a `Scaffold` with `resizeToAvoidBottomInset`
/// removes the bottom inset from its body's `MediaQuery`. Hardware keyboards,
/// floating iPad keyboards and desktop platforms report no inset.
bool isSoftKeyboardVisible(BuildContext context) =>
    (View.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;

/// Whether [node] belongs to a text field, i.e. the keyboard has a live owner.
bool isTextInputFocus(FocusNode? node) =>
    node?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

/// Asks the platform to hide the on-screen keyboard, even when no Flutter text
/// field owns the input connection anymore.
Future<void> hideSoftKeyboard() async {
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  } catch (_) {
    // The text input channel may already be disconnected.
  }
}

/// Closes the on-screen keyboard when the user starts dragging a scrollable
/// below this widget, if the keyboard belongs to this subtree or to no one.
///
/// Unlike [ScrollViewKeyboardDismissBehavior.onDrag], this also closes a
/// keyboard left behind by another screen, whose text field no longer holds
/// focus. A text field focused outside this subtree (e.g. a chat composer in
/// a sibling pane) keeps its keyboard.
class DismissKeyboardOnUserScroll extends StatefulWidget {
  const DismissKeyboardOnUserScroll({super.key, required this.child});

  final Widget child;

  @override
  State<DismissKeyboardOnUserScroll> createState() =>
      _DismissKeyboardOnUserScrollState();
}

class _DismissKeyboardOnUserScrollState
    extends State<DismissKeyboardOnUserScroll> {
  final _subtreeFocus = FocusNode(
    debugLabel: 'DismissKeyboardOnUserScroll',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    _subtreeFocus.dispose();
    super.dispose();
  }

  bool _handleScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails == null || !isSoftKeyboardVisible(context)) {
      return false;
    }
    final primary = FocusManager.instance.primaryFocus;
    final ownedElsewhere = !_subtreeFocus.hasFocus && isTextInputFocus(primary);
    if (ownedElsewhere) return false;
    primary?.unfocus();
    unawaited(hideSoftKeyboard());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _subtreeFocus,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: _handleScrollStart,
        child: widget.child,
      ),
    );
  }
}

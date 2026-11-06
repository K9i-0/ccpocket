import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the on-screen keyboard currently occupies the bottom of [context]'s
/// view.
///
/// Reads the raw view insets: a `Scaffold` with `resizeToAvoidBottomInset`
/// removes the bottom inset from its body's `MediaQuery`. Hardware keyboards
/// and desktop platforms report no inset.
bool isSoftKeyboardVisible(BuildContext context) =>
    (View.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;

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
/// below this widget.
///
/// Unlike [ScrollViewKeyboardDismissBehavior.onDrag], this also closes a
/// keyboard left behind by another screen, whose text field no longer holds
/// focus inside this subtree.
class DismissKeyboardOnUserScroll extends StatelessWidget {
  const DismissKeyboardOnUserScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null &&
            isSoftKeyboardVisible(context)) {
          FocusManager.instance.primaryFocus?.unfocus();
          unawaited(hideSoftKeyboard());
        }
        return false;
      },
      child: child,
    );
  }
}

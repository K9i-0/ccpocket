import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A button shown at the trailing edge of a toast.
@immutable
class AppToastAction {
  final String label;
  final VoidCallback onPressed;

  const AppToastAction({required this.label, required this.onPressed});
}

/// Short notices shown as a small pill under the app bar.
///
/// They sit at the top so they never cover the chat input, approval bar or
/// bottom sheets, and they are drawn on the root overlay so they stay visible
/// above sheets and dialogs.
abstract final class AppToast {
  static const defaultDuration = Duration(seconds: 3);

  /// Capture this before an `await` and call [AppToastMessenger.show] after.
  static AppToastMessenger of(BuildContext context) =>
      AppToastMessenger._(Overlay.of(context, rootOverlay: true));

  static AppToastMessenger? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : AppToastMessenger._(overlay);
  }
}

final _currentToasts = Expando<OverlayEntry>('appToast');

class AppToastMessenger {
  final OverlayState _overlay;

  const AppToastMessenger._(this._overlay);

  bool get mounted => _overlay.mounted;

  /// Shows [message], replacing any toast already on screen.
  void show(
    String message, {
    Duration duration = AppToast.defaultDuration,
    AppToastAction? action,
    Key? key,
  }) {
    if (!_overlay.mounted) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastView(
        toastKey: key,
        message: message,
        duration: duration,
        action: action,
        onDismissed: () => _remove(entry),
      ),
    );
    _currentToasts[_overlay] = entry;
    _overlay.insert(entry);
  }

  /// Removes the toast on screen, if any, without animation.
  void hide() {
    final current = _currentToasts[_overlay];
    if (current != null) _remove(current);
  }

  void _remove(OverlayEntry entry) {
    if (!identical(_currentToasts[_overlay], entry)) return;
    _currentToasts[_overlay] = null;
    entry
      ..remove()
      ..dispose();
  }
}

class _AppToastView extends StatefulWidget {
  final Key? toastKey;
  final String message;
  final Duration duration;
  final AppToastAction? action;
  final VoidCallback onDismissed;

  const _AppToastView({
    required this.toastKey,
    required this.message,
    required this.duration,
    required this.action,
    required this.onDismissed,
  });

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    )..forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = MediaQuery.viewPaddingOf(context);
    final action = widget.action;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    return Positioned(
      top: padding.top + kToolbarHeight + 8,
      left: padding.left + 16,
      right: padding.right + 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(curved),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Dismissible(
                  key: const ValueKey('app_toast_dismissible'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDismissed(),
                  child: Material(
                    key: widget.toastKey ?? const ValueKey('app_toast'),
                    color: scheme.inverseSurface,
                    elevation: 6,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _close,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          action == null ? 10 : 4,
                          action == null ? 16 : 6,
                          action == null ? 10 : 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onInverseSurface,
                                ),
                              ),
                            ),
                            if (action != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                key: const ValueKey('app_toast_action'),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.inversePrimary,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  action.onPressed();
                                  _close();
                                },
                                child: Text(action.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

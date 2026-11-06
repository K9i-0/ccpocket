import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/floating_keyboard_service.dart';
import '../../../widgets/frosted_composer.dart';
import '../../../widgets/soft_keyboard_dismissal.dart';

/// Height reserved above the composer while a completion overlay is shown.
/// Matches the `maxHeight` of the slash / mention overlays plus a gap.
const double floatingComposerCompletionReserve = 228;

/// Gap between a floating keyboard and the composer above it.
const double floatingComposerKeyboardGap = 8;

/// Minimum distance from the top of the layout to the floating composer.
const double floatingComposerTopMargin = 8;

/// Top of the composer while it floats above an iPad floating keyboard.
///
/// The composer sits [floatingComposerKeyboardGap] above the keyboard and
/// only follows it vertically. While a completion overlay is visible, the
/// composer stays at least [completionReserve] below the top so the options
/// (which grow upward from the composer) remain on screen.
@visibleForTesting
double floatingComposerTop({
  required double keyboardTop,
  required double composerHeight,
  required double availableHeight,
  double completionReserve = 0,
}) {
  final minTop = floatingComposerTopMargin + completionReserve;
  final maxTop = math.max(minTop, availableHeight - composerHeight);
  return (keyboardTop - floatingComposerKeyboardGap - composerHeight).clamp(
    minTop,
    maxTop,
  );
}

/// Lets the composer report whether a completion overlay is visible.
class FloatingComposerScope extends InheritedWidget {
  const FloatingComposerScope({
    super.key,
    required this.onCompletionVisibilityChanged,
    required super.child,
  });

  final ValueChanged<bool> onCompletionVisibilityChanged;

  static FloatingComposerScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FloatingComposerScope>();

  @override
  bool updateShouldNotify(FloatingComposerScope oldWidget) => false;
}

/// Exposes whether the composer currently floats above an iPad floating
/// keyboard, so descendants can switch keyboard-dismiss gestures.
class FloatingComposerStatus extends InheritedWidget {
  const FloatingComposerStatus({
    super.key,
    required this.isFloating,
    required super.child,
  });

  final bool isFloating;

  /// Reads the current value without registering a dependency (for gesture
  /// and notification callbacks).
  static bool isFloatingOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<FloatingComposerStatus>()
          ?.isFloating ??
      false;

  @override
  bool updateShouldNotify(FloatingComposerStatus oldWidget) =>
      oldWidget.isFloating != isFloating;
}

/// Chat body + bottom bars + composer.
///
/// Normally a column: [content], [bars], [composer]. While the composer has
/// focus and an iPad floating keyboard is shown, [content] extends behind the
/// composer (down to [bars]) and the composer floats just above the keyboard,
/// so messages stay visible above and below it.
///
/// While floating, the keyboard follows ChatGPT's behavior: scrolling the
/// chat keeps it open (see [FloatingComposerStatus]); tapping the chat area
/// or swiping the composer down closes it.
///
/// The composer keeps the same element in both modes, so in-progress input,
/// attachments and overlay state survive switching keyboard modes.
class FloatingComposerLayout extends StatefulWidget {
  const FloatingComposerLayout({
    super.key,
    required this.content,
    required this.bars,
    this.composer,
    this.keyboardFrame,
  });

  final Widget content;
  final Widget bars;
  final Widget? composer;

  /// Overrides the [FloatingKeyboardService] lookup (tests).
  final ValueListenable<KeyboardGuideFrame?>? keyboardFrame;

  @override
  State<FloatingComposerLayout> createState() => _FloatingComposerLayoutState();
}

class _FloatingComposerLayoutState extends State<FloatingComposerLayout> {
  ValueListenable<KeyboardGuideFrame?>? _keyboardFrame;
  bool _composerFocused = false;
  bool _completionVisible = false;
  Offset _origin = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveKeyboardFrame();
  }

  @override
  void didUpdateWidget(covariant FloatingComposerLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyboardFrame != widget.keyboardFrame) {
      _resolveKeyboardFrame();
    }
  }

  void _resolveKeyboardFrame() {
    final next =
        widget.keyboardFrame ??
        Provider.of<FloatingKeyboardService?>(
          context,
          listen: false,
        )?.floatingFrame;
    if (identical(next, _keyboardFrame)) return;
    _keyboardFrame?.removeListener(_onKeyboardFrameChanged);
    _keyboardFrame = next;
    _keyboardFrame?.addListener(_onKeyboardFrameChanged);
  }

  @override
  void dispose() {
    _keyboardFrame?.removeListener(_onKeyboardFrameChanged);
    super.dispose();
  }

  void _onKeyboardFrameChanged() {
    if (mounted) setState(() {});
  }

  void _onComposerFocusChanged(bool focused) {
    if (focused == _composerFocused) return;
    setState(() => _composerFocused = focused);
  }

  /// Called from the composer's build (via hooks), so defer the rebuild.
  void _onCompletionVisibilityChanged(bool visible) {
    if (visible == _completionVisible) return;
    _completionVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  double _composerDragDistance = 0;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(hideSoftKeyboard());
  }

  void _onComposerDragEnd(DragEndDetails details) {
    final distance = _composerDragDistance;
    _composerDragDistance = 0;
    if (distance > 24 || (details.primaryVelocity ?? 0) > 300) {
      _dismissKeyboard();
    }
  }

  /// The native rect is in view coordinates; keep our global origin from the
  /// last layout to convert it.
  void _syncOrigin() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    if ((origin - _origin).distance <= 0.5) return;
    setState(() => _origin = origin);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _keyboardFrame?.value;
    final composer = widget.composer;
    final floating =
        frame != null &&
        composer != null &&
        _composerFocused &&
        View.of(context).viewInsets.bottom == 0;
    if (frame != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncOrigin());
    }

    return CustomMultiChildLayout(
      delegate: _FloatingComposerLayoutDelegate(
        keyboardTop: floating ? frame.rect.top - _origin.dy : null,
        completionReserve: _completionVisible
            ? floatingComposerCompletionReserve
            : 0,
      ),
      children: [
        LayoutId(
          id: _Slot.content,
          child: FloatingComposerStatus(
            isFloating: floating,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Inner taps (buttons, links) win the arena; plain chat area
              // taps close the floating keyboard.
              onTap: floating ? _dismissKeyboard : null,
              child: widget.content,
            ),
          ),
        ),
        LayoutId(id: _Slot.bars, child: widget.bars),
        if (composer != null)
          LayoutId(
            id: _Slot.composer,
            child: FloatingComposerScope(
              onCompletionVisibilityChanged: _onCompletionVisibilityChanged,
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                includeSemantics: false,
                onFocusChange: _onComposerFocusChanged,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: floating
                      ? (_) => _composerDragDistance = 0
                      : null,
                  onVerticalDragUpdate: floating
                      ? (details) => _composerDragDistance += details.delta.dy
                      : null,
                  onVerticalDragEnd: floating ? _onComposerDragEnd : null,
                  child: _FloatingComposerFrame(
                    floating: floating,
                    child: composer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _Slot { content, bars, composer }

class _FloatingComposerLayoutDelegate extends MultiChildLayoutDelegate {
  _FloatingComposerLayoutDelegate({
    required this.keyboardTop,
    required this.completionReserve,
  });

  /// Floating keyboard top in local coordinates; null when not floating.
  final double? keyboardTop;
  final double completionReserve;

  @override
  void performLayout(Size size) {
    final childConstraints = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    final barsHeight = layoutChild(_Slot.bars, childConstraints).height;
    final composerHeight = hasChild(_Slot.composer)
        ? layoutChild(_Slot.composer, childConstraints).height
        : 0.0;

    final double barsTop;
    final double composerTop;
    final keyboardTop = this.keyboardTop;
    if (keyboardTop == null) {
      composerTop = size.height - composerHeight;
      barsTop = composerTop - barsHeight;
    } else {
      barsTop = size.height - barsHeight;
      composerTop = floatingComposerTop(
        keyboardTop: keyboardTop,
        composerHeight: composerHeight,
        availableHeight: barsTop,
        completionReserve: completionReserve,
      );
    }

    layoutChild(
      _Slot.content,
      BoxConstraints.tightFor(width: size.width, height: math.max(0, barsTop)),
    );
    positionChild(_Slot.content, Offset.zero);
    positionChild(_Slot.bars, Offset(0, barsTop));
    if (hasChild(_Slot.composer)) {
      positionChild(_Slot.composer, Offset(0, composerTop));
    }
  }

  @override
  bool shouldRelayout(_FloatingComposerLayoutDelegate oldDelegate) =>
      oldDelegate.keyboardTop != keyboardTop ||
      oldDelegate.completionReserve != completionReserve;
}

/// Rounds, lifts and frosts the composer while floating. It keeps the pane's full
/// width in both modes (multi-pane layouts stay consistent).
/// The widget types never change between modes, so the composer subtree keeps
/// its state.
class _FloatingComposerFrame extends StatelessWidget {
  const _FloatingComposerFrame({required this.floating, required this.child});

  final bool floating;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(floating ? 20 : 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    // Frosted glass matching ScrollToBottomButton.
    final glass = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
          (isDark ? cs.surfaceContainerHigh : cs.surface).withValues(
            alpha: isDark ? 0.48 : 0.72,
          ),
        ],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.55),
      ),
    );
    return MediaQuery.removePadding(
      context: context,
      removeBottom: floating,
      child: DecoratedBox(
        key: const ValueKey('floating_composer_frame'),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: floating
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          clipBehavior: floating ? Clip.antiAlias : Clip.none,
          child: BackdropFilter(
            enabled: floating,
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: floating ? glass : const BoxDecoration(),
              child: FrostedComposer(enabled: floating, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

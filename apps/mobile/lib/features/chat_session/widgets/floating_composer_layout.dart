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

/// Exposes the composer state to the chat content: whether it floats above
/// an iPad floating keyboard (to switch keyboard-dismiss gestures) and how
/// much of the content's bottom it covers.
class FloatingComposerStatus extends InheritedWidget {
  const FloatingComposerStatus({
    super.key,
    required this.isFloating,
    this.obscuredBottom = 0,
    required super.child,
  });

  final bool isFloating;

  /// Height at the bottom of the content covered by the bars and the frosted
  /// composer. Scrollables pad by it so their last item stays reachable while
  /// the rest scrolls behind the glass.
  final double obscuredBottom;

  /// [obscuredBottom] of the nearest status, registering a dependency.
  static double obscuredBottomOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FloatingComposerStatus>()
          ?.obscuredBottom ??
      0;

  /// Reads the current value without registering a dependency (for gesture
  /// and notification callbacks).
  static bool isFloatingOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<FloatingComposerStatus>()
          ?.isFloating ??
      false;

  @override
  bool updateShouldNotify(FloatingComposerStatus oldWidget) =>
      oldWidget.isFloating != isFloating ||
      oldWidget.obscuredBottom != obscuredBottom;
}

/// Chat body + bottom bars + composer.
///
/// Normally [bars] and the frosted [composer] sit at the bottom over
/// [content], which extends behind them and gets
/// [FloatingComposerStatus.obscuredBottom] to pad its scrollables. While the
/// composer has focus and an iPad floating keyboard is shown, [bars] stay at
/// the bottom and the composer floats just above the keyboard, so messages
/// stay visible above and below it. Without a composer (approval UI), the
/// content simply ends above the bars.
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
  double _obscuredBottom = 0;

  /// Reported by the layout delegate; applied on the next frame.
  void _onObscuredBottomChanged(double value) {
    if ((value - _obscuredBottom).abs() <= 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (value - _obscuredBottom).abs() <= 0.5) return;
      setState(() => _obscuredBottom = value);
    });
  }

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
        onObscuredBottomChanged: _onObscuredBottomChanged,
      ),
      children: [
        LayoutId(
          id: _Slot.content,
          child: FloatingComposerStatus(
            isFloating: floating,
            obscuredBottom: _obscuredBottom,
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
    required this.onObscuredBottomChanged,
  });

  /// Floating keyboard top in local coordinates; null when not floating.
  final double? keyboardTop;
  final double completionReserve;
  final ValueChanged<double> onObscuredBottomChanged;

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

    final hasComposer = hasChild(_Slot.composer);
    final double barsTop;
    final double composerTop;
    var contentHeight = size.height;
    final keyboardTop = this.keyboardTop;
    if (keyboardTop == null) {
      composerTop = size.height - composerHeight;
      barsTop = composerTop - barsHeight;
      // The frosted composer (and the bars above it) cover the content.
      // Without a composer, the content ends above the bars as before.
      if (!hasComposer) contentHeight = barsTop;
    } else {
      barsTop = size.height - barsHeight;
      composerTop = floatingComposerTop(
        keyboardTop: keyboardTop,
        composerHeight: composerHeight,
        availableHeight: barsTop,
        completionReserve: completionReserve,
      );
      contentHeight = barsTop;
    }
    contentHeight = math.max(0, contentHeight);
    // Everything from the composer's (or, without one, the bars') top down
    // covers the content. While floating this lets the newest message scroll
    // up above the composer, with older ones passing below it (ChatGPT-like).
    final coveredFrom = hasComposer ? math.min(composerTop, barsTop) : barsTop;
    onObscuredBottomChanged(math.max(0, contentHeight - coveredFrom));

    layoutChild(
      _Slot.content,
      BoxConstraints.tightFor(width: size.width, height: contentHeight),
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

/// Frosts the composer so the chat shows through, and rounds and lifts it
/// while floating. It keeps the pane's full width in both modes (multi-pane
/// layouts stay consistent).
/// The widget types never change between modes, so the composer subtree keeps
/// its state.
class _FloatingComposerFrame extends StatelessWidget {
  const _FloatingComposerFrame({required this.floating, required this.child});

  final bool floating;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const style = ComposerGlassStyle();
    final radius = BorderRadius.circular(floating ? 20 : 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final edgeColor = Colors.white.withValues(alpha: isDark ? 0.14 : 0.55);
    // Frosted glass in the style of ScrollToBottomButton, more see-through.
    final glass = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: isDark ? style.darkTopAlpha : style.lightTopAlpha,
          ),
          (isDark ? cs.surfaceContainerHigh : cs.surface).withValues(
            alpha: isDark ? style.darkBottomAlpha : style.lightBottomAlpha,
          ),
        ],
      ),
      // A full border would draw lines down the pane edges when docked.
      border: floating
          ? Border.all(color: edgeColor)
          : Border(top: BorderSide(color: edgeColor)),
    );
    return MediaQuery.removePadding(
      context: context,
      removeBottom: floating,
      child: DecoratedBox(
        key: const ValueKey('floating_composer_frame'),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (floating)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          // Always clip: an unclipped BackdropFilter blurs the whole screen.
          clipBehavior: floating ? Clip.antiAlias : Clip.hardEdge,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: style.blurSigma,
              sigmaY: style.blurSigma,
            ),
            child: DecoratedBox(
              decoration: glass,
              child: FrostedComposer(
                enabled: true,
                fillOpacity: style.fillOpacity,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

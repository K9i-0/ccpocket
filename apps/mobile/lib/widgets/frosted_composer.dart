import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Look of the frosted chat composer: clearly see-through, with a strong
/// blur so text behind it stays unreadable.
@immutable
class ComposerGlassStyle {
  const ComposerGlassStyle({
    this.lightTopAlpha = 0.30,
    this.lightBottomAlpha = 0.40,
    this.darkTopAlpha = 0.05,
    this.darkBottomAlpha = 0.18,
    this.blurSigma = 20,
    this.fillOpacity = 0.72,
  });

  /// Gradient alphas of the glass (top-left white highlight, bottom-right
  /// surface tint) per brightness.
  final double lightTopAlpha;
  final double lightBottomAlpha;
  final double darkTopAlpha;
  final double darkBottomAlpha;

  final double blurSigma;

  /// Opacity of field and button fills on the glass: translucent enough to
  /// blend in, opaque enough to keep text and icons readable.
  final double fillOpacity;
}

/// Marks a composer subtree drawn on frosted glass (the chat shows through
/// behind it). Opaque fills inside should use [fill] to let it show slightly.
class FrostedComposer extends InheritedWidget {
  const FrostedComposer({
    super.key,
    required this.enabled,
    this.fillOpacity = 0.72,
    required super.child,
  });

  final bool enabled;
  final double fillOpacity;

  static FrostedComposer? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostedComposer>();

  static bool of(BuildContext context) => _of(context)?.enabled ?? false;

  /// [color] as-is, or slightly translucent inside a frosted composer.
  static Color fill(BuildContext context, Color color) {
    final scope = _of(context);
    if (scope == null || !scope.enabled) return color;
    return color.withValues(alpha: color.a * scope.fillOpacity);
  }

  @override
  bool updateShouldNotify(FrostedComposer oldWidget) =>
      oldWidget.enabled != enabled || oldWidget.fillOpacity != fillOpacity;
}

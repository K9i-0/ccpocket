import 'package:flutter/widgets.dart';

/// Marks a composer subtree drawn on frosted glass (the chat shows through
/// behind it). Opaque fills inside should use [fill] to let it show slightly.
class FrostedComposer extends InheritedWidget {
  const FrostedComposer({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  /// Opacity of field and button fills on frosted glass: translucent enough
  /// to blend in, opaque enough to keep text and icons readable.
  static const fillOpacity = 0.85;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostedComposer>()?.enabled ??
      false;

  /// [color] as-is, or slightly translucent inside a frosted composer.
  static Color fill(BuildContext context, Color color) =>
      of(context) ? color.withValues(alpha: color.a * fillOpacity) : color;

  @override
  bool updateShouldNotify(FrostedComposer oldWidget) =>
      oldWidget.enabled != enabled;
}

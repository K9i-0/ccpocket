import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

import 'editor/markdown_highlight.dart';
import 'editor/source_pane.dart';

/// Maximum readable measure for chat and document views on wide viewports.
const double kReadingMaxWidth = 760;

/// Neutral light and dark palettes matched to [MarkdownThemeData.fallback] and
/// [MarkdownThemeData.dark].
@immutable
class ExampleColors {
  const ExampleColors._({
    required this.background,
    required this.chrome,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSubtle,
    required this.hover,
    required this.syntax,
    required this.markdown,
  });

  /// Light colours.
  static final light = ExampleColors._(
    background: const Color(0xFFFFFFFF),
    chrome: const Color(0xFFF6F8FA),
    surface: const Color(0xFFEFF2F5),
    border: const Color(0xFFD0D7DE),
    text: const Color(0xFF1F2328),
    muted: const Color(0xFF57606A),
    accent: const Color(0xFF1F6FEB),
    accentSubtle: const Color(0xFFDDF4FF),
    hover: const Color(0x14818B98),
    syntax: SyntaxPalette.light,
    markdown: MarkdownThemeData.fallback(),
  );

  /// Dark colours.
  static final dark = ExampleColors._(
    background: const Color(0xFF0D1117),
    chrome: const Color(0xFF161B22),
    surface: const Color(0xFF1C2128),
    border: const Color(0xFF30363D),
    text: const Color(0xFFE6EDF3),
    muted: const Color(0xFF8B949E),
    accent: const Color(0xFF58A6FF),
    accentSubtle: const Color(0xFF13233A),
    hover: const Color(0x26B1BAC4),
    syntax: SyntaxPalette.dark,
    markdown: MarkdownThemeData.dark(),
  );

  /// Behind the main content.
  final Color background;

  /// Behind bars and controls.
  final Color chrome;

  /// Subtle fill behind bubbles and inset controls.
  final Color surface;

  /// Hairline borders between regions.
  final Color border;

  /// Primary text.
  final Color text;

  /// Secondary text and hints.
  final Color muted;

  /// Active controls, links and caret.
  final Color accent;

  /// Soft accent tint for bubbles and custom inline pills.
  final Color accentSubtle;

  /// Hover and press tint.
  final Color hover;

  /// Syntax highlighting colours for the editor source pane.
  final SyntaxPalette syntax;

  /// Theme passed to [MarkdownView] and [SliverMarkdownView].
  final MarkdownThemeData markdown;

  /// Colours of the editor source pane.
  SourcePaneColors get source => SourcePaneColors(
    text: text,
    cursor: accent,
    selection: accent.withValues(alpha: 0.28),
    menuBackground: const Color(0xFF24292F),
    menuText: const Color(0xFFFFFFFF),
  );
}

/// Alias kept for code and tests importing `EditorColors` from `editor.dart`.
typedef EditorColors = ExampleColors;

/// A 1px hairline divider.
class Hairline extends StatelessWidget {
  /// Creates a horizontal hairline.
  const Hairline(this.color, {super.key}) : vertical = false, length = null;

  /// Creates a vertical hairline of [length].
  const Hairline.vertical(this.color, {super.key, this.length = 18})
    : vertical = true;

  /// Line colour.
  final Color color;

  /// Whether the line runs vertically.
  final bool vertical;

  /// Height when [vertical] is true.
  final double? length;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return SizedBox(
        width: 1,
        height: length,
        child: ColoredBox(color: color),
      );
    }
    return SizedBox(height: 1, child: ColoredBox(color: color));
  }
}

/// An on/off toggle button with hover feedback and semantics.
class ToggleChip extends StatefulWidget {
  /// Creates a toggle button.
  const ToggleChip({
    super.key,
    required this.label,
    required this.on,
    required this.colors,
    required this.onChanged,
  });

  /// Button label.
  final String label;

  /// Whether the toggle is active.
  final bool on;

  /// Active palette.
  final ExampleColors colors;

  /// Called with the toggled value.
  final ValueChanged<bool> onChanged;

  @override
  State<ToggleChip> createState() => _ToggleChipState();
}

class _ToggleChipState extends State<ToggleChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final on = widget.on;
    return Semantics(
      button: true,
      toggled: on,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!on),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.hover
                  : (on ? colors.background : colors.chrome),
              border: Border.all(
                color: on
                    ? colors.accent.withValues(alpha: 0.55)
                    : colors.border,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? colors.accent : null,
                        border: on
                            ? null
                            : Border.all(color: colors.muted, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: on ? colors.text : colors.muted,
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual emphasis of an [ActionButton].
enum ActionTone {
  /// Accent-filled primary action.
  primary,

  /// Outlined secondary action.
  outlined,

  /// Quiet borderless action.
  subtle,
}

/// A compact button built on `package:flutter/widgets.dart`.
class ActionButton extends StatefulWidget {
  /// Creates an action button.
  const ActionButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onPressed,
    this.tone = ActionTone.outlined,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.fontSize = 12.5,
  });

  /// Button text.
  final String label;

  /// Active palette.
  final ExampleColors colors;

  /// Callback when tapped; null disables the button.
  final VoidCallback? onPressed;

  /// Visual style.
  final ActionTone tone;

  /// Inner padding.
  final EdgeInsets padding;

  /// Text size.
  final double fontSize;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final enabled = widget.onPressed != null;
    final Color? fill;
    final Border? border;
    final Color labelColor;

    switch (widget.tone) {
      case ActionTone.primary:
        fill = enabled
            ? (_pressed ? colors.accent.withValues(alpha: 0.85) : colors.accent)
            : colors.border;
        border = null;
        labelColor = const Color(0xFFFFFFFF);
      case ActionTone.outlined:
        fill = enabled && (_hovered || _pressed)
            ? colors.hover
            : colors.background;
        border = Border.all(color: colors.border);
        labelColor = enabled ? colors.text : colors.muted;
      case ActionTone.subtle:
        fill = enabled && (_hovered || _pressed) ? colors.hover : null;
        border = null;
        labelColor = enabled ? colors.text : colors.muted;
    }

    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: widget.padding,
        child: Text(
          widget.label,
          style: TextStyle(
            color: labelColor,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: enabled ? button : Opacity(opacity: 0.45, child: button),
        ),
      ),
    );
  }
}

/// A compact segmented control for switching between a few mutually exclusive
/// options.
class SegmentedSwitch<T> extends StatelessWidget {
  /// Creates a segmented control.
  const SegmentedSwitch({
    super.key,
    required this.items,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  /// Choices in display order.
  final List<({T value, String label, Key? key})> items;

  /// Currently selected choice.
  final T value;

  /// Active palette.
  final ExampleColors colors;

  /// Called when the user picks another option.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: const BorderRadius.all(Radius.circular(7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _SegmentItem(
                key: item.key,
                label: item.label,
                selected: item.value == value,
                colors: colors,
                onTap: () => onChanged(item.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentItem extends StatefulWidget {
  const _SegmentItem({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ExampleColors colors;
  final VoidCallback onTap;

  @override
  State<_SegmentItem> createState() => _SegmentItemState();
}

class _SegmentItemState extends State<_SegmentItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.background
                  : (_hovered ? colors.hover : null),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected ? colors.text : colors.muted,
                  fontSize: 12.5,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

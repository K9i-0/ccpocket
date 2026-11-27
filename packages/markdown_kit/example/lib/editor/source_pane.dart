import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart' show kMarkdownMonospaceFallback;

import 'markdown_editing.dart';

// The left pane: a plain multi-line text field for the Markdown source.
//
// markdown_kit renders Markdown and does not edit it, so this is ordinary
// Flutter text editing. It is built on `EditableText` rather than a Material
// or Cupertino text field to keep the example free of a design system; in an
// app, use the text field of yours.

/// Colours of the source pane's own chrome.
@immutable
class SourcePaneColors {
  /// Creates a set of colours.
  const SourcePaneColors({
    required this.text,
    required this.cursor,
    required this.selection,
    required this.menuBackground,
    required this.menuText,
  });

  /// Source text.
  final Color text;

  /// Caret and selection handles.
  final Color cursor;

  /// Behind selected text.
  final Color selection;

  /// Behind the Cut / Copy / Paste menu.
  final Color menuBackground;

  /// Labels of the menu.
  final Color menuText;
}

/// An editable, scrolling view of Markdown source.
class SourcePane extends StatefulWidget {
  /// Creates the pane.
  const SourcePane({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.editableKey,
    required this.colors,
  });

  /// Holds the text and selection.
  final TextEditingController controller;

  /// Focus of the text field.
  final FocusNode focusNode;

  /// Scroll position of the pane.
  final ScrollController scrollController;

  /// Key of the [EditableText], through which the caret can be located.
  final GlobalKey<EditableTextState> editableKey;

  /// Colours of text, caret and menu.
  final SourcePaneColors colors;

  /// Space around the text inside the scroll view.
  static const padding = EdgeInsets.fromLTRB(20, 16, 20, 24);

  @override
  State<SourcePane> createState() => _SourcePaneState();
}

class _SourcePaneState extends State<SourcePane>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);
  late _SelectionControls _controls = _SelectionControls(widget.colors.cursor);
  bool _showHandles = false;

  @override
  void didUpdateWidget(covariant SourcePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colors.cursor != widget.colors.cursor) {
      _controls = _SelectionControls(widget.colors.cursor);
    }
  }

  @override
  GlobalKey<EditableTextState> get editableTextKey => widget.editableKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  void _selectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    // Handles are for fingers: shown after a touch, not after a key or click.
    final show =
        _gestures.shouldShowSelectionToolbar &&
        cause != SelectionChangedCause.keyboard &&
        (cause == SelectionChangedCause.longPress ||
            cause == SelectionChangedCause.stylusHandwriting ||
            widget.controller.text.isNotEmpty);
    if (show != _showHandles) setState(() => _showHandles = show);
    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.drag) {
      widget.editableKey.currentState?.bringIntoView(selection.extent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final style = TextStyle(
      color: colors.text,
      fontFamily: 'monospace',
      fontFamilyFallback: kMarkdownMonospaceFallback,
      fontSize: 14,
      height: 1.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('source-scroll'),
        controller: widget.scrollController,
        padding: SourcePane.padding,
        child: ConstrainedBox(
          // Fills the pane, so a click below the last line still lands in the
          // text field.
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - SourcePane.padding.vertical)
                .clamp(0, double.infinity),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: _gestures.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: EditableText(
                key: widget.editableKey,
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: style,
                strutStyle: StrutStyle.fromTextStyle(
                  style,
                  forceStrutHeight: true,
                ),
                cursorColor: colors.cursor,
                backgroundCursorColor: colors.selection,
                selectionColor: colors.selection,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(1),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                inputFormatters: const [MarkdownEnterFormatter()],
                // The pane scrolls, not the field inside it.
                scrollPhysics: const NeverScrollableScrollPhysics(),
                rendererIgnoresPointer: true,
                showSelectionHandles: _showHandles,
                selectionControls: _controls,
                onSelectionChanged: _selectionChanged,
                contextMenuBuilder: (context, editable) => _ContextMenu(
                  anchors: editable.contextMenuAnchors,
                  items: editable.contextMenuButtonItems,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection handles drawn without a design system: a dot on a short stem.
class _SelectionControls extends TextSelectionControls {
  _SelectionControls(this.color);

  final Color color;

  static const double _dot = 14;
  static const double _stem = 4;

  @override
  Size getHandleSize(double textLineHeight) => const Size(_dot, _dot + _stem);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      const Offset(_dot / 2, 0);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        size: getHandleSize(textLineHeight),
        painter: _HandlePainter(color),
      ),
    );
  }

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) => const SizedBox.shrink();
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = size.width / 2;
    canvas
      ..drawRect(Rect.fromLTWH(center - 1, 0, 2, size.height - center), paint)
      ..drawCircle(Offset(center, size.height - center), center, paint);
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) => oldDelegate.color != color;
}

/// Cut / Copy / Paste / Select all, placed above the selection or at the
/// pointer.
class _ContextMenu extends StatelessWidget {
  const _ContextMenu({
    required this.anchors,
    required this.items,
    required this.colors,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> items;
  final SourcePaneColors colors;

  static String? _label(ContextMenuButtonItem item) => switch (item.type) {
    ContextMenuButtonType.cut => 'Cut',
    ContextMenuButtonType.copy => 'Copy',
    ContextMenuButtonType.paste => 'Paste',
    ContextMenuButtonType.selectAll => 'Select all',
    _ => item.label,
  };

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final item in items)
        if (_label(item) case final label? when item.onPressed != null)
          (label: label, onPressed: item.onPressed!),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    final padding = MediaQuery.paddingOf(context);
    const gap = 8.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, padding.top + 8, 8, padding.bottom + 8),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: anchors.primaryAnchor - Offset(8, padding.top + 8 + gap),
          anchorBelow:
              (anchors.secondaryAnchor ?? anchors.primaryAnchor) -
              Offset(8, padding.top + 8 - gap),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.menuBackground,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: entry.onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      entry.label,
                      style: TextStyle(color: colors.menuText, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

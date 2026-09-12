import 'package:flutter/material.dart';
import 'package:flutter_painter/flutter_painter.dart';

import '../../../l10n/app_localizations.dart';

enum SketchTool { select, pen, eraser, text, arrow, rectangle, ellipse }

class SketchToolbar extends StatelessWidget {
  const SketchToolbar({
    super.key,
    required this.controller,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
  });

  final PainterController controller;
  final SketchTool tool;
  final Color color;
  final double strokeWidth;
  final ValueChanged<SketchTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final candidate in SketchTool.values)
                    SketchToolButton(
                      tool: candidate,
                      selected: tool == candidate,
                      onPressed: () => onToolChanged(candidate),
                    ),
                ],
              ),
            ),
            SketchColorPalette(color: color, onChanged: onColorChanged),
            ValueListenableBuilder<PainterControllerValue>(
              valueListenable: controller,
              builder: (context, value, child) => Row(
                children: [
                  const SizedBox(width: 16),
                  Tooltip(
                    message: l10n.sketchStrokeWidth,
                    child: const Icon(Icons.line_weight, size: 20),
                  ),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('sketch_stroke_width_slider'),
                      value: strokeWidth,
                      min: 2,
                      max: 24,
                      divisions: 11,
                      label: strokeWidth.round().toString(),
                      semanticFormatterCallback: (value) =>
                          '${l10n.sketchStrokeWidth}: ${value.round()}',
                      onChanged: onStrokeWidthChanged,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('sketch_undo_button'),
                    tooltip: l10n.sketchUndo,
                    onPressed: controller.canUndo ? controller.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const ValueKey('sketch_redo_button'),
                    tooltip: l10n.sketchRedo,
                    onPressed: controller.canRedo ? controller.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    key: const ValueKey('sketch_delete_button'),
                    tooltip: l10n.sketchDelete,
                    onPressed: value.selectedObjectDrawable == null
                        ? null
                        : controller.removeSelectedObjectDrawable,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SketchToolButton extends StatelessWidget {
  const SketchToolButton({
    super.key,
    required this.tool,
    required this.selected,
    required this.onPressed,
  });

  final SketchTool tool;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, icon) = switch (tool) {
      SketchTool.select => (l10n.sketchSelect, Icons.near_me_outlined),
      SketchTool.pen => (l10n.sketchPen, Icons.edit_outlined),
      SketchTool.eraser => (l10n.sketchEraser, Icons.auto_fix_normal),
      SketchTool.text => (l10n.sketchText, Icons.text_fields),
      SketchTool.arrow => (l10n.sketchArrow, Icons.arrow_outward),
      SketchTool.rectangle => (l10n.sketchRectangle, Icons.crop_square),
      SketchTool.ellipse => (l10n.sketchEllipse, Icons.circle_outlined),
    };
    return IconButton(
      key: ValueKey('sketch_${tool.name}_button'),
      tooltip: label,
      isSelected: selected,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class SketchColorPalette extends StatelessWidget {
  const SketchColorPalette({
    super.key,
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  static const colors = [
    Colors.black,
    Colors.white,
    Color(0xffe53935),
    Color(0xfffb8c00),
    Color(0xfffdd835),
    Color(0xff43a047),
    Color(0xff1e88e5),
    Color(0xff8e24aa),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < colors.length; index++)
            Semantics(
              label: '${l10n.sketchColor} ${index + 1}',
              selected: colors[index] == color,
              button: true,
              child: InkResponse(
                key: ValueKey('sketch_color_${index}_button'),
                onTap: () => onChanged(colors[index]),
                radius: 24,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: colors[index] == color
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: colors[index].computeLuminance() > 0.4
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../workspace/workspace_layout_metrics.dart';
import 'settings_tiles.dart';

/// Slider for the usable window width at which the workspace splits into
/// panes. The value is committed when the drag ends, so the layout does not
/// switch under the user's finger while crossing the current window width.
class MultiPaneBreakpointTile extends StatefulWidget {
  const MultiPaneBreakpointTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<MultiPaneBreakpointTile> createState() =>
      _MultiPaneBreakpointTileState();
}

class _MultiPaneBreakpointTileState extends State<MultiPaneBreakpointTile> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final value = _dragValue ?? widget.value;
    final windowWidth = _usableWindowWidth(context);
    final splits = windowWidth >= value;
    final isDefault = widget.value == kWorkspaceDefaultMultiPaneBreakpoint;
    final fitting = workspaceMultiPaneBreakpointFittingWidth(windowWidth);
    final guideColor = cs.tertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsLeadingIcon(Icons.vertical_split_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.multiPaneBreakpoint)),
                        Text(
                          '${value.round()}pt',
                          key: const ValueKey(
                            'multi_pane_breakpoint_value_label',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.multiPaneBreakpointDescription(
                        kWorkspaceThreePaneMinWidth.round(),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (fitting != null) ...[
                          Container(
                            key: const ValueKey(
                              'multi_pane_breakpoint_guide_legend',
                            ),
                            width: 3,
                            height: 12,
                            decoration: BoxDecoration(
                              color: guideColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            splits
                                ? l.multiPaneBreakpointCurrentSplit(
                                    windowWidth.round(),
                                  )
                                : l.multiPaneBreakpointCurrentSingle(
                                    windowWidth.round(),
                                  ),
                            key: const ValueKey(
                              'multi_pane_breakpoint_current_width',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: _GuideSliderTrackShape(
                base:
                    SliderTheme.of(context).trackShape ??
                    const RoundedRectSliderTrackShape(),
                guideFraction: fitting == null
                    ? null
                    : (fitting - kWorkspaceMinMultiPaneBreakpoint) /
                          (kWorkspaceMaxMultiPaneBreakpoint -
                              kWorkspaceMinMultiPaneBreakpoint),
                guideColor: guideColor,
              ),
            ),
            child: Slider(
              key: const ValueKey('multi_pane_breakpoint_slider'),
              value: value,
              min: kWorkspaceMinMultiPaneBreakpoint,
              max: kWorkspaceMaxMultiPaneBreakpoint,
              divisions:
                  ((kWorkspaceMaxMultiPaneBreakpoint -
                              kWorkspaceMinMultiPaneBreakpoint) /
                          kWorkspaceMultiPaneBreakpointStep)
                      .round(),
              label: '${value.round()}pt',
              onChanged: (next) => setState(() => _dragValue = next),
              onChangeEnd: (next) {
                setState(() => _dragValue = null);
                widget.onChanged(next);
              },
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (fitting != null)
                TextButton.icon(
                  key: const ValueKey('multi_pane_breakpoint_match_current'),
                  style: TextButton.styleFrom(foregroundColor: guideColor),
                  onPressed: widget.value == fitting
                      ? null
                      : () => widget.onChanged(fitting),
                  icon: const Icon(Icons.straighten_rounded, size: 18),
                  label: Text(
                    l.multiPaneBreakpointMatchCurrent(fitting.round()),
                  ),
                ),
              TextButton(
                key: const ValueKey('multi_pane_breakpoint_reset'),
                onPressed: isDefault
                    ? null
                    : () => widget.onChanged(
                        kWorkspaceDefaultMultiPaneBreakpoint,
                      ),
                child: Text(
                  l.multiPaneBreakpointReset(
                    kWorkspaceDefaultMultiPaneBreakpoint.round(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Window width without horizontal safe-area insets, as the workspace
  /// measures it. Panes keep the window size in [MediaQuery] but strip their
  /// interior insets, so the insets are read from the view.
  static double _usableWindowWidth(BuildContext context) {
    final windowWidth = MediaQuery.sizeOf(context).width;
    final insets = MediaQueryData.fromView(View.of(context)).padding;
    final width = windowWidth - insets.horizontal;
    return width < 0 ? 0 : width;
  }
}

/// Wraps the theme's track shape and marks [guideFraction] of the track, the
/// position of the threshold that just splits the current window. Uses the
/// same position formula as the discrete [Slider] thumb so the thumb sits
/// exactly on the mark when the value matches.
class _GuideSliderTrackShape extends SliderTrackShape {
  const _GuideSliderTrackShape({
    required this.base,
    required this.guideFraction,
    required this.guideColor,
  });

  final SliderTrackShape base;
  final double? guideFraction;
  final Color guideColor;

  @override
  bool get isRounded => base.isRounded;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) => base.getPreferredRect(
    parentBox: parentBox,
    offset: offset,
    sliderTheme: sliderTheme,
    isEnabled: isEnabled,
    isDiscrete: isDiscrete,
  );

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    base.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
      textDirection: textDirection,
    );
    final fraction = guideFraction;
    if (fraction == null) return;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final inset = isRounded && isDiscrete ? trackRect.height : 0.0;
    final visual = textDirection == TextDirection.rtl ? 1 - fraction : fraction;
    final x = trackRect.left + visual * (trackRect.width - inset) + inset / 2;
    final halfHeight = trackRect.height / 2 + 8;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, trackRect.center.dy),
          width: 3,
          height: halfHeight * 2,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = guideColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _GuideSliderTrackShape &&
      other.base == base &&
      other.guideFraction == guideFraction &&
      other.guideColor == guideColor;

  @override
  int get hashCode => Object.hash(base, guideFraction, guideColor);
}

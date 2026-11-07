import 'package:flutter/material.dart';

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
                    Text(
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('multi_pane_breakpoint_reset'),
              onPressed: isDefault
                  ? null
                  : () =>
                        widget.onChanged(kWorkspaceDefaultMultiPaneBreakpoint),
              child: Text(
                l.multiPaneBreakpointReset(
                  kWorkspaceDefaultMultiPaneBreakpoint.round(),
                ),
              ),
            ),
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

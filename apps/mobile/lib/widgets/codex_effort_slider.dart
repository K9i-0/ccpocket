import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/messages.dart';

String codexModelDisplayName(String model) {
  final raw = model.replaceFirst(RegExp(r'^gpt-'), '');
  return raw
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (RegExp(r'^\d').hasMatch(part)) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

const _quickEffortOrder = <ReasoningEffort>[
  ReasoningEffort.none,
  ReasoningEffort.low,
  ReasoningEffort.medium,
  ReasoningEffort.high,
  ReasoningEffort.xhigh,
];

List<ReasoningEffort> codexQuickEfforts(
  List<ReasoningEffort> availableEfforts,
) {
  final efforts = _quickEffortOrder
      .where(availableEfforts.contains)
      .toList(growable: false);
  return efforts.isNotEmpty ? efforts : const [ReasoningEffort.none];
}

ReasoningEffort preferredCodexEffort(
  List<ReasoningEffort> availableEfforts, {
  ReasoningEffort? current,
}) {
  if (current != null && availableEfforts.contains(current)) return current;
  if (availableEfforts.contains(ReasoningEffort.high)) {
    return ReasoningEffort.high;
  }
  return availableEfforts.firstWhere(
    (effort) => effort != ReasoningEffort.none,
    orElse: () => availableEfforts.first,
  );
}

/// Whether the model can use Codex Fast mode.
///
/// `priority` is accepted for compatibility with Bridge versions that exposed
/// the app-server's low-level service-tier id instead of its user-facing Fast
/// speed tier. Missing metadata keeps the control disabled because Bridges old
/// enough not to advertise Speed may also not support changing it.
bool codexSupportsFast(
  String? model,
  Map<String, List<String>> modelServiceTiers, {
  CodexSpeed speed = CodexSpeed.standard,
}) {
  if (speed == CodexSpeed.fast) return true;
  final effectiveModel = model ?? 'gpt-5.5';
  final tiers = modelServiceTiers[effectiveModel];
  if (tiers != null) {
    return tiers.contains('fast') || tiers.contains('priority');
  }
  return false;
}

class CodexSettingsPanel extends StatelessWidget {
  final String model;
  final ReasoningEffort effort;
  final CodexSpeed speed;
  final bool supportsFast;
  final ValueChanged<CodexSpeed> onSpeedChanged;
  final String speedButtonKey;
  final bool showAdvanced;
  final String advancedLabel;
  final String toggleButtonKey;
  final VoidCallback onToggleMode;
  final String quickPanelKey;
  final String advancedPanelKey;
  final String modelLabelKey;
  final String effortLabelKey;
  final Widget quickChild;
  final Widget advancedChild;

  const CodexSettingsPanel({
    super.key,
    required this.model,
    required this.effort,
    required this.speed,
    required this.supportsFast,
    required this.onSpeedChanged,
    required this.speedButtonKey,
    required this.showAdvanced,
    required this.advancedLabel,
    required this.toggleButtonKey,
    required this.onToggleMode,
    required this.quickPanelKey,
    required this.advancedPanelKey,
    required this.modelLabelKey,
    required this.effortLabelKey,
    required this.quickChild,
    required this.advancedChild,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CodexSettingsHeader(
            model: model,
            effort: effort,
            speed: speed,
            supportsFast: supportsFast,
            onSpeedChanged: onSpeedChanged,
            speedButtonKey: speedButtonKey,
            showAdvanced: showAdvanced,
            advancedLabel: advancedLabel,
            toggleButtonKey: toggleButtonKey,
            onToggleMode: onToggleMode,
            modelLabelKey: modelLabelKey,
            effortLabelKey: effortLabelKey,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(showAdvanced ? advancedPanelKey : quickPanelKey),
                child: showAdvanced ? advancedChild : quickChild,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexSettingsHeader extends StatelessWidget {
  final String model;
  final ReasoningEffort effort;
  final CodexSpeed speed;
  final bool supportsFast;
  final ValueChanged<CodexSpeed> onSpeedChanged;
  final String speedButtonKey;
  final bool showAdvanced;
  final String advancedLabel;
  final String toggleButtonKey;
  final VoidCallback onToggleMode;
  final String modelLabelKey;
  final String effortLabelKey;

  const _CodexSettingsHeader({
    required this.model,
    required this.effort,
    required this.speed,
    required this.supportsFast,
    required this.onSpeedChanged,
    required this.speedButtonKey,
    required this.showAdvanced,
    required this.advancedLabel,
    required this.toggleButtonKey,
    required this.onToggleMode,
    required this.modelLabelKey,
    required this.effortLabelKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effortText = Text(
      effort.label,
      key: ValueKey(effortLabelKey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          CodexSpeedButton(
            speed: speed,
            enabled: supportsFast,
            onChanged: onSpeedChanged,
            buttonKey: speedButtonKey,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    codexModelDisplayName(model),
                    key: ValueKey(modelLabelKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Effort',
                  value: effort.label,
                  excludeSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: effortText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          Semantics(
            toggled: showAdvanced,
            child: Tooltip(
              message: advancedLabel,
              child: IconButton(
                key: ValueKey(toggleButtonKey),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onToggleMode();
                },
                style: IconButton.styleFrom(
                  backgroundColor: showAdvanced
                      ? cs.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  foregroundColor: showAdvanced
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    showAdvanced
                        ? Icons.linear_scale_rounded
                        : Icons.tune_rounded,
                    key: ValueKey(showAdvanced),
                    size: 19,
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

class CodexEffortSlider extends StatelessWidget {
  final List<ReasoningEffort> efforts;
  final ReasoningEffort value;
  final ValueChanged<ReasoningEffort> onChanged;
  final String sliderKey;

  const CodexEffortSlider({
    super.key,
    required this.efforts,
    required this.value,
    required this.onChanged,
    required this.sliderKey,
  });

  @override
  Widget build(BuildContext context) {
    final quickEfforts = codexQuickEfforts(efforts);
    final selectedIndex = quickEfforts.indexOf(value);
    final sliderIndex = selectedIndex < 0
        ? quickEfforts.length - 1
        : selectedIndex;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 7,
          activeTrackColor: cs.primary,
          inactiveTrackColor: cs.surfaceContainerHighest,
          thumbColor: cs.primary,
          overlayColor: cs.primary.withValues(alpha: 0.12),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
          activeTickMarkColor: cs.onPrimary.withValues(alpha: 0.45),
          inactiveTickMarkColor: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
        child: Semantics(
          label: 'Effort',
          value: value.label,
          child: Slider(
            key: ValueKey(sliderKey),
            value: sliderIndex.toDouble(),
            min: 0,
            max: (quickEfforts.length - 1).toDouble(),
            divisions: quickEfforts.length > 1 ? quickEfforts.length - 1 : null,
            label: quickEfforts[sliderIndex].label,
            onChanged: quickEfforts.length < 2
                ? null
                : (raw) {
                    final next = quickEfforts[raw.round()];
                    if (next == value) return;
                    HapticFeedback.selectionClick();
                    onChanged(next);
                  },
          ),
        ),
      ),
    );
  }
}

class CodexSpeedButton extends StatelessWidget {
  final CodexSpeed speed;
  final ValueChanged<CodexSpeed> onChanged;
  final String buttonKey;
  final bool enabled;

  const CodexSpeedButton({
    super.key,
    required this.speed,
    required this.onChanged,
    required this.buttonKey,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFast = speed == CodexSpeed.fast;
    return Tooltip(
      message: isFast ? 'Fast mode on' : 'Fast mode off',
      child: IconButton(
        key: ValueKey(buttonKey),
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onChanged(isFast ? CodexSpeed.standard : CodexSpeed.fast);
              }
            : null,
        icon: Icon(
          isFast ? Icons.bolt : Icons.bolt_outlined,
          color: isFast ? cs.primary : cs.onSurfaceVariant,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

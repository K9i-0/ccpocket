import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../state/settings_cubit.dart';

class TextScaleTile extends StatelessWidget {
  const TextScaleTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final percent = _formatPercent(value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.format_size, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.textDensity)),
                        Text(
                          percent,
                          key: const ValueKey('text_scale_value_label'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.textDensityDescription,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            key: const ValueKey('text_scale_slider'),
            value: value,
            min: SettingsCubit.minTextScale,
            max: SettingsCubit.maxTextScale,
            divisions:
                ((SettingsCubit.maxTextScale - SettingsCubit.minTextScale) *
                        100)
                    .round(),
            label: percent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _formatPercent(double scale) => '${(scale * 100).round()}%';
}

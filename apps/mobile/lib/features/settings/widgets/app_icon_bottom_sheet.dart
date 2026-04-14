import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/app_icon.dart';

Future<void> showAppIconBottomSheet({
  required BuildContext context,
  required AppIconVariant current,
  required bool isSupporter,
  required ValueChanged<AppIconVariant> onChanged,
  required VoidCallback onSupporterRequired,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AppIconBottomSheetContent(
      current: current,
      isSupporter: isSupporter,
      onChanged: onChanged,
      onSupporterRequired: onSupporterRequired,
    ),
  );
}

class _AppIconBottomSheetContent extends StatelessWidget {
  const _AppIconBottomSheetContent({
    required this.current,
    required this.isSupporter,
    required this.onChanged,
    required this.onSupporterRequired,
  });

  final AppIconVariant current;
  final bool isSupporter;
  final ValueChanged<AppIconVariant> onChanged;
  final VoidCallback onSupporterRequired;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.appIconPickerTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l.appIconPickerSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _AppIconOptionTile(
              key: const ValueKey('app_icon_option_default'),
              option: AppIconVariant.defaultIcon,
              isSelected: current == AppIconVariant.defaultIcon,
              title: _titleForOption(l, AppIconVariant.defaultIcon),
              subtitle: _subtitleForOption(l, AppIconVariant.defaultIcon),
              onTap: () {
                Navigator.of(context).pop();
                onChanged(AppIconVariant.defaultIcon);
              },
            ),
            const SizedBox(height: 18),
            _SupporterPerkDivider(
              key: const ValueKey('app_icon_supporter_divider'),
              label: l.appIconSupporterSectionLabel,
              locked: !isSupporter,
            ),
            const SizedBox(height: 12),
            for (final option in AppIconVariant.values.skip(1)) ...[
              _AppIconOptionTile(
                key: ValueKey('app_icon_option_${option.id}'),
                option: option,
                isSelected: option == current,
                title: _titleForOption(l, option),
                subtitle: _subtitleForOption(l, option),
                locked: !isSupporter,
                onTap: () {
                  Navigator.of(context).pop();
                  if (!isSupporter) {
                    onSupporterRequired();
                    return;
                  }
                  onChanged(option);
                },
              ),
              if (option != AppIconVariant.values.last)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  String _titleForOption(AppLocalizations l, AppIconVariant option) {
    return switch (option) {
      AppIconVariant.defaultIcon => l.appIconOptionDefaultTitle,
      AppIconVariant.lightOutline => l.appIconOptionLightOutlineTitle,
      AppIconVariant.proCopperEmerald => l.appIconOptionCopperEmeraldTitle,
    };
  }

  String _subtitleForOption(AppLocalizations l, AppIconVariant option) {
    return switch (option) {
      AppIconVariant.defaultIcon => l.appIconOptionDefaultSubtitle,
      AppIconVariant.lightOutline => l.appIconOptionLightOutlineSubtitle,
      AppIconVariant.proCopperEmerald => l.appIconOptionCopperEmeraldSubtitle,
    };
  }
}

class _AppIconOptionTile extends StatelessWidget {
  const _AppIconOptionTile({
    super.key,
    required this.option,
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  final AppIconVariant option;
  final bool isSelected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isSelected && !locked
          ? cs.primaryContainer.withValues(alpha: 0.65)
          : cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  option.previewAssetPath,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked
                    ? Icons.lock_outline
                    : isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off_outlined,
                color: locked
                    ? cs.outline
                    : isSelected
                    ? cs.primary
                    : cs.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupporterPerkDivider extends StatelessWidget {
  const _SupporterPerkDivider({
    super.key,
    required this.label,
    required this.locked,
  });

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

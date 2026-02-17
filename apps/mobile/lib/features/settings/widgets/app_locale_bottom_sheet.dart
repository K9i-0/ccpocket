import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// Available app display locales.
/// id is empty string for system default, otherwise a language code (e.g. 'ja', 'en').
const appLocales = <(String id, String label, String? subtitle)>[
  ('', '', null), // System default — label resolved via l10n
  ('ja', '日本語', 'Japanese'),
  ('en', 'English', null),
];

/// Shows a bottom sheet for selecting the app display locale.
Future<void> showAppLocaleBottomSheet({
  required BuildContext context,
  required String current,
  required ValueChanged<String> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _AppLocaleBottomSheetContent(
      current: current,
      onChanged: (id) {
        onChanged(id);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _AppLocaleBottomSheetContent extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _AppLocaleBottomSheetContent({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: appColors.subtleText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Icon(Icons.language, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(l.language, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        const Divider(height: 1),
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (id, label, subtitle) in appLocales)
                RadioListTile<String>(
                  value: id,
                  title: Text(id.isEmpty ? l.languageSystem : label),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

/// Returns the display label for an app locale ID.
String getAppLocaleLabel(BuildContext context, String localeId) {
  if (localeId.isEmpty) {
    return AppLocalizations.of(context).languageSystem;
  }
  final locale = appLocales.firstWhere(
    (l) => l.$1 == localeId,
    orElse: () => appLocales.first,
  );
  return locale.$2.isNotEmpty ? locale.$2 : localeId;
}

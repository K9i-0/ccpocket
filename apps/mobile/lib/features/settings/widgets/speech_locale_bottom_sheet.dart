import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// Available speech recognition locales.
const speechLocales = <(String id, String label, String? subtitle)>[
  ('ja-JP', 'Japanese', '日本語'),
  ('en-US', 'English (US)', null),
  ('en-GB', 'English (UK)', null),
  ('zh-Hans-CN', 'Chinese (Mandarin)', '中文'),
  ('ko-KR', 'Korean', '한국어'),
  ('es-ES', 'Spanish', 'Español'),
  ('fr-FR', 'French', 'Français'),
  ('de-DE', 'German', 'Deutsch'),
];

/// Shows a bottom sheet for selecting the speech recognition locale.
Future<void> showSpeechLocaleBottomSheet({
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
    builder: (ctx) => _SpeechLocaleBottomSheetContent(
      current: current,
      onChanged: (id) {
        onChanged(id);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _SpeechLocaleBottomSheetContent extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SpeechLocaleBottomSheetContent({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

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
              Icon(Icons.record_voice_over, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).voiceInputLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
              for (final (id, label, subtitle) in speechLocales)
                RadioListTile<String>(
                  value: id,
                  title: Text(label),
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

/// Returns the display label for a speech locale ID.
String getSpeechLocaleLabel(String localeId) {
  final locale = speechLocales.firstWhere(
    (l) => l.$1 == localeId,
    orElse: () => speechLocales.first,
  );
  final subtitle = locale.$3;
  return subtitle != null ? '${locale.$2} ($subtitle)' : locale.$2;
}

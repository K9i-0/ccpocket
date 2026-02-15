import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Shows a bottom sheet for selecting the app theme mode.
Future<void> showThemeBottomSheet({
  required BuildContext context,
  required ThemeMode current,
  required ValueChanged<ThemeMode> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ThemeBottomSheetContent(
      current: current,
      onChanged: (mode) {
        onChanged(mode);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _ThemeBottomSheetContent extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeBottomSheetContent({
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
              Icon(Icons.palette, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: const Text('System'),
                secondary: const Icon(Icons.settings_brightness, size: 20),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: const Text('Light'),
                secondary: const Icon(Icons.light_mode, size: 20),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: const Text('Dark'),
                secondary: const Icon(Icons.dark_mode, size: 20),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

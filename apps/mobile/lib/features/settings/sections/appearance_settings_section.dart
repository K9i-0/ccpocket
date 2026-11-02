import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/app_icon.dart';
import '../../../router/app_router.dart';
import '../../../services/revenuecat_service.dart';
import '../code_font_settings_screen.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/app_icon_bottom_sheet.dart';
import '../widgets/app_locale_bottom_sheet.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/settings_visibility_builder.dart';
import '../widgets/text_scale_tile.dart';

String themeModeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.themeSystem,
  ThemeMode.light => l.themeLight,
  ThemeMode.dark => l.themeDark,
};

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.state,
    required this.visibility,
    required this.environment,
  });

  final SettingsState state;
  final SettingsVisibility visibility;
  final SettingsEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final revenueCat = context.read<RevenueCatService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.theme,
          children: [
            SettingsItem(
              id: SettingsEntryIds.theme,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ThemeModePicker(
                  value: state.themeMode,
                  onChanged: cubit.setThemeMode,
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.settingsGroupDisplay,
          children: [
            SettingsItem(
              id: SettingsEntryIds.language,
              child: SettingsNavTile(
                icon: Icons.translate_rounded,
                title: Text(l.language),
                subtitle: getAppLocaleLabel(context, state.appLocaleId),
                onTap: () => showAppLocaleBottomSheet(
                  context: context,
                  current: state.appLocaleId,
                  onChanged: cubit.setAppLocaleId,
                ),
              ),
            ),
            if (visibility.appIconSupported)
              SettingsItem(
                id: SettingsEntryIds.appIcon,
                child: ValueListenableBuilder<SupporterState>(
                  valueListenable: revenueCat.supporterState,
                  builder: (context, supporterState, _) {
                    return SettingsNavTile(
                      key: const ValueKey('app_icon_tile'),
                      icon: Icons.apps_rounded,
                      title: Text(l.appIconTitle),
                      subtitle: _appIconSubtitle(
                        l,
                        selectedIcon: state.selectedAppIcon,
                        isSupporter: supporterState.isSupporter,
                        deviceName: environment.appIconDeviceName,
                      ),
                      onTap: () => showAppIconBottomSheet(
                        context: context,
                        current: state.selectedAppIcon,
                        isSupporter: supporterState.isSupporter,
                        onChanged: cubit.setSelectedAppIcon,
                        onSupporterRequired: () =>
                            context.pushRoute(const SupporterRoute()),
                      ),
                    );
                  },
                ),
              ),
            SettingsItem(
              id: SettingsEntryIds.textDensity,
              child: TextScaleTile(
                value: state.textScale,
                onChanged: cubit.setTextScale,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.settingsGroupCode,
          children: [
            SettingsItem(
              id: SettingsEntryIds.codeFont,
              child: SettingsNavTile(
                key: const ValueKey('code_font_settings_tile'),
                icon: Icons.font_download_rounded,
                title: Text(l.codeFontFamily),
                subtitle:
                    '${state.codeFontFamily.label} · '
                    '${state.codeFontSize.round()}pt',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CodeFontSettingsScreen(),
                  ),
                ),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.indentSize,
              child: SettingsNavTile(
                icon: Icons.format_indent_increase_rounded,
                title: Text(l.indentSize),
                trailing: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                  ],
                  selected: {state.indentSize},
                  onSelectionChanged: (selected) =>
                      cubit.setIndentSize(selected.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _appIconSubtitle(
    AppLocalizations l, {
    required AppIconVariant selectedIcon,
    required bool isSupporter,
    required String deviceName,
  }) {
    if (!isSupporter) return l.appIconSettingsSubtitle(deviceName);
    return switch (selectedIcon) {
      AppIconVariant.defaultIcon => l.appIconOptionDefaultTitle,
      AppIconVariant.lightOutline => l.appIconOptionLightOutlineTitle,
      AppIconVariant.proCopperEmerald => l.appIconOptionCopperEmeraldTitle,
    };
  }
}

/// Three visual swatches for System / Light / Dark.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        for (final (index, mode) in ThemeMode.values.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _ThemeModeOption(
              key: ValueKey('theme_option_${mode.name}'),
              mode: mode,
              label: themeModeLabel(l, mode),
              selected: mode == value,
              onTap: () => onChanged(mode),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = SettingsAccent.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 72,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? accent
                        : cs.outlineVariant.withValues(alpha: 0.7),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: switch (mode) {
                    ThemeMode.light => const _ThemePreview(dark: false),
                    ThemeMode.dark => const _ThemePreview(dark: true),
                    ThemeMode.system => const Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ThemePreview(dark: false)),
                        Expanded(child: _ThemePreview(dark: true)),
                      ],
                    ),
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle_rounded, size: 16, color: accent),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? accent : cs.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny mock of a chat screen in light or dark colors.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF17181C) : const Color(0xFFF7F5F2);
    final bubble = dark ? const Color(0xFF2A2C33) : const Color(0xFFE6E2DC);
    const accent = Color(0xFFF97316);
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewBar(color: bubble, widthFactor: 0.7),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: const _PreviewBar(color: accent, widthFactor: 0.5),
            ),
            const SizedBox(height: 5),
            _PreviewBar(color: bubble, widthFactor: 0.85),
          ],
        ),
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.color, required this.widthFactor});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

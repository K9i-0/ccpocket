import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../models/settings_catalog.dart';

extension SettingsCategoryVisuals on SettingsCategory {
  String title(AppLocalizations l) => switch (this) {
    SettingsCategory.connection => l.settingsCategoryConnection,
    SettingsCategory.notifications => l.settingsCategoryNotifications,
    SettingsCategory.usage => l.settingsCategoryUsage,
    SettingsCategory.appearance => l.settingsCategoryAppearance,
    SettingsCategory.input => l.settingsCategoryInput,
    SettingsCategory.agents => l.settingsCategoryAgents,
    SettingsCategory.git => l.settingsCategoryGit,
    SettingsCategory.support => l.settingsCategorySupport,
    SettingsCategory.about => l.settingsCategoryAbout,
  };

  IconData get icon => switch (this) {
    SettingsCategory.connection => Icons.lan_rounded,
    SettingsCategory.notifications => Icons.notifications_rounded,
    SettingsCategory.usage => Icons.speed_rounded,
    SettingsCategory.appearance => Icons.palette_rounded,
    SettingsCategory.input => Icons.chat_bubble_rounded,
    SettingsCategory.agents => Icons.smart_toy_rounded,
    SettingsCategory.git => Icons.difference_rounded,
    SettingsCategory.support => Icons.favorite_rounded,
    SettingsCategory.about => Icons.info_rounded,
  };

  /// Accent hue for the category. Tuned to read well on light and dark.
  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      SettingsCategory.connection =>
        dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
      SettingsCategory.notifications =>
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      SettingsCategory.usage =>
        dark ? const Color(0xFF34D399) : const Color(0xFF059669),
      SettingsCategory.appearance =>
        dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      SettingsCategory.input =>
        dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
      SettingsCategory.agents =>
        dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
      SettingsCategory.git =>
        dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      SettingsCategory.support =>
        dark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
      SettingsCategory.about =>
        dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    };
  }

  Key get tileKey => ValueKey('settings_category_$name');
}

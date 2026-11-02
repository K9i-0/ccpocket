import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../sections/about_settings_section.dart';
import '../sections/agents_settings_section.dart';
import '../sections/appearance_settings_section.dart';
import '../sections/connection_settings_section.dart';
import '../sections/git_settings_section.dart';
import '../sections/input_settings_section.dart';
import '../sections/notification_settings_section.dart';
import '../sections/support_settings_section.dart';
import 'settings_category_visuals.dart';
import 'settings_tiles.dart';
import 'settings_visibility_builder.dart';
import 'usage_section.dart';

/// Which row a category should reveal when it opens.
@immutable
class SettingsHighlightRequest {
  const SettingsHighlightRequest(this.entryId, this.requestId);

  final String entryId;
  final int requestId;
}

/// Scrollable content of one settings category.
class SettingsCategoryBody extends StatelessWidget {
  const SettingsCategoryBody({
    super.key,
    required this.category,
    required this.environment,
    required this.onUpdateBridge,
    this.highlight,
    this.showHeader = false,
  });

  final SettingsCategory category;
  final ValueListenable<SettingsEnvironment> environment;
  final ValueChanged<MachineWithStatus> onUpdateBridge;
  final SettingsHighlightRequest? highlight;

  /// Shows a large title, used in the two-pane layout.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SettingsAccent(
      color: category.color(brightness),
      child: SettingsHighlightScope(
        entryId: highlight?.entryId,
        requestId: highlight?.requestId ?? 0,
        child: SettingsVisibilityBuilder(
          environment: environment,
          builder: (context, state, visibility, env) {
            final section = switch (category) {
              SettingsCategory.connection => ConnectionSettingsSection(
                state: state,
                visibility: visibility,
                onUpdateBridge: onUpdateBridge,
              ),
              SettingsCategory.notifications => NotificationSettingsSection(
                state: state,
                visibility: visibility,
              ),
              SettingsCategory.usage => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SettingsItem(
                  id: SettingsEntryIds.usage,
                  framed: true,
                  child: UsageSection(
                    bridgeService: context.read<BridgeService>(),
                    showTitle: false,
                  ),
                ),
              ),
              SettingsCategory.appearance => AppearanceSettingsSection(
                state: state,
                visibility: visibility,
                environment: env,
              ),
              SettingsCategory.input => InputSettingsSection(
                state: state,
                visibility: visibility,
              ),
              SettingsCategory.agents => AgentsSettingsSection(
                state: state,
                visibility: visibility,
              ),
              SettingsCategory.git => GitSettingsSection(state: state),
              SettingsCategory.support => SupportSettingsSection(
                visibility: visibility,
              ),
              SettingsCategory.about => AboutSettingsSection(
                visibility: visibility,
              ),
            };
            return SingleChildScrollView(
              key: PageStorageKey('settings_category_${category.name}'),
              padding: EdgeInsets.only(
                bottom: 32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader) _CategoryHeader(category: category),
                  section,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          SettingsCategoryBadge(
            icon: category.icon,
            color: category.color(theme.brightness),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category.title(l),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen page for one category (single-pane layout).
class SettingsCategoryPage extends StatelessWidget {
  const SettingsCategoryPage({
    super.key,
    required this.category,
    required this.environment,
    required this.onUpdateBridge,
    this.highlight,
  });

  final SettingsCategory category;
  final ValueListenable<SettingsEnvironment> environment;
  final ValueChanged<MachineWithStatus> onUpdateBridge;
  final SettingsHighlightRequest? highlight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      key: ValueKey('settings_category_page_${category.name}'),
      appBar: AppBar(title: Text(category.title(l))),
      body: SettingsCategoryBody(
        category: category,
        environment: environment,
        onUpdateBridge: onUpdateBridge,
        highlight: highlight,
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_tiles.dart';
import '../data/local_bridge_models.dart';
import 'copyable_command.dart';

/// Checklist of the tools ccpocket relies on, with install commands.
class LocalBridgeToolsCard extends StatelessWidget {
  const LocalBridgeToolsCard({
    super.key,
    required this.tools,
    required this.loading,
    required this.unsupported,
    required this.onRecheck,
  });

  final LocalBridgeTools? tools;
  final bool loading;

  /// The Bridge is too old to report tools.
  final bool unsupported;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final report = tools;

    return SettingsCard(
      key: const ValueKey('local_bridge_tools_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unsupported
                        ? l.localBridgeToolsUnsupported
                        : report == null
                        ? ''
                        : report.ready
                        ? l.localBridgeToolsReady
                        : l.localBridgeToolsNotReady,
                    key: const ValueKey('local_bridge_tools_summary'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: report != null && !report.ready
                          ? cs.error
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (!unsupported)
                  TextButton.icon(
                    key: const ValueKey('local_bridge_tools_recheck_button'),
                    onPressed: onRecheck,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.localBridgeToolRecheck),
                  ),
              ],
            ),
          ),
          if (report != null)
            for (final tool in report.tools) ...[
              const SettingsDivider(),
              LocalBridgeToolTile(tool: tool),
            ],
        ],
      ),
    );
  }
}

enum _ToolState { ready, needsSetup, missing }

/// One tool: state at a glance, install / sign-in commands when expanded.
class LocalBridgeToolTile extends StatelessWidget {
  const LocalBridgeToolTile({super.key, required this.tool});

  final LocalBridgeTool tool;

  String _description(AppLocalizations l) => switch (tool.id) {
    'node' => l.localBridgeToolDescNode,
    'git' => l.localBridgeToolDescGit,
    'claude' => l.localBridgeToolDescClaude,
    'codex' => l.localBridgeToolDescCodex,
    'antigravity' => l.localBridgeToolDescAntigravity,
    'gh' => l.localBridgeToolDescGh,
    'tailscale' => l.localBridgeToolDescTailscale,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = tool.ready
        ? _ToolState.ready
        : tool.installed
        ? _ToolState.needsSetup
        : _ToolState.missing;
    final optional = tool.requirement == LocalBridgeToolRequirement.optional;
    final (icon, color, stateLabel) = switch (state) {
      _ToolState.ready => (
        Icons.check_circle_rounded,
        Colors.green,
        l.localBridgeToolReady,
      ),
      _ToolState.needsSetup => (
        Icons.error_rounded,
        cs.tertiary,
        l.localBridgeToolNeedsSetup,
      ),
      _ToolState.missing => (
        optional ? Icons.remove_circle_outline_rounded : Icons.cancel_rounded,
        optional ? cs.onSurfaceVariant : cs.error,
        l.localBridgeToolNotInstalled,
      ),
    };
    final requirement = switch (tool.requirement) {
      LocalBridgeToolRequirement.required => l.localBridgeToolRequired,
      LocalBridgeToolRequirement.agent => l.localBridgeToolAgent,
      LocalBridgeToolRequirement.optional => l.localBridgeToolOptional,
    };
    final subtitle = [
      requirement,
      if (state == _ToolState.ready && tool.version != null)
        tool.version!
      else
        stateLabel,
    ].join(' · ');
    final docsUrl = Uri.tryParse(tool.docsUrl);

    // Give ExpansionTile its own PageStorageKey so it never inherits a parent
    // scrollable's PageStorageKey (which stores a double scroll offset and
    // throws a cast error when ExpansionTile reads bool? on remount).
    return KeyedSubtree(
      key: ValueKey('local_bridge_tool_tile:${tool.id}'),
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'local_bridge_tool_tile_expanded:${tool.id}',
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: color),
        title: Text(tool.name),
        subtitle: Text(subtitle),
        initiallyExpanded: state != _ToolState.ready && !optional,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _description(l),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (tool.message != null) ...[
            const SizedBox(height: 4),
            Text(tool.message!, style: theme.textTheme.bodySmall),
          ],
          if (state == _ToolState.missing &&
              tool.installCommands.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.localBridgeToolInstall, style: theme.textTheme.labelMedium),
            for (final command in tool.installCommands) ...[
              const SizedBox(height: 6),
              CopyableCommand(command: command.command, label: command.label),
            ],
          ],
          if (state == _ToolState.needsSetup && tool.setupCommand != null) ...[
            const SizedBox(height: 10),
            Text(l.localBridgeToolSetup, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            CopyableCommand(command: tool.setupCommand!),
          ],
          if (state != _ToolState.ready &&
              (tool.installCommands.isNotEmpty ||
                  tool.setupCommand != null)) ...[
            const SizedBox(height: 6),
            Text(
              l.localBridgeToolRunInTerminal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (docsUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('local_bridge_tool_docs_button:${tool.id}'),
                onPressed: () =>
                    launchUrl(docsUrl, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l.localBridgeToolDocs),
              ),
            ),
        ],
      ),
    );
  }
}

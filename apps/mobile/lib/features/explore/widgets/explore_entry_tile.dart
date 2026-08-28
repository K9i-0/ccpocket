import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../state/explore_state.dart';

class ExploreEntryTile extends StatelessWidget {
  final ExploreEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onShareFile;
  final bool isHighlighted;

  const ExploreEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onShareFile,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ignoredColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.62);
    return ListTile(
      key: ValueKey('explore_entry_${entry.relativePath}'),
      tileColor: isHighlighted
          ? Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.4)
          : null,
      dense: true,
      leading: Icon(
        entry.isDirectory ? Icons.folder_outlined : Icons.description_outlined,
        size: 20,
        color: entry.isIgnored ? ignoredColor : null,
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: entry.isIgnored ? TextStyle(color: ignoredColor) : null,
      ),
      subtitle: entry.isDirectory
          ? null
          : Text(
              entry.isIgnored
                  ? 'Ignored · ${entry.relativePath}'
                  : entry.relativePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: entry.isIgnored ? ignoredColor : null,
              ),
            ),
      trailing: entry.isDirectory
          ? const Icon(Icons.chevron_right, size: 18)
          : onShareFile == null
          ? null
          : PopupMenuButton<void>(
              key: ValueKey(
                'explore_entry_actions_${entry.relativePath}_button',
              ),
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              itemBuilder: (context) => [
                PopupMenuItem<void>(
                  key: ValueKey(
                    'explore_entry_share_${entry.relativePath}_button',
                  ),
                  onTap: onShareFile,
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context).fileTransferShareOrSave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ProjectStartChoices extends StatelessWidget {
  const ProjectStartChoices({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const ValueKey('create_new_project_button'),
          leading: const Icon(Icons.create_new_folder_outlined),
          title: Text(l.newProject),
          onTap: () => Navigator.pop(context, 'new'),
        ),
        ListTile(
          key: const ValueKey('open_existing_project_button'),
          leading: const Icon(Icons.folder_open),
          title: Text(l.existingProject),
          onTap: () => Navigator.pop(context, 'existing'),
        ),
        ListTile(
          key: const ValueKey('open_multi_project_button'),
          leading: const Icon(Icons.folder_copy_outlined),
          title: Text(l.multiProjectStart),
          trailing: IconButton(
            key: const ValueKey('multi_project_hint_button'),
            tooltip: l.projects,
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(l.projects),
                content: Text(l.multiProjectHint),
              ),
            ),
          ),
          onTap: () => Navigator.pop(context, 'multi'),
        ),
      ],
    );
  }
}

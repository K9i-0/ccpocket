import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../providers/bridge_cubits.dart';
import '../../../services/bridge_service.dart';
import '../../../widgets/directory_browser_sheet.dart';
import '../../../widgets/project_sheet_layout.dart';

Future<void> showProjectManagerSheet({
  required BuildContext context,
  required BridgeService bridge,
  required bool showHiddenDirectories,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  bridge.requestProjects();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ProjectManagerSheet(
      bridge: bridge,
      showHiddenDirectories: showHiddenDirectories,
    ),
  );
}

class _ProjectManagerSheet extends StatelessWidget {
  const _ProjectManagerSheet({
    required this.bridge,
    required this.showHiddenDirectories,
  });

  final BridgeService bridge;
  final bool showHiddenDirectories;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<WorkspaceProjectsCubit, ProjectsMessage>(
      builder: (context, state) => ProjectSheetLayout(
        title: l.projects,
        footer: FilledButton.icon(
          key: const ValueKey('project_create_button'),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(l.createProject),
          onPressed: () => _showProjectEditor(context),
        ),
        children: [
          Text(l.multiProjectHint),
          const SizedBox(height: 20),
          for (final project in state.projects) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: ValueKey('project_${project.id}'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(project.name),
                subtitle: Text(
                  '${l.primary}: ${pathBasename(project.primaryPath)}\n${l.sourceFolders}: ${project.rootPaths.length}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showProjectEditor(context, project: project),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l.noProjectsYet)),
            ),
        ],
      ),
    );
  }

  Future<void> _showProjectEditor(
    BuildContext context, {
    WorkspaceProject? project,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ProjectEditorSheet(
        bridge: bridge,
        project: project,
        showHiddenDirectories: showHiddenDirectories,
      ),
    );
  }
}

class _ProjectEditorSheet extends StatefulWidget {
  const _ProjectEditorSheet({
    required this.bridge,
    required this.project,
    required this.showHiddenDirectories,
  });

  final BridgeService bridge;
  final WorkspaceProject? project;
  final bool showHiddenDirectories;

  @override
  State<_ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<_ProjectEditorSheet> {
  late final TextEditingController _nameController;
  late List<String> _roots;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _roots = [...?widget.project?.rootPaths];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addFolder() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showDirectoryBrowserSheet(
      context: context,
      bridge: widget.bridge,
      initialPath: _roots.firstOrNull,
      allowedRoots: widget.bridge.allowedDirs,
      includeHidden: widget.showHiddenDirectories,
    );
    if (!mounted || selected == null || _roots.contains(selected)) return;
    setState(() => _roots = [..._roots, selected]);
  }

  void _makePrimary(String root) {
    setState(() => _roots = [root, ..._roots.where((item) => item != root)]);
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty || _roots.isEmpty) return;
    final project = widget.project;
    if (project == null) {
      widget.bridge.createProject(name: name, rootPaths: _roots);
    } else {
      widget.bridge.updateProject(
        projectId: project.id,
        name: name,
        rootPaths: _roots,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.project != null;
    final l = AppLocalizations.of(context);
    return ProjectSheetLayout(
      title: editing ? l.editProject : l.createProject,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            key: const ValueKey('project_save_button'),
            onPressed:
                _nameController.text.trim().isNotEmpty && _roots.isNotEmpty
                ? _save
                : null,
            child: Text(editing ? l.save : l.createProject),
          ),
          if (editing)
            TextButton(
              key: const ValueKey('project_delete_button'),
              onPressed: () {
                widget.bridge.removeProject(widget.project!.id);
                Navigator.pop(context);
              },
              child: Text(
                l.removeWorkspaceProject,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      children: [
        TextField(
          key: const ValueKey('project_name_field'),
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(labelText: l.projectName),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Text(l.sourceFolders, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final (index, root) in _roots.indexed)
          _ProjectFolderTile(
            key: ValueKey('project_folder_$root'),
            path: root,
            allowedRoots: widget.bridge.allowedDirs,
            isPrimary: index == 0,
            onMakePrimary: () => _makePrimary(root),
            onRemove: () => setState(() => _roots.remove(root)),
          ),
        TextButton.icon(
          key: const ValueKey('project_add_folder_button'),
          onPressed: _addFolder,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(l.addFolder),
        ),
      ],
    );
  }
}

/// One folder of a multi-project. The name is the title, so the second line
/// only says where the folder is; the full path is on long press.
class _ProjectFolderTile extends StatelessWidget {
  const _ProjectFolderTile({
    super.key,
    required this.path,
    required this.allowedRoots,
    required this.isPrimary,
    required this.onMakePrimary,
    required this.onRemove,
  });

  final String path;
  final List<String> allowedRoots;
  final bool isPrimary;
  final VoidCallback onMakePrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final details = [
      if (isPrimary) l.primary,
      ?folderLocationLabel(path, allowedRoots),
    ].join(' · ');
    return Tooltip(
      message: path,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(isPrimary ? Icons.star : Icons.folder_outlined, size: 20),
        title: Text(
          pathBasename(path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: details.isEmpty
            ? null
            : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPrimary)
              IconButton(
                tooltip: l.makePrimary,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.star_border),
                onPressed: onMakePrimary,
              ),
            IconButton(
              tooltip: l.removeFolder,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

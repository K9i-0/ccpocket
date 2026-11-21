import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../features/session_list/session_list_screen.dart' show shortenPath;
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../../theme/app_theme.dart';
import '../directory_browser_sheet.dart';
import 'project_choice.dart';

class NewSessionRecentProjectsSection extends StatelessWidget {
  final AppColors appColors;
  final Color accentColor;
  final List<NewSessionProjectChoice> projects;
  final String selectedPath;
  final String? selectedProjectId;
  final String? workspaceKind;
  final ValueChanged<NewSessionProjectChoice> onProjectSelected;
  final Future<void> Function(String path)? onProjectRemoved;
  final bool canExpand;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const NewSessionRecentProjectsSection({
    super.key,
    required this.appColors,
    required this.accentColor,
    required this.projects,
    required this.selectedPath,
    required this.selectedProjectId,
    required this.workspaceKind,
    required this.onProjectSelected,
    this.onProjectRemoved,
    this.canExpand = false,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.recentProjects,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: appColors.subtleText,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final project in projects)
          _RecentProjectRow(
            project: project,
            appColors: appColors,
            accentColor: accentColor,
            isSelected: switch (project.kind) {
              NewSessionProjectChoiceKind.workspaceProject =>
                selectedProjectId == project.id,
              NewSessionProjectChoiceKind.workspaceFolder =>
                selectedProjectId == null &&
                    workspaceKind == null &&
                    selectedPath == project.path,
              NewSessionProjectChoiceKind.recent =>
                selectedProjectId == null &&
                    workspaceKind == null &&
                    selectedPath == project.path,
            },
            onTap: () => onProjectSelected(project),
            onProjectRemoved: project.kind == NewSessionProjectChoiceKind.recent
                ? onProjectRemoved
                : null,
          ),
        if (canExpand)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: onToggleExpand,
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: Text(
                isExpanded ? l.showLess : l.showMore,
                style: const TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentProjectRow extends StatelessWidget {
  const _RecentProjectRow({
    required this.project,
    required this.appColors,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    this.onProjectRemoved,
  });

  final NewSessionProjectChoice project;
  final AppColors appColors;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final Future<void> Function(String path)? onProjectRemoved;

  @override
  Widget build(BuildContext context) {
    final tile = _ProjectTile(
      key: ValueKey(project.tileKey),
      project: project,
      appColors: appColors,
      accentColor: accentColor,
      isSelected: isSelected,
      onTap: onTap,
    );
    if (onProjectRemoved == null) return tile;
    return Slidable(
      key: ValueKey('project_${project.path}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.18,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onProjectRemoved?.call(project.path),
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      child: tile,
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final NewSessionProjectChoice project;
  final AppColors appColors;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectTile({
    super.key,
    required this.project,
    required this.appColors,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (project.kind) {
      NewSessionProjectChoiceKind.workspaceProject =>
        Icons.folder_copy_outlined,
      NewSessionProjectChoiceKind.workspaceFolder => Icons.folder_outlined,
      NewSessionProjectChoiceKind.recent => Icons.folder_outlined,
    };
    final identityColor = switch (project.kind) {
      NewSessionProjectChoiceKind.workspaceProject => colorScheme.primary,
      NewSessionProjectChoiceKind.workspaceFolder => appColors.subtleText,
      NewSessionProjectChoiceKind.recent => appColors.subtleText,
    };
    final subtitle = switch (project.kind) {
      NewSessionProjectChoiceKind.workspaceProject ||
      NewSessionProjectChoiceKind.workspaceFolder ||
      NewSessionProjectChoiceKind.recent => shortenPath(project.path),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                icon,
                size: 22,
                color: isSelected ? accentColor : identityColor,
              ),
              title: Text(
                project.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? accentColor : null,
                ),
              ),
              subtitle: Text(
                project.kind == NewSessionProjectChoiceKind.workspaceProject
                    ? '${AppLocalizations.of(context).multiProjectShort} · $subtitle'
                    : subtitle,
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, size: 20, color: accentColor)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AllowedDirChips extends StatelessWidget {
  final List<String> dirs;
  final ValueChanged<String> onSelected;

  const _AllowedDirChips({required this.dirs, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: dirs.map((dir) {
          final trimmed = dir.endsWith('/')
              ? dir.substring(0, dir.length - 1)
              : dir;
          final label = trimmed.split('/').last;
          return ActionChip(
            label: Text(label),
            avatar: const Icon(Icons.folder, size: 16),
            onPressed: () => onSelected(dir),
          );
        }).toList(),
      ),
    );
  }
}

class _PathInput extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final VoidCallback? onBrowse;
  final VoidCallback onChanged;

  const _PathInput({
    required this.controller,
    required this.decoration,
    this.onBrowse,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = onBrowse == null
        ? decoration
        : decoration.copyWith(
            suffixIcon: IconButton(
              key: const ValueKey('dialog_project_path_browse_button'),
              tooltip: AppLocalizations.of(context).browseDirectory,
              onPressed: onBrowse,
              icon: const Icon(Icons.folder_open),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const ValueKey('dialog_project_path'),
        controller: controller,
        decoration: fieldDecoration,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

/// Chip labels for a list of folders: the folder name, or the whole path for
/// folders whose name appears more than once. The whole path stays available
/// as the chip's tooltip.
List<String> folderChipLabels(List<String> paths) {
  final names = [for (final path in paths) pathBasename(path)];
  return [
    for (final (index, path) in paths.indexed)
      names.where((name) => name == names[index]).length > 1
          ? shortenPath(path)
          : names[index],
  ];
}

class NewSessionProjectSectionHeader extends StatelessWidget {
  const NewSessionProjectSectionHeader({
    super.key,
    this.onCreate,
    this.onMulti,
  });
  final VoidCallback? onCreate;
  final VoidCallback? onMulti;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.sessionProject,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('create_new_project_button'),
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l.createProjectShort),
          ),
          TextButton.icon(
            key: const ValueKey('manage_projects_button'),
            onPressed: onMulti,
            icon: const Icon(Icons.folder_copy_outlined, size: 16),
            label: Text(l.multiProjectShort),
          ),
        ],
      ),
    );
  }
}

class NewSessionSelectedProjectCard extends StatelessWidget {
  const NewSessionSelectedProjectCard({
    super.key,
    required this.path,
    this.name,
    required this.isMulti,
    this.onChange,
  });
  final String path;
  final String? name;
  final bool isMulti;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          key: const ValueKey('selected_project_card'),
          leading: Icon(
            isMulti ? Icons.folder_copy_outlined : Icons.folder_outlined,
          ),
          title: Text(
            path.isEmpty ? l.chooseExistingFolder : name ?? pathBasename(path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: path.isEmpty
              ? null
              : Text(
                  path,
                  key: const ValueKey('selected_project_path'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
          trailing: onChange == null || path.isEmpty
              ? null
              : TextButton(
                  key: const ValueKey('change_project_location_button'),
                  onPressed: onChange,
                  child: Text(
                    path.isEmpty
                        ? l.chooseExistingFolder
                        : l.changeProjectLocation,
                  ),
                ),
          onTap: onChange,
        ),
      ),
    );
  }
}

class NewSessionProjectLocationSheet extends StatefulWidget {
  const NewSessionProjectLocationSheet({
    super.key,
    required this.initialPath,
    required this.bridge,
    required this.includeHidden,
  });
  final String initialPath;
  final BridgeService? bridge;
  final bool includeHidden;

  @override
  State<NewSessionProjectLocationSheet> createState() =>
      _ProjectLocationSheetState();
}

class _ProjectLocationSheetState extends State<NewSessionProjectLocationSheet> {
  late final _controller = TextEditingController(text: widget.initialPath);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final bridge = widget.bridge;
    if (bridge == null) return;
    final path = await showDirectoryBrowserSheet(
      context: context,
      bridge: bridge,
      initialPath: _controller.text.trim().isEmpty
          ? null
          : _controller.text.trim(),
      allowedRoots: bridge.allowedDirs,
      includeHidden: widget.includeHidden,
    );
    if (mounted && path != null) setState(() => _controller.text = path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.chooseExistingFolder,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey(
                      'project_location_dismiss_keyboard_button',
                    ),
                    tooltip: l.dismissKeyboard,
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    icon: const Icon(Icons.keyboard_hide),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if ((widget.bridge?.allowedDirs.length ?? 0) > 1)
              _AllowedDirChips(
                dirs: widget.bridge!.allowedDirs,
                onSelected: (path) => setState(() => _controller.text = path),
              ),
            _PathInput(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l.projectPath,
                hintText: l.projectPathHint,
                border: const OutlineInputBorder(),
              ),
              onBrowse: widget.bridge == null ? null : _browse,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('confirm_project_location_button'),
                    onPressed: _controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, _controller.text.trim()),
                    child: Text(l.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
